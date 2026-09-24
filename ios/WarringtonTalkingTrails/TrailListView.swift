//
//  LandmarkListView.swift
//  WarringtonTalkingTrails
//
//  Created by Kevin Grainer on 4/6/20.
//  Copyright © 2020 Chariot Solutions. All rights reserved.
//

import SwiftUI

struct TrailListView: View {
    
    @Environment(UserData.self) var userData
    @State var trailDetailsView = false
    
    var body: some View {
        @Bindable var userData = userData   // enables $userData bindings from @Environment
        _ = userData.initialized            // re-render when trail data finishes loading (@Observable)
        return NavigationStack {
                VStack(spacing: 0) {
                    Text("Choose a trail for step-by-step directions and information about points of interest along the way.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                    Rectangle()
                        .fill(Color(YELLOW))
                        .frame(height: 4)
                        .padding(.horizontal, 20)
                    List {
                        ForEach(landmarkService.getLandmarks().filter{$0.category.rawValue == "Trail"}) { landmark in

                            Button(action: {
                                guard let trail = landmarkService.getTrailById(id: landmark.id) else {
                                    return
                                }
                                self.userData.trailLandmark = landmark
                                if let nearbyLandmark = self.userData.nearbyLandmark {
                                    let trails = landmarkService.getTrailsByLandmarkId(id: nearbyLandmark.id)
                                    if trails.first?.id == trail.id {
                                        self.userData.trailTourCurrentLandmark = nearbyLandmark
                                    } else {
                                        self.userData.trailTourCurrentLandmark = landmark
                                    }
                                    self.userData.checkForTrailTourEnd()
                                } else {
                                    self.userData.trailTourCurrentLandmark = landmark
                                }
                                self.userData.trailTourTrail = trail
                                self.trailDetailsView = true
                            }) {
                                TrailRowView(landmark: landmark)
                            }
                            .buttonStyle(.plain)
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel(trailAccessibilityLabel(for: landmark))
                            .accessibilityHint("Opens trail details")
                        }
                    }.navigationBarTitle(Text("Trail Tours"), displayMode: .inline)
                }
                // Programmatic push of the trail detail screen. Two triggers, same
                // destination: a row tap (trailDetailsView), and the cross-tab launch
                // from tapping a trailhead on the park map (forceStartTour).
                .navigationDestination(isPresented: self.$trailDetailsView) {
                    TrailDetailsView().environment(self.userData)
                }
                .navigationDestination(isPresented: $userData.forceStartTour) {
                    TrailDetailsView().environment(self.userData)
                }
        }
    }

    private func trailAccessibilityLabel(for landmark: Landmark) -> String {
        guard let trail = landmarkService.getTrailById(id: landmark.id) else {
            return landmark.name
        }
        let count = MapService.getLandmarksOnTrail(trail: trail).count
        return "\(landmark.name), \(trail.trailDistanceDescription), \(count) points of interest"
    }
}

struct LandmarksList_Previews: PreviewProvider {
    static var previews: some View {
        TrailListView().environment(UserData.shared)
    }
}
