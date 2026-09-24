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
            if let current = userData.trailTourNextLandmark,
               let trailLandmark = userData.trailLandmark {
                VStack (alignment: .leading, spacing: 0){
                    let nextDistance = getNextLandmarkDistanceDescription()
                    NextPointOfInterestView(selectedLandmark: current, nextLandmarkDistanceDescription: nextDistance, showLandmarkDetails: $showPointOfInterestDetails).environment(userData).padding()
                    TrailTourMapView(landmarks: getLandmarksForMap(landmark: trailLandmark), showPointOfInterestDetails: $showPointOfInterestDetails).environment(userData)
                    Spacer()
                }.navigationBarItems(trailing:
                    TrailTourButtonBarView(landmark: trailLandmark).environment(self.userData)
                    ).navigationBarTitle("\(trailLandmark.name) Tour", displayMode: .inline)
            } else {
                ContentUnavailableView(
                    "Tour Unavailable",
                    systemImage: "map",
                    description: Text("Return to Trail Tours and select a trail to begin again.")
                )
            }
        }
        .sheet(isPresented: self.$showPointOfInterestDetails) {
            if let selectedLandmark = self.userData.trailTourSelectedLandmark {
                PointOfInterestDetailsView(landmark: selectedLandmark, close: self.close)
                    .background(Color(.secondarySystemBackground)).environment(self.userData)
            }
        }
        .onAppear {
            guard let currentLandmark = userData.trailTourCurrentLandmark else {
                return
            }
            print("Trail tour showing for \(currentLandmark.name)")
            self.userData.isTrailTour = true
            BeaconScanner.shared.startScanning()
            // TODO WTF is this doing?
            if UIAccessibility.isVoiceOverRunning {
                if let nextLandmark = self.userData.trailTourNextLandmark,
                   let trailLandmark = self.userData.trailLandmark {
                    self.notificationService.sendTrailTourNotification(currentLandmark: currentLandmark, nextLandmark: nextLandmark, trailLandmark: trailLandmark, trailDirection: self.userData.trailDirection)
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
    
    func getNextLandmarkDistanceDescription() -> String {
        guard let trail = userData.trailTourTrail,
              let currentLandmark = userData.trailTourCurrentLandmark else {
            return ""
        }
        return MapService.distanceToNextLandmark(
            trail: trail,
            currentLandmark: currentLandmark,
            direction: userData.trailDirection
        )?.distanceToNextDescription ?? ""
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
                
                guard let currentLandmark = self.userData.trailTourCurrentLandmark,
                      let trail = self.userData.trailTourTrail else {
                    return
                }
                self.userData.trailTourNextLandmark = MapService.findNextLandmark(
                    trail: trail,
                    landmark: currentLandmark,
                    direction: self.userData.trailDirection
                )
                self.userData.checkForTrailTourEnd()

                if UIAccessibility.isVoiceOverRunning,
                   let nextLandmark = self.userData.trailTourNextLandmark,
                   let trailLandmark = self.userData.trailLandmark {
                    self.notificationService.sendTrailTourNotification(currentLandmark: currentLandmark, nextLandmark: nextLandmark, trailLandmark: trailLandmark, trailDirection: self.userData.trailDirection)
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
