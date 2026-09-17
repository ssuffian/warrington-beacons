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
            VStack (spacing: 0){
                if userData.trailLandmark != nil {
                    VStack(alignment: .leading) {
                        Text(userData.trailLandmark!.longDescription)
                        DirectionButtonView().environment(userData)
                        VStack(alignment: .leading) {
                            Text("If you are not starting at the \(self.userData.trailTourCurrentLandmark!.trailModifiedName), select the closest landmark as your starting point.")
                        }
                    }.padding()
                    TrailMapView(trailLandmark: userData.trailLandmark!).environment(userData)
                    Spacer()
                    Text("Start Tour").modifier(BlueButtonTextStyle())
                        .foregroundColor(Color.blue).onTapGesture {
                            // this sets up the context for the TrailTourView
                            self.userData.trailTourCurrentLandmark = self.userData.trailTourCurrentLandmark ?? self.userData.trailLandmark
                            let trail = landmarkService.getTrailById(id: self.userData.trailLandmark!.id)
                            self.userData.trailTourTrail = trail
                            let nextLandmark = MapService.findNextLandmark(trail: self.userData.trailTourTrail!, landmark: self.userData.trailTourCurrentLandmark!, direction: self.userData.trailDirection)
                            self.userData.trailTourNextLandmark = nextLandmark
                            self.userData.checkForTrailTourEnd()

                            // this triggers the navigationDestination push
                            self.startTrailTour = true
                        }.padding(.bottom)
                }
            }
            .navigationDestination(isPresented: self.$startTrailTour) {
                TrailTourView().environment(self.userData)
            }
            .navigationBarTitle("\(userData.trailLandmark!.name)", displayMode: .inline)
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

