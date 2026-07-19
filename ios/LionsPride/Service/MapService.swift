//
//  MapService.swift
//  LionsPride
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
    
    static func getLandmarksOnTrail(trail: Trail) -> [Landmark] {
        var landmarks = [Landmark]()
        
        for coord in trail.boundaryCoordinates {
            if coord.landmarkId != nil {
                let landmark = landmarkService.getLandmarkById(id: coord.landmarkId!)
                if landmark != nil && landmark?.category != .Trail {
                    landmarks.append(landmark!)
                }
            }
        }
        
        return landmarks
    }
    
    static func findNextLandmark(trail: Trail, landmark: Landmark, direction: Direction) -> Landmark? {
        var boundaryCoordinates = direction == .Clockwise ? trail.boundaryCoordinates :
            trail.boundaryCoordinates.reversed()
        if direction == .Clockwise {
            boundaryCoordinates.append(trail.boundaryCoordinates[0])
        } else {
            boundaryCoordinates.insert( boundaryCoordinates[boundaryCoordinates.count - 1], at: 0)
        }
        var i = 0
        while i < boundaryCoordinates.count {
            var b = boundaryCoordinates[i]
            if b.landmarkId != nil && b.landmarkId == landmark.id {
                i+=1
                while i < boundaryCoordinates.count {
                    b = boundaryCoordinates[i]
                    if b.landmarkId != nil {
                        return landmarkService.getLandmarkById(id: b.landmarkId!)
                    }
                    i+=1
                }
                // continue until we find the landmark
                // if we don't find one the return the head of the array
            }
            i+=1
        }
        return landmark
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
                    if boundaryCoordinates[i].landmarkId == nil {
                        coord = boundaryCoordinates[i]
                        coordinates.append(CLLocationCoordinate2D(latitude: coord.latitude, longitude: coord.longitude))
                    }
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
