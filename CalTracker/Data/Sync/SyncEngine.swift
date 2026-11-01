import Foundation
import Observation
import SwiftData

/// Keeps the log and the goal in step with the Gramwise backend, in both directions.
///
/// One pass pushes local changes, reconciles the goal (the newest day's goal wins), then pulls the days that
/// changed on the server and restores what's missing. When the server refuses the push or the goal, the other
/// steps still run, so this device keeps getting the other devices' changes. Overlapping requests share one
/// running pass, plus one more afterwards when something changed during it.
@Observable
final class SyncEngine {
    /// How long `scheduleSync()` waits for more changes before syncing.
    static let defaultDebounce: Duration = .seconds(2)

    /// Where sync stands.
    private(set) var status: SyncStatus

    /// When the last pass finished successfully, or `nil` if none has for this account.
    private(set) var lastSyncedAt: Date?

    @ObservationIgnored private let modelContext: ModelContext
    @ObservationIgnored private let targets: TargetsStore
    @ObservationIgnored private let account: AccountSession
    @ObservationIgnored private let api: any GramwiseAPI
    @ObservationIgnored private let foodLookup: any FoodLookup
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let calendar: Calendar
    @ObservationIgnored private let debounce: Duration
    @ObservationIgnored private let now: () -> Date

    @ObservationIgnored private var currentPass: Task<Void, Never>?
    @ObservationIgnored private var needsAnotherPass = false
    @ObservationIgnored private var debounceTask: Task<Void, Never>?

    /// Creates an engine that syncs `modelContext` and `targets` for `account`'s user.
    ///
    /// - Parameters:
    ///   - defaults: Where the sync markers (account, cursor, goal push time) are kept.
    ///   - calendar: The calendar whose days the log is grouped into on the server.
    ///   - debounce: How long `scheduleSync()` waits for more changes.
    ///   - now: The clock, so tests can control it.
    init(
        modelContext: ModelContext,
        targets: TargetsStore,
        account: AccountSession,
        api: any GramwiseAPI,
        foodLookup: any FoodLookup,
        defaults: UserDefaults,
        calendar: Calendar = .current,
        debounce: Duration = SyncEngine.defaultDebounce,
        now: @escaping () -> Date = { .now }
    ) {
        self.modelContext = modelContext
        self.targets = targets
        self.account = account
        self.api = api
        self.foodLookup = foodLookup
        self.defaults = defaults
        self.calendar = calendar
        self.debounce = debounce
        self.now = now
        let lastSyncedAt = defaults.object(forKey: Key.lastSyncedAt) as? Date
        self.lastSyncedAt = lastSyncedAt
        status = account.isSignedIn ? lastSyncedAt.map(SyncStatus.upToDate) ?? .syncing : .signedOut
    }

    /// Starts a sync pass now, or asks the running one to go again once it finishes.
    ///
    /// - Returns: The running pass, which tests can await.
    @discardableResult
    func requestSync() -> Task<Void, Never> {
        debounceTask?.cancel()
        debounceTask = nil
        if let currentPass {
            needsAnotherPass = true
            return currentPass
        }
        let pass = Task(name: "Gramwise sync") {
            await runPasses()
        }
        currentPass = pass
        return pass
    }

    /// Syncs after `debounce`, restarting the wait on every call, so a burst of edits becomes one push.
    func scheduleSync() {
        guard account.isSignedIn else { return }
        debounceTask?.cancel()
        debounceTask = Task(name: "Gramwise sync debounce") { [debounce] in
            do {
                try await Task.sleep(for: debounce)
            } catch {
                // A newer change restarted the wait.
                return
            }
            requestSync()
        }
    }

    private func runPasses() async {
        repeat {
            needsAnotherPass = false
            await syncOnce()
        } while needsAnotherPass
        currentPass = nil
    }

