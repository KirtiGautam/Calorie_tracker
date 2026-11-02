import Foundation
import Testing
@testable import CalTracker

struct UserMessageTests {
    @Test func anInvalidTargetHasItsOwnMessage() {
        #expect(userMessage(for: TargetsError.invalidTarget).key == LocalizedStringResource.errorInvalidTarget.key)
    }

    @Test func anInvalidAmountKeepsTheLoggingMessage() {
        #expect(userMessage(for: LogFoodError.invalidAmount).key == LocalizedStringResource.errorInvalidAmount.key)
    }
}
