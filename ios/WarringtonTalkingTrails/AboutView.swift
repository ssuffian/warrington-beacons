//
//  AboutView.swift
//  WarringtonTalkingTrails
//
//  Created by Kevin Grainer on 4/3/20.
//  Copyright © 2020 Chariot Solutions. All rights reserved.
//

import SwiftUI

struct AboutView: View {
    var body: some View {
        VStack {
            ZStack (alignment: .top){
                ImageStore.shared.image(name:"field-photo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .accessibilityLabel("A wooded Warrington trail")
                VStack (alignment: .center) {
                    Text("About").modifier(HeaderStyle())
                    Text("Warrington Talking Trails")
                    .modifier(HeaderStyle())
                }
            }
            Rectangle()
                .fill(Color(YELLOW))
                .frame(height: 5).padding(.bottom)
            AboutTextView()
            Spacer()
        }
    }
}

struct AboutView_Previews: PreviewProvider {
    static var previews: some View {
        AboutView()
    }
}
