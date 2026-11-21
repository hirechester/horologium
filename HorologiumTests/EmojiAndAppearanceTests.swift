import XCTest
@testable import Horologium

final class EmojiAndAppearanceTests: XCTestCase {
    func testNativeEmojiSearchAndFlagPriority() throws {
        let catalog = try EmojiCatalog.bundled()
        XCTAssertGreaterThan(catalog.entries.count, 3000)
        let firstNonFlag = try XCTUnwrap(catalog.entries.firstIndex { !$0.isCountryFlag })
        XCTAssertGreaterThan(firstNonFlag, 200)
        XCTAssertFalse(catalog.entries.dropFirst(firstNonFlag).contains(where: \.isCountryFlag))
        XCTAssertTrue(catalog.search("united kingdom").contains { $0.glyph == "🇬🇧" })
        XCTAssertTrue(catalog.search("usa").contains { $0.glyph == "🇺🇸" })
        XCTAssertTrue(catalog.search("coffee").contains { $0.glyph == "☕" })
        XCTAssertTrue(catalog.search("japan", category: "Country flags").allSatisfy(\.isCountryFlag))
        XCTAssertTrue(catalog.search("🇯🇵").contains { $0.glyph == "🇯🇵" })
    }

    func testLegacyPreferencesAndLocationsStillDecode() throws {
        let preferences = try JSONDecoder().decode(Preferences.self, from: Data(#"{"showDate":false,"clockFormat":"twentyFourHour"}"#.utf8))
        XCTAssertEqual(preferences.appearance, .system)
        XCTAssertFalse(preferences.showDate)
        let json = #"{"id":"67A90164-A54C-4D1B-8BC1-DA748C15A620","label":"London","detail":"United Kingdom","timeZoneID":"Europe/London"}"#
        let location = try JSONDecoder().decode(SavedLocation.self, from: Data(json.utf8))
        XCTAssertNil(location.emoji)
        XCTAssertEqual(location.displayLabel, "London")
    }

    @MainActor func testEmojiLabelAndAppearancePersist() throws {
        let suite = "HorologiumTests.\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = AppStore(defaults: defaults)
        store.add(SavedLocation(label: "Alex", detail: "United Kingdom", timeZoneID: "Europe/London", emoji: "🇬🇧", sourceName: "London"))
        store.preferences.appearance = .dark
        let restored = AppStore(defaults: defaults)
        XCTAssertEqual(restored.locations[0].displayLabel, "🇬🇧 Alex")
        XCTAssertEqual(restored.locations[0].sourceName, "London")
        XCTAssertEqual(restored.preferences.appearance, .dark)
        restored.locations[0].emoji = nil
        restored.preferences.appearance = .light
        let light = AppStore(defaults: defaults)
        XCTAssertNil(light.locations[0].emoji)
        XCTAssertEqual(light.preferences.appearance, .light)
    }
}
