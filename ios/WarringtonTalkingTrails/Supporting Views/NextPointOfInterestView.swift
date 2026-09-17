//
//  NextPointOfInterestView.swift
//  WarringtonTalkingTrails
//
//  Created by Kevin Grainer on 5/14/20.
//  Copyright © 2020 Chariot Solutions. All rights reserved.
//

import SwiftUI

struct NextPointOfInterestView: View {
    var selectedLandmark: Landmark
    var nextLandmarkDistanceDescription: String
    @Binding var showLandmarkDetails: Bool
    @Environment(UserData.self) var userData
    
    var body: some View {
        ZStack {
            VStack(alignment: .leading) {
                HStack(alignment: .top) {
                    AsyncImage(url: selectedLandmark.imageUrl) { image in
                        image
                            .resizable()
                    } placeholder: {
                        ProgressView()
                    }
                    .frame(width: 100, height: 75)
                    .accessibilityLabel(selectedLandmark.imageAlt)
                    VStack(alignment: .leading) {
                        Text("Next").modifier(GrayUpperStyle())
                        Button(action: {
                                self.userData.trailTourSelectedLandmark = selectedLandmark
                                self.showLandmarkDetails = true
                        }) {
                            Text(selectedLandmark.trailModifiedName).modifier(LinkStyle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Opens details for the next point of interest")
                    }
                }
                
                HStack(alignment: .center) {
                    Text("Directions:").modifier(LabelStyle()).padding([.top])
                    Text(nextLandmarkDistanceDescription).modifier(ParagraphStyle()).padding([.top])
                }
            
                HStack {
                    Text("From:").modifier(LabelStyle())
                    let widget = Text(self.userData.trailTourEnded ? "Go to the other end of the trail to continue in this direction" : self.userData.trailTourCurrentLandmark!.trailModifiedName)
                    if(!self.userData.trailTourEnded) {
                        Button(action: {
                            self.userData.trailTourSelectedLandmark = self.userData.trailTourCurrentLandmark!
                            self.showLandmarkDetails = true
                        }) {
                            widget.modifier(SmallLinkStyle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Opens details for the current point of interest")
                    } else {
                        widget.modifier(ParagraphStyle())
                    }
                }
            }
        }
        
        
    }
}

struct NextPointOfInterestView_Previews: PreviewProvider {
    static var previews: some View {
        NextPointOfInterestView(selectedLandmark: landmarkService.getLandmarkById(id: 1010)!, nextLandmarkDistanceDescription: "800 feet along path", showLandmarkDetails: Binding.constant(false))
    }
}
