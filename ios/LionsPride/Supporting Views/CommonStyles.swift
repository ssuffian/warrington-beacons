//
//  CommonStyles.swift
//  LionsPride
//
//  Created by Kevin Grainer on 4/7/20.
//  Copyright © 2020 Chariot Solutions. All rights reserved.
//

import Foundation
import SwiftUI

extension UIColor {

    // MARK: - Initialization

    convenience init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0

        var r: CGFloat = 0.0
        var g: CGFloat = 0.0
        var b: CGFloat = 0.0
        var a: CGFloat = 1.0

        let length = hexSanitized.count

        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

        if length == 6 {
            r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
            g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
            b = CGFloat(rgb & 0x0000FF) / 255.0

        } else if length == 8 {
            r = CGFloat((rgb & 0xFF000000) >> 24) / 255.0
            g = CGFloat((rgb & 0x00FF0000) >> 16) / 255.0
            b = CGFloat((rgb & 0x0000FF00) >> 8) / 255.0
            a = CGFloat(rgb & 0x000000FF) / 255.0

        } else {
            return nil
        }

        self.init(red: r, green: g, blue: b, alpha: a)
    }

    // MARK: - Computed Properties

    var toHex: String? {
        return toHex()
    }

    // MARK: - From UIColor to String

    func toHex(alpha: Bool = false) -> String? {
        guard let components = cgColor.components, components.count >= 3 else {
            return nil
        }

        let r = Float(components[0])
        let g = Float(components[1])
        let b = Float(components[2])
        var a = Float(1.0)

        if components.count >= 4 {
            a = Float(components[3])
        }

        if alpha {
            return String(format: "%02lX%02lX%02lX%02lX", lroundf(r * 255), lroundf(g * 255), lroundf(b * 255), lroundf(a * 255))
        } else {
            return String(format: "%02lX%02lX%02lX", lroundf(r * 255), lroundf(g * 255), lroundf(b * 255))
        }
    }

}

let GREEN = UIColor(hex: "#7BA130")!
let ORANGE = UIColor(hex: "#ED6124")!
let YELLOW = UIColor(hex: "#F9BF51")!
let TRAIL_DESELECTED = UIColor.blue.withAlphaComponent(CGFloat(0.5))
let TRAIL_SELECTED = UIColor.blue
let LINE_DASH_PATTERN = NSNumber(5)
let LINE_WIDTH = CGFloat(2.0)

struct SmallGrayStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(Font.custom("Arial Rounded MT", size: 12))
            .foregroundColor(Color.gray)
    }
}

struct ParagraphStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(Font.custom("Arial Rounded MT", size: 14))
            .foregroundColor(Color.black)
    }
}

struct ParagraphStyleBold: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(Font.custom("Arial Rounded MT Bold", size: 14))
            .foregroundColor(Color.black)
    }
}

struct HeaderStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(Font.custom("Arial Rounded MT Bold", size: 36))
            .foregroundColor(Color.black)
    }
}

struct SubHeaderStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(Font.custom("Arial Rounded MT Bold", size: 24))
            .foregroundColor(Color.black)
    }
}

struct GrayUpperStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(Font.body.smallCaps())
            .font(Font.custom("Arial Rounded MT Bold", size: 24))
            .foregroundColor(Color.gray)
    }
}

struct WhiteUpperStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(Font.body.smallCaps())
            .font(Font.custom("Arial Rounded MT Bold", size: 24))
            .foregroundColor(Color.white)
    }
}

struct LabelStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(Font.custom("Arial Rounded MT", size: 18))
    }
}

struct ValueStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(Font.custom("Arial Rounded MT", size: 22))
    }
}

struct LinkStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(Font.custom("Arial Rounded MT Bold", size: 24))
            .foregroundColor(Color.blue)
    }
}

struct SmallLinkStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(Font.custom("Arial Rounded MT Bold", size: 18))
            .foregroundColor(Color.blue)
    }
}

struct LinkParagraphStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(Font.custom("Arial Rounded MT", size: 14))
            .foregroundColor(Color.blue)
    }
}

struct BlueButtonTextStyle: ViewModifier {
    func body(content: Content) -> some View {
        content.foregroundColor(.white)
        .padding(.leading, 65)
        .padding(.trailing, 65)
        .padding(.top, 10)
        .padding(.bottom, 10)
            .background(RoundedRectangle(cornerRadius: 5).fill(Color.blue))
        .compositingGroup()
        .font(.title)
    }
}

// This is used by buttons that manually toggle the foreground and background colors
// on top of the basic styles declared here
struct SmallButtonTextStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
        .padding(.leading, 5)
        .padding(.trailing, 5)
        .padding(.top, 5)
        .padding(.bottom, 5)
        .compositingGroup()
        .font(.body)
    }
}

struct BlueButtonStyle: ButtonStyle {
    var color: Color = .blue
    
    public func makeBody(configuration: BlueButtonStyle.Configuration) -> some View {
        
        configuration.label
            .foregroundColor(.white)
            .padding(.leading, 65)
            .padding(.trailing, 65)
            .padding(.top, 10)
            .padding(.bottom, 10)
            .background(RoundedRectangle(cornerRadius: 5).fill(color))
            .compositingGroup()
            .opacity(configuration.isPressed ? 0.5 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.8 : 1.0)
            .font(.title)
            
    }
}

struct TabLabelStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(Font.custom("Arial Rounded MT", size: 14))
            .foregroundColor(Color.gray)
    }
}

