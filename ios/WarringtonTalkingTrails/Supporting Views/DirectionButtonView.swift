//
//  DirectionButtonView.swift
//  WarringtonTalkingTrails
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
                Button(action: {
                        self.userData.trailDirection = .Clockwise
                }) {
                    Text("Forward").modifier(SmallButtonTextStyle())
                        .foregroundColor(getDirectionForeground(direction: .Clockwise))
                        .background(RoundedRectangle(cornerRadius: 5).fill(getDirectionBackground(direction: .Clockwise)))
                }
                .accessibilityLabel("Forward direction")
                .accessibilityValue(userData.trailDirection == .Clockwise ? "Selected" : "Not selected")
                .accessibilityAddTraits(userData.trailDirection == .Clockwise ? .isSelected : [])
                Button(action: {
                    self.userData.trailDirection = .CounterClockwise
                }) {
                    Text("Reverse").modifier(SmallButtonTextStyle())
                        .foregroundColor(getDirectionForeground(direction: .CounterClockwise))
                        .background(RoundedRectangle(cornerRadius: 5).fill(getDirectionBackground(direction: .CounterClockwise)))
                }
                .accessibilityLabel("Reverse direction")
                .accessibilityValue(userData.trailDirection == .CounterClockwise ? "Selected" : "Not selected")
                .accessibilityAddTraits(userData.trailDirection == .CounterClockwise ? .isSelected : [])
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
