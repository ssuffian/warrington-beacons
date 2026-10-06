//
//  Trail.swift
//  WarringtonTalkingTrails
//
//  Created by Kevin Grainer on 4/10/20.
//  Copyright © 2020 Chariot Solutions. All rights reserved.
//

import UIKit
import MapKit

struct Trail: Hashable, Codable, Identifiable {
    var id = ""
    var location: String?
    var name: String
    var isOpen: Bool
    var trailDistanceDescription: String
    var midCoordinates: Coordinates?
    var overlayTopLeftCoordinates: Coordinates?
    var overlayTopRightCoordinates: Coordinates?
    var overlayBottomLeftCoordinates: Coordinates?
    var overlayBottomRightCoordinates: Coordinates?
    var boundaryCoordinates: [Coordinates]
    // Optional beacon-free trail start and end points (never landmarks).
    var start: TrailEndpoint?
    var end: TrailEndpoint?

}

enum TrailEndpointKind: Hashable {
    case start
    case end

    var title: String {
        switch self {
        case .start: return "Trail start"
        case .end: return "Trail end"
        }
    }
}

/// A beacon-free trail start or end. `distance` and `directions` lead toward the
/// adjacent tour stop: from the start to the first stop (forward), or from the
/// end back to the last stop (reverse).
struct TrailEndpoint: Hashable, Codable {
    var latitude: Double
    var longitude: Double
    var distance: String
    var directions: String

    var locationCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

extension Trail {
    func endpoint(_ kind: TrailEndpointKind) -> TrailEndpoint? {
        kind == .start ? start : end
    }

    /// Ordered tour-stop IDs embedded in the route.
    var stopIds: [String] {
        boundaryCoordinates.compactMap { $0.landmarkId }
    }
}
