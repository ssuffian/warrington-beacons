//
//  AboutTextView.swift
//  WarringtonTalkingTrails
//
//  Created by Kevin Grainer on 4/7/20.
//  Copyright © 2020 Chariot Solutions. All rights reserved.
//

import SwiftUI

struct AboutTextView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text("Explore Warrington's parks and trails with maps, self-guided tours, and information about nearby landmarks.")
                    .font(.body)
                    .lineSpacing(2)
                    .padding(.bottom, 6)

                Text("Lions Pride Park")
                    .font(.headline)
                Text("3129 Bradley Road\nWarrington, PA 18976")
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 6)

                Text("US-202 to Bradford Dam Trail")
                    .font(.headline)
                Text("Stump Road across from 785\nChalfont, PA 18914")
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 6)

                Text("As you walk, the app can use your on-device location and Bluetooth to identify trail beacons and show information about nearby points of interest. Trail Tours show the distance to the next stop.")
                    .lineSpacing(2)
                    .padding(.bottom, 6)

                Text("Warrington Talking Trails is provided by Warrington Township to help visitors explore local parks and trails.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
    }
}

struct AboutTextView_Previews: PreviewProvider {
    static var previews: some View {
        AboutTextView()
    }
}
