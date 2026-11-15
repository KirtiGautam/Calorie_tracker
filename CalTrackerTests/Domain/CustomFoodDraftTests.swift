import Foundation
import Testing
@testable import CalTracker

struct CustomFoodDraftTests {
    /// A 350 g serving of dal, with its values typed for the whole serving.
    private func dalServing() -> CustomFoodDraft {
        var draft = CustomFoodDraft(name: "  Grandma's dal ", referenceGrams: 350)
        draft[.energy] = 420
        draft[.protein] = 21
        draft[.carbohydrates] = 52.5
        draft[.fat] = 14
        return draft
    }

    @Test func scalesTheValuesToPer100Grams() throws {
        let profile = try dalServing().per100g()

        expectApproximately(profile.energy, 120)
        expectApproximately(profile.protein, 6)
        expectApproximately(profile.carbohydrates, 15)
        expectApproximately(profile.fat, 4)
    }

    @Test func leavesBlankNutrientsUnknown() throws {
        let profile = try dalServing().per100g()

        #expect(profile.fiber == nil)
        #expect(profile.sodium == nil)
    }

    @Test func convertsEachNutrientFromItsChosenUnit() throws {
        var draft = CustomFoodDraft(name: "Milk", referenceGrams: 200)
        draft[.energy] = 520
        draft[unitOf: .energy] = .kilojoules
        draft[.sodium] = 0.2
        draft[unitOf: .sodium] = .grams
        draft[.vitaminD] = 80
        draft[unitOf: .vitaminD] = .internationalUnits

        let profile = try draft.per100g()

        expectApproximately(profile.energy, 520 / NutrientUnit.kilojoulesPerKilocalorie / 2)
        expectApproximately(profile.sodium, 100)
        expectApproximately(profile.vitaminD, 1)
    }

    @Test func ignoresAUnitTheNutrientCantBeTypedIn() {
        var draft = CustomFoodDraft()
        draft[unitOf: .protein] = .milligrams

        #expect(draft[unitOf: .protein] == .grams)
    }

    @Test func calculatesBlankEnergyFromTheMacros() throws {
        var draft = dalServing()
        draft[.energy] = nil

        let profile = try draft.per100g()

        expectApproximately(profile.energy, 4 * 6 + 4 * 15 + 9 * 4)
    }

    @Test func needsEnergyOrAllThreeMacros() {
        var draft = dalServing()
        draft[.energy] = nil
        draft[.fat] = nil

        #expect(throws: CustomFoodError.missingEnergy) { try draft.per100g() }
    }

    @Test(arguments: [nil, 0, -5, Double.infinity] as [Double?])
    func refusesAWeightThatIsntPositive(weight: Double?) {
        var draft = dalServing()
        draft.referenceGrams = weight

        #expect(throws: CustomFoodError.invalidReferenceAmount) { try draft.per100g() }
    }

    @Test func refusesANegativeAmount() {
        var draft = dalServing()
        draft[.fiber] = -1

        #expect(throws: CustomFoodError.implausibleAmount(.fiber)) { try draft.per100g() }
    }

    @Test func refusesMoreOfOneNutrientThanTheWeightHolds() {
        var draft = CustomFoodDraft(name: "Typo", referenceGrams: 30)
        draft[.energy] = 100
        draft[.protein] = 40

        #expect(throws: CustomFoodError.implausibleAmount(.protein)) { try draft.per100g() }
    }

    @Test func refusesMoreEnergyThanPureFat() {
        var draft = CustomFoodDraft(name: "Typo", referenceGrams: 100)
        draft[.energy] = 1_000

        #expect(throws: CustomFoodError.implausibleAmount(.energy)) { try draft.per100g() }
    }

    @Test func refusesMacrosThatOutweighTheFood() {
        var draft = CustomFoodDraft(name: "Typo", referenceGrams: 100)
        draft[.energy] = 500
        draft[.protein] = 50
        draft[.carbohydrates] = 40
        draft[.fat] = 11

        #expect(throws: CustomFoodError.macrosExceedWeight) { try draft.per100g() }
    }

    @Test func allowsLabelsThatRoundTheMacrosUp() throws {
        var draft = CustomFoodDraft(name: "Butter", referenceGrams: 100)
        draft[.protein] = 0.9
        draft[.carbohydrates] = 0.1
        draft[.fat] = 99.4

        let profile = try draft.per100g()

        expectApproximately(profile.energy, 4 * 0.9 + 4 * 0.1 + 9 * 99.4)
    }

    @Test func standardizesIntoACustomFoodWithAServerSafeID() throws {
        let code = try #require(UUID(uuidString: "0F8FAD5B-D9CB-469F-A165-70867728950E"))

        let record = try dalServing().standardized(code: code)

        #expect(record.food.id == "cus-0f8fad5bd9cb469fa16570867728950e")
        #expect(record.food.name == "Grandma's dal")
        #expect(record.food.brand == nil)
        #expect(record.food.source == .custom)
        #expect(record.servingGrams == 350)
        expectApproximately(record.food.per100g.energy, 120)
    }

    @Test func needsAName() {
        var draft = dalServing()
        draft.name = "   "

        #expect(throws: CustomFoodError.missingName) { try draft.standardized() }
    }
}
