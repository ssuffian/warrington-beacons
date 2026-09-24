//
//  WarringtonTalkingTrailsUITests.swift
//  WarringtonTalkingTrailsUITests
//
//  Created by Kevin Grainer on 4/1/20.
//  Copyright © 2020 Chariot Solutions. All rights reserved.
//

import XCTest

class WarringtonTalkingTrailsUITests: XCTestCase {

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
        let trailRow = app.buttons.matching(
            NSPredicate(format: "label CONTAINS 'points of interest'")).firstMatch
        XCTAssertTrue(trailRow.waitForExistence(timeout: 20), "Trail list should show at least one decoded trail")
        attach(app, name: "3-trail-list")

        trailRow.tap()
        let startTour = app.buttons["Start Tour"]
        XCTAssertTrue(startTour.waitForExistence(timeout: 10), "Trail details should show Start Tour")
        scrollToHittable(startTour, in: app)
        attach(app, name: "4-trail-detail")

        startTour.tap()
        let reverse = app.buttons["Reverse"]
        XCTAssertTrue(reverse.waitForExistence(timeout: 10), "Trail tour should start and show the Reverse button")
        attach(app, name: "5-trail-tour")
    }

    // Exercises the remaining top-level navigation and the long landmark detail
    // sheet, including scrolling to text below the initially visible area.
    func testAllTabsAndScrollableLandmarkDetails() throws {
        let app = XCUIApplication()
        app.launch()

        addUIInterruptionMonitor(withDescription: "System permission dialogs") { alert in
            for label in ["Allow While Using App", "Allow Once", "Allow", "OK"] {
                if alert.buttons[label].exists { alert.buttons[label].tap(); return true }
            }
            return false
        }

        let continueButton = app.buttons["Continue"]
        if continueButton.waitForExistence(timeout: 5) { continueButton.tap() }

        let search = app.buttons["Search"]
        XCTAssertTrue(search.waitForExistence(timeout: 25))
        search.tap()

        let parkEntrance = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH 'Park Entrance,'")).firstMatch
        XCTAssertTrue(parkEntrance.waitForExistence(timeout: 10))
        parkEntrance.tap()

        let detailsLink = app.buttons.matching(NSPredicate(
            format: "label == 'Park Entrance' AND NOT identifier BEGINSWITH 'landmark-map-pin-'"
        )).firstMatch
        XCTAssertTrue(detailsLink.waitForExistence(timeout: 10))
        detailsLink.tap()

        let closeDetails = app.buttons["Close landmark details"]
        XCTAssertTrue(closeDetails.waitForExistence(timeout: 10))
        app.swipeUp()
        XCTAssertTrue(closeDetails.exists, "Landmark details should remain available after scrolling")
        closeDetails.tap()

        app.tabBars.buttons["About"].tap()
        XCTAssertTrue(app.staticTexts["Warrington Talking Trails"].waitForExistence(timeout: 5))

        app.tabBars.buttons["Settings"].tap()
        let simplifiedText = app.switches["Simplified Text"]
        XCTAssertTrue(simplifiedText.waitForExistence(timeout: 5))
        simplifiedText.tap()

        if app.tabBars.buttons["Beacons"].exists {
            app.tabBars.buttons["Beacons"].tap()
            XCTAssertTrue(app.navigationBars["Beacons"].waitForExistence(timeout: 5))
        }
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

        let trailRow = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH '202 Connector Trail,'")).firstMatch
        XCTAssertTrue(trailRow.waitForExistence(timeout: 10), "Trailhead should be listed in Search (data loaded)")
        trailRow.tap()

        // Back on the map, the summary shows the trailhead name ("202 Connector
        // Trailhead") as a tappable link; tapping it is the cross-tab launch into the
        // Trail Tours tab's detail screen.
        let trailheadLink = app.buttons.matching(NSPredicate(
            format: "label == '202 Connector Trailhead' AND NOT identifier BEGINSWITH 'landmark-map-pin-'"
        )).firstMatch
        XCTAssertTrue(trailheadLink.waitForExistence(timeout: 10), "Trailhead summary link should appear")
        trailheadLink.tap()

        // We should now be on the trail detail screen in the Trail Tours tab
        let startTour = app.buttons["Start Tour"]
        XCTAssertTrue(startTour.waitForExistence(timeout: 10),
                      "Cross-tab launch should push the trail detail (Start Tour) via forceStartTour")
        attach(app, name: "crosstab-detail")
    }

    /// Audits the screens needed to find a trail, choose its direction, and start
    /// navigation. These categories catch missing VoiceOver elements, labels,
    /// traits, and actions without mixing in visual-only contrast checks.
    func testVoiceOverCommonTasks() throws {
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

        let search = app.buttons["Search"]
        XCTAssertTrue(search.waitForExistence(timeout: 25))
        try auditVoiceOver(in: app)

        app.tabBars.buttons["About"].tap()
        XCTAssertTrue(app.staticTexts["Warrington Talking Trails"].waitForExistence(timeout: 5))
        try auditVoiceOver(in: app)

        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(app.switches["Simplified Text"].waitForExistence(timeout: 5))
        try auditVoiceOver(in: app)

        if app.tabBars.buttons["Beacons"].exists {
            app.tabBars.buttons["Beacons"].tap()
            XCTAssertTrue(app.navigationBars["Beacons"].waitForExistence(timeout: 5))
            try auditVoiceOver(in: app)
        }

        app.tabBars.buttons["Trail Tours"].tap()
        let trailRow = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH '202 Connector Trail,'")).firstMatch
        XCTAssertTrue(trailRow.waitForExistence(timeout: 20))
        try auditVoiceOver(in: app)
        trailRow.tap()

        let startTour = app.buttons["Start Tour"]
        XCTAssertTrue(startTour.waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Forward direction"].exists)
        XCTAssertTrue(app.buttons["Reverse direction"].exists)
        try auditVoiceOver(in: app)

        startTour.tap()
        XCTAssertTrue(app.buttons["Reverse"].waitForExistence(timeout: 10))
        try auditVoiceOver(in: app)
    }

    private func auditVoiceOver(in app: XCUIApplication) throws {
        app.activate()
        XCTAssertEqual(app.state, .runningForeground)

        do {
            try app.performAccessibilityAudit(for: [
                .elementDetection,
                .sufficientElementDescription,
                .trait
            ]) { issue in
                // MapKit renders geographic labels into map tiles. The audit's OCR
                // reports those pixels as text with no corresponding UI element;
                // there is no app-owned element to label. Keep every actionable
                // accessibility issue failing the test.
                if issue.auditType == .elementDetection && issue.element == nil {
                    return true
                }
                return false
            }
        } catch {
            let auditError = error as NSError
            guard auditError.domain == "com.apple.accessibilityAudit",
                  auditError.code == -902 else {
                throw error
            }

            // Xcode can intermittently lose the audit service's target process
            // while the app remains foregrounded and its accessibility tree stays
            // available. In that case, directly verify that every interactive
            // VoiceOver element exposed by the current screen has a spoken label.
            assertInteractiveElementsHaveLabels(in: app)
        }
    }

    private func assertInteractiveElementsHaveLabels(in app: XCUIApplication) {
        let interactiveTypes: [XCUIElement.ElementType] = [
            .button, .link, .switch, .textField, .secureTextField, .searchField
        ]

        for type in interactiveTypes {
            for element in app.descendants(matching: type).allElementsBoundByIndex where element.exists {
                XCTAssertFalse(
                    element.label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                    "Every interactive VoiceOver element must have a spoken label (type: \(type.rawValue))"
                )
            }
        }
    }

    private func attach(_ app: XCUIApplication, name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    private func scrollToHittable(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<4 where !element.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(element.isHittable)
    }
}
