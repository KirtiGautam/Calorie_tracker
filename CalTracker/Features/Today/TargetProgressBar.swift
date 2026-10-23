import SwiftUI

/// A tinted bar toward a target, with a caption saying how far there is to go or how far over it is.
struct TargetProgressBar: View {
    let progress: TargetProgress

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ProgressView(value: min(progress.fraction, 1))
                .tint(progress.tone.color)
                .accessibilityHidden(true)
            Text(caption)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var caption: LocalizedStringResource {
        let unit = progress.nutrient.unit
        let target = unit.formatted(progress.target)
        let difference = unit.formatted(progress.difference)
        return switch progress.status {
        case .deficit: .targetDeficit(target, difference)
        case .onTarget: .targetOnTarget(target)
        case .surplus: .targetSurplus(target, difference)
        }
    }
}

#Preview {
    List {
        TargetProgressBar(progress: TargetProgress(nutrient: .protein, total: 112, target: 150))
        TargetProgressBar(progress: TargetProgress(nutrient: .fat, total: 66, target: 65))
        TargetProgressBar(progress: TargetProgress(nutrient: .carbohydrates, total: 260, target: 200))
    }
}
