import SwiftUI

/// The root screen: today's totals and log, with buttons to add food and edit targets.
///
/// Arrows and swipes step back through earlier days that have entries, which are read-only.
/// It owns the navigation path and every sheet, so logging a food can return here in one step.
struct TodayView: View {
    /// How long the log confirmation stays on screen.
    private static let confirmationDuration: Duration = .seconds(3)

    /// How long a confirmation with Undo stays on screen, long enough to reach the button.
    private static let undoableConfirmationDuration: Duration = .seconds(5)

    /// How long a confirmation with Undo stays while VoiceOver runs, so there's time to find the button.
    private static let undoableConfirmationVoiceOverDuration: Duration = .seconds(10)

    @Environment(\.calendar) private var calendar
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dependencies) private var dependencies
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled

    @State private var path: [TodayDestination] = []
    @State private var sheet: TodaySheet?

    /// The food just logged, shown as a banner until it times out.
    @State private var confirmation: LoggedFood?

    /// Why undoing a log failed, shown in an alert.
    @State private var undoFailureMessage: LocalizedStringResource?

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
                ToolbarItem(placement: .topBarLeading) {
                    SyncStatusButton(status: dependencies.sync.status, action: showAccount)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button(.addFood, systemImage: "plus", action: showSearch)
                }
            }
            .navigationDestination(for: TodayDestination.self) { destination in
                switch destination {
                case .search:
                    FoodSearchView(
                        viewModel: dependencies.makeSearchViewModel(),
                        frequentFoods: dependencies.makeFrequentFoodsViewModel(),
                        customFoods: dependencies.makeCustomFoodsViewModel(),
                        onSelect: showLogFood,
                        onSelectFrequent: showLogFrequentFood,
                        onLogged: didLog,
                        onShowFilters: showSearchFilters,
                        onSelectCustom: showLogCustomFood,
                        onAddCustomFood: showCustomFood
                    )
                }
            }
            .safeAreaInset(edge: .bottom) {
                if let confirmation {
                    LogConfirmationBanner(loggedFood: confirmation, onUndo: undoConfirmedLog)
                        .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .sheet(item: $sheet) { sheet in
            switch sheet {
            case .logFood(let food, let grams):
                LogFoodView(viewModel: dependencies.makeLogFoodViewModel(food: food, grams: grams), onLogged: didLog)
            case .targets:
                TargetsView(viewModel: dependencies.makeTargetsViewModel())
            case .account:
                AccountView(viewModel: dependencies.makeAccountViewModel())
            case .searchFilters(let viewModel):
                FoodSearchFiltersView(
                    filters: viewModel.filters,
                    brandOptions: viewModel.brandOptions,
                    onApply: viewModel.applyFilters
                )
            case .customFood(let name, let library):
                CustomFoodView(viewModel: dependencies.makeCustomFoodViewModel(name: name)) { record in
                    didSaveCustomFood(record, library: library)
                }
            }
        }
        .sensoryFeedback(.success, trigger: confirmation) { _, newValue in
            newValue != nil
        }
        .task(id: confirmation) {
            await hideConfirmationAfterDelay()
        }
        .errorAlert(.deleteFailedTitle, message: $undoFailureMessage)
        // `initial: true` covers launch, so a separate launch sync would start a second pass.
        .onChange(of: scenePhase, initial: true) { _, newPhase in
            sceneDidChange(to: newPhase)
        }
        .task {
            await refreshOnSignificantTimeChanges()
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

    private func showAccount() {
        sheet = .account
    }

    private func showLogFood(_ food: FoodItem) {
        sheet = .logFood(food, grams: LogFoodViewModel.defaultGrams)
    }

    /// Opens the log sheet for a frequent food at the amount logged last time.
    private func showLogFrequentFood(_ frequentFood: FrequentFood) {
        sheet = .logFood(frequentFood.food, grams: frequentFood.grams)
    }

    private func showSearchFilters(for viewModel: FoodSearchViewModel) {
        sheet = .searchFilters(viewModel)
    }

    /// Opens the log sheet for one of the person's own foods at the weight they entered its values for.
    private func showLogCustomFood(_ record: CustomFoodRecord) {
        sheet = .logFood(record.food, grams: record.servingGrams)
    }

    private func showCustomFood(name: String, library: CustomFoodsViewModel) {
        sheet = .customFood(name: name, library: library)
    }

    /// Lists the new food on the search screen and replaces the custom food sheet with the log sheet for it.
    private func didSaveCustomFood(_ record: CustomFoodRecord, library: CustomFoodsViewModel) {
        library.reload()
        showLogCustomFood(record)
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

    /// Removes the entry the confirmation offers to undo, then hides the confirmation.
    private func undoConfirmedLog() {
        guard let confirmation, let entry = confirmation.undoableEntry else { return }
        // The person may have swiped the entry away already, and deleting it twice would leave a second tombstone.
        if entry.isDeleted == false, entry.modelContext != nil {
            do {
                try dependencies.foodLog.delete(entry)
            } catch {
                undoFailureMessage = userMessage(for: error)
                return
            }
        }
        withAnimation {
            self.confirmation = nil
        }
        AccessibilityNotification.Announcement(String(localized: .logUndoneAnnouncement(confirmation.name))).post()
    }

    private func hideConfirmationAfterDelay() async {
        guard let confirmation else { return }
        let duration = if confirmation.undoableEntry == nil {
            Self.confirmationDuration
        } else if voiceOverEnabled {
            Self.undoableConfirmationVoiceOverDuration
        } else {
            Self.undoableConfirmationDuration
        }
        do {
            try await Task.sleep(for: duration)
        } catch {
            // A newer confirmation replaced this one, or the view went away.
            return
        }
        withAnimation {
            self.confirmation = nil
        }
    }

    /// Rolls the log over and syncs at launch and whenever the app comes back to the foreground.
    private func sceneDidChange(to phase: ScenePhase) {
        if phase == .active {
            refreshReferenceDate()
            dependencies.sync.requestSync()
        }
    }

    private func refreshReferenceDate() {
        referenceDate = .now
    }

    /// Rolls the log over at midnight, and after a time zone or clock change, for as long as the view is on screen.
    private func refreshOnSignificantTimeChanges() async {
        for await _ in NotificationCenter.default.notifications(named: UIApplication.significantTimeChangeNotification) {
            refreshReferenceDate()
        }
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
        _ = try? store.log(food, grams: grams, loggedAt: date)
    }
    return TodayView()
        .modelContainer(container)
        .environment(\.dependencies, .live(modelContext: container.mainContext, tokenStore: InMemoryTokenStore()))
}
