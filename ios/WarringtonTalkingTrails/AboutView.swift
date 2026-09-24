//
//  AboutView.swift
//  WarringtonTalkingTrails
//
//  Created by Kevin Grainer on 4/3/20.
//  Copyright © 2020 Chariot Solutions. All rights reserved.
//

import SwiftUI

struct AboutView: View {
    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                ImageStore.shared.image(name:"field-photo")
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 190)
                    .clipped()
                    .accessibilityLabel("A wooded Warrington trail")
                LinearGradient(
                    colors: [Color.black.opacity(0.74), Color.black.opacity(0.40), Color.black.opacity(0.16)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                VStack(alignment: .center, spacing: 4) {
                    Text("About")
                        .font(.title2.weight(.semibold))
                    Text("Warrington Talking Trails")
                        .font(.largeTitle.weight(.bold))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.70)
                }
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.85), radius: 2, x: 0, y: 1)
                .padding(.horizontal, 24)
            }
            .frame(height: 190)
            Rectangle()
                .fill(Color(YELLOW))
                .frame(height: 5)
            AboutTextView()
        }
        .background(Color(.systemBackground))
    }
}

struct AboutView_Previews: PreviewProvider {
    static var previews: some View {
        AboutView()
    }
}
