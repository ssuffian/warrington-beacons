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
        @Bindable var userData = userData
        VStack(alignment: .leading, spacing: 8) {
            Text("Direction")
                .font(.headline)
                .foregroundStyle(.secondary)
            Picker("Direction", selection: $userData.trailDirection) {
                Text("Forward")
                    .accessibilityLabel("Forward direction")
                    .tag(Direction.Clockwise)
                Text("Reverse")
                    .accessibilityLabel("Reverse direction")
                    .tag(Direction.CounterClockwise)
            }
            .pickerStyle(.segmented)
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
