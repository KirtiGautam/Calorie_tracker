import XCTest

/// Drives entering a custom food from the search screen and logging it. It needs no network.
@MainActor
final class CustomFoodFlowUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testEnterAndLogACustomFood() {
        let app = XCUIApplication()
        app.launchArguments += ["-search.regionFilterEnabled", "NO"]
        app.launch()

        // Not scoped to the navigation bar: on wide windows iOS moves toolbar items into a side toolbar.
        app.buttons["Add Food"].tap()
        let addCustomFood = app.buttons["addCustomFood"]
        XCTAssertTrue(addCustomFood.waitForExistence(timeout: 5), "There's no way to add a custom food")
        addCustomFood.tap()

        // A unique name, because custom foods stay on the simulator between runs.
        let name = "Test Kadhi \(Int.random(in: 1_000...9_999))"
        let nameField = app.textFields["customFoodName"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5), "The Custom Food sheet never appeared")
        nameField.tap()
        nameField.typeText(name)

        // Energy is left blank, so it's calculated from the macros.
        for (field, value) in [("Protein", "4"), ("Carbs", "10"), ("Fat", "5")] {
            let textField = app.textFields[field]
            textField.tap()
            textField.typeText(value)
        }
        attachScreenshot(named: "1 Custom food")

        app.buttons["Save"].tap()

        // Saving opens the log sheet at the weight the values were entered for.
        let gramsField = app.textFields["Grams"]
        XCTAssertTrue(gramsField.waitForExistence(timeout: 5), "The Log Food sheet never appeared")
        XCTAssertEqual(gramsField.value as? String, "100", "The sheet didn't start at the entered weight")
        attachScreenshot(named: "2 Log Food sheet")
        app.buttons["Log"].tap()

        let confirmation = app.descendants(matching: .any)["logConfirmation"]
        XCTAssertTrue(confirmation.waitForExistence(timeout: 5), "No log confirmation appeared")
        XCTAssertTrue(app.navigationBars["Today"].waitForExistence(timeout: 5), "Logging didn't return to Today")
        let loggedEntry = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", name)).firstMatch
        XCTAssertTrue(loggedEntry.waitForExistence(timeout: 5), "\(name) isn't in today's log")
        attachScreenshot(named: "3 Logged")
    }

    private func attachScreenshot(named name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
