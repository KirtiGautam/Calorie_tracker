/// Reasons a custom food can't be saved.
nonisolated enum CustomFoodError: Error, Equatable, Sendable {
    /// The name is blank.
    case missingName

    /// The weight the values are for isn't a positive, finite number of grams.
    case invalidReferenceAmount

    /// The nutrient's amount is negative, not a number, or more than the food's weight can hold.
    case implausibleAmount(Nutrient)

    /// Protein, carbohydrates and fat add up to more than the weight the values are for.
    case macrosExceedWeight

    /// Energy is blank, and it can't be calculated because protein, carbohydrates or fat is blank too.
    case missingEnergy
}
