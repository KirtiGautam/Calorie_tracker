import Foundation
import Testing
@testable import CalTracker

@Suite(.tags(.persistence))
struct TargetsStoreTests {
    private let isolated = IsolatedDefaults()
    private let targets = DailyTargets(energy: 2_560, protein: 112, carbohydrates: 368, fat: 71)
    private let body = BodyProfile(sex: .male, age: 30, heightCentimetres: 175, weightKilograms: 70, activity: .moderate)

    @Test func freshStoreIsEmpty() {
        let store = TargetsStore(defaults: isolated.defaults)

        #expect(store.targets.isEmpty)
        #expect(store.bodyProfile == nil)
        #expect(store.goal == nil)
    }

    @Test func savedValuesSurviveReopening() throws {
        try TargetsStore(defaults: isolated.defaults).save(targets: targets, bodyProfile: body, goal: .cut)

        let reopened = TargetsStore(defaults: isolated.defaults)

        #expect(reopened.targets == targets)
        #expect(reopened.bodyProfile == body)
        #expect(reopened.goal == .cut)
    }

    @Test func saveUpdatesTheStoreImmediately() throws {
        let store = TargetsStore(defaults: isolated.defaults)

        try store.save(targets: targets, bodyProfile: nil, goal: .bulk)

        #expect(store.targets == targets)
        #expect(store.goal == .bulk)
    }

    @Test func savingWithoutABodyProfileClearsTheOldOne() throws {
        try TargetsStore(defaults: isolated.defaults).save(targets: targets, bodyProfile: body, goal: .maintain)
        try TargetsStore(defaults: isolated.defaults).save(targets: targets, bodyProfile: nil, goal: .maintain)

        #expect(TargetsStore(defaults: isolated.defaults).bodyProfile == nil)
    }

    @Test func unreadableDataIsTreatedAsNeverSaved() {
        isolated.defaults.set(Data("not json".utf8), forKey: "targets.daily")

        #expect(TargetsStore(defaults: isolated.defaults).targets.isEmpty)
    }
}
