//
//  BottomSheetView.swift
//
//  Created by Majid Jabrayilov
//  Copyright © 2019 Majid Jabrayilov. All rights reserved.
//
import SwiftUI

fileprivate enum Constants {
    static let radius: CGFloat = 16
    static let indicatorHeight: CGFloat = 6
    static let indicatorWidth: CGFloat = 60
    static let snapRatio: CGFloat = 0.25
    static let minHeightRatio: CGFloat = 0
}

struct BottomSheetView<Content: View>: View {
    var close: () -> Void

    let maxHeight: CGFloat
    let minHeight: CGFloat
    let content: Content

    @GestureState private var translation: CGFloat = 0

    private var offset: CGFloat {
        0
    }

    private var indicator: some View {
        RoundedRectangle(cornerRadius: Constants.radius)
            .fill(Color.secondary)
            .frame(
                width: Constants.indicatorWidth,
                height: Constants.indicatorHeight
        ).onTapGesture {
            self.close()
        }
    }

    init(maxHeight: CGFloat, close: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.minHeight = maxHeight * Constants.minHeightRatio
        self.maxHeight = maxHeight
        self.content = content()
        self.close = close
    }

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
//                self.indicator.padding()
                self.content
            }
            .frame(width: geometry.size.width, height: self.maxHeight, alignment: .top)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(Constants.radius)
            .frame(height: geometry.size.height, alignment: .bottom)
            .offset(y: max(self.offset + self.translation, 0))
            .animation(.interactiveSpring())
            .gesture(
                DragGesture().updating(self.$translation) { value, state, _ in
                    state = value.translation.height
                }.onEnded { value in
                    let snapDistance = self.maxHeight * Constants.snapRatio
                    guard abs(value.translation.height) > snapDistance else {
                        return
                    }
//                    self.isOpen = value.translation.height < 0
                }
            )
        }
    }
}

struct BottomSheetView_Previews: PreviewProvider {
    func close() -> Void {
        
    }
    
    static var previews: some View {
        BottomSheetView(maxHeight: 600, close: {}) {
            Rectangle().fill(Color.red)
        }.edgesIgnoringSafeArea(.all)
    }
}
