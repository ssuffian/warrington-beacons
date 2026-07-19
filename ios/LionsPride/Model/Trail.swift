//
//  Trail.swift
//  LionsPride
//
//  Created by Kevin Grainer on 4/10/20.
//  Copyright © 2020 Chariot Solutions. All rights reserved.
//

import UIKit
import MapKit

struct Trail: Hashable, Codable, Identifiable {
    var id = 0
    var name: String
    var isOpen: Bool
    var trailDistanceDescription: String
    var midCoordinates: Coordinates?
    var overlayTopLeftCoordinates: Coordinates?
    var overlayTopRightCoordinates: Coordinates?
    var overlayBottomLeftCoordinates: Coordinates?
    var overlayBottomRightCoordinates: Coordinates?
    var boundaryCoordinates: [Coordinates]

}
