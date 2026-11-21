import XCTest
@testable import Horologium

final class StoreAndSearchTests: XCTestCase {
    func testAccentSearchRankingAndDisambiguation() {
        let catalog = CityCatalog(cities: [
            City(id: 1, name: "Paris", region: "Texas", country: "US", timeZoneID: "America/Chicago", population: 25000, aliases: ""),
            City(id: 2, name: "Paris", region: "Île-de-France", country: "FR", timeZoneID: "Europe/Paris", population: 2000000, aliases: ""),
            City(id: 3, name: "São Paulo", region: "São Paulo", country: "BR", timeZoneID: "America/Sao_Paulo", population: 12000000, aliases: "Sampa")
        ])
        XCTAssertEqual(catalog.search("Paris").map(\.id), [2, 1])
        XCTAssertEqual(catalog.search("paris texas").map(\.id), [1])
        XCTAssertEqual(catalog.search("sao").map(\.id), [3])
        XCTAssertEqual(catalog.search("Sampa").map(\.id), [3])
        XCTAssertTrue(catalog.search("not a city").isEmpty)
    }

    func testBundledCatalogAndTimeZoneCoverage() throws {
        let catalog = try CityCatalog.bundled()
        XCTAssertGreaterThan(catalog.cities.count, 30000)
        XCTAssertTrue(catalog.search("London United Kingdom").contains { $0.timeZoneID == "Europe/London" })
        XCTAssertTrue(catalog.search("Tokyo Japan").contains { $0.timeZoneID == "Asia/Tokyo" })
        for identifier in Set(catalog.cities.map(\.timeZoneID)) {
            XCTAssertNotNil(TimeZone(identifier: identifier), "Unsupported bundled time zone: \(identifier)")
        }
    }

    @MainActor func testPersistenceReorderEditsAndTransientPreview() {
        let name = "HorologiumTests.\(UUID())"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let now = Date(timeIntervalSince1970: 1795000000)
        let store = AppStore(defaults: defaults, clock: { now })
        store.add(SavedLocation(label: "Colleague", detail: "London", timeZoneID: "Europe/London"))
        store.add(SavedLocation(label: "Tokyo", detail: "Japan", timeZoneID: "Asia/Tokyo"))
        store.locations.swapAt(0, 1)
        store.locations[0].label = "Japan office"
        store.preferences.clockFormat = .twentyFourHour
        store.preferences.showDate = false
        store.select(now.addingTimeInterval(86400))
        XCTAssertNotNil(store.previewDate)
        let restored = AppStore(defaults: defaults, clock: { now })
        XCTAssertEqual(restored.locations, store.locations)
        XCTAssertEqual(restored.preferences, store.preferences)
        XCTAssertNil(restored.previewDate)
        store.returnToNow()
        XCTAssertEqual(store.displayedDate, now)
        XCTAssertNil(store.previewDate)
    }

    @MainActor func testCorruptSettingsKeepRecoveryCopy() {
        let name = "HorologiumTests.\(UUID())"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let data = Data("broken".utf8)
        defaults.set(data, forKey: "horologium.state")
        let store = AppStore(defaults: defaults)
        XCTAssertTrue(store.locations.isEmpty)
        XCTAssertNotNil(store.storageWarning)
        XCTAssertEqual(defaults.data(forKey: "horologium.recovery"), data)
    }

    @MainActor func testInjectedClockRefresh() {
        let name = "HorologiumTests.\(UUID())"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        var now = Date(timeIntervalSince1970: 1795000000)
        let store = AppStore(defaults: defaults, clock: { now })
        now = now.addingTimeInterval(3600)
        store.refresh()
        XCTAssertEqual(store.now, now)
    }
}
