import SwiftData
import SwiftUI

/// The totals and entries for one day, backed by a `@Query` filtered on `loggedAt`.
///
/// Today's entries can be deleted. Past days are read-only.
struct TodayLogList: View {
    /// How far a horizontal swipe must travel to change the day.
    private static let swipeThreshold: CGFloat = 60

    @Environment(\.dependencies) private var dependencies
    @Environment(\.layoutDirection) private var layoutDirection

    /// The start of the day being shown.
    private let day: Date

    /// The start of the current day, which bounds how far forward the person can go.
    private let today: Date

    /// The calendar that defines where days start.
    private let calendar: Calendar

    /// Called when the person taps the prompt to set targets.
    let onSetTargets: () -> Void

    /// Called with the start of the day to show next.
    let onSelectDay: (Date) -> Void

    @Query private var entries: [FoodLogEntry]

    /// The latest entry before `day`, used to find the previous day with entries.
    @Query private var previousEntries: [FoodLogEntry]

    /// The earliest entry after `day` and before today, used to find the next day with entries.
    @Query private var nextEntries: [FoodLogEntry]

    @State private var failureMessage: LocalizedStringResource?

    /// Creates a list of entries logged on the same day as `day` in `calendar`.
    ///
    /// - Parameters:
    ///   - day: Any moment in the day to show.
    ///   - today: Any moment in the current day, which bounds how far forward the person can go.
    ///   - calendar: The calendar that defines where days start.
    ///   - onSetTargets: Called when the person taps the prompt to set targets.
    ///   - onSelectDay: Called with the start of the day to show next.
    init(
        day: Date,
        today: Date,
        calendar: Calendar,
        onSetTargets: @escaping () -> Void,
        onSelectDay: @escaping (Date) -> Void
    ) {
        self.day = calendar.startOfDay(for: day)
        _entries = Query(
            filter: FoodLogEntry.loggedOnSameDay(as: day, calendar: calendar),
            sort: \.loggedAt,
            order: .reverse
        )

        var previous = FetchDescriptor(
            predicate: FoodLogEntry.loggedBeforeDay(of: day, calendar: calendar),
            sortBy: [SortDescriptor(\.loggedAt, order: .reverse)]
        )
        previous.fetchLimit = 1
        _previousEntries = Query(previous)

        var next = FetchDescriptor(
            predicate: FoodLogEntry.loggedBetweenDay(after: day, andDay: today, calendar: calendar),
            sortBy: [SortDescriptor(\.loggedAt)]
        )
        next.fetchLimit = 1
        _nextEntries = Query(next)

        self.today = calendar.startOfDay(for: today)
        self.calendar = calendar
        self.onSetTargets = onSetTargets
        self.onSelectDay = onSelectDay
    }

    var body: some View {
        let totals = DailyTotals(entries: entries.map(\.nutrients))
        let targets = dependencies.targets.targets
        let navigation = DayNavigation(
            day: day,
            today: today,
            previousEntryDate: previousEntries.first?.loggedAt,
            nextEntryDate: nextEntries.first?.loggedAt,
            calendar: calendar
        )
        let motivation: DailyMotivation? = navigation.isToday
            ? DailyMotivation(targets: targets, totals: totals, hasEntries: entries.isEmpty == false)
            : nil
        let emptyMessage: LocalizedStringResource = navigation.isToday ? .emptyLogMessage : .emptyPastDayMessage
        let logHeader: LocalizedStringResource = navigation.isToday ? .logSection : .pastDayLogSection

        List {
            Section {
                DailyTotalsCard(
                    totals: totals,
                    targets: targets,
                    goal: targets.isEmpty ? nil : dependencies.targets.goal
                )
                if navigation.isToday && targets.isEmpty {
                    Button(.setTargetsPrompt, systemImage: "target", action: onSetTargets)
                }
                MicronutrientDisclosure(totals: totals)
            } header: {
                DayNavigationHeader(
                    day: day,
                    navigation: navigation,
                    motivation: motivation,
                    onSelectDay: onSelectDay
                )
                // Drop the header's text inset so the callout lines up with the card's edges.
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 8, trailing: 0))
            }

            Section {
                if entries.isEmpty {
                    Text(emptyMessage)
                        .foregroundStyle(.secondary)
                }
                ForEach(entries) { entry in
                    LogEntryRow(entry: entry)
                        .deleteDisabled(navigation.isToday == false)
                }
                .onDelete(perform: delete)
            } header: {
                Text(logHeader)
            }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 24).onEnded { value in
                swipe(value.translation, navigation: navigation)
            }
        )
        .alert(.deleteFailedTitle, item: $failureMessage) { _ in
        } message: { message in
            Text(message)
        }
    }

    /// Steps to the previous or next day for a mostly horizontal swipe, following the reading direction.
    private func swipe(_ translation: CGSize, navigation: DayNavigation) {
        guard abs(translation.width) > Self.swipeThreshold,
              abs(translation.width) > abs(translation.height) * 2 else { return }
        // Swiping toward the trailing edge reveals the earlier day, like turning back a page.
        let towardTrailing = layoutDirection == .leftToRight ? translation.width > 0 : translation.width < 0
        if let destination = towardTrailing ? navigation.previous : navigation.next {
            onSelectDay(destination)
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
        TodayLogList(day: .now, today: .now, calendar: .current, onSetTargets: {}, onSelectDay: { _ in })
    }
    .modelContainer(AppModelContainer.preview)
}
