import XCTest
@testable import Horologium

final class TimeEngineTests: XCTestCase {
    private func date(_ value: String) -> Date { ISO8601DateFormatter().date(from: value)! }
    private func engine(_ zone: String) -> TimeEngine {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: zone)!
        calendar.firstWeekday = 2
        return TimeEngine(calendar: calendar)
    }

    func testSpringForwardHas23HoursAndSkipsMissingHour() {
        let engine = engine("America/New_York")
        let day = date("2026-03-08T12:00:00Z")
        XCTAssertEqual(engine.dayInterval(for: day).duration, 23 * 3600)
        XCTAssertEqual(engine.maximumStep(on: day), 91)
        let afterJump = engine.instant(on: day, step: 8)
        XCTAssertEqual(engine.calendar.component(.hour, from: afterJump), 3)
    }

    func testFallBackHas25HoursAndDistinctRepeatedTimes() {
        let engine = engine("America/New_York")
        let day = date("2026-11-01T12:00:00Z")
        XCTAssertEqual(engine.maximumStep(on: day), 99)
        let first = engine.instant(on: day, step: 4)
        let second = engine.instant(on: day, step: 8)
        XCTAssertEqual(engine.calendar.component(.hour, from: first), 1)
        XCTAssertEqual(engine.calendar.component(.hour, from: second), 1)
        XCTAssertEqual(second.timeIntervalSince(first), 3600)
        XCTAssertNotEqual(ClockText.preview(first, format: .twentyFourHour, zone: engine.calendar.timeZone), ClockText.preview(second, format: .twentyFourHour, zone: engine.calendar.timeZone))
    }

    func testMissingLocalTimeResolvesWithinSelectedDay() {
        let engine = engine("America/New_York")
        let target = date("2026-03-08T12:00:00Z")
        let source = date("2026-03-07T07:30:00Z")
        let preview = engine.preview(on: target, preserving: source)
        XCTAssertTrue(engine.calendar.isDate(preview, inSameDayAs: target))
        XCTAssertEqual(engine.calendar.component(.hour, from: preview), 3)
    }

    func testFractionalOffsetAndDSTDifference() {
        let utc = TimeZone(secondsFromGMT: 0)!
        XCTAssertEqual(TimeEngine.offset(of: TimeZone(identifier: "Asia/Kathmandu")!, from: utc, at: date("2026-01-01T00:00:00Z")), "+5h 45m")
        let ny = TimeZone(identifier: "America/New_York")!
        let london = TimeZone(identifier: "Europe/London")!
        XCTAssertEqual(TimeEngine.offset(of: london, from: ny, at: date("2026-03-15T12:00:00Z")), "+4h")
        XCTAssertEqual(TimeEngine.offset(of: london, from: ny, at: date("2026-04-15T12:00:00Z")), "+5h")
    }

    func testLeapMonthAndWeekStart() {
        let engine = engine("UTC")
        let days = engine.monthDays(containing: date("2028-02-15T12:00:00Z"))
        XCTAssertEqual(days.count % 7, 0)
        XCTAssertEqual(engine.calendar.component(.weekday, from: days.first!), 2)
        XCTAssertTrue(days.contains { engine.calendar.component(.month, from: $0) == 2 && engine.calendar.component(.day, from: $0) == 29 })
    }

    func testInternationalDateBoundaryAndStepClamping() {
        let engine = engine("UTC")
        let instant = date("2026-12-31T23:45:00Z")
        var tokyo = engine.calendar
        tokyo.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        XCTAssertEqual(tokyo.component(.year, from: instant), 2027)
        XCTAssertEqual(engine.instant(on: instant, step: -1), engine.dayInterval(for: instant).start)
        XCTAssertLessThan(engine.instant(on: instant, step: 1000), engine.dayInterval(for: instant).end)
    }
}
