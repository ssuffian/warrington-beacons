//
//  PointOfInterest.swift
//  LionsPride
//
//  Created by Kevin Grainer on 4/2/20.
//  Copyright © 2020 Chariot Solutions. All rights reserved.
//

import SwiftUI
import CoreLocation



struct Landmark: Hashable, Codable, Identifiable {
    var id: Int
    var name: String
    var imageName: String
    var coordinates: Coordinates
    var category: Category
    var description: String
    var longDescription: String
    var latitudeDelta: CLLocationDegrees?
    var longitudeDelta: CLLocationDegrees?
    var imageAlt: String
    var isOpen: Bool?
    var trailDistanceDescription: String?

    var locationCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(
            latitude: coordinates.latitude,
            longitude: coordinates.longitude)
    }
    
    var trailModifiedName: String {
        return category == .Trail ? name + "head" : name
    }

    enum Category: String, CaseIterable, Codable, Hashable {
        case Trail = "Trail"
        case PointOfInterest = "PointOfInterest"
        case Building = "Building"
        
        func friendlyValue() -> String {
            switch(self) {
                case .Trail: return "Trailhead"
                case .Building: return "Building"
                default: return "Landmark"
            }
        }
    }
}

extension Landmark {
    var image: Image {
        ImageStore.shared.image(name: imageName)
    }
}

struct Coordinates: Hashable, Codable {
    var latitude: Double
    var longitude: Double
    var landmarkId: Int?
    var distanceToNextClockwise: String?
    var distanceToNextCounterClockwise: String?
    var distanceToNextClockwiseDescription: String?
    var distanceToNextCounterClockwiseDescription: String?
}
