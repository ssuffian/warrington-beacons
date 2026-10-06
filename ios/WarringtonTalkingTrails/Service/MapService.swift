//
//  MapService.swift
//  WarringtonTalkingTrails
//
//  Created by Kevin Grainer on 5/8/20.
//  Copyright © 2020 Chariot Solutions. All rights reserved.
//

import Foundation
import CoreLocation

class MapService {
    
    static func distanceToNextLandmark(trail: Trail, currentLandmark: Landmark, direction: Direction) -> (distanceToNext: String?, distanceToNextDescription: String?)? {
        
        // iterate over the trail coordinates until the landmark is found by id
        // return the description for the selected direction
        
        guard let coord = findTrailCoordinates(trail: trail, landmark: currentLandmark) else {
            return nil
        }
        if direction == .Clockwise {
            return (distanceToNext: coord.distanceToNextClockwise, distanceToNextDescription: coord.distanceToNextClockwiseDescription)
                
        } else {
            return (distanceToNext: coord.distanceToNextCounterClockwise, distanceToNextDescription: coord.distanceToNextCounterClockwiseDescription)
        }
    }
    
    static func getLandmarksOnTrail(trail: Trail, service: LandmarkService = landmarkService) -> [Landmark] {
        return trail.stopIds.compactMap { service.getLandmarkById(id: $0) }
            .filter { $0.category != .Trail }
    }

    /// The next tour stop in the given direction, wrapping around the ends.
    /// Returns the landmark itself when it is not a stop on the trail.
    static func findNextLandmark(trail: Trail, landmark: Landmark, direction: Direction, service: LandmarkService = landmarkService) -> Landmark? {
        let stops = trail.stopIds
        guard !stops.isEmpty else { return nil }
        guard let index = stops.firstIndex(of: landmark.id) else { return landmark }
        let step = direction == .Clockwise ? 1 : -1
        let nextIndex = (index + step + stops.count) % stops.count
        return service.getLandmarkById(id: stops[nextIndex]) ?? landmark
    }

    /// What the tour card shows next. Beacon-free trail start/end points are
    /// never landmarks, so they are described separately from the next stop.
    struct TourStep: Equatable {
        /// The next tour stop, when the next target is a landmark.
        var nextLandmark: Landmark?
        /// Set when the next target is the trail start or end instead of a stop.
        var nextEndpoint: TrailEndpointKind?
        /// Set when the visitor is standing at the trail start or end.
        var startingFromEndpoint: TrailEndpointKind?
        var directions: String

        var nextName: String {
            nextEndpoint?.title ?? nextLandmark?.trailModifiedName ?? ""
        }
    }

    static func tourStep(trail: Trail, currentLandmark: Landmark, direction: Direction, atEndpoint: TrailEndpointKind? = nil, service: LandmarkService = landmarkService) -> TourStep {
        let stops = trail.stopIds
        let isFirstStop = stops.first == currentLandmark.id
        let isLastStop = stops.last == currentLandmark.id

        // Standing at the start heading forward, or at the end heading back:
        // the endpoint's own directions lead to the adjacent stop.
        if atEndpoint == .start, direction == .Clockwise, let start = trail.start,
           let first = stops.first.flatMap({ service.getLandmarkById(id: $0) }) {
            return TourStep(nextLandmark: first, startingFromEndpoint: .start,
                            directions: "From the trail start: \(start.directions)")
        }
        if atEndpoint == .end, direction == .CounterClockwise, let end = trail.end,
           let last = stops.last.flatMap({ service.getLandmarkById(id: $0) }) {
            return TourStep(nextLandmark: last, startingFromEndpoint: .end,
                            directions: "From the trail end: \(end.directions)")
        }

        let distance = distanceToNextLandmark(trail: trail, currentLandmark: currentLandmark, direction: direction)
        let directions = distance?.distanceToNextDescription ?? ""

        // At the last stop going forward (or the first going back) the stop's
        // own distance fields point toward the trail end (or start).
        if direction == .Clockwise, isLastStop, trail.end != nil {
            return TourStep(nextEndpoint: .end, directions: directions)
        }
        if direction == .CounterClockwise, isFirstStop, trail.start != nil {
            return TourStep(nextEndpoint: .start, directions: directions)
        }
        return TourStep(
            nextLandmark: findNextLandmark(trail: trail, landmark: currentLandmark, direction: direction, service: service),
            directions: directions
        )
    }

    static func isSelectedLandmarkOnTrail(trail: Trail, landmark: Landmark) -> Bool {
        for c in trail.boundaryCoordinates {
            if c.landmarkId == landmark.id {
                return true
            }
        }
        return false
    }
    
    static func findTrailCoordinates(trail: Trail, landmark: Landmark) -> Coordinates? {
        for b in trail.boundaryCoordinates {
            if b.landmarkId == landmark.id {
                // keep going until the next landmark is found
                // if no landmark is found use the head or tail of the list
                return b
            }
        }
        return nil
    }
    
    static func pointsToNextLandmark(trail: Trail, currentLandmark: Landmark, direction: Direction) -> [CLLocationCoordinate2D]{
        
        var coordinates = [CLLocationCoordinate2D]()
        guard !trail.boundaryCoordinates.isEmpty else {
            return coordinates
        }
        
        var i = 0
        var boundaryCoordinates = direction == .Clockwise ? trail.boundaryCoordinates :
            trail.boundaryCoordinates.reversed()
        
        if direction == .Clockwise {
            boundaryCoordinates.append(trail.boundaryCoordinates[0])
        } else {
            boundaryCoordinates.insert( boundaryCoordinates[boundaryCoordinates.count - 1], at: 0)
        }
        
        while i < boundaryCoordinates.count {
            var coord = boundaryCoordinates[i]
            if coord.latitude == currentLandmark.coordinates.latitude &&
                coord.longitude == currentLandmark.coordinates.longitude {
                // add the current landmark
                coordinates.append(CLLocationCoordinate2D(latitude: coord.latitude, longitude: coord.longitude))
                i+=1
                // track points until the next landmark
                while i < boundaryCoordinates.count && boundaryCoordinates[i].landmarkId == nil {
                    coord = boundaryCoordinates[i]
                    coordinates.append(CLLocationCoordinate2D(latitude: coord.latitude, longitude: coord.longitude))
                    i+=1
                }
                if i < boundaryCoordinates.count {
                    coord = boundaryCoordinates[i]
                    coordinates.append(CLLocationCoordinate2D(latitude: coord.latitude, longitude: coord.longitude))
                }
                return coordinates
            }
            i+=1
        }
        
        return coordinates
        
    }
}
