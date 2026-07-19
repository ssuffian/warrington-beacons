//
//  Site.swift
//  Lions Pride
//
//  Created by Aaron Mulder on 9/16/20.
//  Copyright © 2020 Kevin Grainer. All rights reserved.
//

import Foundation

struct Site: Codable {
    var boundaryCoordinates: [Coordinates]
    var beaconUUID: String
    var beaconMajorCode: Int
}
