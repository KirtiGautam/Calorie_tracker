import SwiftData
import SwiftUI

/// The totals and entries for one day, backed by a `@Query` filtered on `loggedAt`.
struct TodayLogList: View {
    @Environment(\.dependencies) private var dependencies

    /// Called when the person taps the prompt to set targets.
    let onSetTargets: () -> Void

    @Query private var entries: [FoodLogEntry]
    @State private var failureMessage: LocalizedStringResource?

    /// Creates a list of entries logged on the same day as `day` in `calendar`.
    init(day: Date, calendar: Calendar, onSetTargets: @escaping () -> Void) {
        _entries = Query(
            filter: FoodLogEntry.loggedOnSameDay(as: day, calendar: calendar),
            sort: \.loggedAt,
            order: .reverse
        )
        self.onSetTargets = onSetTargets
    }

    var body: some View {
        let totals = DailyTotals(entries: entries.map(\.nutrients))
        let targets = dependencies.targets.targets

        List {
            Section {
                DailyTotalsCard(
                    totals: totals,
                    targets: targets,
                    goal: targets.isEmpty ? nil : dependencies.targets.goal
                )
                if targets.isEmpty {
                    Button(.setTargetsPrompt, systemImage: "target", action: onSetTargets)
                }
                MicronutrientDisclosure(totals: totals)
            }

            Section {
                if entries.isEmpty {
                    Text(.emptyLogMessage)
                        .foregroundStyle(.secondary)
                }
                ForEach(entries) { entry in
                    LogEntryRow(entry: entry)
                }
                .onDelete(perform: delete)
            } header: {
                Text(.logSection)
            }
        }
        .alert(.deleteFailedTitle, item: $failureMessage) { _ in
        } message: { message in
            Text(message)
        }
    }

    private func delete(at offsets: IndexSet) {
        let doomed = offsets.map { entries[$0] }
        do {
            for entry in doomed {
                try dependencies.foodLog.delete(entry)
            }
        } catch {
            failureMessage = userMessage(for: error)
        }
    }
}

#Preview {
    NavigationStack {
        TodayLogList(day: .now, calendar: .current) {}
    }
    .modelContainer(AppModelContainer.preview)
}
