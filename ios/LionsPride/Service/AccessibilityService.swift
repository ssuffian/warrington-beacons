//
//  AccessibilityService.swift
//  LionsPride
//
//  Created by Kevin Grainer on 6/5/20.
//  Copyright © 2020 Chariot Solutions. All rights reserved.
//

import Foundation
import SwiftUI

// NOTE: These functions work but we're using Notifications instead because VoiceOver reads them automatically
class AccessibilityService {
    
    static func nextLandmarkAccessibility(_ landmarkDescription: Landmark, nextLandmarkDescription: String) -> Void {
        
        if UIAccessibility.isVoiceOverRunning {
            let notification = UIAccessibility.Notification.announcement
            UIAccessibility.post(notification: notification, argument: "Next point of interest \(landmarkDescription) \(nextLandmarkDescription)")
        }
    }
    
    static func landmarkAccessibility(_ landmark: Landmark) -> Void {
        if UIAccessibility.isVoiceOverRunning {
            let notification = UIAccessibility.Notification.announcement
            UIAccessibility.post(notification: notification, argument: "Nearby point of interest: \(landmark.name)")
        }
    }
}
