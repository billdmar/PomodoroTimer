//
//  pomadoro2UITestsLaunchTests.swift
//  pomadoro2UITests
//
//  Created by Bill Mar on 7/30/25.
//

import XCTest

final class pomadoro2UITestsLaunchTests: XCTestCase {

    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunch() throws {
        let app = XCUIApplication()
        app.launch()

        // The app should reach a running, interactive state on launch.
        XCTAssertEqual(app.state, .runningForeground)

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
