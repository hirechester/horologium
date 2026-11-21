import Foundation

struct TimeEngine {
    var calendar: Calendar = .autoupdatingCurrent
    var now: () -> Date = Date.init

    func dayInterval(for date: Date) -> DateInterval {
        calendar.dateInterval(of: .day, for: date)!
    }

    func preview(on day: Date, preserving time: Date) -> Date {
        let components = calendar.dateComponents([.hour, .minute], from: time)
        return calendar.date(bySettingHour: components.hour!, minute: components.minute!, second: 0,
                             of: day, matchingPolicy: .nextTime, repeatedTimePolicy: .first)!
    }

    func instant(on day: Date, step: Double) -> Date {
        let interval = dayInterval(for: day)
        return interval.start.addingTimeInterval(min(max(step.rounded(), 0), maximumStep(on: day)) * 900)
    }

    func maximumStep(on day: Date) -> Double {
        (dayInterval(for: day).duration / 900) - 1
    }

    func step(for date: Date) -> Double {
        date.timeIntervalSince(dayInterval(for: date).start) / 900
    }

    func monthDays(containing date: Date) -> [Date] {
        let start = calendar.dateInterval(of: .month, for: date)!.start
        let padding = (calendar.component(.weekday, from: start) - calendar.firstWeekday + 7) % 7
        let count = calendar.range(of: .day, in: .month, for: date)!.count
        let cells = ((padding + count + 6) / 7) * 7
        return (0..<cells).map { calendar.date(byAdding: .day, value: $0 - padding, to: start)! }
    }

    static func offset(of zone: TimeZone, from local: TimeZone, at date: Date) -> String {
        let minutes = (zone.secondsFromGMT(for: date) - local.secondsFromGMT(for: date)) / 60
        if minutes == 0 { return "Same time" }
        let sign = minutes > 0 ? "+" : "−"
        let absolute = abs(minutes)
        return absolute % 60 == 0 ? "\(sign)\(absolute / 60)h" : "\(sign)\(absolute / 60)h \(absolute % 60)m"
    }
}

enum ClockFormat: String, Codable, CaseIterable, Identifiable {
    case system, twelveHour, twentyFourHour
    var id: Self { self }
    var title: String {
        switch self {
        case .system: "System"
        case .twelveHour: "12-hour"
        case .twentyFourHour: "24-hour"
        }
    }
}

enum ClockText {
    static func time(_ date: Date, zone: TimeZone = .autoupdatingCurrent, format: ClockFormat) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = zone
        switch format {
        case .system: formatter.timeStyle = .short
        case .twelveHour: formatter.dateFormat = "h:mm a"
        case .twentyFourHour: formatter.dateFormat = "HH:mm"
        }
        return formatter.string(from: date)
    }

    static func date(_ date: Date, zone: TimeZone = .autoupdatingCurrent, template: String = "EEE MMM d") -> String {
        let formatter = DateFormatter()
        formatter.timeZone = zone
        formatter.setLocalizedDateFormatFromTemplate(template)
        return formatter.string(from: date)
    }

    static func preview(_ date: Date, format: ClockFormat, zone: TimeZone = .autoupdatingCurrent) -> String {
        let offset = zone.secondsFromGMT(for: date)
        let sign = offset < 0 ? "−" : "+"
        let absolute = abs(offset) / 60
        let gmt = String(format: "GMT%@%02d:%02d", sign, absolute / 60, absolute % 60)
        return "\(time(date, zone: zone, format: format)) · \(zone.abbreviation(for: date) ?? zone.identifier) · \(gmt)"
    }
}
