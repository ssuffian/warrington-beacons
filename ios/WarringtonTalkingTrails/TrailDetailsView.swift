/*
See LICENSE folder for this sample’s licensing information.

Abstract:
A view showing the details for a landmark.
*/

import CoreLocation
import SwiftUI

struct TrailDetailsView: View {
    
    @Environment(UserData.self) var userData
    @State var startTrailTour = false
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            if let trailLandmark = userData.trailLandmark,
               let currentLandmark = userData.trailTourCurrentLandmark {
                VStack(spacing: 0) {
                    VStack(alignment: .leading) {
                        Text(trailLandmark.longDescription)
                            .fixedSize(horizontal: false, vertical: true)
                        DirectionButtonView().environment(userData)
                        Text("If you are not starting at the \(currentLandmark.trailModifiedName), select the closest landmark as your starting point.")
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding()

                    TrailMapView(trailLandmark: trailLandmark)
                        .environment(userData)
                        .frame(height: 360)

                    Button(action: {
                            guard let trail = landmarkService.getTrailById(id: trailLandmark.id) else {
                                return
                            }
                            let currentLandmark = self.userData.trailTourCurrentLandmark ?? trailLandmark
                            self.userData.trailTourCurrentLandmark = currentLandmark
                            self.userData.trailTourTrail = trail
                            self.userData.trailTourNextLandmark = MapService.findNextLandmark(
                                trail: trail,
                                landmark: currentLandmark,
                                direction: self.userData.trailDirection
                            )
                            self.userData.checkForTrailTourEnd()

                            // this triggers the navigationDestination push
                            self.startTrailTour = self.userData.trailTourNextLandmark != nil
                    }) {
                        Text("Start Tour").modifier(BlueButtonTextStyle())
                            .foregroundColor(Color.blue)
                    }
                    .accessibilityHint("Starts spoken trail navigation")
                    .padding()
                }
            }
        }
            .navigationDestination(isPresented: self.$startTrailTour) {
                TrailTourView().environment(self.userData)
            }
            .navigationBarTitle(userData.trailLandmark?.name ?? "Trail", displayMode: .inline)
            .onAppear {
                print("Trail details showing")
            }.onDisappear {
                print("Trail details hiding")
            }
    }
    
    
    func getLandmarksForMap(landmark: Landmark) -> [Landmark] {
        var landmarks = [Landmark]()
        landmarks.append(landmark)
        if landmark.category == Landmark.Category.Trail {
            landmarks.append(contentsOf: landmarkService.getLandmarksByTrailId(id: landmark.id))
        }
        return landmarks
    }
    
}

struct TrailDetailsView_Previews: PreviewProvider {
    static var previews: some View {
        let userData = UserData.shared
        userData.trailLandmark = landmarkService.getLandmarkById(id: 1002)!
        return TrailDetailsView()
            .environment(userData)
    }
}