    private func syncOnce() async {
        // Reads the saved sign-in on the first pass, and on later ones until the Keychain can be read.
        await account.restore()
        guard let user = account.user else {
            status = .signedOut
            return
        }

        let previousStatus = status
        status = .syncing
        do {
            try resetMarkersIfAccountChanged(to: user.id)
            var refusal: GramwiseAPIError?
            for step in [push, syncGoal, pull] as [() async throws -> Void] {
                do {
                    try await step()
                } catch let error as GramwiseAPIError where error.isRefusal {
                    // Sending it again won't help, but the other steps can still succeed.
                    refusal = refusal ?? error
                }
            }
            if let refusal {
                throw refusal
            }
            let finishedAt = now()
            lastSyncedAt = finishedAt
            defaults.set(finishedAt, forKey: Key.lastSyncedAt)
            status = .upToDate(finishedAt)
        } catch is CancellationError {
            status = previousStatus
        } catch GramwiseAPIError.sessionExpired {
            status = .signedOut
        } catch {
            status = .failed(Self.message(for: error))
        }
    }

    /// The message for a failed pass. A refusal gets a sync message, because the usual one for `invalidInput`
    /// is about the account form.
    static func message(for error: any Error) -> LocalizedStringResource {
        if let apiError = error as? GramwiseAPIError, apiError.isRefusal {
            return .errorSyncRefused
        }
        return userMessage(for: error)
    }

    // MARK: - Account switches

    /// Forgets what was synced with another account, so this device's log uploads to the new one.
    private func resetMarkersIfAccountChanged(to userID: UUID) throws {
        guard defaults.string(forKey: Key.userID) != userID.uuidString else { return }

        let synced = try modelContext.fetch(FetchDescriptor<FoodLogEntry>(
            predicate: #Predicate { $0.syncedDay != nil }
        ))
        for entry in synced {
            entry.syncedDay = nil
        }
        try modelContext.delete(model: FoodLogDeletion.self)
        try modelContext.save()

        for key in [Key.cursor, Key.goalPushedAt, Key.lastSyncedAt, Key.unconfirmed] {
            defaults.removeObject(forKey: key)
        }
        lastSyncedAt = nil
        defaults.set(userID.uuidString, forKey: Key.userID)
    }

    // MARK: - Push

    /// Sends entries that haven't been pushed and the pending deletions, in batches the server accepts.
    ///
    /// Entries that don't fit in their day stay on this device, unsynced.
    private func push() async throws {
        try tombstoneDeletionsFromUnconfirmedPush()

        let pending = try modelContext.fetch(FetchDescriptor<FoodLogEntry>(
            predicate: FoodLogEntry.notSynced,
            sortBy: [SortDescriptor(\.loggedAt)]
        ))
        var room: [String: Int] = [:]
        var added: [PendingFood] = []
        for entry in pending where Self.isSyncable(entry) {
            let day = dayKey(for: entry.loggedAt)
            let space = try room[day] ?? Self.maxFoodsPerDay - modelContext.fetchCount(FetchDescriptor(predicate: FoodLogEntry.synced(onDay: day)))
            guard space > 0 else {
                room[day] = 0
                continue
            }
            room[day] = space - 1
            // Entries from schema version 1 get their ID here, saved before it's sent.
            let syncID = entry.syncID ?? UUID()
            entry.syncID = syncID
            added.append((entry, GramwiseAddedFood(logDate: day, food: Self.loggedFood(for: entry, id: syncID))))
        }
        try modelContext.save()

        let removed = try modelContext.fetch(FetchDescriptor<FoodLogDeletion>()).map { tombstone in
            (tombstone: tombstone, food: GramwiseRemovedFood(logDate: tombstone.day, entryID: tombstone.syncID))
        }

        let addedBatches = Self.batches(of: added, size: GramwiseLogChanges.maxCount)
        let removedBatches = Self.batches(of: removed, size: GramwiseLogChanges.maxCount)
        var refusal: GramwiseAPIError?
        for index in 0..<max(addedBatches.count, removedBatches.count) {
            // After a refused day, the rest of this pass's additions wait too.
            let addedBatch = index < addedBatches.count && refusal == nil ? addedBatches[index] : []
            let removedBatch = index < removedBatches.count ? removedBatches[index] : []
            do {
                try await send(addedBatch, removedBatch)
            } catch GramwiseAPIError.tooManyFoods where addedBatch.isEmpty == false {
                // Another device filled a day this one hasn't pulled yet. The pull brings that day's foods, so the
                // next pass holds back the entries that don't fit. The removals can still go now.
                refusal = .tooManyFoods
                try await send([], removedBatch)
            }
        }
        if let refusal {
            throw refusal
        }
    }

