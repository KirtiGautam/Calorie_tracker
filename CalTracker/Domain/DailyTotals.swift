/// The summed nutrients for a set of logged entries.
nonisolated struct DailyTotals: Hashable, Sendable {
    /// The summed amounts. A nutrient is `nil` when no entry reported it.
    let profile: NutrientProfile

    /// Nutrients that at least one entry didn't report, so their totals undercount.
    let partialNutrients: Set<Nutrient>

    /// Creates totals by summing each entry's already-scaled nutrients.
    ///
    /// With no entries every nutrient is 0, because nothing has been eaten.
    init(entries: [NutrientProfile]) {
        guard entries.isEmpty == false else {
            var zero = NutrientProfile()
            for nutrient in Nutrient.allCases {
                zero[nutrient] = 0
            }
            profile = zero
            partialNutrients = []
            return
        }

        profile = entries.reduce(NutrientProfile(), +)
        partialNutrients = Set(Nutrient.allCases.filter { nutrient in
            let knownCount = entries.count { $0[nutrient] != nil }
            return knownCount > 0 && knownCount < entries.count
        })
    }

    /// Returns whether the total for `nutrient` is missing data from some entries.
    func isPartial(_ nutrient: Nutrient) -> Bool {
        partialNutrients.contains(nutrient)
    }
}
