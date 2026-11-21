import Combine
import Foundation

enum AppearanceMode: String, Codable, CaseIterable, Identifiable {
    case system, light, dark
    var id: Self { self }
    var title: String { rawValue.capitalized }
}

enum WeekStart: Int, Codable, CaseIterable, Identifiable {
    case system = 0, sunday, monday, tuesday, wednesday, thursday, friday, saturday
    var id: Self { self }
    var title: String { self == .system ? "System" : Calendar.autoupdatingCurrent.weekdaySymbols[rawValue - 1] }
}

enum TravelInterval: Int, Codable, CaseIterable, Identifiable {
    case fifteen = 15, thirty = 30, sixty = 60
    var id: Self { self }
    var title: String { "\(rawValue) minutes" }
}

enum DropdownSection: String, Codable, CaseIterable, Identifiable {
    case calendar, timeTravel, timeZones
    var id: Self { self }
    var title: String {
        switch self {
        case .calendar: "Calendar"
        case .timeTravel: "Time travel"
        case .timeZones: "Time zones"
        }
    }
}

struct Preferences: Codable, Equatable {
    var calendarIconOnly = false
    var showDate = true
    var showWeekNumber = false
    var showDayOfWeek = true
    var showMonth = true
    var showTime = true
    var showSeconds = false
    var showAMPM = true
    var clockFormat = ClockFormat.system
    var appearance = AppearanceMode.system
    var accentMode = AccentMode.system
    var customAccent: SavedAccentColor?
    var weekStart = WeekStart.system
    var travelInterval = TravelInterval.thirty
    var sectionOrder = DropdownSection.allCases

    init() {}
    private enum CodingKeys: String, CodingKey {
        case calendarIconOnly, showDate, showWeekNumber, showDayOfWeek, showMonth, showTime, showSeconds, showAMPM
        case clockFormat, appearance, accentMode, customAccent, weekStart, travelInterval, sectionOrder
    }
    init(from decoder: Decoder) throws {
        let v = try decoder.container(keyedBy: CodingKeys.self)
        calendarIconOnly = try v.decodeIfPresent(Bool.self, forKey: .calendarIconOnly) ?? false
        showDate = try v.decodeIfPresent(Bool.self, forKey: .showDate) ?? true
        showWeekNumber = try v.decodeIfPresent(Bool.self, forKey: .showWeekNumber) ?? false
        showDayOfWeek = try v.decodeIfPresent(Bool.self, forKey: .showDayOfWeek) ?? showDate
        showMonth = try v.decodeIfPresent(Bool.self, forKey: .showMonth) ?? true
        showTime = try v.decodeIfPresent(Bool.self, forKey: .showTime) ?? true
        showSeconds = try v.decodeIfPresent(Bool.self, forKey: .showSeconds) ?? false
        showAMPM = try v.decodeIfPresent(Bool.self, forKey: .showAMPM) ?? true
        clockFormat = try v.decodeIfPresent(ClockFormat.self, forKey: .clockFormat) ?? .system
        appearance = try v.decodeIfPresent(AppearanceMode.self, forKey: .appearance) ?? .system
        accentMode = try v.decodeIfPresent(AccentMode.self, forKey: .accentMode) ?? .system
        customAccent = try v.decodeIfPresent(SavedAccentColor.self, forKey: .customAccent)
        weekStart = try v.decodeIfPresent(WeekStart.self, forKey: .weekStart) ?? .system
        travelInterval = try v.decodeIfPresent(TravelInterval.self, forKey: .travelInterval) ?? .thirty
        let order = try v.decodeIfPresent([DropdownSection].self, forKey: .sectionOrder) ?? DropdownSection.allCases
        sectionOrder = []
        for section in order + DropdownSection.allCases where !sectionOrder.contains(section) { sectionOrder.append(section) }
        if calendarIconOnly { setCalendarIconOnly(true) }
    }

