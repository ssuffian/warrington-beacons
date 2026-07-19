//
//  LandmarkSearchFieldValue.swift
//  LionsPride
//
//  Created by Kevin Grainer on 4/23/20.
//  Copyright © 2020 Chariot Solutions. All rights reserved.
//

import SwiftUI

struct LandmarkSearchFieldView: View {
    @Binding var searchValue: String
    
    var body: some View {
        HStack() {
            Button(
                action: {
                    print("back!")
                }
            ) {
                Image(systemName: "lessthan").padding(.leading)
            }
            TextField(" Search", text: self.$searchValue, onEditingChanged: { (editingChanged) in
                if editingChanged {
                    print("TextField focused")
                } else {
                    print("TextField focus removed")
                }
            } ).padding(5)
            Spacer()
            Button(action: {
                print("search!")
            }){
            Image(systemName: "magnifyingglass").padding(.trailing)
            }
        }.background(Color.white).cornerRadius(8).padding()
    }
}

struct LandmarkSearchFieldValue_Previews: PreviewProvider {
    static var previews: some View {
        LandmarkSearchFieldView(searchValue: Binding.constant(""))
    }
}
