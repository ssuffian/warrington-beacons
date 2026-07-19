//
//  AboutView.swift
//  LionsPride
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
                    .aspectRatio(contentMode: .fit).accessibility(label: Text("About the US-202 to Bradford Dam connector trail"))
                VStack (alignment: .center) {
                    Text("About").modifier(HeaderStyle())
                    Text("the US-202 to Bradford Dam connector trail")
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
