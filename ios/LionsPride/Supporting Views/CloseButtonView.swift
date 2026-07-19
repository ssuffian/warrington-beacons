//
//  CloseButtonView.swift
//  LionsPride
//
//  Created by Kevin Grainer on 5/1/20.
//  Copyright © 2020 Chariot Solutions. All rights reserved.
//

import SwiftUI

struct CloseButtonView: View {
    var foregroundColor = Color.white
    var backgroundColor = Color.black
    var circleFrameSize: CGFloat = 50
    var xLineLength: CGFloat = 25
    var xLineWidth:CGFloat = 2.5
    var backgroundOpacity = 0.6
    
    var body: some View {
        ZStack {
            Image(systemName: "xmark.circle.fill").resizable().frame(width: 40, height: 40).accessibility(label: Text("Close point of interest summary")).foregroundColor(.black).opacity(backgroundOpacity)
        }
    }
}

struct CloseButtonView_Previews: PreviewProvider {
    static var previews: some View {
        CloseButtonView()
    }
}
