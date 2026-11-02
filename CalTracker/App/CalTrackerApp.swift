import SwiftData
import SwiftUI

/// The app: one window showing Today, backed by the shared database and dependencies.
@main
struct CalTrackerApp: App {
    private let modelContainer: ModelContainer
    private let dependencies: AppDependencies

    /// Opens the database and builds the live dependencies, seeding sample meals when a Debug launch asks for them.
    init() {
        let container = AppModelContainer.make()
        #if DEBUG
        SampleLogSeeder.seedIfRequested(into: container.mainContext)
        #endif
        modelContainer = container
        dependencies = .live(modelContext: container.mainContext)
    }

    var body: some Scene {
        WindowGroup {
            TodayView()
        }
        .modelContainer(modelContainer)
        .environment(\.dependencies, dependencies)
    }
}
