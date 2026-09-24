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
