//
//  AccessibilityService.swift
//  WarringtonTalkingTrails
//
//  Created by Kevin Grainer on 6/5/20.
//  Copyright © 2020 Chariot Solutions. All rights reserved.
//

import Foundation
import SwiftUI

class AccessibilityService {

    /// Speak immediately while the app is open. This does not depend on the user
    /// granting notification permission, which is important for the core tour flow.
    static func announce(_ message: String) {
        DispatchQueue.main.async {
            guard UIAccessibility.isVoiceOverRunning,
                  UIApplication.shared.applicationState == .active else { return }
            UIAccessibility.post(notification: .announcement, argument: message)
        }
    }

    static func nextLandmarkAccessibility(_ landmarkDescription: String, nextLandmarkDescription: String) {
        announce("Next point of interest. \(landmarkDescription). \(nextLandmarkDescription)")
    }

    static func landmarkAccessibility(_ landmark: Landmark) -> Void {
        announce("Nearby point of interest: \(landmark.name)")
    }
}
