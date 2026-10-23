import Foundation

/// What was just logged, for the confirmation shown on Today.
struct LoggedFood: Identifiable, Equatable {
    /// Unique per log, so logging the same food twice restarts the confirmation.
    let id = UUID()

    /// The food's name.
    let name: String

    /// The amount logged, in grams.
    let grams: Double

    /// The confirmation text, such as "Logged 150 g of Bananas, raw".
    var message: LocalizedStringResource {
        .loggedConfirmation(NutrientUnit.grams.formatted(grams), name)
    }
}
