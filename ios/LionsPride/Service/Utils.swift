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
