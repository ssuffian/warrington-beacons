//
//  LionsPrideData.swift
//  Lions Pride
//
//  Created by Kevin Grainer on 6/18/20.
//  Copyright © 2020 Chariot Solutions. All rights reserved.
//

import Foundation

struct LionsPrideData: Codable {
    var site: Site
    var landmarks: [Landmark]
    var trails: [Trail]
}
