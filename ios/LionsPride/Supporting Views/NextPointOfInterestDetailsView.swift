//
//  PointOfInterestDetailsView.swift
//  LionsPride
//
//  Created by Kevin Grainer on 4/20/20.
//  Copyright © 2020 Chariot Solutions. All rights reserved.
//

import SwiftUI

struct NextPointOfInterestDetailsView: View {
    var landmark: Landmark
    var close: () -> Void
    @Environment(UserData.self) var userData
    
    func trailNamesSeparated(trails: [Trail]) -> String{
        let names = trails.map{t in t.name}
        if names.count > 0 {
            return names.joined(separator: ", ")
        }
        return "None"
    }
    
    var body: some View {
        BottomSheetView(maxHeight: 600, close: close) {
            GeometryReader { geo in
                ZStack {
                    VStack(alignment: .leading) {
                        AsyncImage(url: getUrl("\(BASE_URL_STRING)/images/\(self.landmark.imageName).jpg")) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                        } placeholder: {
                            ProgressView()
                        }
                        .frame(width: geo.size.width)
                        Text(self.landmark.category.friendlyValue()).modifier(GrayUpperStyle()).padding([.top, .leading])
                        Text(self.landmark.name).modifier(SubHeaderStyle())
                            .foregroundColor(Color.black).padding()
                        Text(self.userData.showSimplifiedView ? self.landmark.description : self.landmark.longDescription).padding(.leading)
                        if self.landmark.category.rawValue != "Trail" {
                            HStack {
                                Text("Trails").modifier(LabelStyle())
                                Text("\(self.trailNamesSeparated(trails: landmarkService.getTrailsByLandmarkId(id: self.landmark.id)))")
                            }.padding([.top, .leading, .trailing])
                        }
                        Spacer()
                    }
                    CloseButtonView().offset(x: geo.size.width / 2 - 35, y: -(geo.size.height / 2 - 35)).onTapGesture {
                        self.close()
                    }
                }
            }
        }
    }
}

struct NextPointOfInterestDetailsView_Previews: PreviewProvider {
    static var previews: some View {
        PointOfInterestDetailsView(landmark: landmarkService.getLandmarks()[0], close: {})
    }
}
