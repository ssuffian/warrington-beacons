//
//  LandmarkService.swift
//  LionsPride
//
//  Created by Kevin Grainer on 4/27/20.
//  Copyright © 2020 Chariot Solutions. All rights reserved.
//

import Foundation
import CoreLocation
import MapKit

let landmarkService = LandmarkService()

class LandmarkService {
    private var landmarks = [Landmark]()
    private var landmarksById: [Int: Landmark]
    private var landmarksByName: [String: Landmark]
    private var landmarksByCategory: [Landmark.Category: [Landmark]]
    private var trailsById: [Int: Trail]
    private var trails = [Trail]()
    private var spans: [Int: MKCoordinateSpan]

    public func processData(_ lionsPrideData: LionsPrideData) {
        self.landmarks = lionsPrideData.landmarks
        self.trails = lionsPrideData.trails

        Landmark.Category.allCases.forEach{c in
            landmarksByCategory[c] = [Landmark]()
        }

        landmarks.forEach{landmark in
            landmarksById[landmark.id] = landmark
            landmarksByName[landmark.name] = landmark
            landmarksByCategory[landmark.category]?.append(landmark)
        }

        for index in 0..<trails.count {
            self.setUpTrail(trail: &trails[index]) // Must set midpoint before putting trail into hash
            trailsById[trails[index].id] = trails[index]
        }
    }
    
    init() {
        landmarksById = [:]
        landmarksByName = [:]
        landmarksByCategory = [:]
        trailsById = [:]
        spans = [:]
    }
    
    func getTrails() -> [Trail] {
        return trails
    }
    
    func getLandmarks() -> [Landmark] {
        return landmarks
    }

    func getLandmarksByCategory(category: Landmark.Category) -> [Landmark] {
        return landmarksByCategory[category]!
    }

    func getLandmarkByName(name: String) -> Landmark?{
        return landmarksByName[name]
    }
    
    func getLandmarkById(id: NSNumber) -> Landmark? {
        return landmarksById[id as! Int]
    }

    func getLandmarkById(id: Int) -> Landmark? {
        return landmarksById[id]
    }

    func getTrailById(id: Int) -> Trail? {
        return trailsById[id]
    }
    
    func getCenterCoordinates(id: Int) -> CLLocationCoordinate2D? {
        let landmark = getLandmarkById(id: id)
        if landmark != nil {
            if landmark!.category == .Trail {
                return getTrailCenterCoordinates(id: id)
            }
            else {
                return landmark?.locationCoordinate
            }
        }
        return nil
    }
    
    func getTrailCenterCoordinates(id: Int) -> CLLocationCoordinate2D? {

        if let trail = getTrailById(id: id) {
            return CLLocationCoordinate2D(latitude: trail.midCoordinates!.latitude, longitude: trail.midCoordinates!.longitude)
        }
        return nil
    }

    func getTrailsByLandmarkId(id: Int) -> [Trail] {
        let trails = landmarkService.getTrails()

        return trails.filter {
            for coordinate in $0.boundaryCoordinates {
                if coordinate.landmarkId == id {
                    return true
                }
            }
            return false
        }
    }

    func getLandmarksByTrailId(id: Int) -> [Landmark] {
        let trail = self.getTrailById(id: id)
        var landmarks = [Landmark]()
        trail?.boundaryCoordinates.forEach { coordinate in
            if let landmarkId = coordinate.landmarkId {
                if let landmark = getLandmarkById(id: landmarkId) {
                    landmarks.append(landmark)
                }
            }
        }
        return landmarks
    }
    
    func getSpanForTrail(trailId: Int) -> MKCoordinateSpan? {
        return spans[trailId]
    }
        
    // The midCoordinates was removed from the data partway through in favor of being calculated
    func setUpTrail(trail:inout Trail) {
        // TODO: change this to a self.trails = data.trails.map(...) in processData
        //       to set the midCoordinates on any trail missing them
        if(trail.midCoordinates == nil) {
            var minLat:CLLocationDegrees = 90.0;
            var maxLat:CLLocationDegrees = -90.0;
            var minLon:CLLocationDegrees = 180.0;
            var maxLon:CLLocationDegrees = -180.0;
            for loc in trail.boundaryCoordinates {
                if loc.latitude < minLat {minLat = loc.latitude}
                if loc.longitude < minLon {minLon = loc.longitude}
                if loc.latitude > maxLat {maxLat = loc.latitude}
                if loc.longitude > maxLon {maxLon = loc.longitude}
            }
            let span = MKCoordinateSpan(latitudeDelta:maxLat-minLat, longitudeDelta:maxLon-minLon)
            let center = CLLocationCoordinate2DMake((maxLat - span.latitudeDelta / 2), maxLon - span.longitudeDelta / 2)
            trail.midCoordinates = Coordinates(latitude:center.latitude,longitude:center.longitude)
            // Factor > 1 is because active trail tour map zooms to exactly this and needs some "padding" around the edges
            spans[trail.id] = MKCoordinateSpan(latitudeDelta:span.latitudeDelta*2, longitudeDelta:span.longitudeDelta*2)
        }
    }
}
