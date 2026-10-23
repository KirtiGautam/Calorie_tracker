/// How one nutrient's daily total compares with its target.
nonisolated struct TargetProgress: Hashable, Sendable {
    /// How far from the target, as a fraction of it, still counts as on target.
    static let tolerance = 0.1

    let nutrient: Nutrient
    let total: Double
    let target: Double

    /// The total as a fraction of the target. It can exceed 1.
    var fraction: Double {
        total / target
    }

    /// Whether the total is under, on or over the target.
    var status: TargetStatus {
        if fraction < 1 - Self.tolerance {
            .deficit
        } else if fraction > 1 + Self.tolerance {
            .surplus
        } else {
            .onTarget
        }
    }

    /// The colour cue. Only a carbohydrate surplus is a problem.
    var tone: TargetTone {
        switch status {
        case .deficit: .caution
        case .onTarget: .good
        case .surplus: nutrient == .carbohydrates ? .alert : .good
        }
    }

    /// How far the total is from the target, always positive.
    var difference: Double {
        abs(target - total)
    }
}
