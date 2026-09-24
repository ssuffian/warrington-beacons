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
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    AsyncImage(url: selectedLandmark.imageUrl) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        ProgressView()
                    }
                    .frame(width: 96, height: 76)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .accessibilityLabel(selectedLandmark.imageAlt)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Next stop")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Button(action: {
                                self.userData.trailTourSelectedLandmark = selectedLandmark
                                self.showLandmarkDetails = true
                        }) {
                            Text(selectedLandmark.trailModifiedName)
                                .font(.title3.weight(.semibold))
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.tint)
                        .accessibilityHint("Opens details for the next point of interest")
                    }
                }
                
                VStack(alignment: .leading, spacing: 3) {
                    Text("Directions")
                        .font(.headline)
                    Text(nextLandmarkDistanceDescription)
                        .font(.body)
                        .fixedSize(horizontal: false, vertical: true)
                }
            
                VStack(alignment: .leading, spacing: 3) {
                    Text("Starting from")
                        .font(.headline)
                    let widget = Text(self.userData.trailTourEnded ? "Go to the other end of the trail to continue in this direction" : self.userData.trailTourCurrentLandmark!.trailModifiedName)
                    if(!self.userData.trailTourEnded) {
                        Button(action: {
                            self.userData.trailTourSelectedLandmark = self.userData.trailTourCurrentLandmark!
                            self.showLandmarkDetails = true
                        }) {
                            widget
                                .font(.body.weight(.semibold))
                                .multilineTextAlignment(.leading)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.tint)
                        .accessibilityHint("Opens details for the current point of interest")
                    } else {
                        widget
                            .font(.body)
                            .fixedSize(horizontal: false, vertical: true)
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
