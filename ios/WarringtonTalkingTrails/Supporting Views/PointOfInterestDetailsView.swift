//
//  PointOfInterestDetailsView.swift
//  WarringtonTalkingTrails
//
//  Created by Kevin Grainer on 4/20/20.
//  Copyright © 2020 Chariot Solutions. All rights reserved.
//

import SwiftUI

struct PointOfInterestDetailsView: View {
    var landmark: Landmark
    var close: () -> Void
    @Environment(UserData.self) var userData
    
    func trailNamesSeparated(trails: [Trail]) -> String {
        let names = trails.map{t in t.name}
        if names.count > 0 {
            return names.joined(separator: ", ")
        }
        return "None"
    }
    
    func landmarkNamesForTrailSeparated(landmark: Landmark) -> String {
        let landmarks = landmarkService.getLandmarksByTrailId(id: landmark.id)
        if landmarks.count > 0 {
            return landmarks.filter {$0.name != landmark.name}.map { $0.name }.joined(separator: ", ")
        }
        return "None"
    }
    
    var body: some View {
        
        ZStack(alignment: .topTrailing) {
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 0) {
                    AsyncImage(url: self.landmark.imageUrl) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .accessibility(label: Text(self.landmark.imageAlt))
                    } placeholder: {
                        ProgressView()
                    }

                    if self.userData.isTrailTour && self.landmark == self.userData.trailTourNextLandmark {
                        HStack(spacing: 8) {
                            Image(systemName: "info.circle.fill")
                            Text("Next Point of Interest")
                                .font(.headline)
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color(GREEN))
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        Text(self.landmark.category.friendlyValue())
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(self.landmark.trailModifiedName)
                            .font(.title2.weight(.bold))
                        Text(self.userData.showSimplifiedView ? self.landmark.description : self.landmark.longDescription)
                            .fixedSize(horizontal: false, vertical: true)
                            .lineSpacing(2)
                        if self.landmark.category.rawValue != "Trail" {
                            Text("Trails: \(self.trailNamesSeparated(trails: landmarkService.getTrailsByLandmarkId(id: self.landmark.id)))")
                                .fixedSize(horizontal: false, vertical: true)
                        } else {
                            Text("Points of Interest: \(self.landmarkNamesForTrailSeparated(landmark: self.landmark))")
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(20)
                    Spacer(minLength: 40)
                }
            }
            Button(action: self.close) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 34))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, Color.black.opacity(0.68))
                    .frame(width: 44, height: 44)
            }
            .padding(10)
            .accessibilityLabel("Close landmark details")
        }
    }
}

struct PointOfInterestDetailsView_Previews: PreviewProvider {
    static var previews: some View {
        NextPointOfInterestDetailsView(landmark: landmarkService.getLandmarks()[0], close: {})
    }
    
    // TODO
    static var previewsXXX: some View {
        
//        let jsonString = """
//        {
//          "name": "Yellow Trail",
//          "category": "Trail",
//          "id": 1002,
//          "coordinates": {
//            "latitude": 40.2472,
//            "longitude": -75.1773
//          },
//          "imageName": "trail",
//          "imageAlt": "Picture of trail",
//          "description": "The yellow trail is really great",
//          "longDescription": "The yellow trail is a 0.4 mile loop around the grove of Lions Pride Park.",
//          "latitudeDelta": 0.0034,
//          "longitudeDelta": 0.0033
//        }
//        """
        
        let jsonString = """
            {
              "name": "Park Entrance",
              "category": "PointOfInterest",
              "id": 1009,
              "coordinates": {
                "longitude": -75.1774876,
                "latitude": 40.2460564
              },
              "imageName": "park_entrance",
              "imageAlt": "View of trees and field from park entrance",
              "description": "The entrance to the park",
              "longDescription": "The first point of interest of the park, the entrance is the start of the Red Trail and is only 100 feet away from the park office",
              "latitudeDelta": 0.0031,
              "longitudeDelta": 0.0031
            }
        """
        
        let jsonData = jsonString.data(using: .utf8)!
        let landmark = try! JSONDecoder().decode(Landmark.self, from: jsonData)

        //let landmark = Landmark(from: jsonString)

//    var id: Int
//    var name: String
//    var imageName: String
//    var coordinates: Coordinates
//    var category: Category
//    var description: String
//    var longDescription: String
//    var latitudeDelta: CLLocationDegrees
//    var longitudeDelta: CLLocationDegrees
//    var imageAlt: String
        
        return NextPointOfInterestDetailsView(landmark:landmark, close: {})
    }
}
