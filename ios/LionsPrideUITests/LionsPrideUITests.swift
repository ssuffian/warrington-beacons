//
//  LionsPrideUITests.swift
//  LionsPrideUITests
//
//  Created by Kevin Grainer on 4/1/20.
//  Copyright © 2020 Chariot Solutions. All rights reserved.
//

import XCTest

class LionsPrideUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // Walks the main flows: welcome -> park map -> trail tours -> trail detail
    // -> start tour. Also proves the remote JSON downloaded and decoded, since
    // the trail list is only populated after a successful load.
    func testWalkthrough() throws {
        let app = XCUIApplication()
        app.launch()

        // Auto-dismiss permission alerts (location, notifications, bluetooth)
        addUIInterruptionMonitor(withDescription: "System permission dialogs") { alert in
            for label in ["Allow While Using App", "Allow Once", "Allow", "OK"] {
                if alert.buttons[label].exists {
                    alert.buttons[label].tap()
                    return true
                }
            }
            return false
        }

        // Splash (2s) then welcome screen (first launch only — welcome_seen persists)
        let continueButton = app.buttons["Continue"]
        if continueButton.waitForExistence(timeout: 15) {
            attach(app, name: "1-welcome")
            continueButton.tap()
        }

        // Park map tab appears; nudge to flush any permission alerts
        app.swipeUp(velocity: .slow)
        // Map pins are accessibility elements titled by landmark; waiting for one
        // proves the JSON loaded AND the park map rendered its annotations
        let pin = app.otherElements.matching(
            NSPredicate(format: "label CONTAINS 'Trailhead'")).firstMatch
        XCTAssertTrue(pin.waitForExistence(timeout: 25), "Park map should show landmark pins once data loads")
        attach(app, name: "2-park-map")

        // Trail Tours tab: the row only exists if the JSON loaded + decoded
        app.tabBars.buttons["Trail Tours"].tap()
        let trailRow = app.staticTexts["202 Connector Trail"]
        XCTAssertTrue(trailRow.waitForExistence(timeout: 20), "Trail list should show the 202 Connector Trail (JSON loaded and decoded)")
        attach(app, name: "3-trail-list")

        trailRow.tap()
        let startTour = app.staticTexts["Start Tour"]
        XCTAssertTrue(startTour.waitForExistence(timeout: 10), "Trail details should show Start Tour")
        attach(app, name: "4-trail-detail")

        startTour.tap()
        let reverse = app.buttons["Reverse"]
        XCTAssertTrue(reverse.waitForExistence(timeout: 10), "Trail tour should start and show the Reverse button")
        attach(app, name: "5-trail-tour")
    }

    // The cross-tab launch is the fragile flow: selecting a trailhead on the park
    // map shows a summary link that must jump to the Trail Tours tab and push the
    // trail detail (driven by forceStartTour → navigationDestination after the
    // NavigationStack migration). We reach the trailhead via Search rather than a
    // corner map pin (which XCUITest can't reliably tap), exercising the identical
    // selection → summary → forceStartTour code path.
    func testTrailheadCrossTabLaunch() throws {
        let app = XCUIApplication()
        app.launch()

        addUIInterruptionMonitor(withDescription: "System permission dialogs") { alert in
            for label in ["Allow While Using App", "Allow Once", "Allow", "OK"] {
                if alert.buttons[label].exists { alert.buttons[label].tap(); return true }
            }
            return false
        }

        let continueButton = app.buttons["Continue"]
        if continueButton.waitForExistence(timeout: 15) { continueButton.tap() }

        // Open Search from the park map and select the trailhead (a Trail landmark),
        // which sets it as the map's selected landmark just like tapping its pin.
        let search = app.buttons["Search"]
        XCTAssertTrue(search.waitForExistence(timeout: 25), "Search button should appear on the park map")
        search.tap()

        let trailRow = app.staticTexts["202 Connector Trail"]
        XCTAssertTrue(trailRow.waitForExistence(timeout: 10), "Trailhead should be listed in Search (data loaded)")
        trailRow.tap()

        // Back on the map, the summary shows the trailhead name ("202 Connector
        // Trailhead") as a tappable link; tapping it is the cross-tab launch into the
        // Trail Tours tab's detail screen.
        let trailheadLink = app.staticTexts["202 Connector Trailhead"]
        XCTAssertTrue(trailheadLink.waitForExistence(timeout: 10), "Trailhead summary link should appear")
        trailheadLink.tap()

        // We should now be on the trail detail screen in the Trail Tours tab
        let startTour = app.staticTexts["Start Tour"]
        XCTAssertTrue(startTour.waitForExistence(timeout: 10),
                      "Cross-tab launch should push the trail detail (Start Tour) via forceStartTour")
        attach(app, name: "crosstab-detail")
    }

    private func attach(_ app: XCUIApplication, name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }
}
