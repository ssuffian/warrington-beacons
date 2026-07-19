//
//  PointOfInterestDetailsView.swift
//  LionsPride
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
        
        ZStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    HStack{
                        Spacer()
                        Button(action: self.close) {
                        Image(systemName: "xmark.circle.fill").resizable().frame(width: 35, height: 35).accessibility(label: Text("Close point of interest summary")).foregroundColor(.black).opacity(0.6)
                        }.padding()
                    }
                    
                    AsyncImage(url: getUrl("\(BASE_URL_STRING)/images/\(self.landmark.imageName).jpg")) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .accessibility(label: Text(self.landmark.imageAlt))
                    } placeholder: {
                        ProgressView()
                    }

                    if self.userData.isTrailTour && self.landmark == self.userData.trailTourNextLandmark {
                        ZStack(alignment: .leading) {
                            Rectangle().fill(Color(GREEN)).frame(height: 26)
                            HStack {
                                Image(systemName: "info.circle").foregroundColor(.white)
                                Text("Next Point of Interest").modifier(WhiteUpperStyle())
                            }.padding([.leading])
                        }
                    }
                    Text(self.landmark.category.friendlyValue()).modifier(GrayUpperStyle()).padding([.top, .leading])
                    Text(self.landmark.trailModifiedName).modifier(SubHeaderStyle())
                        .foregroundColor(Color.black).padding()
                    Text(self.userData.showSimplifiedView ? self.landmark.description : self.landmark.longDescription).padding([.leading, .trailing])
                    if self.landmark.category.rawValue != "Trail" {
                        Text("Trails:  \(self.trailNamesSeparated(trails: landmarkService.getTrailsByLandmarkId(id: self.landmark.id)))").padding([.top, .leading, .trailing])
                    } else {
                        Text("Points of Interest:  \(self.landmarkNamesForTrailSeparated(landmark: self.landmark))").padding([.top, .leading, .trailing])
                    }
                    Spacer()
                }
            }
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
