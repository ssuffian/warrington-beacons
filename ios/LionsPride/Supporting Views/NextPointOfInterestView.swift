//
//  NextPointOfInterestView.swift
//  LionsPride
//
//  Created by Kevin Grainer on 5/14/20.
//  Copyright © 2020 Chariot Solutions. All rights reserved.
//

import SwiftUI

struct NextPointOfInterestView: View {
    var selectedLandmark: Landmark
    var nextLandmarkDistanceDescription: String
    @Binding var showLandmarkDetails: Bool
    @Environment(UserData.self) var userData
    
    var body: some View {
        ZStack {
            VStack(alignment: .leading) {
                HStack(alignment: .top) {
                    AsyncImage(url: getUrl("\(BASE_URL_STRING)/images/\(selectedLandmark.imageName).jpg")) { image in
                        image
                            .resizable()
                    } placeholder: {
                        ProgressView()
                    }
                    .frame(width: 100, height: 75)
                    VStack(alignment: .leading) {
                        Text("Next").modifier(GrayUpperStyle())
                        Text(selectedLandmark.trailModifiedName).modifier(LinkStyle())
                            .onTapGesture {
                                self.userData.trailTourSelectedLandmark = selectedLandmark
                                self.showLandmarkDetails = true
                        }
                    }
                }
                
                HStack(alignment: .center) {
                    Text("Directions:").modifier(LabelStyle()).padding([.top])
                    Text(nextLandmarkDistanceDescription).modifier(ParagraphStyle()).padding([.top])
                }
            
                HStack {
                    Text("From:").modifier(LabelStyle())
                    let widget = Text(self.userData.trailTourEnded ? "Go to the other end of the trail to continue in this direction" : self.userData.trailTourCurrentLandmark!.trailModifiedName)
                    if(!self.userData.trailTourEnded) {
                        widget.modifier(SmallLinkStyle()).onTapGesture {
                            self.userData.trailTourSelectedLandmark = self.userData.trailTourCurrentLandmark!
                            self.showLandmarkDetails = true
                        }
                    } else {
                        widget.modifier(ParagraphStyle())
                    }
                }
            }
        }
        
        
    }
}

struct NextPointOfInterestView_Previews: PreviewProvider {
    static var previews: some View {
        NextPointOfInterestView(selectedLandmark: landmarkService.getLandmarkById(id: 1010)!, nextLandmarkDistanceDescription: "800 feet along path", showLandmarkDetails: Binding.constant(false))
    }
}