    /// Sends one batch, then marks its entries as synced and drops its tombstones.
    private func send(_ added: ArraySlice<PendingFood>, _ removed: ArraySlice<PendingRemoval>) async throws {
        guard added.isEmpty == false || removed.isEmpty == false else { return }
        let changes = GramwiseLogChanges(added: added.map(\.food), removed: removed.map(\.food))
        rememberUnconfirmed(added.map(\.food))
        do {
            _ = try await account.withAccessToken { [api] accessToken in
                try await api.pushChanges(changes, accessToken: accessToken)
            }
        } catch let error as GramwiseAPIError where error.isRefusal {
            // The server answered without storing anything.
            defaults.removeObject(forKey: Key.unconfirmed)
            throw error
        }

        for (entry, food) in added {
            if entry.isDeleted || entry.modelContext == nil {
                // Deleted while the push was in flight, before it counted as synced, so the server needs a removal.
                modelContext.insert(FoodLogDeletion(syncID: food.food.entryID, day: food.logDate))
            } else {
                entry.syncedDay = food.logDate
            }
        }
        for (tombstone, _) in removed where tombstone.isDeleted == false {
            modelContext.delete(tombstone)
        }
        try modelContext.save()
        defaults.removeObject(forKey: Key.unconfirmed)
    }

    /// Keeps the entries being sent, with their days, until the response is handled.
    ///
    /// If the response never arrives, for example after a timeout or when the app is suspended, the server may
    /// have stored them even though they don't count as synced here.
    private func rememberUnconfirmed(_ foods: [GramwiseAddedFood]) {
        guard foods.isEmpty == false else { return }
        let days = Dictionary(foods.map { ($0.food.entryID.uuidString, $0.logDate) }) { first, _ in first }
        defaults.set(days, forKey: Key.unconfirmed)
    }

