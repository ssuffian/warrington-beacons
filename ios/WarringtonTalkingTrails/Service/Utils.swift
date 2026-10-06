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
let API_MAJOR_VERSION = "v3"
let TRAILS_DATA_URL_STRING = getApiUrlString(resource: "trails.json")
let TRAILS_KML_URL_STRING = getApiUrlString(resource: "talking-trails.kml")

func getBaseUrlString() -> String {
    guard let configurationUrlString = Bundle.main.object(forInfoDictionaryKey: "base_url_string") as? String else {
        fatalError("base_url_string configuration value missing")
    }
    
    return configurationUrlString
}

func getApiUrlString(
    baseUrlString: String = BASE_URL_STRING,
    version: String = API_MAJOR_VERSION,
    resource: String
) -> String {
    let base = baseUrlString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    return "\(base)/api/\(version)/\(resource)"
}

func getUrl(_ urlString: String) -> URL {
    guard let url = URL(string: urlString) else {
        fatalError("cannot parse url")
    }
    return url
}
