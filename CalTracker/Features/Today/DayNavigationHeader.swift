import SwiftUI

/// Arrows to step between logged days, around the shown day's date or today's motivation.
///
/// It spans the full width of the card below it, with the centre held between the two arrows. On today, the centre is
/// a compact callout in the same colour as the progress bars. On a past day, it's the date. An arrow with nowhere to go
/// is hidden but keeps its space, so the centre stays centred.
struct DayNavigationHeader: View {
    @Environment(\.calendar) private var calendar

    /// The start of the day being shown.
    let day: Date

    /// Where the arrows can go.
    let navigation: DayNavigation

    /// Today's message, shown instead of the date on today.
    var motivation: DailyMotivation?

    /// Called with the start of the day to show.
    let onSelectDay: (Date) -> Void

    var body: some View {
        HStack(spacing: 4) {
            arrow(.previousDayAction, systemImage: "chevron.backward", to: navigation.previous)

            Group {
                if navigation.isToday {
                    if let motivation {
                        callout(for: motivation)
                    }
                } else {
                    date
                        .accessibilityAddTraits(.isHeader)
                }
            }
            .frame(maxWidth: .infinity)

            arrow(.nextDayAction, systemImage: "chevron.forward", to: navigation.next)
        }
        .textCase(nil)
    }

    private func callout(for motivation: DailyMotivation) -> some View {
        Label {
            Text(motivation.message)
        } icon: {
            Image(systemName: motivation.systemImage)
                .foregroundStyle(motivation.tone.color)
        }
        .font(.subheadline)
        .bold()
        // Section headers dim hierarchical styles, so the message uses the primary colour directly.
        .foregroundStyle(Color.primary)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(motivation.tone.color.quaternary, in: .rect(cornerRadius: 10))
    }

    private var date: some View {
        let format: Date.FormatStyle = calendar.isDate(day, equalTo: .now, toGranularity: .year)
            ? .dateTime.weekday(.abbreviated).month(.abbreviated).day()
            : .dateTime.weekday(.abbreviated).month(.abbreviated).day().year()
        return Text(day, format: format)
            .font(.headline)
            // Section headers dim hierarchical styles, so the date uses the primary colour directly.
            .foregroundStyle(Color.primary)
    }

    @ViewBuilder
    private func arrow(_ title: LocalizedStringResource, systemImage: String, to destination: Date?) -> some View {
        let button = Button(title, systemImage: systemImage) {
            if let destination {
                onSelectDay(destination)
            }
        }
        .labelStyle(.iconOnly)
        .font(.subheadline)
        .bold()
        .foregroundStyle(.secondary)
        .frame(minWidth: 44, minHeight: 44)
        .contentShape(.rect)

        if destination == nil {
            // Hidden rather than removed, so it still takes up its share of the row.
            button.hidden()
        } else {
            button
        }
    }
}

#Preview {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: .now)
    let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today
    List {
        Section {
            Text(verbatim: "Today")
        } header: {
            DayNavigationHeader(
                day: today,
                navigation: DayNavigation(day: today, today: today, previousEntryDate: yesterday, nextEntryDate: nil, calendar: calendar),
                motivation: .energyRemaining(kilocalories: 620)
            ) { _ in }
        }
        Section {
            Text(verbatim: "Yesterday")
        } header: {
            DayNavigationHeader(
                day: yesterday,
                navigation: DayNavigation(day: yesterday, today: today, previousEntryDate: nil, nextEntryDate: nil, calendar: calendar)
            ) { _ in }
        }
    }
}
