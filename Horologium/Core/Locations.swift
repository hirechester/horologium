import Foundation

struct SavedLocation: Codable, Identifiable, Equatable, Sendable {
    var id = UUID()
    var label: String
    var detail: String
    var timeZoneID: String
    var emoji: String? = nil
    var sourceName: String? = nil
    var displayLabel: String { [emoji, label].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " ") }
    var timeZoneDisplayName: String { Self.displayTimeZone(timeZoneID) }
    static func displayTimeZone(_ identifier: String) -> String { identifier.replacingOccurrences(of: "_", with: " ") }
    var timeZone: TimeZone? { TimeZone(identifier: timeZoneID) }
}

struct City: Codable, Identifiable, Sendable {
    let id: Int
    let name: String
    let region: String
    let country: String
    let timeZoneID: String
    let population: Int
    let aliases: String
    var countryName: String { Locale(identifier: "en").localizedString(forRegionCode: country) ?? country }
    var detail: String { [region, countryName].filter { !$0.isEmpty }.joined(separator: ", ") }
    var location: SavedLocation { SavedLocation(label: name, detail: detail, timeZoneID: timeZoneID, sourceName: name) }
}

struct CityCatalog: Sendable {
    let cities: [City]
    private let searchKeys: [String]

    init(cities: [City]) {
        self.cities = cities.sorted { $0.population > $1.population }
        self.searchKeys = self.cities.map {
            Self.normalize("\($0.name) \($0.region) \($0.country) \($0.countryName) \($0.aliases)")
        }
    }

    static func bundled() throws -> CityCatalog {
        guard let url = Bundle.main.url(forResource: "Cities", withExtension: "json") else {
            throw CocoaError(.fileNoSuchFile)
        }
        return CityCatalog(cities: try JSONDecoder().decode([City].self, from: Data(contentsOf: url)))
    }

    func search(_ query: String, limit: Int = 60) -> [City] {
        let terms = Self.normalize(query).split(separator: " ").map(String.init)
        guard !terms.isEmpty else { return Array(cities.prefix(limit)) }
        let matching = cities.indices.filter { index in terms.allSatisfy { searchKeys[index].contains($0) } }
        let normalized = Self.normalize(query)
        let ranked = matching.sorted {
            let left = Self.normalize(cities[$0].name)
            let right = Self.normalize(cities[$1].name)
            let leftRank = left == normalized ? 0 : (left.hasPrefix(normalized) ? 1 : 2)
            let rightRank = right == normalized ? 0 : (right.hasPrefix(normalized) ? 1 : 2)
            return leftRank == rightRank ? cities[$0].population > cities[$1].population : leftRank < rightRank
        }
        return ranked.prefix(limit).map { cities[$0] }
    }

    private static func normalize(_ value: String) -> String {
        value.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
    }
}
