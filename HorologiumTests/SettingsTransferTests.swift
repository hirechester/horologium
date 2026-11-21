import XCTest
@testable import Horologium

final class SettingsTransferTests: XCTestCase {
    private func location(_ label: String = "London office") -> SavedLocation {
        SavedLocation(label: label, detail: "United Kingdom", timeZoneID: "Europe/London", emoji: "🇬🇧", sourceName: "London")
    }

    private func modify(_ data: Data, _ transform: (inout [String: Any]) -> Void) throws -> Data {
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        transform(&json)
        return try JSONSerialization.data(withJSONObject: json)
    }

    @MainActor func testRoundTripRestoresAllPortableSettingsAndLocationOrder() throws {
        let sourceName = "HorologiumTests.\(UUID())"
        let targetName = "HorologiumTests.\(UUID())"
        let sourceDefaults = UserDefaults(suiteName: sourceName)!
        let targetDefaults = UserDefaults(suiteName: targetName)!
        defer {
            sourceDefaults.removePersistentDomain(forName: sourceName)
            targetDefaults.removePersistentDomain(forName: targetName)
        }
        let source = AppStore(defaults: sourceDefaults)
        source.locations = [location("Alice"), SavedLocation(label: "Tokyo", detail: "Japan", timeZoneID: "Asia/Tokyo", emoji: "🇯🇵", sourceName: "Tokyo")]
        var p = Preferences()
        p.showWeekNumber = true
        p.showDate = false
        p.showMonth = false
        p.showDayOfWeek = false
        p.showTime = true
        p.showSeconds = true
        p.showAMPM = false
        p.clockFormat = .twentyFourHour
        p.appearance = .dark
        p.accentMode = .custom
        p.customAccent = SavedAccentColor(red: 0.2, green: 0.6, blue: 0.3)
        p.weekStart = .monday
        p.travelInterval = .sixty
        p.sectionOrder = [.timeZones, .timeTravel, .calendar]
        source.preferences = p
        let data = try source.exportSettings()
        XCTAssertTrue(String(decoding: data, as: UTF8.self).contains("\n"))
        let archive = try SettingsArchive.decode(data)
        XCTAssertEqual(archive.locations, source.locations)
        XCTAssertEqual(archive.preferences, p)
        let target = AppStore(defaults: targetDefaults)
        target.add(location("Existing location"))
        let previous = try XCTUnwrap(targetDefaults.data(forKey: "horologium.state"))
        target.select(Date().addingTimeInterval(86400))
        try target.importSettings(archive)
        XCTAssertEqual(target.locations, source.locations)
        XCTAssertEqual(target.preferences, p)
        XCTAssertNil(target.previewDate)
        XCTAssertEqual(targetDefaults.data(forKey: "horologium.beforeImport"), previous)
        let restored = AppStore(defaults: targetDefaults)
        XCTAssertEqual(restored.locations, source.locations)
        XCTAssertEqual(restored.preferences, p)
    }

    func testLegacyVersionOneFixtureUsesDefaultsForNewerPreferences() throws {
        // Keep this fixture unchanged as future settings are added.
        let json = #"{"format":"app.ardens.horologium.settings","formatVersion":1,"locations":[{"id":"67A90164-A54C-4D1B-8BC1-DA748C15A620","label":"London","detail":"United Kingdom","timeZoneID":"Europe/London"}],"preferences":{"showDate":false,"clockFormat":"twelveHour"}}"#
        let archive = try SettingsArchive.decode(Data(json.utf8))
        XCTAssertEqual(archive.locations[0].label, "London")
        XCTAssertNil(archive.locations[0].emoji)
        XCTAssertEqual(archive.preferences.clockFormat, .twelveHour)
        XCTAssertFalse(archive.preferences.showDate)
        XCTAssertEqual(archive.preferences.accentMode, .system)
        XCTAssertEqual(archive.preferences.travelInterval, .thirty)
        XCTAssertEqual(archive.preferences.sectionOrder, DropdownSection.allCases)
    }

    @MainActor func testInvalidFilesDoNotChangeCurrentSettingsOrRecoveryCopy() throws {
        let suite = "HorologiumTests.\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = AppStore(defaults: defaults)
        store.add(location())
        let before = defaults.data(forKey: "horologium.state")
        let originalLocations = store.locations
        let originalPreferences = store.preferences
        let valid = try store.exportSettings()
        let invalidFiles = try [
            Data("not JSON".utf8),
            modify(valid) { $0["format"] = "some.other.app" },
            modify(valid) { $0["formatVersion"] = 99; $0.removeValue(forKey: "preferences") },
            modify(valid) { $0.removeValue(forKey: "locations") },
            modify(valid) { json in
                var rows = json["locations"] as! [[String: Any]]
                rows[0]["timeZoneID"] = "Mars/Olympus"
                json["locations"] = rows
            },
            modify(valid) { json in
                let rows = json["locations"] as! [[String: Any]]
                json["locations"] = rows + rows
            },
            modify(valid) { json in
                var prefs = json["preferences"] as! [String: Any]
                prefs["customAccent"] = ["red": 2.0, "green": 0.0, "blue": 0.0]
                json["preferences"] = prefs
            }
        ]
        for data in invalidFiles {
            XCTAssertThrowsError(try store.importSettings(from: data))
            XCTAssertEqual(store.locations, originalLocations)
            XCTAssertEqual(store.preferences, originalPreferences)
            XCTAssertEqual(defaults.data(forKey: "horologium.state"), before)
            XCTAssertNil(defaults.data(forKey: "horologium.beforeImport"))
        }
        XCTAssertThrowsError(try SettingsArchive.decode(try modify(valid) { $0["formatVersion"] = 99 })) {
            XCTAssertEqual($0 as? SettingsTransferError, .unsupportedVersion(99))
        }
    }

    @MainActor func testEmptyArchiveReplacesRatherThanMergesAndIconModeSurvives() throws {
        let suite = "HorologiumTests.\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = AppStore(defaults: defaults)
        store.add(location())
        var preferences = Preferences()
        preferences.setCalendarIconOnly(true)
        let data = try SettingsArchive(locations: [], preferences: preferences).encoded()
        try store.importSettings(from: data)
        XCTAssertTrue(store.locations.isEmpty)
        XCTAssertTrue(store.preferences.calendarIconOnly)
        XCTAssertEqual(store.menuTitle, "🗓️")
        try store.importSettings(from: data)
        XCTAssertTrue(store.locations.isEmpty)
    }

    @MainActor func testPreparingImportDoesNotApplyAndOversizedFilesAreRejected() throws {
        let suite = "HorologiumTests.\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = AppStore(defaults: defaults)
        store.add(location("Keep me"))
        let candidate = try SettingsArchive(locations: [], preferences: Preferences()).encoded()
        _ = try SettingsArchive.decode(candidate)
        XCTAssertEqual(store.locations[0].label, "Keep me")
        let oversized = Data(repeating: 32, count: SettingsArchive.maximumFileSize + 1)
        XCTAssertThrowsError(try store.importSettings(from: oversized)) {
            XCTAssertEqual($0 as? SettingsTransferError, .tooLarge)
        }
        XCTAssertEqual(store.locations[0].label, "Keep me")
    }
}
