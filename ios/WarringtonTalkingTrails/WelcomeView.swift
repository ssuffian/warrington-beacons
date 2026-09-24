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
                ZStack(alignment: .top) {
                    ImageStore.shared.image(name:"field-photo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .accessibilityLabel("A wooded Warrington trail")
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.black.opacity(0.72),
                            Color.black.opacity(0.30),
                            Color.clear
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .allowsHitTesting(false)
                    VStack(alignment: .center, spacing: 2) {
                        Text("Welcome to")
                            .modifier(HeaderStyle())
                            .foregroundColor(.white)
                        Text("Warrington Talking Trails")
                            .modifier(HeaderStyle())
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .minimumScaleFactor(0.75)
                    }
                    .shadow(color: Color.black.opacity(0.85), radius: 2, x: 0, y: 1)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
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
