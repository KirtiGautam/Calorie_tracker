import Testing
@testable import CalTracker

struct FoodSourceTests {
    @Test(arguments: zip(FoodSource.allCases, ["usda-173944", "off-173944", "cus-173944"]))
    func buildsSourcePrefixedIDs(source: FoodSource, expected: String) {
        #expect(source.foodID(code: "173944") == expected)
    }

    @Test(arguments: zip(["usda-173944", "off-3017620422003", "cus-0f8fad5bd9cb469fa16570867728950e"], FoodSource.allCases))
    func readsTheSourceFromAnID(foodID: String, expected: FoodSource) {
        #expect(FoodSource(foodID: foodID) == expected)
    }

    @Test(arguments: ["", "usda", "sample-1", "USDA-1", "offline-1", "custom-1"])
    func hasNoSourceForAnUnknownPrefix(foodID: String) {
        #expect(FoodSource(foodID: foodID) == nil)
    }

    @Test func readsTheCodeAfterItsOwnPrefixOnly() {
        #expect(FoodSource.usda.code(fromFoodID: "usda-173944") == "173944")
        #expect(FoodSource.openFoodFacts.code(fromFoodID: "off-3017620422003") == "3017620422003")
        #expect(FoodSource.usda.code(fromFoodID: "off-3017620422003") == nil)
        #expect(FoodSource.openFoodFacts.code(fromFoodID: "off-") == "")
    }

    @Test func listsUSDAFirst() {
        #expect(FoodSource.allCases == [.usda, .openFoodFacts, .custom])
    }

    @Test func searchesOnlyTheDatabases() {
        #expect(FoodSource.databases == [.usda, .openFoodFacts])
    }
}
