import Combine
import Foundation

enum AppearanceMode: String, Codable, CaseIterable, Identifiable {
    case system, light, dark
    var id: Self { self }
    var title: String { rawValue.capitalized }
}

struct Preferences: Codable, Equatable {
    var showDate = true
    var clockFormat = ClockFormat.system
    var appearance = AppearanceMode.system

    init() {}
    private enum CodingKeys: String, CodingKey { case showDate, clockFormat, appearance }
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        showDate = try values.decodeIfPresent(Bool.self, forKey: .showDate) ?? true
        clockFormat = try values.decodeIfPresent(ClockFormat.self, forKey: .clockFormat) ?? .system
        appearance = try values.decodeIfPresent(AppearanceMode.self, forKey: .appearance) ?? .system
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
    private let defaults: UserDefaults
    private let clock: () -> Date
    var engine: TimeEngine { TimeEngine(now: clock) }
    var displayedDate: Date { previewDate ?? now }
    var selectedDate: Date { previewDate ?? now }
    var menuTitle: String {
        let time = ClockText.time(now, format: preferences.clockFormat)
        return preferences.showDate ? "\(ClockText.date(now, template: "EEE MMM d"))  \(time)" : time
    }

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

    private func save() {
        do {
            let data = try JSONEncoder().encode(State(locations: locations, preferences: preferences))
            defaults.set(data, forKey: "horologium.state")
        } catch {
            storageWarning = "Settings could not be saved: \(error.localizedDescription)"
        }
    }
}
