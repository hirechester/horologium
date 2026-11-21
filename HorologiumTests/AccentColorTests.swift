import AppKit
import XCTest
@testable import Horologium

final class AccentColorTests: XCTestCase {
    func testLegacySettingsFollowSystemAccent() throws {
        let preferences = try JSONDecoder().decode(Preferences.self, from: Data("{}".utf8))
        XCTAssertEqual(preferences.accentMode, .system)
        XCTAssertNil(preferences.customAccent)
        XCTAssertNil(preferences.appAccent)
    }

    @MainActor func testCustomAccentPersistsAndSystemModePreservesChoice() {
        let suite = "HorologiumTests.\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = AppStore(defaults: defaults)
        let color = SavedAccentColor(red: 0.65, green: 0.19, blue: 0.82)
        store.preferences.customAccent = color
        store.preferences.accentMode = .custom
        let restored = AppStore(defaults: defaults)
        XCTAssertEqual(restored.preferences.accentMode, .custom)
        XCTAssertEqual(restored.preferences.customAccent, color)
        XCTAssertNotNil(restored.preferences.appAccent)
        restored.preferences.accentMode = .system
        let system = AppStore(defaults: defaults)
        XCTAssertEqual(system.preferences.customAccent, color)
        XCTAssertNil(system.preferences.appAccent)
        system.preferences.accentMode = .custom
        XCTAssertNotNil(system.preferences.appAccent)
    }

    func testNativeColorRoundTripAndSelectionContrast() throws {
        let native = NSColor(srgbRed: 0.3, green: 0.5, blue: 0.7, alpha: 0.2)
        let saved = try XCTUnwrap(SavedAccentColor(nsColor: native))
        XCTAssertEqual(saved.red, 0.3, accuracy: 0.001)
        XCTAssertEqual(saved.green, 0.5, accuracy: 0.001)
        XCTAssertEqual(saved.blue, 0.7, accuracy: 0.001)
        XCTAssertEqual(saved.nsColor.alphaComponent, 1)
        XCTAssertEqual(try JSONDecoder().decode(SavedAccentColor.self, from: JSONEncoder().encode(saved)), saved)
        XCTAssertFalse(SavedAccentColor(red: 1, green: 1, blue: 0).usesLightForeground)
        XCTAssertTrue(SavedAccentColor(red: 0, green: 0, blue: 0).usesLightForeground)
    }
}
