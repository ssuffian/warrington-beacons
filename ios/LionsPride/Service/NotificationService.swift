//
//  NotificationService.swift
//  LionsPride
//
//  Created by Kevin Grainer on 6/10/20.
//  Copyright © 2020 Chariot Solutions. All rights reserved.
//

import Foundation
import SwiftUI

let TRAIL_TOUR_POINT_OF_INTEREST_IDENTIFIER = "TRAIL_TOUR_POINT_OF_INTEREST"
let NEARBY_POINT_OF_INTEREST_IDENTIFIER = "NEARBY_POINT_OF_INTEREST"

class NotificationService : NSObject, UNUserNotificationCenterDelegate{
    private static var instance: NotificationService?

    static let shared = NotificationService()
    
    private override init() {
        super.init()
        
        UNUserNotificationCenter.current().delegate = self

        let center =  UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { (result, error) in
           //handle result of request failure
        }
        
        // Define the notification type
        let trailTourPointOfInterestCategory =
              UNNotificationCategory(identifier: TRAIL_TOUR_POINT_OF_INTEREST_IDENTIFIER,
              actions: [],
              intentIdentifiers: [],
              hiddenPreviewsBodyPlaceholder: "")
        
        let nearbyPointOfInterestCategory =
            UNNotificationCategory(identifier: NEARBY_POINT_OF_INTEREST_IDENTIFIER,
            actions: [],
            intentIdentifiers: [],
            hiddenPreviewsBodyPlaceholder: "")
        // Register the notification type.
        let notificationCenter = UNUserNotificationCenter.current()
        notificationCenter.setNotificationCategories([trailTourPointOfInterestCategory, nearbyPointOfInterestCategory])
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {

         if UIAccessibility.isVoiceOverRunning {
            // show alerts because VoiceOver will read the text for the user
            completionHandler([.alert, .sound])
        } else {
            // just play the sound
            completionHandler([.sound])
        }
        
//        if notification.request.content.categoryIdentifier == TRAIL_TOUR_POINT_OF_INTEREST_IDENTIFIER {
//            completionHandler([.alert, .sound])
//        }
//        if notification.request.content.categoryIdentifier == NEARBY_POINT_OF_INTEREST_IDENTIFIER {
//                completionHandler([.sound])
//        }
            
    }
    
    //
    func sendNearbyLandmarkNotification(landmark: Landmark) {
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        let uuidString = UUID().uuidString
        let content = UNMutableNotificationContent()
        content.title = "Nearby point of interest"
        content.sound = UNNotificationSound.default
        content.categoryIdentifier = NEARBY_POINT_OF_INTEREST_IDENTIFIER
        content.body = landmark.name

        let request = UNNotificationRequest(identifier: uuidString, content: content, trigger: trigger)
        let notificationCenter = UNUserNotificationCenter.current()
        notificationCenter.add(request) { (error) in
           if error != nil {
              // ignore
           }
        }
    }
    
    func sendTrailTourNotification(currentLandmark: Landmark, nextLandmark: Landmark, trailLandmark: Landmark, trailDirection: Direction) {
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        let uuidString = UUID().uuidString
        let content = UNMutableNotificationContent()
        content.title = "Trail tour"
        content.sound = UNNotificationSound.default
        content.categoryIdentifier = TRAIL_TOUR_POINT_OF_INTEREST_IDENTIFIER
        
        let trail = landmarkService.getTrailById(id: trailLandmark.id)
        if MapService.isSelectedLandmarkOnTrail(trail: trail!, landmark: currentLandmark) {
            let distanceTuple = MapService.distanceToNextLandmark(
                trail: trail!,
                currentLandmark: currentLandmark,
                direction: trailDirection)
            content.body = "\(currentLandmark.name) has been reached. \(distanceTuple!.distanceToNextDescription!) to \(nextLandmark.trailModifiedName)"
            let request = UNNotificationRequest(identifier: uuidString, content: content, trigger: trigger)
            let notificationCenter = UNUserNotificationCenter.current()
            notificationCenter.add(request) { (error) in
               if error != nil {
                  // ignore
               }
            }
        }
    }
}
