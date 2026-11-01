import Foundation
import SwiftData
import Testing
@testable import CalTracker

@Suite(.tags(.persistence))
struct SyncEngineTests {
    private let server = FakeGramwiseAPI()
    private let banana = FoodItem.fixture(
        id: "usda-173944",
        name: "Bananas, raw",
        per100g: NutrientProfile(energy: 89, protein: 1.1, carbohydrates: 22.8, fat: 0.3, fiber: 2.6, vitaminC: 8.7)
    )
    private let nutella = FoodItem.fixture(
        id: "off-3017620422003",
        name: "Nutella",
        source: .openFoodFacts,
        per100g: NutrientProfile(energy: 539, protein: 6.3, carbohydrates: 57.5, fat: 30.9)
    )
    private let breakfast = Date(timeIntervalSince1970: 1_798_000_000) // 2026-12-23 04:26:40 UTC
    private let breakfastDay = "2026-12-23"

    private func signUp(_ email: String = "ada@example.com") async throws -> GramwiseTokenPair {
        try await server.signUp(email: email, password: "correct horse")
    }

    // MARK: - Push

    @Test func pushMarksEntriesSyncedAndServerTotalsMatch() async throws {
        let tokens = try await signUp()
        let device = SyncTestDevice(server: server, tokens: tokens)
        try device.store.log(banana, grams: 120, loggedAt: breakfast)
        try device.store.log(nutella, grams: 15, loggedAt: breakfast.addingTimeInterval(60))

        await device.sync()

        let entries = try device.entries()
        #expect(entries.allSatisfy { $0.syncedDay == breakfastDay })
        let foods = try #require(server.foods(for: tokens.user, on: breakfastDay))
        #expect(Set(foods.map(\.entryID)) == Set(entries.compactMap(\.syncID)))
        let localTotals = DailyTotals(entries: entries.map(\.nutrients))
        expectApproximately(foods.compactMap(\.energyKcal).reduce(0, +), try #require(localTotals.profile.energy))
        expectApproximately(foods.compactMap(\.fatG).reduce(0, +), try #require(localTotals.profile.fat))
        #expect(device.engine.status == .upToDate(Date(timeIntervalSince1970: 1_800_000_000)))
    }

    @Test func syncedEntriesAreNotPushedAgain() async throws {
        let device = SyncTestDevice(server: server, tokens: try await signUp())
        try device.store.log(banana, grams: 120, loggedAt: breakfast)
        await device.sync()

        await device.sync()

        #expect(server.calls.filter { $0 == "pushChanges" }.count == 1)
    }

    @Test func sampleEntriesNeverSync() async throws {
        let tokens = try await signUp()
        let device = SyncTestDevice(server: server, tokens: tokens)
        try device.store.log(.fixture(id: "sample-oats"), grams: 70, loggedAt: breakfast)

        await device.sync()

        #expect(try device.entries().first?.syncedDay == nil)
        #expect(server.dayKeys(for: tokens.user).isEmpty)
    }

    @Test func entriesFromSchemaVersion1GetASyncIDBeforeTheirFirstPush() async throws {
        let tokens = try await signUp()
        let device = SyncTestDevice(server: server, tokens: tokens)
        try device.store.log(banana, grams: 120, loggedAt: breakfast)
        let entry = try #require(try device.entries().first)
        entry.syncID = nil

        await device.sync()

        let syncID = try #require(entry.syncID)
        #expect(server.foods(for: tokens.user, on: breakfastDay)?.map(\.entryID) == [syncID])
    }

    @Test func entriesPastTheDailyLimitStayOnTheDevice() async throws {
        let tokens = try await signUp()
        let device = SyncTestDevice(server: server, tokens: tokens)
        for minute in 0...SyncEngine.maxFoodsPerDay {
            try device.store.log(banana, grams: 10, loggedAt: breakfast.addingTimeInterval(Double(minute) * 60))
        }

        await device.sync()

        #expect(device.engine.status == .upToDate(Date(timeIntervalSince1970: 1_800_000_000)))
        #expect(server.foods(for: tokens.user, on: breakfastDay)?.count == SyncEngine.maxFoodsPerDay)
        let entries = try device.entries()
        #expect(entries.count == SyncEngine.maxFoodsPerDay + 1)
        #expect(entries.last?.syncedDay == nil)
    }

    @Test func aDayFilledOnAnotherDeviceHoldsBackOnlyItsExtraEntries() async throws {
        let tokens = try await signUp()
        let phone = SyncTestDevice(server: server, tokens: tokens)
        let tablet = SyncTestDevice(server: server, tokens: tokens)
        for minute in 0..<SyncEngine.maxFoodsPerDay {
            try phone.store.log(banana, grams: 10, loggedAt: breakfast.addingTimeInterval(Double(minute) * 60))
        }
        await phone.sync()
        try tablet.store.log(nutella, grams: 15, loggedAt: breakfast)
        try tablet.store.log(nutella, grams: 15, loggedAt: breakfast.addingTimeInterval(86_400))

        await tablet.sync()
        #expect(tablet.engine.status == .failed(.errorSyncRefused))
        #expect(try tablet.entries().count == SyncEngine.maxFoodsPerDay + 2)
        await tablet.sync()

        #expect(tablet.engine.status == .upToDate(Date(timeIntervalSince1970: 1_800_000_000)))
        #expect(server.foods(for: tokens.user, on: breakfastDay)?.count == SyncEngine.maxFoodsPerDay)
        #expect(server.foods(for: tokens.user, on: "2026-12-24")?.map(\.foodID) == [nutella.id])
    }

    @Test func namesAreCutToTheServersLimitInUnicodeScalars() {
        // Each thumbs-up with a skin tone is one character but two Unicode scalars.
        let entry = FoodLogEntry(food: .fixture(name: String(repeating: "👍🏽", count: 300)), grams: 100, loggedAt: breakfast)

        let food = SyncEngine.loggedFood(for: entry, id: UUID())

        #expect(food.name.unicodeScalars.count == SyncEngine.maxNameLength)
    }

    @Test func aFoodIDLongerThanTheServerAllowsDoesNotSync() {
        let longest = FoodLogEntry(food: .fixture(id: "off-" + String(repeating: "1", count: 60)), grams: 100, loggedAt: breakfast)
        let tooLong = FoodLogEntry(food: .fixture(id: "off-" + String(repeating: "1", count: 61)), grams: 100, loggedAt: breakfast)

        #expect(SyncEngine.isSyncable(longest))
        #expect(SyncEngine.isSyncable(tooLong) == false)
    }

    // MARK: - Deletions

    @Test func deletingASyncedEntryPushesARemoval() async throws {
        let tokens = try await signUp()
        let device = SyncTestDevice(server: server, tokens: tokens)
        try device.store.log(banana, grams: 120, loggedAt: breakfast)
        await device.sync()

        try device.store.delete(try #require(try device.entries().first))
        #expect(try device.tombstones().count == 1)
        await device.sync()

        #expect(server.foods(for: tokens.user, on: breakfastDay)?.isEmpty == true)
        #expect(try device.tombstones().isEmpty)
    }

    @Test func anEntryDeletedAfterAPushWhoseResponseWasLostStaysDeleted() async throws {
        let tokens = try await signUp()
        let device = SyncTestDevice(server: server, tokens: tokens)
        try device.store.log(banana, grams: 120, loggedAt: breakfast)
        server.loseNextPushResponse()
        await device.sync()
        #expect(device.engine.status == .failed(.errorTimeout))
        #expect(server.foods(for: tokens.user, on: breakfastDay)?.count == 1)

        try device.store.delete(try #require(try device.entries().first))
        await device.sync()

        #expect(try device.entries().isEmpty)
        #expect(server.foods(for: tokens.user, on: breakfastDay)?.isEmpty == true)
        #expect(try device.tombstones().isEmpty)
    }

    @Test func anEntryDeletedWhileItsPushIsInFlightGetsARemoval() async throws {
        let tokens = try await signUp()
        let device = SyncTestDevice(server: server, tokens: tokens)
        try device.store.log(banana, grams: 120, loggedAt: breakfast)
        server.onPush {
            if let entry = try? device.entries().first {
                try? device.store.delete(entry)
            }
        }

        await device.sync()
        #expect(try device.entries().isEmpty)
        #expect(try device.tombstones().count == 1)
        await device.sync()

        #expect(try device.entries().isEmpty)
        #expect(server.foods(for: tokens.user, on: breakfastDay)?.isEmpty == true)
        #expect(try device.tombstones().isEmpty)
    }

    @Test func remoteDeletionRemovesOnlySyncedEntries() async throws {
        let tokens = try await signUp()
        let phone = SyncTestDevice(server: server, tokens: tokens)
        let tablet = SyncTestDevice(server: server, tokens: tokens)
        try phone.store.log(banana, grams: 120, loggedAt: breakfast)
        await phone.sync()
        await tablet.sync()
        // Sample entries never sync, so this one stays unsynced on the same day.
        try tablet.store.log(.fixture(id: "sample-oats", name: "Oats"), grams: 70, loggedAt: breakfast.addingTimeInterval(30))

        try phone.store.delete(try #require(try phone.entries().first))
        await phone.sync()
        await tablet.sync()

        #expect(try tablet.entries().map(\.foodID) == ["sample-oats"])
    }

    // MARK: - Restore

    @Test func anEmptyDeviceRestoresTheLogWithLoggedMacrosAndProviderMicros() async throws {
        let tokens = try await signUp()
        let phone = SyncTestDevice(server: server, tokens: tokens)
        try phone.store.log(banana, grams: 120, loggedAt: breakfast)
        await phone.sync()
        let original = try #require(try phone.entries().first)
        // The provider's data changed since the food was logged. Macros must still match what was logged.
        let updatedBanana = FoodItem.fixture(
            id: banana.id,
            name: "Bananas, raw (updated)",
            brand: "Nature",
            per100g: NutrientProfile(energy: 95, protein: 1, carbohydrates: 23, fat: 0.5, fiber: 3, vitaminC: 9)
        )
        let lookup = StubFoodLookup(foods: [updatedBanana])
        let reinstalled = SyncTestDevice(server: server, tokens: tokens, lookup: lookup)

        await reinstalled.sync()

        let restored = try #require(try reinstalled.entries().first)
        #expect(try reinstalled.entries().count == 1)
        #expect(restored.syncID == original.syncID)
        #expect(restored.syncedDay == breakfastDay)
        #expect(restored.grams == 120)
        #expect(restored.loggedAt == original.loggedAt)
        #expect(restored.name == "Bananas, raw")
        #expect(restored.brand == "Nature")
        for nutrient in Nutrient.macros {
            expectApproximately(restored.nutrients[nutrient], try #require(original.nutrients[nutrient]), tolerance: 1e-6)
        }
        #expect(restored.per100g.fiber == 3)
        #expect(restored.per100g.vitaminC == 9)
        #expect(lookup.requestedIDs == [[banana.id]])
    }

    @Test func aFailedLookupFallsBackToTheLoggedNameAndMacros() async throws {
        let tokens = try await signUp()
        let phone = SyncTestDevice(server: server, tokens: tokens)
        try phone.store.log(nutella, grams: 15, loggedAt: breakfast)
        await phone.sync()
        let reinstalled = SyncTestDevice(server: server, tokens: tokens, lookup: StubFoodLookup())

        await reinstalled.sync()

        let restored = try #require(try reinstalled.entries().first)
        #expect(restored.name == "Nutella")
        #expect(restored.source == .openFoodFacts)
        expectApproximately(restored.nutrients.energy, 539 * 0.15, tolerance: 1e-6)
        #expect(restored.per100g.fiber == nil)
        #expect(reinstalled.engine.status == .upToDate(Date(timeIntervalSince1970: 1_800_000_000)))
    }

    @Test func restoringDoesNotPushTheRestoredEntriesBack() async throws {
        let tokens = try await signUp()
        let phone = SyncTestDevice(server: server, tokens: tokens)
        try phone.store.log(banana, grams: 120, loggedAt: breakfast)
        await phone.sync()
        let reinstalled = SyncTestDevice(server: server, tokens: tokens)

        await reinstalled.sync()
        await reinstalled.sync()

        #expect(server.calls.filter { $0 == "pushChanges" }.count == 1)
    }

    @Test func pullsEveryPage() async throws {
        let pagedServer = FakeGramwiseAPI(pageSize: 2)
        let tokens = try await pagedServer.signUp(email: "ada@example.com", password: "correct horse")
        let phone = SyncTestDevice(server: pagedServer, tokens: tokens)
        for day in 0..<5 {
            try phone.store.log(banana, grams: 100, loggedAt: breakfast.addingTimeInterval(Double(day) * 86_400))
        }
        await phone.sync()
        let pullsBefore = pagedServer.calls.filter { $0 == "dailyLogs" }.count
        let reinstalled = SyncTestDevice(server: pagedServer, tokens: tokens)

        await reinstalled.sync()

        #expect(try reinstalled.entries().count == 5)
        // Five days, two per page.
        #expect(pagedServer.calls.filter { $0 == "dailyLogs" }.count - pullsBefore == 3)
    }

    // MARK: - Accounts

    @Test func switchingAccountsUploadsTheLogToTheNewAccount() async throws {
        let ada = try await signUp("ada@example.com")
        let device = SyncTestDevice(server: server, tokens: ada)
        try device.store.log(banana, grams: 120, loggedAt: breakfast)
        await device.sync()

        try await device.account.signOut()
        let bob = try await signUp("bob@example.com")
        try await device.account.signIn(email: "bob@example.com", password: "correct horse")
        await device.sync()

        #expect(server.foods(for: bob.user, on: breakfastDay)?.count == 1)
        #expect(server.foods(for: ada.user, on: breakfastDay)?.count == 1)
        #expect(try device.entries().first?.syncedDay == breakfastDay)
    }

    @Test func signedOutDoesNothing() async throws {
        let device = SyncTestDevice(server: server, tokens: nil)
        try device.store.log(banana, grams: 120, loggedAt: breakfast)

        await device.sync()

        #expect(device.engine.status == .signedOut)
        #expect(server.calls.isEmpty)
    }

    @Test func revokedTokensSignOut() async throws {
        let device = SyncTestDevice(server: server, tokens: try await signUp())
        server.revokeAllTokens()

        await device.sync()

        #expect(device.engine.status == .signedOut)
        #expect(device.account.isSignedIn == false)
        #expect(device.tokenStore.tokens == nil)
    }

    @Test func expiredAccessTokenIsRefreshedAndSyncContinues() async throws {
        let tokens = try await signUp()
        let device = SyncTestDevice(server: server, tokens: tokens)
        try device.store.log(banana, grams: 120, loggedAt: breakfast)
        server.expireAccessTokens()

        await device.sync()

        #expect(server.calls.contains("refresh"))
        #expect(server.foods(for: tokens.user, on: breakfastDay)?.count == 1)
        #expect(device.tokenStore.tokens?.accessToken != tokens.accessToken)
    }

    // MARK: - Goal

    @Test func aLaterSaveTheSameDayIsPushed() async throws {
        let tokens = try await signUp()
        let device = SyncTestDevice(server: server, tokens: tokens)
        server.setGoal(goal(.bulk, DailyTargets(energy: 3_000), savedAt: breakfast), for: tokens.user)
        let savedAt = breakfast.addingTimeInterval(60)
        try device.targets.save(targets: DailyTargets(energy: 1_800, protein: 140), bodyProfile: nil, goal: .cut, savedAt: savedAt)

        await device.sync()

        let stored = try #require(server.storedGoal(for: tokens.user))
        #expect(stored == goal(.cut, DailyTargets(energy: 1_800, protein: 140), savedAt: savedAt))
        #expect(device.targets.goal == .cut)
    }

    @Test func theGoalIsDatedWithItsDayInTheEngineCalendar() async throws {
        let tokens = try await signUp()
        var honolulu = Calendar(identifier: .gregorian)
        honolulu.timeZone = try #require(TimeZone(identifier: "Pacific/Honolulu"))
        let device = SyncTestDevice(server: server, tokens: tokens, calendar: honolulu)
        // 04:26 UTC on December 23 is still the evening of December 22 in Honolulu.
        try device.targets.save(targets: DailyTargets(energy: 1_800), bodyProfile: nil, goal: .cut, savedAt: breakfast)

        await device.sync()

        #expect(server.storedGoal(for: tokens.user)?.effectiveFrom == "2026-12-22")
    }

    @Test func aNewerRemoteGoalIsAppliedAndKeepsTheBodyProfile() async throws {
        let tokens = try await signUp()
        let device = SyncTestDevice(server: server, tokens: tokens)
        let body = BodyProfile(sex: .female, age: 34, heightCentimetres: 168, weightKilograms: 61, activity: .light)
        try device.targets.save(targets: DailyTargets(energy: 1_800), bodyProfile: body, goal: .cut, savedAt: breakfast)
        await device.sync()
        let remoteSave = breakfast.addingTimeInterval(86_400)
        server.setGoal(goal(.bulk, DailyTargets(energy: 3_000), savedAt: remoteSave), for: tokens.user)

        await device.sync()
        await device.sync()

        #expect(device.targets.goal == .bulk)
        #expect(device.targets.targets == DailyTargets(energy: 3_000))
        #expect(device.targets.updatedAt == remoteSave)
        #expect(device.targets.bodyProfile == body)
        // The applied goal isn't pushed back.
        #expect(server.calls.filter { $0 == "putGoal" }.count == 1)
    }

    @Test func anEarlierSaveTheSameDayIsRefusedAndTheServersGoalIsTaken() async throws {
        let tokens = try await signUp()
        let device = SyncTestDevice(server: server, tokens: tokens)
        try device.targets.save(targets: DailyTargets(energy: 1_800), bodyProfile: nil, goal: .cut, savedAt: breakfast)
        let newer = goal(.maintain, DailyTargets(energy: 2_400), savedAt: breakfast.addingTimeInterval(60))
        server.setGoal(newer, for: tokens.user)

        await device.sync()

        #expect(server.storedGoal(for: tokens.user) == newer)
        #expect(device.targets.goal == .maintain)
        #expect(device.targets.updatedAt == newer.updatedAt)
        #expect(device.engine.status == .upToDate(Date(timeIntervalSince1970: 1_800_000_000)))
    }

    @Test func aGoalFromAnEarlierDayIsRefusedEvenWhenSavedLater() async throws {
        let tokens = try await signUp()
        let device = SyncTestDevice(server: server, tokens: tokens)
        // Saved at 10:26 UTC, which is already December 24 on a device in UTC+14.
        let nextDay = GramwiseGoal(
            goal: .bulk,
            targets: DailyTargets(energy: 3_000),
            updatedAt: breakfast.addingTimeInterval(6 * 3_600),
            effectiveFrom: "2026-12-24"
        )
        server.setGoal(nextDay, for: tokens.user)
        // An hour later, but still December 23 on this device.
        try device.targets.save(
            targets: DailyTargets(energy: 1_800),
            bodyProfile: nil,
            goal: .cut,
            savedAt: breakfast.addingTimeInterval(7 * 3_600)
        )

        await device.sync()
        await device.sync()

        #expect(server.storedGoal(for: tokens.user) == nextDay)
        #expect(device.targets.goal == .bulk)
        #expect(server.calls.filter { $0 == "putGoal" }.count == 1)
    }

    @Test func aReinstalledDeviceRestoresTheGoal() async throws {
        let tokens = try await signUp()
        let restored = goal(.cut, DailyTargets(energy: 1_900, fat: 60), savedAt: breakfast)
        server.setGoal(restored, for: tokens.user)
        let device = SyncTestDevice(server: server, tokens: tokens)

        await device.sync()

        #expect(device.targets.goal == .cut)
        #expect(device.targets.targets == restored.targets)
        #expect(server.calls.contains("putGoal") == false)
    }

    @Test func aGoalSavedBeforeSaveTimesWereRecordedIsPushedAsSavedNow() async throws {
        let tokens = try await signUp()
        let saved = DailyTargets(energy: 2_000, protein: 150, fat: 62)
        let now = Date(timeIntervalSince1970: 1_800_000_000) // 2027-01-15 08:00 UTC
        let device = SyncTestDevice(server: server, tokens: tokens, isolated: try legacyDefaults(targets: saved, goal: .cut), now: now)

        await device.sync()
        await device.sync()

        #expect(server.storedGoal(for: tokens.user) == GramwiseGoal(goal: .cut, targets: saved, updatedAt: now, effectiveFrom: "2027-01-15"))
        #expect(device.targets.updatedAt == now)
        #expect(server.calls.filter { $0 == "putGoal" }.count == 1)
    }

    @Test func aGoalSavedBeforeSaveTimesWereRecordedLosesToTheServer() async throws {
        let tokens = try await signUp()
        let remote = goal(.bulk, DailyTargets(energy: 3_000), savedAt: breakfast)
        server.setGoal(remote, for: tokens.user)
        let isolated = try legacyDefaults(targets: DailyTargets(energy: 2_000), goal: .cut)
        let device = SyncTestDevice(server: server, tokens: tokens, isolated: isolated)

        await device.sync()

        #expect(server.storedGoal(for: tokens.user) == remote)
        #expect(device.targets.goal == .bulk)
        #expect(device.targets.updatedAt == breakfast)
        #expect(server.calls.contains("putGoal") == false)
    }

    @Test func aGoalTheServerLostIsPushedAgain() async throws {
        let tokens = try await signUp()
        let device = SyncTestDevice(server: server, tokens: tokens)
        try device.targets.save(targets: DailyTargets(energy: 1_800), bodyProfile: nil, goal: .cut, savedAt: breakfast)
        await device.sync()
        server.removeGoal(for: tokens.user)

        await device.sync()

        #expect(server.storedGoal(for: tokens.user) == goal(.cut, DailyTargets(energy: 1_800), savedAt: breakfast))
    }

    @Test func noGoalOnEitherSideStaysEmpty() async throws {
        let tokens = try await signUp()
        let device = SyncTestDevice(server: server, tokens: tokens)

        await device.sync()

        #expect(server.storedGoal(for: tokens.user) == nil)
        #expect(device.targets.goal == nil)
        #expect(server.calls.contains("putGoal") == false)
    }

    /// A goal saved at `savedAt`, dated with that moment's day in GMT like `SyncTestDevice`'s calendar.
    private func goal(_ goal: WeightGoal, _ targets: DailyTargets, savedAt: Date) -> GramwiseGoal {
        let day = savedAt.formatted(Date.ISO8601FormatStyle(timeZone: .gmt).year().month().day())
        return GramwiseGoal(goal: goal, targets: targets, updatedAt: savedAt, effectiveFrom: day)
    }

    /// Defaults holding targets and a goal the way the app saved them before it recorded save times.
    private func legacyDefaults(targets: DailyTargets, goal: WeightGoal) throws -> IsolatedDefaults {
        let isolated = IsolatedDefaults()
        isolated.defaults.set(try JSONEncoder().encode(targets), forKey: "targets.daily")
        isolated.defaults.set(try JSONEncoder().encode(goal), forKey: "targets.goal")
        return isolated
    }

    // MARK: - Status

    @Test func aFailureSetsTheFailedStatusAndKeepsEntriesPending() async throws {
        let device = SyncTestDevice(server: server, tokens: try await signUp())
        try device.store.log(banana, grams: 120, loggedAt: breakfast)
        server.fail(with: URLError(.notConnectedToInternet))

        await device.sync()

        #expect(device.engine.status == .failed(.errorOffline))
        #expect(try device.entries().first?.syncedDay == nil)
    }

    @Test func aRefusedPushStillPullsOtherDevicesChanges() async throws {
        let tokens = try await signUp()
        let phone = SyncTestDevice(server: server, tokens: tokens)
        let tablet = SyncTestDevice(server: server, tokens: tokens)
        try phone.store.log(banana, grams: 120, loggedAt: breakfast)
        await phone.sync()
        try tablet.store.log(nutella, grams: 15, loggedAt: breakfast.addingTimeInterval(60))
        server.refuse("pushChanges", with: .invalidInput)

        await tablet.sync()

        #expect(tablet.engine.status == .failed(.errorSyncRefused))
        #expect(try tablet.entries().map(\.foodID) == [banana.id, nutella.id])
    }

    @Test func aCursorTheServerRefusesStartsThePullOver() async throws {
        let tokens = try await signUp()
        let phone = SyncTestDevice(server: server, tokens: tokens)
        let tablet = SyncTestDevice(server: server, tokens: tokens)
        await tablet.sync()
        try phone.store.log(banana, grams: 120, loggedAt: breakfast)
        await phone.sync()
        tablet.isolated.defaults.set("not-a-cursor", forKey: "sync.cursor")

        await tablet.sync()

        #expect(tablet.engine.status == .upToDate(Date(timeIntervalSince1970: 1_800_000_000)))
        #expect(try tablet.entries().map(\.foodID) == [banana.id])
        #expect(tablet.isolated.defaults.string(forKey: "sync.cursor") != "not-a-cursor")
    }

    @Test func anUnreachableServerSaysSo() async throws {
        let device = SyncTestDevice(server: server, tokens: try await signUp())
        server.fail(with: GramwiseAPIError.unreachable)

        await device.sync()

        #expect(device.engine.status == .failed(.errorSyncServer))
    }

    @Test func requestsBeforeAPassStartsShareIt() async throws {
        let device = SyncTestDevice(server: server, tokens: try await signUp())

        let first = device.engine.requestSync()
        let second = device.engine.requestSync()
        await first.value

        #expect(first == second)
        #expect(server.calls.filter { $0 == "dailyLogs" }.count == 1)
    }

    @Test func aRequestDuringAPassRunsOneMoreAfterIt() async throws {
        let tokens = try await signUp()
        let phone = SyncTestDevice(server: server, tokens: tokens)
        try phone.store.log(banana, grams: 120, loggedAt: breakfast)
        await phone.sync()
        let lookup = StubFoodLookup()
        let reinstalled = SyncTestDevice(server: server, tokens: tokens, lookup: lookup)
        var duringPass: Task<Void, Never>?
        lookup.onLookup { duringPass = reinstalled.engine.requestSync() }
        let pullsBefore = server.calls.filter { $0 == "dailyLogs" }.count

        let pass = reinstalled.engine.requestSync()
        await pass.value

        #expect(duringPass == pass)
        #expect(server.calls.filter { $0 == "dailyLogs" }.count - pullsBefore == 2)
        #expect(try reinstalled.entries().count == 1)
    }

    @Test func dayKeysUseTheEngineCalendar() async throws {
        var tokyo = Calendar(identifier: .gregorian)
        tokyo.timeZone = try #require(TimeZone(identifier: "Asia/Tokyo"))
        let tokens = try await signUp()
        let device = SyncTestDevice(server: server, tokens: tokens, calendar: tokyo)
        // 20:00 UTC on 2026-12-23 is already the 24th in Tokyo.
        let lateEvening = try Date("2026-12-23T20:00:00Z", strategy: .iso8601)
        try device.store.log(banana, grams: 120, loggedAt: lateEvening)

        await device.sync()

        #expect(server.dayKeys(for: tokens.user) == ["2026-12-24"])
    }
}
