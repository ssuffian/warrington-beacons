//
//  UserData.swift
//  LionsPride
//
//  Created by Kevin Grainer on 4/2/20.
//  Copyright © 2020 Chariot Solutions. All rights reserved.
//

import Foundation
import SwiftUI
import Observation
import CoreLocation

enum Direction {
    case Clockwise
    case CounterClockwise
}

// This data drives the view and also is acting like a state machine
// this is confusing AF and could be improved
@Observable final class UserData {
    var showSimplifiedView = UserDefaults.standard.bool(forKey: "simplified_text") {
        didSet { UserDefaults.standard.set(showSimplifiedView, forKey: "simplified_text") }
    }
    var mainMapSelectedLandmark: Landmark?
    var trailDirection: Direction = .Clockwise
    var nearbyLandmark: Landmark?
    var isTrailTour = false
    var trailTourNextLandmark: Landmark?
    var trailLandmark: Landmark?
    var trailTourCurrentLandmark: Landmark?
    var trailTourSelectedLandmark: Landmark?
    var trailTourTrail: Trail?
    var initialized = false
    var trailTourEnded = false
    var distanceToSelectedLandmark = ""
    var forceStartTour = false
    var screenSize = UIScreen.main.bounds

    var parkMapVisible = false
    @ObservationIgnored private var lastLocation: CLLocation?
    @ObservationIgnored private var lastDistance = 99999999.0
    static var shared = UserData();
    private init () { }

    // This could be BeaconScannerDelegate.updateLocation
    // This class us called UserData but I'm adding functions like a controller, sorry
    func updateLocation(minor: Int) {
        print("\(type(of:self)): \(#function) minor=\(minor)")

        guard let landmark = landmarkService.getLandmarkById(id: minor) else { return }

        // It seems like there should be better way to tell which screens are visible, hacking with env variables
        if isTrailTour {
            updateTourProgress(landmark: landmark)
        } else if parkMapVisible {
            updateMapView(landmark: landmark)
        }
    }
    
    func checkForTrailTourEnd() {
        guard let trailTourTrail = trailTourTrail else { return }
        guard let trailTourCurrentLandmark = trailTourCurrentLandmark else { return }
        if trailTourTrail.isOpen {
            if (trailDirection == .CounterClockwise &&
                    trailTourCurrentLandmark.id == trailTourTrail.boundaryCoordinates.first!.landmarkId) ||
               (trailDirection == .Clockwise &&
                    trailTourCurrentLandmark.id == trailTourTrail.boundaryCoordinates.last!.landmarkId) {
                trailTourEnded = true;
            } else {
                trailTourEnded = false;
            }
        } else {
            trailTourEnded = false;
        }
//        print("Trail tour from \(trailTourCurrentLandmark.name) ended: \(trailTourEnded)")
    }

    private func updateTourProgress(landmark: Landmark) {
        
        // TODO what's the difference between currentLandmark and trailLandmark, can we make this less confusing?
        guard let trailTourTrail = trailTourTrail else { return }
        guard let trailLandmark = trailLandmark else { return }
        guard MapService.isSelectedLandmarkOnTrail(trail: trailTourTrail, landmark: landmark) else { return }

        trailTourCurrentLandmark = landmark
        checkForTrailTourEnd()

        if let nextLandmark = MapService.findNextLandmark(trail: trailTourTrail, landmark: landmark, direction: trailDirection) {
            trailTourNextLandmark = nextLandmark
            let notificationService = NotificationService.shared
            notificationService.sendTrailTourNotification(
                    currentLandmark: landmark,
                    nextLandmark: nextLandmark,
                    trailLandmark: trailLandmark,
                    trailDirection: trailDirection
            )
        }
    }

    // Select the nearby landmark and send a notification. If the details sheet
    // for a landmark is showing, update to show the new landmark
    private func updateMapView(landmark: Landmark) {

        if mainMapSelectedLandmark != landmark {     // landmark changed
            mainMapSelectedLandmark = landmark
            resetLandmarkDistance()
            nearbyLandmark = landmark

            let notificationService = NotificationService.shared
            notificationService.sendNearbyLandmarkNotification(landmark: landmark)

        }
    }

    func resetLandmarkDistance() {
        lastDistance = 99999999.0
        distanceToSelectedLandmark = ""
        if lastLocation != nil {
            updateCurrentLocation(location:lastLocation!)
        }
    }
    
    func updateCurrentLocation(location:CLLocation) {
        lastLocation = location
        if mainMapSelectedLandmark != nil {
            let pos = CLLocation(latitude: mainMapSelectedLandmark!.coordinates.latitude, longitude: mainMapSelectedLandmark!.coordinates.longitude)
            let meters = pos.distance(from: location)
            // Only update the screen if there's a significant difference from the last visible value
            let difference = abs(meters - lastDistance)
            if difference > 10 || (meters < 10 && difference > 2) {
                lastDistance = meters
                distanceToSelectedLandmark = "\(Int(meters*3.28084)) ft"
            }
        }
    }
}

