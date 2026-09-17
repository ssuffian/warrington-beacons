/*
See LICENSE folder for this sample’s licensing information.

Abstract:
A view showing the details for a landmark.
*/

import CoreLocation
import SwiftUI

struct TrailTourView: View {
    
    @Environment(UserData.self) var userData
    @State var showPointOfInterestDetails = false
    @State var showPointOfInterestSummary = true
    let notificationService = NotificationService.shared
    
    func close() -> Void {
        self.showPointOfInterestDetails = false
    }
    
    var body: some View {
        ZStack {
            
                VStack (alignment: .leading, spacing: 0){
                    let current = userData.trailTourNextLandmark!
                    let nextDistance = getNextLandmarkDistanceDescription()!
                    NextPointOfInterestView(selectedLandmark: current, nextLandmarkDistanceDescription: nextDistance, showLandmarkDetails: $showPointOfInterestDetails).environment(userData).padding()
                    TrailTourMapView(landmarks: getLandmarksForMap(landmark: userData.trailLandmark!), showPointOfInterestDetails: $showPointOfInterestDetails).environment(userData)
                    Spacer()
                }.navigationBarItems(trailing:
                    TrailTourButtonBarView(landmark: userData.trailLandmark!).environment(self.userData)
                    ).navigationBarTitle("\(userData.trailLandmark!.name) Tour", displayMode: .inline)
                    .sheet(isPresented: self.$showPointOfInterestDetails) {
                        PointOfInterestDetailsView(landmark: self.userData.trailTourSelectedLandmark!, close: self.close)
                            .background(Color(.secondarySystemBackground)).environment(self.userData)
            }
        }.onAppear {
            print("Trail tour showing for \(userData.trailTourCurrentLandmark!.name)")
            self.userData.isTrailTour = true
            BeaconScanner.shared.startScanning()
            // TODO WTF is this doing?
            if UIAccessibility.isVoiceOverRunning {
                if self.userData.trailTourCurrentLandmark != nil && self.userData.trailTourNextLandmark != nil && self.userData.trailLandmark != nil {
                    self.notificationService.sendTrailTourNotification(currentLandmark: self.userData.trailTourCurrentLandmark!, nextLandmark: self.userData.trailTourNextLandmark!, trailLandmark: self.userData.trailLandmark!, trailDirection: self.userData.trailDirection)
                }
            }
        }.onDisappear {
            print("Trail tour hiding")
            self.userData.isTrailTour = false
            if(!self.userData.parkMapVisible) {
                BeaconScanner.shared.stopScanning()
            }
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
    
    func getDirectionForeground(direction: Direction) -> Color {
        if userData.trailDirection == direction {
            return .white
        } else {
            return .blue
        }
    }
    
    func getDirectionBackground(direction: Direction) -> Color {
        if userData.trailDirection == direction {
            return .blue
        } else {
            return .white
        }
    }
    
    func getNextLandmarkDistanceDescription() -> String? {
        let trail = userData.trailTourTrail
        
        if trail != nil && userData.trailTourCurrentLandmark != nil {
            let distanceTuple = MapService.distanceToNextLandmark(trail: trail!, currentLandmark: userData.trailTourCurrentLandmark!, direction: userData.trailDirection)
            return distanceTuple?.distanceToNextDescription
        }
        print("getNextLandmarkDistanceDescription not found")
        return ""
    }
}

struct TrailTourButtonBarView: View {
    var landmark: Landmark
    @Environment(UserData.self) var userData
    let notificationService = NotificationService.shared
    
    var body: some View {
        HStack {
            Button("Reverse") {
                if self.userData.trailDirection == .Clockwise {
                    self.userData.trailDirection = .CounterClockwise
                } else {
                    self.userData.trailDirection = .Clockwise
                }
                
                if self.userData.trailTourCurrentLandmark != nil && self.userData.trailTourCurrentLandmark != nil {
                    // recalculate the next landmark
                    self.userData.trailTourNextLandmark = MapService.findNextLandmark(trail: self.userData.trailTourTrail!, landmark: self.userData.trailTourCurrentLandmark!, direction: self.userData.trailDirection)
                    if self.userData.trailTourNextLandmark != nil && self.userData.trailTourTrail != nil {
                        self.userData.checkForTrailTourEnd()

                        if UIAccessibility.isVoiceOverRunning {
                            self.notificationService.sendTrailTourNotification(currentLandmark: self.userData.trailTourCurrentLandmark!, nextLandmark: self.userData.trailTourNextLandmark!, trailLandmark: self.userData.trailLandmark!, trailDirection: self.userData.trailDirection)
                        }
                    }
                }
            }
        }
    }
}

struct TrailTour_Previews: PreviewProvider {
    static var previews: some View {
        let userData = UserData.shared
        userData.trailLandmark = landmarkService.getLandmarks()[0]
        return TrailTourView()
            .environment(userData)
    }
}

struct CornerRadiusStyle: ViewModifier {
    var radius: CGFloat
    var corners: UIRectCorner

    struct CornerRadiusShape: Shape {

        var radius = CGFloat.infinity
        var corners = UIRectCorner.allCorners

        func path(in rect: CGRect) -> Path {
            let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
            return Path(path.cgPath)
        }
    }

    func body(content: Content) -> some View {
        content
            .clipShape(CornerRadiusShape(radius: radius, corners: corners))
    }
}

extension View {
    func cornerRadius(radius: CGFloat, corners: UIRectCorner) -> some View {
        ModifiedContent(content: self, modifier: CornerRadiusStyle(radius: radius, corners: corners))
    }
}
