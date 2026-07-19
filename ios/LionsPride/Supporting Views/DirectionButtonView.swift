//
//  DirectionButtonView.swift
//  LionsPride
//
//  Created by Kevin Grainer on 5/12/20.
//  Copyright © 2020 Chariot Solutions. All rights reserved.
//

import SwiftUI

struct DirectionButtonView: View {
    @Environment(UserData.self) var userData
    
    var body: some View {
        ZStack {
            
            HStack(spacing: 0) {
                Text("Direction:  ").modifier(GrayUpperStyle())
                Text("Forward").modifier(SmallButtonTextStyle())
                    .foregroundColor(getDirectionForeground(direction: .Clockwise))
                    .background(RoundedRectangle(cornerRadius: 5).fill(getDirectionBackground(direction: .Clockwise)))
                    .onTapGesture {
                        self.userData.trailDirection = .Clockwise
                    }
                Text("Reverse").modifier(SmallButtonTextStyle())
                    .foregroundColor(getDirectionForeground(direction: .CounterClockwise))
                    .background(RoundedRectangle(cornerRadius: 5).fill(getDirectionBackground(direction: .CounterClockwise)))
                    .onTapGesture {
                        self.userData.trailDirection = .CounterClockwise
                    }
                Spacer()
            }
        }
    }
    
    
    func getDirectionForeground(direction: Direction) -> Color {
        if userData.trailDirection == direction {
            return .white
        } else {
            return .blue
        }
    }
    
    func getDirectionBackground(direction: Direction) -> Color {
        if userData.trailDirection == direction {
            return .blue
        } else {
            return .white
        }
    }
}

struct DirectionButtonView_Previews: PreviewProvider {
    static var previews: some View {
        DirectionButtonView().environment(UserData.shared)
    }
}
