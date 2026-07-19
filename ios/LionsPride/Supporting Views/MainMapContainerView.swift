//
//  MainMapContainerView.swift
//  LionsPride
//
//  Created by Kevin Grainer on 5/15/20.
//  Copyright © 2020 Chariot Solutions. All rights reserved.
//

import SwiftUI
import CoreLocation

struct MainMapContainerView: View {
    @Binding var showMap: Bool
    @Environment(UserData.self) var userData
    
    var body: some View {
            // landmarkService is a plain global; reading userData.initialized makes
            // this view (and the map/search it builds) re-render once the trail data
            // finishes loading. Under @Observable, views only invalidate on the
            // properties they actually read.
            let _ = userData.initialized
            return ZStack(alignment:
                 .topLeading) {
                     // using opacity instead of if so that the map is updated properly from the search view
                    if showMap {
                        // TODO get coordinates from configuration
                         VStack {
                             MainMapView(coordinate: CLLocationCoordinate2D(
                             latitude: 40.248831,
                             longitude: -75.174176), landmarks: landmarkService.getLandmarks()).environment(userData)
                             .font(.title)
                         }
                    }
            
                    else {
                         VStack {
                            LandmarkSearchView(showMap: $showMap).environment(userData)
                         }
                    }
        }.navigationBarItems(trailing:
            Button(action: {
               self.showMap.toggle()
               if self.showMap {
                   UIApplication.shared.endEditing(true)
               }
               
            }) {
               Text(self.showMap ? "Search": "Cancel")
            }.padding(.trailing)
        )
    }
}

struct MainMapContainerView_Previews: PreviewProvider {
    static var previews: some View {
        MainMapContainerView(showMap: Binding.constant(true)).environment(UserData.shared)
    }
}
