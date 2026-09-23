//
//  PointOfInterestSummaryView.swift
//  WarringtonTalkingTrails
//
//  Created by Kevin Grainer on 6/2/20.
//  Copyright © 2020 Chariot Solutions. All rights reserved.
//

import SwiftUI

struct PointOfInterestSummaryView: View {
    @Environment(UserData.self) var userData
    @State var showDetails = false
    @Binding var showPointOfInterestSummary: Bool
    @Binding var showPointOfInterestDetails: Bool
    @Binding var selectedTab: Int
    
    func close() -> Void {
        self.userData.mainMapSelectedLandmark = nil
        self.showDetails = false
        self.showPointOfInterestSummary = false
    }
    
    var body: some View {
        GeometryReader { geo in
            if let landmark = self.userData.mainMapSelectedLandmark {
            HStack(alignment: .top) {
                VStack {
                    AsyncImage(url: landmark.imageUrl) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit).accessibility(label: Text(landmark.imageAlt))
                    } placeholder: {
                        ProgressView()
                    }
                    .frame(width: 75, height: 75).padding(.trailing)
                    .accessibilityHidden(true)
                }
                VStack(alignment: .leading) {
                    // iPhone 7: 320x568
                    // iPhone X: 375x812
                    let small = self.userData.screenSize.width < 360
                    if self.userData.nearbyLandmark == landmark {
                        ZStack(alignment: .center) {
                            Rectangle().fill(Color(GREEN)).frame(width: small ? 150 : 200, height: 26)
                            HStack {
                                Image(systemName: "info.circle").foregroundColor(.white)
                                Text((small ? "" : "Nearby ") + landmark.category.friendlyValue()).modifier(WhiteUpperStyle())
                            }
                        }
                    } else {
                        Text(landmark.category.friendlyValue()).modifier(GrayUpperStyle()).padding(.bottom)
                    }
                    if landmark.category == .Trail {
                        Button(action: {
                                self.userData.trailLandmark = landmark
                                self.userData.trailTourTrail = landmarkService.getTrailById(id: self.userData.trailLandmark!.id)
                                self.userData.trailTourCurrentLandmark = self.userData.trailLandmark
                                self.userData.trailTourNextLandmark =  MapService.findNextLandmark(trail: self.userData.trailTourTrail!, landmark: self.userData.trailTourCurrentLandmark!, direction: self.userData.trailDirection)
                                self.userData.checkForTrailTourEnd()
                                self.selectedTab = 1
                                // If this call is synchronous it corrupts the navigation stack
                                // The "back" link has two things overwriting each other for certain trails
                                // and using it can produce a gray screen and "cannot add self as subview" error
                                // But making it async allows the tab to render and then a new view to be pushed
                                // onto the view stack as we expect
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                    // Push the tour view unless it is already showing
                                    if !self.userData.isTrailTour {
                                        self.userData.forceStartTour = true
                                    }
                                }
                        }) {
                            Text(landmark.trailModifiedName).modifier(LinkStyle())
                                .foregroundColor(Color.blue)
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Opens this trail in Trail Tours")
                    } else {
                        Button(action: {
                            self.showDetails = true
                            self.showPointOfInterestDetails = true
                        }) {
                            Text(landmark.name).modifier(LinkStyle())
                                                .foregroundColor(Color.blue)
                        }
                    }
                    Text(self.userData.distanceToSelectedLandmark).modifier(ParagraphStyle())
                }
                Spacer()
                Button(action: self.close) {
                    Image(systemName: "xmark.circle.fill").resizable().frame(width: 35, height: 35).foregroundColor(.black).opacity(0.6)
                }
                .accessibilityLabel("Close point of interest summary")
                }.padding()
            }
            EmptyView()
        }
    }
}

struct PointOfInterestSummaryView_Previews: PreviewProvider {
    static var previews: some View {
        let userData = UserData.shared
        userData.mainMapSelectedLandmark = landmarkService.getLandmarks()[0]
        userData.nearbyLandmark = userData.mainMapSelectedLandmark
        return PointOfInterestSummaryView(showPointOfInterestSummary: Binding.constant(false), showPointOfInterestDetails: Binding.constant(false), selectedTab:Binding.constant(0)).environment(userData)
    }
}
