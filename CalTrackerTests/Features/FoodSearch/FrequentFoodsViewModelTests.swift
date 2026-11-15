import Foundation
import Testing
@testable import CalTracker

struct FrequentFoodsViewModelTests {
    private let calendar: Calendar
    private let banana = FoodItem.fixture(id: "usda-1", name: "Banana")
    private let oats = FoodItem.fixture(id: "usda-2", name: "Oats")

    init() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        self.calendar = calendar
    }

    @Test func loadAsksForTheLookbackWindowAndRanksWhatComesBack() throws {
        let now = try Date("2026-10-23T18:00:00Z", strategy: .iso8601)
        let history = StubFoodHistory(records: [
            FoodLogRecord(food: banana, grams: 120, loggedAt: try Date("2026-10-23T08:00:00Z", strategy: .iso8601)),
            FoodLogRecord(food: oats, grams: 60, loggedAt: try Date("2026-10-22T08:00:00Z", strategy: .iso8601)),
            FoodLogRecord(food: oats, grams: 50, loggedAt: try Date("2026-10-21T08:00:00Z", strategy: .iso8601)),
        ])
        let viewModel = FrequentFoodsViewModel(history: history, foodLog: SpyFoodLogging())

        viewModel.load(now: now, calendar: calendar)

        #expect(history.requestedStarts == [FrequentFoodRanking.windowStart(endingAt: now, calendar: calendar)])
        #expect(viewModel.frequentFoods == [
            FrequentFood(food: oats, grams: 60),
            FrequentFood(food: banana, grams: 120),
        ])
        #expect(viewModel.loadFailure == nil)
        #expect(viewModel.hasContent)
    }

    @Test func anEmptyLogHasNothingToShow() {
        let viewModel = FrequentFoodsViewModel(history: StubFoodHistory(), foodLog: SpyFoodLogging())

        viewModel.load(now: .now, calendar: calendar)

        #expect(viewModel.frequentFoods.isEmpty)
        #expect(viewModel.hasContent == false)
    }

    @Test func aFailedLoadShowsWhyAndClearsTheFoods() {
        let history = StubFoodHistory(records: [FoodLogRecord(food: banana, grams: 120, loggedAt: .now)])
        let viewModel = FrequentFoodsViewModel(history: history, foodLog: SpyFoodLogging())
        viewModel.load(now: .now, calendar: calendar)

        history.errorToThrow = APIError.invalidResponse
        viewModel.load(now: .now, calendar: calendar)

        #expect(viewModel.frequentFoods.isEmpty)
        #expect(viewModel.loadFailure?.key == userMessage(for: APIError.invalidResponse).key)
        #expect(viewModel.hasContent)
    }

    @Test func quickLogLogsTheLastAmountAndOffersUndo() throws {
        let spy = SpyFoodLogging()
        let viewModel = FrequentFoodsViewModel(history: StubFoodHistory(), foodLog: spy)

        let loggedFood = try viewModel.quickLog(FrequentFood(food: banana, grams: 120))

        let call = try #require(spy.loggedCalls.first)
        #expect(spy.loggedCalls.count == 1)
        #expect(call.food == banana)
        #expect(call.grams == 120)
        #expect(loggedFood.name == banana.name)
        #expect(loggedFood.grams == 120)
        let entry = try #require(loggedFood.undoableEntry)
        #expect(entry.foodID == banana.id)
        #expect(entry.grams == 120)
    }

    @Test func quickLogSurfacesStoreErrors() {
        let spy = SpyFoodLogging()
        spy.errorToThrow = APIError.invalidResponse
        let viewModel = FrequentFoodsViewModel(history: StubFoodHistory(), foodLog: spy)

        #expect(throws: APIError.invalidResponse) {
            _ = try viewModel.quickLog(FrequentFood(food: banana, grams: 120))
        }
    }
}
