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
    /// When set, the next target is the beacon-free trail start or end rather than selectedLandmark.
    var nextEndpoint: TrailEndpointKind? = nil
    /// When set, the visitor is starting from the trail start or end.
    var startingFromEndpoint: TrailEndpointKind? = nil
    @Binding var showLandmarkDetails: Bool
    @Environment(UserData.self) var userData
    
    var body: some View {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    if let nextEndpoint {
                        Image(systemName: trailEndpointSymbol(nextEndpoint))
                            .font(.system(size: 34))
                            .foregroundStyle(.secondary)
                            .frame(width: 96, height: 76)
                            .accessibilityHidden(true)
                    } else {
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
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Next stop")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                        if let nextEndpoint {
                            Text(nextEndpoint.title)
                                .font(.title3.weight(.semibold))
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                        } else {
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
                    if let startingFromEndpoint {
                        Text(startingFromEndpoint.title)
                            .font(.body.weight(.semibold))
                    } else if !self.userData.trailTourEnded, let current = self.userData.trailTourCurrentLandmark {
                        Button(action: {
                            self.userData.trailTourSelectedLandmark = current
                            self.showLandmarkDetails = true
                        }) {
                            Text(current.trailModifiedName)
                                .font(.body.weight(.semibold))
                                .multilineTextAlignment(.leading)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.tint)
                        .accessibilityHint("Opens details for the current point of interest")
                    } else {
                        Text("Go to the other end of the trail to continue in this direction")
                            .font(.body)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
    }
}

func trailEndpointSymbol(_ kind: TrailEndpointKind) -> String {
    kind == .start ? "flag.fill" : "flag.checkered"
}

struct NextPointOfInterestView_Previews: PreviewProvider {
    static var previews: some View {
        if let landmark = landmarkService.getLandmarks().first {
            NextPointOfInterestView(selectedLandmark: landmark, nextLandmarkDistanceDescription: "800 feet along path", showLandmarkDetails: Binding.constant(false))
                .environment(UserData.shared)
        } else {
            Text("No trail data loaded")
        }
    }
}
