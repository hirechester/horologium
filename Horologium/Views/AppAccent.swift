import AppKit
import SwiftUI

extension SavedAccentColor {
    init?(nsColor: NSColor) {
        guard let color = nsColor.usingColorSpace(.sRGB) else { return nil }
        red = min(max(Double(color.redComponent), 0), 1)
        green = min(max(Double(color.greenComponent), 0), 1)
        blue = min(max(Double(color.blueComponent), 0), 1)
    }

    var color: Color { Color(.sRGB, red: red, green: green, blue: blue, opacity: 1) }
    var nsColor: NSColor { NSColor(srgbRed: red, green: green, blue: blue, alpha: 1) }
}

extension Preferences {
    var appAccent: Color? { accentMode == .custom ? customAccent?.color : nil }
    var calendarSelectionForeground: Color {
        guard accentMode == .custom, let customAccent else { return .white }
        return customAccent.usesLightForeground ? .white : .black
    }
}

struct AppAccent: ViewModifier {
    let preferences: Preferences
    func body(content: Content) -> some View {
        content
            .tint(preferences.appAccent ?? Color(nsColor: .controlAccentColor))
            .accentColor(preferences.appAccent)
    }
}
