//
//  WelcomeView.swift
//  WarringtonTalkingTrails
//
//  Created by Kevin Grainer on 4/7/20.
//  Copyright © 2020 Chariot Solutions. All rights reserved.
//

import SwiftUI

struct WelcomeView: View {
    @Binding var showWelcome: Bool
    
    var body: some View {
        
            VStack {
                ZStack (alignment: .top){
                    ImageStore.shared.image(name:"field-photo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .accessibilityLabel("A wooded Warrington trail")
                    VStack (alignment: .center) {
                        Text("Welcome to").modifier(HeaderStyle())
                        Text("Warrington Talking Trails")
                        .modifier(HeaderStyle())
                    }
                }
                Rectangle()
                    .fill(Color(YELLOW))
                    .frame(height: 5).padding(.bottom)
                AboutTextView()
                Spacer()
                VStack {
                    Button(action: {
                        UserDefaults.standard.set(true, forKey: "welcome_seen")
                        self.showWelcome = false
                    }) {
                        Text("Continue")
                    }.buttonStyle(BlueButtonStyle(color: .blue))
                }.padding(.bottom)
        }
        
    }
}

struct WelcomeView_Previews: PreviewProvider {
    @State var showWelcome = true
    
    static var previews: some View {
        WelcomeView(showWelcome: .constant(true))
    }
}
