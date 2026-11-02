import SwiftUI

/// The cloud in the Today toolbar that shows where sync stands and opens the account sheet.
///
/// Every state has its own shape as well as its own color: an outline when signed out, a spinner while
/// syncing, a filled cloud when up to date, and a badge when the last sync failed.
struct SyncStatusButton: View {
    /// Where sync stands.
    let status: SyncStatus

    /// Opens the account sheet.
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        // The icon is the button's whole content rather than a Label's icon, because a toolbar draws a Label's icon
        // in its own monochrome style, which drops the state colors and the spinner and badge overlays. The
        // accessibility label gives VoiceOver and Voice Control its name.
        Button(action: action) {
            icon
                .accessibilityHidden(true)
        }
        .accessibilityLabel(Text(accessibilityLabel))
        .accessibilityHint(Text(.syncStatusHint))
        .animation(reduceMotion ? nil : .default, value: status)
    }

    @ViewBuilder
    private var icon: some View {
        switch status {
        case .signedOut:
            Image(systemName: "cloud")
                .foregroundStyle(.red)
        case .syncing:
            Image(systemName: "cloud.fill")
                .foregroundStyle(.secondary)
                .overlay {
                    if reduceMotion {
                        // A still symbol instead of a spinning one.
                        Image(systemName: "ellipsis")
                            .font(.caption2.bold())
                            .foregroundStyle(.background)
                    } else {
                        ProgressView()
                            .controlSize(.mini)
                            .tint(Color(uiColor: .systemBackground))
                    }
                }
        case .upToDate:
            Image(systemName: "cloud.fill")
                .foregroundStyle(.green)
        case .failed:
            Image(systemName: "cloud.fill")
                .foregroundStyle(.orange)
                .overlay(alignment: .bottomTrailing) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.caption2)
                        .foregroundStyle(.white, .orange)
                        .offset(x: 4, y: 4)
                }
        }
    }

    private var accessibilityLabel: LocalizedStringResource {
        switch status {
        case .signedOut: .syncSignedOutLabel
        case .syncing: .syncSyncingLabel
        case .upToDate: .syncUpToDateLabel
        case .failed: .syncFailedLabel
        }
    }
}

#Preview {
    HStack(spacing: 24) {
        SyncStatusButton(status: .signedOut) {}
        SyncStatusButton(status: .syncing) {}
        SyncStatusButton(status: .upToDate(.now)) {}
        SyncStatusButton(status: .failed(.errorSyncServer)) {}
    }
    .font(.title)
}
