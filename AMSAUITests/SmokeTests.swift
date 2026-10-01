import XCTest

/// Launch smoke test: a signed-out launch lands on Login and can reach Signup and Forgot password.
final class SmokeTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testSignedOutLaunchShowsAuthFlow() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestSignedOut"]
        app.launch()

        XCTAssertTrue(app.staticTexts["Welcome back"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Sign in to your AMSA account"].exists)
        XCTAssertTrue(app.textFields.firstMatch.exists)
        XCTAssertTrue(app.secureTextFields.firstMatch.exists)
    }

    @MainActor
    func testLoginLinksToSignupAndForgotPassword() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestSignedOut"]
        app.launch()

        XCTAssertTrue(app.buttons["Register"].waitForExistence(timeout: 10))
        app.buttons["Register"].tap()
        XCTAssertTrue(app.staticTexts["Create an account"].waitForExistence(timeout: 5))

        app.terminate()
        app.launch()
        XCTAssertTrue(app.buttons["Forgot password?"].waitForExistence(timeout: 10))
        app.buttons["Forgot password?"].tap()
        XCTAssertTrue(app.staticTexts["Forgot password"].waitForExistence(timeout: 5))
    }
}
