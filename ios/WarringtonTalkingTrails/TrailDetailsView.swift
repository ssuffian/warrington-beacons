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
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(trailLandmark.longDescription)
                            .fixedSize(horizontal: false, vertical: true)
                        DirectionButtonView().environment(userData)
                        Text("If you are not starting at the \(currentLandmark.trailModifiedName), select the closest landmark as your starting point.")
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding()

                    TrailMapView(trailLandmark: trailLandmark)
                        .environment(userData)
                        .frame(minHeight: 280, idealHeight: 340, maxHeight: 380)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal)

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
                        Text("Start Tour")
                            .font(.headline)
                            .frame(maxWidth: .infinity, minHeight: 28)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .accessibilityHint("Starts spoken trail navigation")
                    .padding(.horizontal)
                    .padding(.bottom, 20)
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
