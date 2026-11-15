import Foundation
import SwiftData
import Testing
@testable import CalTracker

@Suite(.tags(.persistence))
struct CustomFoodStoreTests {
    private let container = AppModelContainer.make(inMemory: true)
    private let start = Date(timeIntervalSince1970: 1_800_000_000)

    /// A store whose clock moves a minute on for every save, so the order of saves is the order of `createdAt`.
    private func makeStore() -> CustomFoodStore {
        var minutes = 0.0
        return CustomFoodStore(modelContext: container.mainContext) { [start] in
            minutes += 1
            return start.addingTimeInterval(minutes * 60)
        }
    }

    @Test func savedFoodsComeBackNewestFirstWithTheirValues() throws {
        let store = makeStore()
        let dal = CustomFoodRecord.fixture(id: "cus-1", name: "Grandma's dal")
        let kheer = CustomFoodRecord.fixture(
            id: "cus-2",
            name: "Kheer",
            per100g: NutrientProfile(energy: 150, protein: 4, carbohydrates: 22, fat: 5, calcium: 120),
            servingGrams: 180
        )

        try store.save(dal)
        try store.save(kheer)

        #expect(try store.foods(matching: "") == [kheer, dal])
    }

    @Test func matchesNamesIgnoringCaseAccentsAndSurroundingSpace() throws {
        let store = makeStore()
        let creme = CustomFoodRecord.fixture(id: "cus-1", name: "Crème brûlée")
        try store.save(creme)
        try store.save(.fixture(id: "cus-2", name: "Kheer"))

        #expect(try store.foods(matching: "  creme BRU ") == [creme])
        #expect(try store.foods(matching: "rajma").isEmpty)
    }

    @Test func deleteRemovesOnlyThatFoodAndLeavesTheLog() throws {
        let store = makeStore()
        let log = FoodLogStore(modelContext: container.mainContext)
        let dal = CustomFoodRecord.fixture(id: "cus-1")
        let kheer = CustomFoodRecord.fixture(id: "cus-2", name: "Kheer")
        try store.save(dal)
        try store.save(kheer)
        try log.log(dal.food, grams: 350)

        try store.delete(id: dal.id)

        #expect(try store.foods(matching: "") == [kheer])
        let entries = try container.mainContext.fetch(FetchDescriptor<FoodLogEntry>())
        #expect(entries.map(\.foodID) == ["cus-1"])
        #expect(entries.first?.source == .custom)
    }
}
