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
            VStack(alignment: .leading, spacing: 8) {
                Text("Explore Warrington's parks and trails with maps, self-guided tours, and information about nearby landmarks.")
                    .padding(.bottom, 4)

                Text("Lions Pride Park").fontWeight(.semibold)
                Text("3129 Bradley Road\nWarrington, PA 18976")
                    .padding(.bottom, 4)

                Text("US-202 to Bradford Dam Trail").fontWeight(.semibold)
                Text("Stump Road across from 785\nChalfont, PA 18914")
                    .padding(.bottom, 4)

                Text("As you walk, the app can use your on-device location and Bluetooth to identify trail beacons and show information about nearby points of interest. Trail Tours show the distance to the next stop.")
                    .padding(.bottom, 4)

                Text("This is an independent application for park visitors. It is not an official Warrington Township application.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
    }
}

struct AboutTextView_Previews: PreviewProvider {
    static var previews: some View {
        AboutTextView()
    }
}
