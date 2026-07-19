//
//  AboutTextView.swift
//  LionsPride
//
//  Created by Kevin Grainer on 4/7/20.
//  Copyright © 2020 Chariot Solutions. All rights reserved.
//

import SwiftUI

struct AboutTextView: View {
    var body: some View {
        VStack(alignment: .leading) {
            Text("Trailhead")
            Text("Stump Road across from 785")
            Text("Chalfont, PA 18914").padding(.bottom)
            Text("This app is designed to enrich your trail experience by providing information about the trail.  As you move along the trail you will be alerted when there is a new point of interest nearby.").padding(.bottom)
            Text("Trail Tours indicate the distances to the next point of interest on the trail.")
        }.padding()
    }
}

struct AboutTextView_Previews: PreviewProvider {
    static var previews: some View {
        AboutTextView()
    }
}
