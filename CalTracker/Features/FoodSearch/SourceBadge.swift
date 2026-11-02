import SwiftUI

/// A small capsule naming the database a food came from.
struct SourceBadge: View {
    /// The database to name.
    let source: FoodSource

    var body: some View {
        Text(source.title)
            .capsuleBadge()
    }
}

#Preview {
    VStack {
        SourceBadge(source: .usda)
        SourceBadge(source: .openFoodFacts)
    }
}
