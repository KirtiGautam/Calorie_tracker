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

    @ObservationIgnored private let defaults: UserDefaults

    /// Creates a store that reads and writes `defaults`.
    ///
    /// Values that can't be decoded are treated as never saved.
    init(defaults: UserDefaults) {
        self.defaults = defaults
        targets = Self.decode(DailyTargets.self, forKey: Key.targets, in: defaults) ?? DailyTargets()
        bodyProfile = Self.decode(BodyProfile.self, forKey: Key.bodyProfile, in: defaults)
        goal = Self.decode(WeightGoal.self, forKey: Key.goal, in: defaults)
    }

    /// Saves all three values together.
    ///
    /// - Throws: An `EncodingError` if a value can't be encoded. Nothing is written in that case.
    func save(targets: DailyTargets, bodyProfile: BodyProfile?, goal: WeightGoal) throws {
        let encoder = JSONEncoder()
        let targetsData = try encoder.encode(targets)
        let bodyData = try bodyProfile.map { try encoder.encode($0) }
        let goalData = try encoder.encode(goal)

        defaults.set(targetsData, forKey: Key.targets)
        defaults.set(bodyData, forKey: Key.bodyProfile)
        defaults.set(goalData, forKey: Key.goal)

        self.targets = targets
        self.bodyProfile = bodyProfile
        self.goal = goal
    }

    private static func decode<Value: Decodable>(_ type: Value.Type, forKey key: String, in defaults: UserDefaults) -> Value? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    private enum Key {
        static let targets = "targets.daily"
        static let bodyProfile = "targets.bodyProfile"
        static let goal = "targets.goal"
    }
}
