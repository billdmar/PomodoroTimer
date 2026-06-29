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

    /// Opens the Stats screen and confirms the pass-2 additions render
    /// (daily-goal ring + focus-history chart), capturing a screenshot.
    @MainActor
    func testStatsScreenShowsGoalAndHistory() throws {
        let app = launchApp()

        let statsButton = app.buttons["Stats and streak calendar"]
        XCTAssertTrue(statsButton.waitForExistence(timeout: 5), "Stats button should be visible")
        statsButton.tap()

        XCTAssertTrue(app.staticTexts["Daily Goal"].waitForExistence(timeout: 5),
                      "Daily goal section should appear")
        XCTAssertTrue(app.staticTexts["Focus History"].exists,
                      "Focus history section should appear")
        XCTAssertTrue(app.staticTexts["Achievements"].exists,
                      "Achievements section should appear")

        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "stats-screen"
        shot.lifetime = .keepAlways
        add(shot)
    }
}
