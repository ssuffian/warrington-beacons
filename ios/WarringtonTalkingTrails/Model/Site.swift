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
    // The beacons dual-advertise iBeacon and AltBeacon frames, and the frames can
    // carry different UUIDs (Lions Pride AltBeacon frames use 00112233-…).
    // CoreLocation only ever sees the iBeacon frame, so iBeaconUUID is the one
    // BeaconScanner cares about; altBeaconUUID is documented for Android.
    var iBeaconUUID: String
    var altBeaconUUID: String
    var beaconMajorCode: Int
}
