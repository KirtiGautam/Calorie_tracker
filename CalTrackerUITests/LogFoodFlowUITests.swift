import XCTest

/// Drives the whole logging flow against the live food APIs: search, pick a result, log it.
@MainActor
final class LogFoodFlowUITests: XCTestCase {
    /// The search debounce plus a generous allowance for both APIs to answer.
    private let resultsTimeout: TimeInterval = 30

    override func setUp() {
        continueAfterFailure = false
    }

    func testSearchPickAndLogRajma() {
        let app = XCUIApplication()
        app.launch()
        attachScreenshot(named: "1 Today")

        // Not scoped to the navigation bar: on wide windows iOS moves toolbar items into a side toolbar.
        app.buttons["Add Food"].tap()

        let searchField = app.searchFields.firstMatch
        XCTAssertTrue(searchField.waitForExistence(timeout: 5), "The search field never appeared")
        searchField.tap()

        // Type one character at a time so a dropped keystroke shows exactly where it happened.
        var typed = ""
        for character in "rajma" {
            searchField.typeText(String(character))
            typed.append(character)
            XCTAssertEqual(searchField.value as? String, typed, "The search field dropped a keystroke")
        }
        attachScreenshot(named: "2 Typed rajma")

        // Result rows read as "<name>, <source>, <energy>, per 100 g".
        let firstResult = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "per 100 g")).firstMatch
        XCTAssertTrue(firstResult.waitForExistence(timeout: resultsTimeout), "No search results appeared")
        attachScreenshot(named: "3 Results")
        let pickedLabel = firstResult.label
        firstResult.tap()

        let logButton = app.buttons["Log"]
        XCTAssertTrue(logButton.waitForExistence(timeout: 5), "The Log Food sheet never appeared")
        attachScreenshot(named: "4 Log Food sheet")
        logButton.tap()

        // Logging closes the sheet onto Today, which confirms what was logged.
        XCTAssertTrue(logButton.waitForNonExistence(timeout: 5), "The Log Food sheet didn't close")
        let confirmation = app.descendants(matching: .any)["logConfirmation"]
        XCTAssertTrue(confirmation.waitForExistence(timeout: 5), "No log confirmation appeared")
        attachScreenshot(named: "5 Confirmation")
        XCTAssertTrue(confirmation.label.hasPrefix("Logged"), "Unexpected confirmation: \(confirmation.label)")
        XCTAssertTrue(app.navigationBars["Today"].waitForExistence(timeout: 5), "Logging didn't return to Today")
        XCTAssertFalse(app.searchFields.firstMatch.exists, "The search screen is still showing")
        XCTAssertTrue(confirmation.waitForNonExistence(timeout: 6), "The confirmation never went away")

        let pickedName = pickedLabel.components(separatedBy: ",").first ?? pickedLabel
        let loggedEntry = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", pickedName)).firstMatch
        XCTAssertTrue(loggedEntry.waitForExistence(timeout: 5), "\(pickedName) isn't in today's log")
        attachScreenshot(named: "6 Logged")
    }

    private func attachScreenshot(named name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
