import SwiftUI

extension TargetTone {
    /// The tint for progress bars in this tone.
    var color: Color {
        switch self {
        case .caution: .yellow
        case .good: .green
        case .alert: .red
        }
    }
}
