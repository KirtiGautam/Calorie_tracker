import Foundation

/// A short line of encouragement for today, based on progress toward the daily targets.
///
/// It follows the same status and tone rules as the progress bars, so the message never contradicts their colours.
nonisolated enum DailyMotivation: Hashable, Sendable {
    /// Nothing has been logged yet today.
    case freshStart

    /// Carbohydrates are over target, the one surplus the progress bars flag as a problem.
    case carbohydratesOver

    /// No target is still short.
    case allTargetsMet

    /// Energy is still short by `kilocalories`.
    case energyRemaining(kilocalories: Double)

    /// `met` of the `total` targets are on target or over where that's fine.
    case targetsProgress(met: Int, total: Int)

    /// Picks the message for today's `totals`, or returns `nil` when there are no targets to measure against.
    ///
    /// - Parameters:
    ///   - targets: The person's daily targets.
    ///   - totals: What has been eaten so far today.
    ///   - hasEntries: Whether anything has been logged today.
    init?(targets: DailyTargets, totals: DailyTotals, hasEntries: Bool) {
        let progress = Nutrient.macros.compactMap { targets.progress(for: $0, in: totals) }
        guard progress.isEmpty == false else { return nil }

        if hasEntries == false {
            self = .freshStart
        } else if progress.contains(where: { $0.tone == .alert }) {
            self = .carbohydratesOver
        } else if progress.allSatisfy({ $0.status != .deficit }) {
            self = .allTargetsMet
        } else if let energy = progress.first(where: { $0.nutrient == .energy }), energy.status == .deficit {
            self = .energyRemaining(kilocalories: energy.difference)
        } else {
            self = .targetsProgress(met: progress.count { $0.status != .deficit }, total: progress.count)
        }
    }

    /// The colour cue, matching the progress bars: amber while short, green when met, red when carbs are over.
    var tone: TargetTone {
        switch self {
        case .freshStart, .allTargetsMet: .good
        case .carbohydratesOver: .alert
        case .energyRemaining, .targetsProgress: .caution
        }
    }

    /// The SF Symbol shown beside the message.
    var systemImage: String {
        switch self {
        case .freshStart: "sunrise.fill"
        case .carbohydratesOver: "exclamationmark.triangle.fill"
        case .allTargetsMet: "checkmark.seal.fill"
        case .energyRemaining: "flame.fill"
        case .targetsProgress: "chart.bar.fill"
        }
    }

    /// The localized message shown on Today.
    var message: LocalizedStringResource {
        switch self {
        case .freshStart:
            .motivationFreshStart
        case .carbohydratesOver:
            .motivationCarbohydratesOver
        case .allTargetsMet:
            .motivationAllTargetsMet
        case .energyRemaining(let kilocalories):
            .motivationEnergyRemaining(NutrientUnit.kilocalories.formatted(kilocalories))
        case .targetsProgress(let met, let total):
            .motivationTargetsProgress(met, total)
        }
    }
}
