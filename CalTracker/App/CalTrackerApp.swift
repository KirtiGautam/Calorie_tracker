import SwiftData
import SwiftUI

@main
struct CalTrackerApp: App {
    private let modelContainer: ModelContainer
    private let dependencies: AppDependencies

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
