import SwiftUI

/// A small capsule naming the database a food came from.
struct SourceBadge: View {
    let source: FoodSource

    /// Capsule insets that grow with Dynamic Type so the badge never clips its text.
    @ScaledMetric(relativeTo: .caption) private var horizontalInset = 8.0
    @ScaledMetric(relativeTo: .caption) private var verticalInset = 4.0

    var body: some View {
        Text(source.title)
            .font(.caption)
            .bold()
            .foregroundStyle(.secondary)
            .padding(.horizontal, horizontalInset)
            .padding(.vertical, verticalInset)
            .background(.fill.tertiary, in: .capsule)
    }
}

#Preview {
    VStack {
        SourceBadge(source: .usda)
        SourceBadge(source: .openFoodFacts)
    }
}
