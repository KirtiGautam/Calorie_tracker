import XCTest

/// Drives quick add on the search screen: open a frequent food at its last amount, log one with +, then undo it.
///
/// The frequent foods come from the Debug sample log, so this flow needs no network.
@MainActor
final class QuickAddFlowUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testOpenLogAndUndoAFrequentFood() throws {
        let app = XCUIApplication()
        // Seeding fills only past days that have no entries, so running it again never duplicates meals.
        app.launchArguments += ["-seedSampleLog", "-sampleLog.seeded", "NO", "-search.regionFilterEnabled", "NO"]
        app.launch()

        // Not scoped to the navigation bar: on wide windows iOS moves toolbar items into a side toolbar.
        app.buttons["Add Food"].tap()

        let quickLog = app.buttons["quickLog"].firstMatch
        XCTAssertTrue(quickLog.waitForExistence(timeout: 5), "No frequent foods appeared")
        attachScreenshot(named: "1 Frequent foods")

        // The + button reads "Log <amount> g of <name>".
        let label = quickLog.label
        let amount = try XCTUnwrap(label.firstMatch(of: /\d[\d,.]*/)?.output, "No amount in \(label)")
        let nameStart = try XCTUnwrap(label.range(of: " of ")?.upperBound, "No food name in \(label)")
        let name = String(label[nameStart...])

        // The row opens the log sheet at the amount logged last time.
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", name)).firstMatch.tap()
        let gramsField = app.textFields["Grams"]
        XCTAssertTrue(gramsField.waitForExistence(timeout: 5), "The Log Food sheet never appeared")
        XCTAssertEqual(gramsField.value as? String, String(amount), "The sheet didn't start at the last amount")
        attachScreenshot(named: "2 Log Food sheet")
        // Not scoped to the navigation bar, for the same reason as Add Food.
        app.buttons["Cancel"].tap()
        XCTAssertTrue(gramsField.waitForNonExistence(timeout: 5), "The Log Food sheet didn't close")

        // + logs straight away and returns to Today, where the confirmation offers Undo.
        quickLog.tap()
        let confirmation = app.descendants(matching: .any)["logConfirmation"]
        XCTAssertTrue(confirmation.waitForExistence(timeout: 5), "No log confirmation appeared")
        XCTAssertTrue(confirmation.label.hasPrefix("Logged"), "Unexpected confirmation: \(confirmation.label)")
        XCTAssertTrue(app.navigationBars["Today"].waitForExistence(timeout: 5), "Quick add didn't return to Today")
        let loggedEntries = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", name))
        XCTAssertTrue(loggedEntries.firstMatch.waitForExistence(timeout: 5), "\(name) isn't in today's log")
        let countWithQuickAdd = loggedEntries.count
        attachScreenshot(named: "3 Confirmation with Undo")

        let undo = app.buttons["undoLog"]
        XCTAssertTrue(undo.exists, "The confirmation has no Undo button")
        undo.tap()
        XCTAssertTrue(confirmation.waitForNonExistence(timeout: 3), "Undo didn't dismiss the confirmation")
        // A row can match more than once (the row and its name), and the food may have been logged earlier today,
        // so compare with the count before Undo rather than expecting a specific number.
        let removed = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "count < %d", countWithQuickAdd),
            object: loggedEntries
        )
        XCTAssertEqual(XCTWaiter.wait(for: [removed], timeout: 5), .completed, "Undo didn't remove the entry")
        attachScreenshot(named: "4 Undone")
    }

    private func attachScreenshot(named name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
