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
        if let landmark = self.userData.mainMapSelectedLandmark {
            HStack(alignment: .top, spacing: 12) {
                AsyncImage(url: landmark.imageUrl) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    ProgressView()
                }
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 6) {
                    if self.userData.nearbyLandmark == landmark {
                        Label("Nearby \(landmark.category.friendlyValue())", systemImage: "info.circle.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(Color(GREEN), in: Capsule())
                    } else {
                        Text(landmark.category.friendlyValue())
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    if landmark.category == .Trail {
                        Button(action: {
                                guard let trail = landmarkService.getTrailById(id: landmark.id) else {
                                    return
                                }
                                self.userData.trailLandmark = landmark
                                self.userData.trailTourTrail = trail
                                self.userData.trailTourCurrentLandmark = landmark
                                self.userData.trailTourNextLandmark = MapService.findNextLandmark(
                                    trail: trail,
                                    landmark: landmark,
                                    direction: self.userData.trailDirection
                                )
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
                            Text(landmark.trailModifiedName)
                                .font(.headline)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.tint)
                        .accessibilityHint("Opens this trail in Trail Tours")
                    } else {
                        Button(action: {
                            self.showDetails = true
                            self.showPointOfInterestDetails = true
                        }) {
                            Text(landmark.name)
                                .font(.headline)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.tint)
                    }
                    if !self.userData.distanceToSelectedLandmark.isEmpty {
                        Text(self.userData.distanceToSelectedLandmark)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Button(action: self.close) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(.secondary)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("Close point of interest summary")
            }
            .padding(12)
            .background(Color(.secondarySystemBackground))
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