    mutating func setCalendarIconOnly(_ enabled: Bool) {
        calendarIconOnly = enabled
        showWeekNumber = false
        showDayOfWeek = !enabled
        showDate = !enabled
        showMonth = !enabled
        showTime = !enabled
        showSeconds = false
        showAMPM = !enabled
    }

}

@MainActor
final class AppStore: ObservableObject {
    @Published var locations: [SavedLocation] { didSet { save() } }
    @Published var preferences: Preferences { didSet { save() } }
    @Published var now: Date
    @Published var previewDate: Date?
    @Published var month: Date
    @Published var storageWarning: String?
    private var applyingImport = false
    private let defaults: UserDefaults
    private let clock: () -> Date
    var engine: TimeEngine {
        var calendar = Calendar.autoupdatingCurrent
        if preferences.weekStart != .system { calendar.firstWeekday = preferences.weekStart.rawValue }
        return TimeEngine(calendar: calendar, now: clock, stepMinutes: preferences.travelInterval.rawValue)
    }
    var displayedDate: Date { previewDate ?? now }
    var selectedDate: Date { previewDate ?? now }
    var menuTitle: String { ClockText.menuTitle(now, preferences: preferences) }

    private struct State: Codable {
        var version = 1
        var locations: [SavedLocation]
        var preferences: Preferences
    }

    init(defaults: UserDefaults = .standard, clock: @escaping () -> Date = Date.init) {
        self.defaults = defaults
        self.clock = clock
        let now = clock()
        self.now = now
        self.month = now
        if let data = defaults.data(forKey: "horologium.state") {
            do {
                let state = try JSONDecoder().decode(State.self, from: data)
                guard state.version == 1 else { throw CocoaError(.coderReadCorrupt) }
                locations = state.locations
                preferences = state.preferences
            } catch {
                // Preserve the original payload for recovery before a later edit saves fresh settings.
                defaults.set(data, forKey: "horologium.recovery")
                locations = []
                preferences = Preferences()
                storageWarning = "Saved settings could not be read. A recovery copy was kept locally."
            }
        } else {
            locations = []
            preferences = Preferences()
        }
    }

    func refresh() {
        let previous = now
        now = clock()
        if previewDate == nil && !engine.calendar.isDate(previous, inSameDayAs: now) { month = now }
    }

    func returnToNow() {
        refresh()
        previewDate = nil
        month = now
    }

    func select(_ day: Date) {
        previewDate = engine.preview(on: day, preserving: displayedDate)
        month = day
    }

    func travel(step: Double) {
        previewDate = engine.instant(on: selectedDate, step: step)
    }

    func shiftMonth(_ amount: Int) {
        if let date = engine.calendar.date(byAdding: .month, value: amount, to: month) { month = date }
    }

    func moveSelection(days: Int) {
        if let day = engine.calendar.date(byAdding: .day, value: days, to: selectedDate) { select(day) }
    }

    func add(_ location: SavedLocation) {
        locations.append(location)
    }

    func exportSettings() throws -> Data {
        try SettingsArchive(locations: locations, preferences: preferences, exportedAt: clock()).encoded()
    }

    func importSettings(from data: Data) throws {
        try importSettings(SettingsArchive.decode(data))
    }

    func importSettings(_ archive: SettingsArchive) throws {
        try archive.validate()
        // Encode and validate everything before changing either the stored or visible state.
        let data = try JSONEncoder().encode(State(locations: archive.locations, preferences: archive.preferences))
        if let previous = defaults.data(forKey: "horologium.state") {
            defaults.set(previous, forKey: "horologium.beforeImport")
        }
        defaults.set(data, forKey: "horologium.state")
        applyingImport = true
        locations = archive.locations
        preferences = archive.preferences
        applyingImport = false
        storageWarning = nil
        returnToNow()
    }

    private func save() {
        guard !applyingImport else { return }
        do {
            let data = try JSONEncoder().encode(State(locations: locations, preferences: preferences))
            defaults.set(data, forKey: "horologium.state")
        } catch {
            storageWarning = "Settings could not be saved: \(error.localizedDescription)"
        }
    }
}
