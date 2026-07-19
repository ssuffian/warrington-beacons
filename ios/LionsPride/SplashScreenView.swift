//
//  WelcomeView.swift
//  LionsPride
//
//  Created by Kevin Grainer on 4/3/20.
//  Copyright © 2020 Chariot Solutions. All rights reserved.
//

import SwiftUI

struct SplashScreenView: View {
    var trails = landmarkService.getTrails()
    
    var body: some View {
        
        VStack {
           ImageStore.shared.image(name: "warrington-township-pa")
               .resizable()
               .frame(width: 250, height: 250)
               .padding()
           Rectangle()
               .fill(Color(GREEN))
               .frame(width: 250, height: 25)
           Rectangle()
               .fill(Color(YELLOW))
               .frame(width: 250, height: 25)
           Rectangle()
               .fill(Color(ORANGE))
               .frame(width: 250, height: 25)
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.white)
    }
}

struct SplashScreenView_Previews: PreviewProvider {
    static var previews: some View {
        SplashScreenView()
    }
}
