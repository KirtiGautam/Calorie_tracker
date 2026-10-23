import XCTest

/// Drives the targets flow: pick a goal, calculate from body measurements, save, and see progress on Today.
@MainActor
final class TargetsFlowUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testCalculateAndSaveCutTargets() {
        let app = XCUIApplication()
        // The arguments domain shadows earlier runs' saved targets with unreadable values, so the editor starts blank.
        app.launchArguments += ["-targets.daily", "", "-targets.bodyProfile", "", "-targets.goal", ""]
        app.launch()

        // Not scoped to the navigation bar: on wide windows iOS moves toolbar items into a side toolbar.
        app.buttons["Targets"].tap()
        XCTAssertTrue(app.navigationBars["Daily Targets"].waitForExistence(timeout: 5), "The Targets sheet never appeared")

        app.buttons["Cut"].tap()

        // Pick Male so the result matches the worked example: 2,040 kcal for a moderate cut.
        // Pickers come first, before the keyboard can cover them.
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Sex")).firstMatch.tap()
        app.buttons["Male"].tap()

        fill(app.textFields["Age"], with: "30")
        fill(app.textFields["Height (cm)"], with: "175")
        fill(app.textFields["Weight (kg)"], with: "70")
        attachScreenshot(named: "1 Body measurements")

        let calculate = app.buttons["Calculate Targets"]
        XCTAssertTrue(calculate.isEnabled, "Calculate is disabled, so the measurements weren't accepted")
        calculate.tap()
        let energyField = app.textFields["Energy"]
        XCTAssertEqual(energyField.value as? String, "2,040", "Calculate didn't fill in the energy target")
        attachScreenshot(named: "2 Calculated")

        app.buttons["Save"].tap()
        XCTAssertTrue(app.navigationBars["Today"].waitForExistence(timeout: 5), "Saving didn't return to Today")

        let badge = app.descendants(matching: .any)["Goal: Cut"]
        XCTAssertTrue(badge.waitForExistence(timeout: 5), "The Cut badge isn't on the totals card")
        let energyCaption = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "2,040 kcal")).firstMatch
        XCTAssertTrue(energyCaption.exists, "The energy target isn't shown on Today")
        attachScreenshot(named: "3 Today with targets")
    }

    private func fill(_ field: XCUIElement, with text: String) {
        XCTAssertTrue(field.waitForExistence(timeout: 5), "\(field) doesn't exist")
        field.tap()
        field.typeText(text)
        XCTAssertEqual(field.value as? String, text, "\(field) didn't end up holding exactly \(text)")
    }

    private func attachScreenshot(named name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
