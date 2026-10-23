import SwiftUI

extension EnvironmentValues {
    /// The app's services. `CalTrackerApp` injects the live set; the default is the stable, in-memory preview set.
    @Entry var dependencies: AppDependencies = .preview
}
