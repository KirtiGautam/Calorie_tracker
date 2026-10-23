import Testing
@testable import CalTracker

struct LogFoodViewModelTests {
    private let food = FoodItem.fixture(per100g: NutrientProfile(energy: 200, protein: 10))

    @Test func defaultsTo100Grams() {
        let viewModel = LogFoodViewModel(food: food, foodLog: SpyFoodLogging())

        #expect(viewModel.grams == 100)
        #expect(viewModel.isValid)
    }

    @Test(arguments: zip(
        [-1.0, 0, 0.1, 100, 5_000, .infinity, .nan],
        [false, false, true, true, true, false, false]
    ))
    func validityRequiresAPositiveFiniteAmount(grams: Double, isValid: Bool) {
        let viewModel = LogFoodViewModel(food: food, foodLog: SpyFoodLogging())

        viewModel.grams = grams

        #expect(viewModel.isValid == isValid)
    }

    @Test func previewScalesToTheChosenAmount() {
        let viewModel = LogFoodViewModel(food: food, foodLog: SpyFoodLogging())

        viewModel.grams = 150

        #expect(viewModel.preview.energy == 300)
        #expect(viewModel.preview.protein == 15)
        #expect(viewModel.preview.fat == nil)
    }

    @Test func logPassesTheFoodAndGramsToTheStore() throws {
        let spy = SpyFoodLogging()
        let viewModel = LogFoodViewModel(food: food, foodLog: spy)
        viewModel.grams = 150

        _ = try viewModel.log()

        let call = try #require(spy.loggedCalls.first)
        #expect(spy.loggedCalls.count == 1)
        #expect(call.food == food)
        #expect(call.grams == 150)
    }

    @Test func logReturnsWhatWasLogged() throws {
        let viewModel = LogFoodViewModel(food: food, foodLog: SpyFoodLogging())
        viewModel.grams = 150

        let loggedFood = try viewModel.log()

        #expect(loggedFood.name == food.name)
        #expect(loggedFood.grams == 150)
    }

    @Test func everyLogHasADistinctConfirmation() throws {
        let viewModel = LogFoodViewModel(food: food, foodLog: SpyFoodLogging())

        let first = try viewModel.log()
        let second = try viewModel.log()

        #expect(first != second, "Logging the same food twice must restart the banner")
    }

    @Test func logRefusesAnInvalidAmountWithoutCallingTheStore() {
        let spy = SpyFoodLogging()
        let viewModel = LogFoodViewModel(food: food, foodLog: spy)
        viewModel.grams = 0

        #expect(throws: LogFoodError.invalidAmount) {
            _ = try viewModel.log()
        }
        #expect(spy.loggedCalls.isEmpty)
    }

    @Test func logSurfacesStoreErrors() {
        let spy = SpyFoodLogging()
        spy.errorToThrow = APIError.invalidResponse
        let viewModel = LogFoodViewModel(food: food, foodLog: spy)

        #expect(throws: APIError.invalidResponse) {
            _ = try viewModel.log()
        }
    }
}
