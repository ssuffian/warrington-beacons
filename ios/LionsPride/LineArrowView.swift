//
//  LineArrowView.swift
//  LionsPride
//
//  Created by Kevin Grainer on 5/18/20.
//  Copyright © 2020 Chariot Solutions. All rights reserved.
//

import SwiftUI

struct LineArrowView: View {
    var body: some View {
        Line()
    }
}



struct Line: View {
    let end = CGPoint(x: 200.0, y: 100.0)
    let start = CGPoint(x: 100.0, y: 200.0)
    let pointerLineLength = CGFloat(25.0)
    let arrowAngle = CGFloat(0.61)
    
    var body: some View {
        
        Path { path in
            path.move(to: start)
            path.addLine(to: end)

            let startEndAngle = atan((end.y - start.y) / (end.x - start.x)) + ((end.x - start.x) < 0 ? CGFloat(Double.pi) : 0)
            let arrowLine1 = CGPoint(x: end.x + pointerLineLength * cos(CGFloat(Double.pi) - startEndAngle + arrowAngle), y: end.y - pointerLineLength * sin(CGFloat(Double.pi) - startEndAngle + arrowAngle))
            let arrowLine2 = CGPoint(x: end.x + pointerLineLength * cos(CGFloat(Double.pi) - startEndAngle - arrowAngle), y: end.y - pointerLineLength * sin(CGFloat(Double.pi) - startEndAngle - arrowAngle))
            path.addLine(to: arrowLine1)
            path.move(to: end)
            path.addLine(to: arrowLine2)
        }.stroke()
//        Image(systemName: "arrowtriangle.up.fill")
//        .rotationEffect(.radians(45))
    }
}



struct LineArrowView_Previews: PreviewProvider {
    static var previews: some View {
        LineArrowView()
    }
}
