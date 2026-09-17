//
//  WarringtonTalkingTrailsData.swift
//  Lions Pride
//
//  Created by Kevin Grainer on 6/18/20.
//  Copyright © 2020 Chariot Solutions. All rights reserved.
//

import Foundation

struct WarringtonTalkingTrailsData: Codable {
    // Current combined format, shared with Android.
    var locations: [TrailLocation]?
    // Legacy single-park format, retained so an older cached response can still
    // be decoded during the migration to warrington-trails.json.
    var site: Site?
    var landmarks: [Landmark]
    var trails: [Trail]
}

struct TrailLocation: Codable {
    var id: String
    var name: String
    var address: String
    var beaconMajorCode: Int
    var iBeaconUUID: String
    var altBeaconUUID: String
}
