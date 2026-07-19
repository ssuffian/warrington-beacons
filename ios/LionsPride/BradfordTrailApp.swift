//
//  BradfordTrailApp.swift
//  202Connector
//
//  SwiftUI App entry point (replaced the UIKit AppDelegate/SceneDelegate on
//  2026-07-18). The single shared UserData is injected into the environment here;
//  MainView owns the splash/welcome/tab flow.
//

import SwiftUI

@main
struct BradfordTrailApp: App {
    var body: some Scene {
        WindowGroup {
            MainView()
                .environment(UserData.shared)
                #if DEBUG
                // Debug-only: fake beacon detections driven from the command line
                // (see FakeBeacon in BeaconScanner.swift and ./simulate_beacon.sh).
                // onOpenURL also receives the launch URL, so this covers both cases.
                .onOpenURL { url in FakeBeacon.handle(url: url) }
                #endif
        }
    }
}
