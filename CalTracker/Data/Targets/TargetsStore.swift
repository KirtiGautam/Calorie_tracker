import Foundation
import Observation

/// Keeps the person's daily targets, body measurements and goal in `UserDefaults`.
@Observable
final class TargetsStore {
    /// The daily macro targets. Empty until the first save.
    private(set) var targets: DailyTargets

    /// The measurements the targets were calculated from, when they were complete.
    private(set) var bodyProfile: BodyProfile?

    /// The goal shown on Today. `nil` until the first save.
    private(set) var goal: WeightGoal?

    /// When the targets and goal were last saved here or arrived from the server. Sync uses it so the newest save wins.
    ///
    /// `nil` when there's no goal, or for a goal saved before the app recorded save times.
    private(set) var updatedAt: Date?

    /// Called after the person saves, so sync can push the change. `applyRemote` doesn't call it.
    @ObservationIgnored var onChange: () -> Void

    @ObservationIgnored private let defaults: UserDefaults

    /// Creates a store that reads and writes `defaults` and calls `onChange` after each save.
    ///
    /// Values that can't be decoded are treated as never saved.
    init(defaults: UserDefaults, onChange: @escaping () -> Void = {}) {
        self.defaults = defaults
        self.onChange = onChange
        targets = Self.decode(DailyTargets.self, forKey: Key.targets, in: defaults) ?? DailyTargets()
        bodyProfile = Self.decode(BodyProfile.self, forKey: Key.bodyProfile, in: defaults)
        goal = Self.decode(WeightGoal.self, forKey: Key.goal, in: defaults)
        updatedAt = Self.decode(Date.self, forKey: Key.updatedAt, in: defaults)
    }

    /// Saves all three values together, stamped with `savedAt`.
    ///
    /// - Throws: An `EncodingError` if a value can't be encoded. Nothing is written in that case.
    func save(targets: DailyTargets, bodyProfile: BodyProfile?, goal: WeightGoal, savedAt: Date = .now) throws {
        let encoder = JSONEncoder()
        let bodyData = try bodyProfile.map { try encoder.encode($0) }
        try write(targets: targets, goal: goal, updatedAt: savedAt)
        defaults.set(bodyData, forKey: Key.bodyProfile)
        self.bodyProfile = bodyProfile
        onChange()
    }

    /// Replaces the targets and goal with newer ones from the server. The body profile stays as it is.
    ///
    /// - Throws: An `EncodingError` if a value can't be encoded. Nothing is written in that case.
    func applyRemote(targets: DailyTargets, goal: WeightGoal, updatedAt: Date) throws {
        try write(targets: targets, goal: goal, updatedAt: updatedAt)
    }

    /// Gives a goal saved before the app recorded save times the save time `date`, so sync can upload it.
    ///
    /// Does nothing when there's no goal or it already has a save time. Doesn't call `onChange`.
    ///
    /// - Throws: An `EncodingError` if the date can't be encoded. Nothing is written in that case.
    func recordSaveTime(_ date: Date) throws {
        guard goal != nil, updatedAt == nil else { return }
        defaults.set(try JSONEncoder().encode(date), forKey: Key.updatedAt)
        updatedAt = date
    }

    private func write(targets: DailyTargets, goal: WeightGoal, updatedAt: Date) throws {
        let encoder = JSONEncoder()
        let targetsData = try encoder.encode(targets)
        let goalData = try encoder.encode(goal)
        let updatedAtData = try encoder.encode(updatedAt)

        defaults.set(targetsData, forKey: Key.targets)
        defaults.set(goalData, forKey: Key.goal)
        defaults.set(updatedAtData, forKey: Key.updatedAt)

        self.targets = targets
        self.goal = goal
        self.updatedAt = updatedAt
    }

    private static func decode<Value: Decodable>(_ type: Value.Type, forKey key: String, in defaults: UserDefaults) -> Value? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    private enum Key {
        static let targets = "targets.daily"
        static let bodyProfile = "targets.bodyProfile"
        static let goal = "targets.goal"
        static let updatedAt = "targets.updatedAt"
    }
}
