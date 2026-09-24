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
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    private var heroHeight: CGFloat {
        verticalSizeClass == .compact ? 150 : 240
    }
    
    var body: some View {
        
            VStack(spacing: 0) {
                ZStack {
                    ImageStore.shared.image(name:"field-photo")
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: heroHeight)
                        .clipped()
                        .accessibilityLabel("A wooded Warrington trail")
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.black.opacity(0.74),
                            Color.black.opacity(0.42),
                            Color.black.opacity(0.16)
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .allowsHitTesting(false)
                    VStack(alignment: .center, spacing: 6) {
                        Text("Welcome to")
                            .font(.title2.weight(.semibold))
                        Text("Warrington Talking Trails")
                            .font(.largeTitle.weight(.bold))
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.70)
                    }
                    .foregroundColor(.white)
                    .shadow(color: Color.black.opacity(0.85), radius: 2, x: 0, y: 1)
                    .padding(.horizontal, 24)
                }
                .frame(height: heroHeight)
                .clipped()
                Rectangle()
                    .fill(Color(YELLOW))
                    .frame(height: 5)
                AboutTextView()
                Divider()
                VStack(spacing: 0) {
                    Button(action: {
                        UserDefaults.standard.set(true, forKey: "welcome_seen")
                        self.showWelcome = false
                    }) {
                        Text("Continue")
                            .font(.headline)
                            .frame(maxWidth: .infinity, minHeight: 28)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .accessibilityHint("Opens the park map")
                }
                .frame(maxWidth: 520)
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 8)
        }
        .background(Color(.systemBackground))
        
    }
}

struct WelcomeView_Previews: PreviewProvider {
    @State var showWelcome = true
    
    static var previews: some View {
        WelcomeView(showWelcome: .constant(true))
    }
}
