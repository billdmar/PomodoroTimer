//
//  pomadoro2UITests.swift
//  pomadoro2UITests
//
//  Smoke tests covering the core timer screen. The welcome carousel is skipped
//  via a launch argument so these tests start deterministically on the main UI.
//

import XCTest

final class pomadoro2UITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-skipWelcome"]
        app.launch()
        return app
    }

    @MainActor
    func testLaunchesAndReachesTimerScreen() throws {
        let app = launchApp()

        // The main screen shows the "🍅 Pomodoro" title.
        let title = app.staticTexts["🍅 Pomodoro"]
        XCTAssertTrue(title.waitForExistence(timeout: 5), "Main timer screen should appear on launch")
    }

    @MainActor
    func testStartingASessionShowsFocusTimer() throws {
        let app = launchApp()

        // The timer dial carries the "Focus timer" label with an `.isButton`
        // trait, so it surfaces as a button. Tapping it starts the session.
        let focusTimer = app.buttons["Focus timer"]
        XCTAssertTrue(focusTimer.waitForExistence(timeout: 5), "Idle focus timer dial should be visible")
        focusTimer.tap()

        // Once running, the full-screen focus time readout is exposed to VoiceOver.
        let runningTimer = app.staticTexts["Focus time remaining"]
        XCTAssertTrue(runningTimer.waitForExistence(timeout: 5), "Running focus timer should be visible after starting")
    }
}
