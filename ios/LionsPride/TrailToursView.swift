//
//  TrailToursView.swift
//  LionsPride
//
//  Created by Kevin Grainer on 4/6/20.
//  Copyright © 2020 Kevin Grainer. All rights reserved.
//

import SwiftUI

struct TrailToursView: View {
    
    @EnvironmentObject private var userData: UserData
    
    var body: some View {
        VStack{
            Text("Trail Tours").modifier(HeaderStyle())
                Text("Trail Tours guide you through a pathway while highlighting the points of interest along the way.  The guidance will direct which cardinal direction and distance to walk.")
                NavigationView {
                    List {
                        
                        ForEach(landmarkService.getLandmarks().filter{$0.category.rawValue == "Trail"}) { landmark in
                            NavigationLink(
                                destination: LandmarkDetail(landmark: landmark)
                                    .environmentObject(self.userData)
                            ) {
                                LandmarkRow(landmark: landmark)
                            }
                        }
                    }
                    .navigationBarTitle(Text("Trail Tours"))
                }
            }
    }
}

struct TrailToursView_Previews: PreviewProvider {
    static var previews: some View {
        TrailToursView()
    }
}
