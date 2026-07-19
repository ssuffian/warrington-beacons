//
//  LandmarkListView.swift
//  LionsPride
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
        return GeometryReader { geo in
            NavigationStack {
                VStack {
                    Text("Trail Tours guide you through a pathway while highlighting the points of interest along the way.  The guidance will direct which cardinal direction and distance to walk").padding(10)
                    Rectangle()
                    .fill(Color.yellow)
                        .frame(width: geo.size.width - 40, height: 5)
                    List {
                        ForEach(landmarkService.getLandmarks().filter{$0.category.rawValue == "Trail"}) { landmark in

                            TrailRowView(landmark: landmark).onTapGesture {
                                self.userData.trailLandmark = landmark
                                let trail = landmarkService.getTrailById(id: self.userData.trailLandmark!.id)
                                if self.userData.nearbyLandmark != nil {
                                    let trails = landmarkService.getTrailsByLandmarkId(id: self.userData.nearbyLandmark!.id)
                                    if !trails.isEmpty && trails[0].id == trail!.id {
                                        self.userData.trailTourCurrentLandmark = self.userData.nearbyLandmark!
                                    } else {
                                        self.userData.trailTourCurrentLandmark = landmark
                                    }
                                    self.userData.checkForTrailTourEnd()
                                } else {
                                    self.userData.trailTourCurrentLandmark = landmark
                                }
                                // TODO: if self.control.userData.nearbyLandmark is set and is on this trail, use that instead
                                self.userData.trailTourTrail = trail
                                self.trailDetailsView = true
                            }
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
    }
}

struct LandmarksList_Previews: PreviewProvider {
    static var previews: some View {
        TrailListView().environment(UserData.shared)
    }
}
