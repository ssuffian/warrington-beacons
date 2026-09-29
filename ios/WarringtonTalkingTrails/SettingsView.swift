//
//  SettingsView.swift
//  WarringtonTalkingTrails
//
//  Created by Kevin Grainer on 4/6/20.
//  Copyright © 2020 Chariot Solutions. All rights reserved.
//

import SwiftUI

struct SettingsView: View {
    @Environment(UserData.self) var userData

    private var buildDescription: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "Unknown"
        return "Version \(version) (\(build)) · Data API \(API_MAJOR_VERSION)"
    }
    
    var body: some View {
        @Bindable var userData = userData   // enables $userData bindings from @Environment
        return NavigationStack {
            Form {
                Section {
                    Toggle("Simplified Text", isOn: $userData.showSimplifiedView)
                } footer: {
                    Text("Uses shorter, easier-to-understand landmark descriptions throughout the app.")
                        .fixedSize(horizontal: false, vertical: true)
                }

                Section("About") {
                    Text(buildDescription)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityLabel("App \(buildDescription.replacingOccurrences(of: "·", with: ","))")
                }
            }
            .navigationTitle("Settings")
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        return SettingsView().environment(UserData.shared)
    }
}
