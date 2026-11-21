import Foundation

enum AccentMode: String, Codable, CaseIterable, Identifiable {
    case system, custom
    var id: Self { self }
    var title: String { rawValue.capitalized }
}

/// Opaque sRGB components keep the user's color independent of appearance and device color space.
struct SavedAccentColor: Codable, Equatable {
    var red: Double
    var green: Double
    var blue: Double

    var usesLightForeground: Bool {
        func linear(_ component: Double) -> Double {
            component <= 0.04045 ? component / 12.92 : pow((component + 0.055) / 1.055, 2.4)
        }
        let luminance = 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
        return luminance < 0.179
    }
}
