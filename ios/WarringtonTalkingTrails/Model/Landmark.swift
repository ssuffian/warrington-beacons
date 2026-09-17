//
//  PointOfInterest.swift
//  WarringtonTalkingTrails
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
    var imagePath: String?
    var location: String?
    var coordinates: Coordinates
    var category: Category
    var description: String
    var longDescription: String
    var latitudeDelta: CLLocationDegrees?
    var longitudeDelta: CLLocationDegrees?
    var imageAlt: String
    var isOpen: Bool?
    var trailDistanceDescription: String?

    // Not present in the JSON — set by LandmarkService to the URL of the park
    // directory this landmark was loaded from, so photos resolve per park.
    var imageBase: String?

    var imageUrl: URL {
        if let imagePath {
            return getUrl("\(BASE_URL_STRING)/\(imagePath)")
        }
        return getUrl("\(imageBase ?? BASE_URL_STRING)/images/\(imageName).jpg")
    }

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

    enum CodingKeys: String, CodingKey {
        case id, name, imageName, imagePath, location, coordinates, category
        case description, longDescription, latitudeDelta, longitudeDelta
        case imageAlt, isOpen, trailDistanceDescription
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        imagePath = try container.decodeIfPresent(String.self, forKey: .imagePath)
        location = try container.decodeIfPresent(String.self, forKey: .location)
        if let legacyName = try container.decodeIfPresent(String.self, forKey: .imageName) {
            imageName = legacyName
        } else if let imagePath {
            imageName = URL(fileURLWithPath: imagePath).deletingPathExtension().lastPathComponent
        } else {
            throw DecodingError.keyNotFound(
                CodingKeys.imagePath,
                .init(codingPath: decoder.codingPath, debugDescription: "Landmark requires imagePath or imageName")
            )
        }
        coordinates = try container.decode(Coordinates.self, forKey: .coordinates)
        category = try container.decode(Category.self, forKey: .category)
        description = try container.decode(String.self, forKey: .description)
        longDescription = try container.decode(String.self, forKey: .longDescription)
        latitudeDelta = try container.decodeIfPresent(CLLocationDegrees.self, forKey: .latitudeDelta)
        longitudeDelta = try container.decodeIfPresent(CLLocationDegrees.self, forKey: .longitudeDelta)
        imageAlt = try container.decode(String.self, forKey: .imageAlt)
        isOpen = try container.decodeIfPresent(Bool.self, forKey: .isOpen)
        trailDistanceDescription = try container.decodeIfPresent(String.self, forKey: .trailDistanceDescription)
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
