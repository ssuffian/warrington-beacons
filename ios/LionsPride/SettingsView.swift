//
//  SettingsView.swift
//  LionsPride
//
//  Created by Kevin Grainer on 4/6/20.
//  Copyright © 2020 Chariot Solutions. All rights reserved.
//

import SwiftUI

struct SettingsView: View {
    @Environment(UserData.self) var userData
    
    var body: some View {
        @Bindable var userData = userData   // enables $userData bindings from @Environment
        return VStack(alignment: .leading) {
            Text("Settings").modifier(HeaderStyle()).padding()
            Rectangle()
                .fill(Color(YELLOW))
                .frame(height: 5)
            Divider()
            VStack {
                HStack{
                    Toggle(isOn: $userData.showSimplifiedView) {
                        Text("Simplified Text").modifier(ValueStyle()).padding()
                    }.padding()
                }
                Text("Simplified text enables easier to understand landmark descriptions.")
                    .lineLimit(nil).padding()
                Divider()
            }
            Spacer()
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        return SettingsView().environment(UserData.shared)
    }
}
