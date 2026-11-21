import Foundation

struct EmojiEntry: Codable, Identifiable, Sendable {
    let glyph: String
    let name: String
    let group: String
    let subgroup: String
    let aliases: String
    var id: String { glyph }
    var isCountryFlag: Bool { subgroup == "country-flag" || subgroup == "subdivision-flag" }
}

struct EmojiCatalog: Sendable {
    let entries: [EmojiEntry]
    private let searchKeys: [String]

    init(entries: [EmojiEntry]) {
        // Preserve Unicode's order within each section, promoting country flags.
        self.entries = entries.filter(\.isCountryFlag) + entries.filter { !$0.isCountryFlag }
        self.searchKeys = self.entries.map { Self.normalize("\($0.glyph) \($0.name) \($0.group) \($0.subgroup) \($0.aliases)") }
    }

    static func bundled() throws -> EmojiCatalog {
        guard let url = Bundle.main.url(forResource: "Emoji", withExtension: "json") else { throw CocoaError(.fileNoSuchFile) }
        return EmojiCatalog(entries: try JSONDecoder().decode([EmojiEntry].self, from: Data(contentsOf: url)))
    }

    func search(_ query: String, category: String = "All emoji") -> [EmojiEntry] {
        let terms = Self.normalize(query).split(separator: " ").map(String.init)
        return entries.indices.filter { index in
            let entry = entries[index]
            let categoryMatches = category == "All emoji" || (category == "Country flags" ? entry.isCountryFlag : entry.group == category)
            return categoryMatches && terms.allSatisfy { searchKeys[index].contains($0) }
        }.map { entries[$0] }
    }

    private static func normalize(_ value: String) -> String {
        value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
    }
}
