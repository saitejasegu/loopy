import XCTest

final class LoopyUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunchAndReachToday() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-hasCompletedOnboarding", "YES"]
        app.launch()

        // Onboarding may still appear for first install; dismiss if present.
        if app.buttons["Get started"].waitForExistence(timeout: 2) {
            app.buttons["Get started"].tap()
            if app.textFields["Your name"].waitForExistence(timeout: 2) {
                app.textFields["Your name"].tap()
                app.textFields["Your name"].typeText("Tester")
                app.buttons["Continue"].tap()
            }
            if app.buttons["Start looping"].waitForExistence(timeout: 2) {
                app.buttons["Start looping"].tap()
            }
        }

        XCTAssertTrue(
            app.staticTexts["Today’s habits"].waitForExistence(timeout: 5)
                || app.staticTexts["Hey there"].waitForExistence(timeout: 5)
                || app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Hey'")).firstMatch.waitForExistence(timeout: 5)
        )
    }

    @MainActor
    func testOpenAddHabitSheet() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-hasCompletedOnboarding", "YES"]
        app.launch()

        if app.buttons["Get started"].waitForExistence(timeout: 1) {
            throw XCTSkip("Onboarding still required in this fresh install path")
        }

        let addButton = app.buttons["Add habit"]
        if addButton.waitForExistence(timeout: 3) {
            addButton.tap()
        } else if app.buttons["Add Habit"].waitForExistence(timeout: 2) {
            app.buttons["Add Habit"].tap()
        } else {
            XCTFail("Could not find add habit control")
            return
        }

        XCTAssertTrue(
            app.staticTexts["New habit"].waitForExistence(timeout: 5)
                || app.textFields["Name"].waitForExistence(timeout: 5)
                || app.textFields["e.g. Stretch"].waitForExistence(timeout: 5)
        )
        app.buttons["Cancel"].tap()
    }
}
