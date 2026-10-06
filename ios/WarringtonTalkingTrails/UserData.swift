//
//  UserData.swift
//  WarringtonTalkingTrails
//
//  Created by Kevin Grainer on 4/2/20.
//  Copyright © 2020 Chariot Solutions. All rights reserved.
//

import Foundation
import SwiftUI
import Observation
import CoreLocation

enum Direction: Hashable {
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
    var trailDirection: Direction = .Clockwise {
        didSet {
            // Turning around at the trail start/end leaves the endpoint behind.
            if (trailTourEndpoint == .start && trailDirection == .CounterClockwise) ||
                (trailTourEndpoint == .end && trailDirection == .Clockwise) {
                trailTourEndpoint = nil
            }
        }
    }
    var nearbyLandmark: Landmark?
    var isTrailTour = false
    var trailTourNextLandmark: Landmark?
    var trailLandmark: Landmark?
    var trailTourCurrentLandmark: Landmark?
    var trailTourSelectedLandmark: Landmark?
    var trailTourTrail: Trail?
    // Set while the visitor stands at the trail's beacon-free start or end
    // (trailTourCurrentLandmark is then the adjacent first/last stop).
    var trailTourEndpoint: TrailEndpointKind?
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

        // Beacons identify places by beaconMinor; places without one never match.
        guard let landmark = landmarkService.getLandmarkByBeaconMinor(minor) else { return }

        // It seems like there should be better way to tell which screens are visible, hacking with env variables
        if isTrailTour {
            updateTourProgress(landmark: landmark)
        } else if parkMapVisible {
            updateMapView(landmark: landmark)
        }
    }
    
    /// Prepares the trail details/tour state for a trail. When the trail has a
    /// beacon-free start, the tour begins there (heading forward to the first
    /// stop) unless the visitor is already at a stop on this trail.
    func prepareTrailTour(trail: Trail, preferredLandmark: Landmark? = nil) {
        let stops = landmarkService.getLandmarksByTrailId(id: trail.id)
        let preferred = preferredLandmark.flatMap { landmark in
            MapService.isSelectedLandmarkOnTrail(trail: trail, landmark: landmark) ? landmark : nil
        }
        trailTourTrail = trail
        if trail.start != nil {
            trailLandmark = stops.first
            trailTourCurrentLandmark = preferred ?? stops.first
            trailTourEndpoint = (preferred == nil && !stops.isEmpty) ? .start : nil
            if trailTourEndpoint == .start {
                trailDirection = .Clockwise
            }
        } else {
            let trailhead = stops.first { $0.category == .Trail } ?? stops.first
            trailLandmark = trailhead
            trailTourCurrentLandmark = preferred ?? trailhead
            trailTourEndpoint = nil
        }
        trailTourNextLandmark = trailTourCurrentLandmark.flatMap {
            MapService.findNextLandmark(trail: trail, landmark: $0, direction: trailDirection)
        }
        checkForTrailTourEnd()
    }

    /// Selects the trail start or end as the tour starting point.
    func selectTrailEndpoint(_ kind: TrailEndpointKind) {
        guard let trail = trailTourTrail, trail.endpoint(kind) != nil else { return }
        let stopIds = trail.stopIds
        guard let adjacentId = kind == .start ? stopIds.first : stopIds.last,
              let adjacent = landmarkService.getLandmarkById(id: adjacentId) else { return }
        trailTourEndpoint = kind
        trailDirection = kind == .start ? .Clockwise : .CounterClockwise
        trailTourCurrentLandmark = adjacent
        trailTourNextLandmark = MapService.findNextLandmark(trail: trail, landmark: adjacent, direction: trailDirection)
        checkForTrailTourEnd()
    }

    /// The current tour card content, or nil when no tour position is set.
    var trailTourStep: MapService.TourStep? {
        guard let trail = trailTourTrail, let current = trailTourCurrentLandmark else { return nil }
        return MapService.tourStep(trail: trail, currentLandmark: current, direction: trailDirection, atEndpoint: trailTourEndpoint)
    }

    func checkForTrailTourEnd() {
        guard let trailTourTrail = trailTourTrail else { return }
        guard let trailTourCurrentLandmark = trailTourCurrentLandmark else { return }
        let step = MapService.tourStep(trail: trailTourTrail, currentLandmark: trailTourCurrentLandmark,
                                       direction: trailDirection, atEndpoint: trailTourEndpoint)
        let stopIds = trailTourTrail.stopIds
        if step.startingFromEndpoint != nil || step.nextEndpoint != nil {
            // Heading from or toward a trail start/end: the tour continues.
            trailTourEnded = false
        } else if trailTourTrail.isOpen, let first = stopIds.first, let last = stopIds.last {
            trailTourEnded = (trailDirection == .CounterClockwise && trailTourCurrentLandmark.id == first) ||
                (trailDirection == .Clockwise && trailTourCurrentLandmark.id == last)
        } else {
            trailTourEnded = false
        }
    }

    private func updateTourProgress(landmark: Landmark) {
        guard let trailTourTrail = trailTourTrail else { return }
        guard MapService.isSelectedLandmarkOnTrail(trail: trailTourTrail, landmark: landmark) else { return }

        // Arriving at a stop means the visitor has left the trail start/end.
        trailTourEndpoint = nil
        trailTourCurrentLandmark = landmark
        checkForTrailTourEnd()

        if let nextLandmark = MapService.findNextLandmark(trail: trailTourTrail, landmark: landmark, direction: trailDirection) {
            trailTourNextLandmark = nextLandmark
            NotificationService.shared.sendTrailTourNotification(
                currentLandmark: landmark,
                trail: trailTourTrail,
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
        if let lastLocation {
            updateCurrentLocation(location: lastLocation)
        }
    }
    
    func updateCurrentLocation(location:CLLocation) {
        lastLocation = location
        if let selectedLandmark = mainMapSelectedLandmark {
            let pos = CLLocation(latitude: selectedLandmark.coordinates.latitude, longitude: selectedLandmark.coordinates.longitude)
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
