//
//  Utils.swift
//  Lions Pride
//
//  Created by Kevin Grainer on 6/19/20.
//  Copyright © 2020 Chariot Solutions. All rights reserved.
//

import Foundation
import SwiftUI

let BASE_URL_STRING = getBaseUrlString()

// The configured base URL points at the US-202 directory
// (e.g. https://trails.warringtoneac.org/us-202); Lions Pride lives alongside
// it. Both parks' data files are fetched so either park's beacons resolve to
// landmarks.
let LIONS_PRIDE_BASE_URL_STRING =
    URL(string: BASE_URL_STRING)!
        .deletingLastPathComponent()
        .appendingPathComponent("lions-pride-park")
        .absoluteString

func getBaseUrlString() -> String {
    guard let configurationUrlString = Bundle.main.object(forInfoDictionaryKey: "base_url_string") as? String else {
        fatalError("base_url_string configuration value missing")
    }
    
    return configurationUrlString
}

func getUrl(_ urlString: String) -> URL {
    guard let url = URL(string: urlString) else {
        fatalError("cannot parse url")
    }
    return url
}
