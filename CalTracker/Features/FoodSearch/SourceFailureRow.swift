import SwiftUI

/// An inline note that one database couldn't answer, shown above the other's results.
struct SourceFailureRow: View {
    let failure: SourceFailure

    var body: some View {
        Label {
            VStack(alignment: .leading) {
                Text(failure.source.title)
                    .font(.subheadline)
                    .bold()
                Text(userMessage(for: failure.error))
                    .font(.subheadline)
            }
        } icon: {
            Image(systemName: "exclamationmark.triangle")
        }
        .foregroundStyle(.secondary)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    List {
        SourceFailureRow(failure: SourceFailure(source: .usda, error: APIError.rateLimited))
    }
}