    /// Adds a removal for each entry of an earlier push whose response never arrived, if it has been deleted since.
    ///
    /// Such an entry didn't count as synced, so deleting it left no tombstone. The server may still have it, and
    /// without a removal the next pull would restore it. The server ignores removals of entries it doesn't have.
    private func tombstoneDeletionsFromUnconfirmedPush() throws {
        guard let unconfirmed = defaults.dictionary(forKey: Key.unconfirmed) as? [String: String] else { return }
        let identified = try modelContext.fetch(FetchDescriptor<FoodLogEntry>(predicate: #Predicate { $0.syncID != nil }))
        let tombstoned = try modelContext.fetch(FetchDescriptor<FoodLogDeletion>()).map(\.syncID)
        let known = Set(identified.compactMap(\.syncID)).union(tombstoned)
        for (id, day) in unconfirmed {
            guard let syncID = UUID(uuidString: id), known.contains(syncID) == false else { continue }
            modelContext.insert(FoodLogDeletion(syncID: syncID, day: day))
        }
        try modelContext.save()
        defaults.removeObject(forKey: Key.unconfirmed)
    }

    // MARK: - Goal

    /// Pushes the local goal if it changed since the last push, otherwise takes the server's.
    ///
    /// The server keeps one goal per day and refuses a goal older than its current one: one from an earlier day,
    /// or from earlier the same day. A refused goal is replaced by the server's. When the server has no goal but
    /// this device does, the device's goal is pushed again, so a server that lost it (for example, after its data
    /// was reset) gets it back.
    private func syncGoal() async throws {
        let savedAt = targets.updatedAt
        guard let goal = targets.goal else {
            if let remote = try await fetchGoal() {
                try adopt(remote, ifStillSavedAt: savedAt)
            }
            return
        }

        guard let savedAt else {
            // Saved before the app recorded save times. Its age is unknown, so a goal on the server wins.
            if let remote = try await fetchGoal() {
                try adopt(remote, ifStillSavedAt: nil)
            } else if targets.updatedAt == nil, let goal = targets.goal {
                let now = now()
                try targets.recordSaveTime(now)
                try await pushGoal(goal, savedAt: now)
            }
            return
        }

        let pushedAt = defaults.object(forKey: Key.goalPushedAt) as? Date ?? .distantPast
        if savedAt > pushedAt {
            try await pushGoal(goal, savedAt: savedAt)
        } else if let remote = try await fetchGoal() {
            try adopt(remote, ifStillSavedAt: savedAt)
        } else {
            try await pushGoal(goal, savedAt: savedAt)
        }
    }

    private func fetchGoal() async throws -> GramwiseGoal? {
        try await account.withAccessToken { [api] accessToken in
            try await api.goal(accessToken: accessToken)
        }
    }

    /// Sends the local goal saved at `savedAt`, dated with that moment's day in this engine's calendar.
    private func pushGoal(_ goal: WeightGoal, savedAt: Date) async throws {
        let local = GramwiseGoal(goal: goal, targets: targets.targets, updatedAt: savedAt, effectiveFrom: dayKey(for: savedAt))
        let stored: GramwiseGoal
        do {
            stored = try await account.withAccessToken { [api] accessToken in
                try await api.putGoal(local, accessToken: accessToken)
            }
        } catch GramwiseAPIError.goalOutdated {
            // A goal from a later day, or from later the same day, is already stored, and past goals can't change.
            if let remote = try await fetchGoal() {
                try adopt(remote, ifStillSavedAt: savedAt)
            }
            return
        }
        try adopt(stored, ifStillSavedAt: savedAt)
    }

    /// Makes `remote` the local goal, unless the person saved another goal here after `savedAt` while a request was
    /// in flight. The next pass pushes that one instead.
    private func adopt(_ remote: GramwiseGoal, ifStillSavedAt savedAt: Date?) throws {
        guard targets.updatedAt == savedAt else { return }
        if remote.goal != targets.goal || remote.targets != targets.targets || remote.updatedAt != savedAt {
            try targets.applyRemote(targets: remote.targets, goal: remote.goal, updatedAt: remote.updatedAt)
        }
        // It came from the server, so there's nothing to push back.
        defaults.set(remote.updatedAt, forKey: Key.goalPushedAt)
    }

    // MARK: - Pull

    /// Fetches every day changed since the stored cursor, applies them, then stores the new cursor.
    private func pull() async throws {
        var cursor = defaults.string(forKey: Key.cursor)
        // A day can change again between pages. Keep its latest version.
        var days: [String: GramwiseDailyLog] = [:]
        var hasMore = true
        var canStartOver = true
        while hasMore {
            let page: GramwiseDailyLogPage
            do {
                page = try await account.withAccessToken { [api, cursor] accessToken in
                    try await api.dailyLogs(after: cursor, accessToken: accessToken)
                }
            } catch GramwiseAPIError.invalidCursor where cursor != nil && canStartOver {
                // The server no longer accepts the cursor, for example after its data was restored from a backup.
                // Pulling every day again is safe: a day that's already here changes nothing.
                defaults.removeObject(forKey: Key.cursor)
                cursor = nil
                days.removeAll()
                canStartOver = false
                continue
            }
            for day in page.days {
                days[day.logDate] = day
            }
            cursor = page.nextCursor ?? cursor
            // Stop rather than loop forever if a server ever claims more without returning any.
            hasMore = page.hasMore && page.days.isEmpty == false
        }

        try await apply(Array(days.values))
        if let cursor {
            defaults.set(cursor, forKey: Key.cursor)
        }
    }

    /// Mirrors server days locally: removes entries deleted elsewhere, marks matches as synced, and restores missing ones.
    private func apply(_ days: [GramwiseDailyLog]) async throws {
        guard days.isEmpty == false else { return }

        let tombstoned = Set(try modelContext.fetch(FetchDescriptor<FoodLogDeletion>()).map(\.syncID))
        let identified = try modelContext.fetch(FetchDescriptor<FoodLogEntry>(predicate: #Predicate { $0.syncID != nil }))
        var local: [UUID: FoodLogEntry] = [:]
        for entry in identified {
            if let syncID = entry.syncID {
                local[syncID] = entry
            }
        }

        var missing: [(day: String, food: GramwiseLoggedFood)] = []
        for day in days {
            let remoteIDs = Set(day.foods.map(\.entryID))
            // A pushed entry the server no longer lists was deleted on another device.
            for entry in try modelContext.fetch(FetchDescriptor(predicate: FoodLogEntry.synced(onDay: day.logDate))) {
                guard let syncID = entry.syncID, remoteIDs.contains(syncID) == false else { continue }
                local[syncID] = nil
                modelContext.delete(entry)
            }

            for food in day.foods {
                if let entry = local[food.entryID] {
                    if entry.syncedDay == nil {
                        entry.syncedDay = day.logDate
                    }
                } else if tombstoned.contains(food.entryID) == false {
                    missing.append((day.logDate, food))
                }
            }
        }
        try modelContext.save()

        guard missing.isEmpty == false else { return }
        let found = await foodLookup.foods(withIDs: Set(missing.map(\.food.foodID)))
        for (day, food) in missing {
            let item = Self.restoredFood(from: food, provider: found[food.foodID])
            modelContext.insert(FoodLogEntry(
                food: item,
                grams: food.grams,
                loggedAt: food.loggedAt,
                syncID: food.entryID,
                syncedDay: day
            ))
        }
        try modelContext.save()
    }

    // MARK: - Mapping

    /// Whether the server accepts `entry`: a USDA or Open Food Facts food ID it allows and an amount it allows.
    static func isSyncable(_ entry: FoodLogEntry) -> Bool {
        entry.foodID.wholeMatch(of: /(usda|off)-[A-Za-z0-9]+/) != nil
            && entry.foodID.unicodeScalars.count <= maxFoodIDLength
            && entry.grams > 0
            && entry.grams <= maxGrams
    }

    /// The largest amount the server accepts for one entry, in grams.
    static let maxGrams = 5_000.0

    /// The longest food ID the server accepts.
    static let maxFoodIDLength = 64

    /// The longest name the server accepts, in Unicode scalars, because it counts code points rather than characters.
    static let maxNameLength = 500

    /// The most foods the server keeps for one day, counting every device's foods.
    static let maxFoodsPerDay = 200

    /// The item the server stores for `entry`, with the macros for the amount eaten.
    static func loggedFood(for entry: FoodLogEntry, id: UUID) -> GramwiseLoggedFood {
        let name = entry.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let nutrients = entry.nutrients
        return GramwiseLoggedFood(
            entryID: id,
            foodID: entry.foodID,
            name: name.isEmpty ? entry.foodID : String(String.UnicodeScalarView(name.unicodeScalars.prefix(maxNameLength))),
            grams: entry.grams,
            loggedAt: entry.loggedAt,
            energyKcal: nutrients.energy,
            proteinG: nutrients.protein,
            carbsG: nutrients.carbohydrates,
            fatG: nutrients.fat
        )
    }

    /// Rebuilds the food for a restored entry.
    ///
    /// Micronutrients come from the provider's current data when the lookup found it. The macros always come from
    /// the logged item, scaled back to 100 g, so the day's totals match what was logged.
    static func restoredFood(from food: GramwiseLoggedFood, provider: FoodItem?) -> FoodItem {
        var per100g = provider?.per100g ?? NutrientProfile()
        let factor = food.grams > 0 ? 100 / food.grams : 0
        per100g.energy = food.energyKcal.map { $0 * factor }
        per100g.protein = food.proteinG.map { $0 * factor }
        per100g.carbohydrates = food.carbsG.map { $0 * factor }
        per100g.fat = food.fatG.map { $0 * factor }

        return FoodItem(
            id: food.foodID,
            name: food.name,
            brand: provider?.brand,
            source: provider?.source ?? (food.foodID.hasPrefix("off-") ? .openFoodFacts : .usda),
            per100g: per100g
        )
    }

    /// The server day for `date` in this engine's calendar, such as `2026-10-29`.
    func dayKey(for date: Date) -> String {
        date.formatted(Date.ISO8601FormatStyle(timeZone: calendar.timeZone).year().month().day())
    }

    private static func batches<Element>(of elements: [Element], size: Int) -> [ArraySlice<Element>] {
        stride(from: 0, to: elements.count, by: size).map { start in
            elements[start..<min(start + size, elements.count)]
        }
    }

    /// An entry being pushed, with the item sent for it.
    private typealias PendingFood = (entry: FoodLogEntry, food: GramwiseAddedFood)

    /// A tombstone being pushed, with the removal sent for it.
    private typealias PendingRemoval = (tombstone: FoodLogDeletion, food: GramwiseRemovedFood)

    private enum Key {
        static let userID = "sync.userID"
        static let cursor = "sync.cursor"
        static let goalPushedAt = "sync.goalPushedAt"
        static let lastSyncedAt = "sync.lastSyncedAt"
        static let unconfirmed = "sync.unconfirmed"
    }
}
