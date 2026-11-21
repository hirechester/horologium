import XCTest
@testable import Horologium

final class DisplayPreferencesTests: XCTestCase {
    private let date = ISO8601DateFormatter().date(from: "2026-11-21T15:30:42Z")!
    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(secondsFromGMT: 0)!
        return c
    }
    private func title(_ preferences: Preferences) -> String {
        ClockText.menuTitle(date, preferences: preferences, calendar: calendar, locale: Locale(identifier: "en_US"))
    }

    func testIndependentMenuBarComponentsAndFallback() {
        var p = Preferences()
        p.showDate = false
        p.showDayOfWeek = false
        p.showTime = false
        XCTAssertEqual(title(p), "") // The status item displays a clock symbol for an empty title.
        p.showWeekNumber = true
        XCTAssertEqual(title(p), "W\(calendar.component(.weekOfYear, from: date))")
        p.showWeekNumber = false
        p.showDayOfWeek = true
        XCTAssertEqual(title(p), "Sat")
        p.showDayOfWeek = false
        p.showDate = true
        p.showMonth = false
        XCTAssertEqual(title(p), "21")
        p.showMonth = true
        XCTAssertEqual(title(p), "Nov 21")
    }

    func testMenuBarTimeSecondsAndAMPM() {
        var p = Preferences()
        p.showDate = false
        p.showDayOfWeek = false
        p.clockFormat = .twelveHour
        XCTAssertEqual(title(p), "3:30 PM")
        p.showSeconds = true
        XCTAssertEqual(title(p), "3:30:42 PM")
        p.showAMPM = false
        XCTAssertEqual(title(p), "3:30:42")
        p.clockFormat = .twentyFourHour
        p.showAMPM = true
        XCTAssertEqual(title(p), "15:30:42")
    }

    func testDefaultsAndOrderMigration() throws {
        let p = try JSONDecoder().decode(Preferences.self, from: Data("{}".utf8))
        XCTAssertEqual(p.weekStart, .system)
        XCTAssertEqual(p.clockFormat, .system)
        XCTAssertEqual(p.travelInterval, .thirty)
        XCTAssertEqual(p.sectionOrder, [.calendar, .timeTravel, .timeZones])
        let migrated = try JSONDecoder().decode(Preferences.self, from: Data(#"{"showDate":false,"sectionOrder":["timeZones","timeZones","calendar"]}"#.utf8))
        XCTAssertFalse(migrated.showDayOfWeek)
        XCTAssertEqual(migrated.sectionOrder, [.timeZones, .calendar, .timeTravel])
    }

    @MainActor func testWeekStartTravelIntervalAndLayoutPersistence() {
        let name = "HorologiumTests.\(UUID())"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let store = AppStore(defaults: defaults, clock: { self.date })
        XCTAssertEqual(store.engine.calendar.firstWeekday, Calendar.autoupdatingCurrent.firstWeekday)
        for start in WeekStart.allCases where start != .system {
            store.preferences.weekStart = start
            XCTAssertEqual(store.engine.calendar.firstWeekday, start.rawValue)
            let first = store.engine.monthDays(containing: date).first!
            XCTAssertEqual(store.engine.calendar.component(.weekday, from: first), start.rawValue)
        }
        store.preferences.travelInterval = .sixty
        store.preferences.sectionOrder = [.timeZones, .timeTravel, .calendar]
        store.preferences.showSeconds = true
        let restored = AppStore(defaults: defaults)
        XCTAssertEqual(restored.preferences, store.preferences)
        XCTAssertEqual(restored.engine.stepMinutes, 60)
    }

    func testIntervalsOnShortLongAndHalfHourDSTDays() {
        for minutes in [15, 30, 60] {
            var engine = TimeEngine(calendar: calendar, stepMinutes: minutes)
            engine.calendar.timeZone = TimeZone(identifier: "America/New_York")!
            let spring = ISO8601DateFormatter().date(from: "2026-03-08T12:00:00Z")!
            let fall = ISO8601DateFormatter().date(from: "2026-11-01T12:00:00Z")!
            XCTAssertEqual(engine.maximumStep(on: spring), Double(23 * 60 / minutes - 1))
            XCTAssertEqual(engine.maximumStep(on: fall), Double(25 * 60 / minutes - 1))
            let start = engine.dayInterval(for: spring).start
            XCTAssertEqual(engine.instant(on: spring, step: 1).timeIntervalSince(start), Double(minutes * 60))
            engine.calendar.timeZone = TimeZone(identifier: "Australia/Lord_Howe")!
            let halfHourDay = ISO8601DateFormatter().date(from: "2026-10-04T12:00:00Z")!
            let last = engine.instant(on: halfHourDay, step: engine.maximumStep(on: halfHourDay))
            XCTAssertLessThan(last, engine.dayInterval(for: halfHourDay).end)
            XCTAssertEqual(engine.maximumStep(on: halfHourDay).truncatingRemainder(dividingBy: 1), 0)
        }
    }
}
