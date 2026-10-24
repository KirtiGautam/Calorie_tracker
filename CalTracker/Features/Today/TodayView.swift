import SwiftUI

/// The root screen: today's totals and log, with buttons to add food and edit targets.
///
/// Arrows and swipes step back through earlier days that have entries, which are read-only.
/// It owns the navigation path and every sheet, so logging a food can return here in one step.
struct TodayView: View {
    /// How long the log confirmation stays on screen.
    private static let confirmationDuration: Duration = .seconds(3)

    @Environment(\.calendar) private var calendar
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dependencies) private var dependencies
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var path: [TodayDestination] = []
    @State private var sheet: TodaySheet?

    /// The food just logged, shown as a banner until it times out.
    @State private var confirmation: LoggedFood?

    /// The moment that defines "today".
    ///
    /// It's refreshed on a significant time change (midnight, or a time zone or clock change) and whenever the app
    /// becomes active, so the log rolls over even while the app stays open.
    @State private var referenceDate = Date.now

    /// The start of the past day being shown, or `nil` to show today and follow it across midnight.
    @State private var selectedDay: Date?

    /// Whether the last day change moved later in time, which sets the direction of the transition.
    @State private var isMovingForward = false

    var body: some View {
        let day = selectedDay ?? calendar.startOfDay(for: referenceDate)

        NavigationStack(path: $path) {
            ZStack {
                // The environment calendar isn't readable in an init, so the child that owns the @Query receives it here.
                TodayLogList(
                    day: day,
                    today: referenceDate,
                    calendar: calendar,
                    onSetTargets: showTargets,
                    onSelectDay: select
                )
                .id(day)
                .transition(reduceMotion ? .opacity : .push(from: isMovingForward ? .trailing : .leading))
            }
            .navigationTitle(title)
            // Inline, so the title doesn't shout over the day's totals.
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(.targetsAction, systemImage: "target", action: showTargets)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button(.addFood, systemImage: "plus", action: showSearch)
                }
            }
            .navigationDestination(for: TodayDestination.self) { destination in
                switch destination {
                case .search:
                    FoodSearchView(viewModel: dependencies.makeSearchViewModel(), onSelect: showLogFood)
                }
            }
            .safeAreaInset(edge: .bottom) {
                if let confirmation {
                    LogConfirmationBanner(loggedFood: confirmation)
                        .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .sheet(item: $sheet) { sheet in
            switch sheet {
            case .logFood(let food):
                LogFoodView(viewModel: dependencies.makeLogFoodViewModel(food: food), onLogged: didLog)
            case .targets:
                TargetsView(viewModel: dependencies.makeTargetsViewModel())
            }
        }
        .sensoryFeedback(.success, trigger: confirmation) { _, newValue in
            newValue != nil
        }
        .task(id: confirmation) {
            await hideConfirmationAfterDelay()
        }
        .onChange(of: scenePhase) { _, newPhase in
            refreshReferenceDate(for: newPhase)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
            refreshReferenceDate()
        }
    }

    /// "Today", or a neutral title while a past day is shown.
    private var title: LocalizedStringResource {
        selectedDay == nil ? .todayTitle : .pastDayTitle
    }

    /// Shows the day that starts at `day`, sliding in from the side it comes from.
    private func select(_ day: Date) {
        let current = selectedDay ?? calendar.startOfDay(for: referenceDate)
        isMovingForward = day > current
        withAnimation {
            selectedDay = calendar.isDate(day, inSameDayAs: referenceDate) ? nil : day
        }
    }

    private func showSearch() {
        path.append(.search)
    }

    private func showTargets() {
        sheet = .targets
    }

    private func showLogFood(_ food: FoodItem) {
        sheet = .logFood(food)
    }

    /// Returns to Today behind the closing sheet and confirms what was logged.
    private func didLog(_ loggedFood: LoggedFood) {
        path.removeAll()
        selectedDay = nil
        withAnimation {
            confirmation = loggedFood
        }
        AccessibilityNotification.Announcement(String(localized: loggedFood.message)).post()
    }

    private func hideConfirmationAfterDelay() async {
        guard confirmation != nil else { return }
        do {
            try await Task.sleep(for: Self.confirmationDuration)
        } catch {
            // A newer confirmation replaced this one, or the view went away.
            return
        }
        withAnimation {
            confirmation = nil
        }
    }

    private func refreshReferenceDate(for phase: ScenePhase) {
        if phase == .active {
            refreshReferenceDate()
        }
    }

    private func refreshReferenceDate() {
        referenceDate = .now
    }
}

#Preview {
    TodayView()
        .modelContainer(AppModelContainer.preview)
}

#Preview("Past days") {
    let container = AppModelContainer.make(inMemory: true)
    let store = FoodLogStore(modelContext: container.mainContext)
    let calendar = Calendar.current
    // Today, yesterday, and three days ago, leaving a gap the arrows skip.
    let seeds: [(daysAgo: Int, food: FoodItem, grams: Double)] = [
        (0, .previewBanana, 120), (1, .previewNutella, 30), (3, .previewBanana, 200),
    ]
    for (daysAgo, food, grams) in seeds {
        let date = calendar.date(byAdding: .day, value: -daysAgo, to: .now) ?? .now
        try? store.log(food, grams: grams, loggedAt: date)
    }
    return TodayView()
        .modelContainer(container)
        .environment(\.dependencies, .live(modelContext: container.mainContext))
}
