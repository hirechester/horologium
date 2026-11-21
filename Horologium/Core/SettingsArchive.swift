import Foundation

struct SettingsArchive: Codable {
    static let currentFormat = "app.ardens.horologium.settings"
    static let currentVersion = 1
    static let maximumFileSize = 2 * 1024 * 1024

    let format: String
    let formatVersion: Int
    let appVersion: String?
    let appBuild: String?
    let exportedAt: Date?
    let locations: [SavedLocation]
    let preferences: Preferences

    init(locations: [SavedLocation], preferences: Preferences, exportedAt: Date = Date()) {
        format = Self.currentFormat
        formatVersion = Self.currentVersion
        appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        appBuild = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        self.exportedAt = exportedAt
        self.locations = locations
        self.preferences = preferences
    }

    func encoded() throws -> Data {
        try validate()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(self)
        guard data.count <= Self.maximumFileSize else { throw SettingsTransferError.tooLarge }
        return data
    }

    static func decode(_ data: Data) throws -> SettingsArchive {
        guard data.count <= maximumFileSize else { throw SettingsTransferError.tooLarge }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        // Read the header first so future formats get an actionable error even if their payload changes.
        struct Header: Decodable { let format: String; let formatVersion: Int }
        guard let header = try? decoder.decode(Header.self, from: data) else { throw SettingsTransferError.invalidFile }
        guard header.format == currentFormat else { throw SettingsTransferError.invalidFile }
        guard header.formatVersion == currentVersion else { throw SettingsTransferError.unsupportedVersion(header.formatVersion) }
        let archive: SettingsArchive
        do { archive = try decoder.decode(SettingsArchive.self, from: data) }
        catch { throw SettingsTransferError.invalidFile }
        try archive.validate()
        return archive
    }

    func validate() throws {
        guard format == Self.currentFormat else { throw SettingsTransferError.invalidFile }
        guard formatVersion == Self.currentVersion else { throw SettingsTransferError.unsupportedVersion(formatVersion) }
        guard Set(locations.map(\.id)).count == locations.count else { throw SettingsTransferError.duplicateLocations }
        for location in locations {
            guard !location.label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw SettingsTransferError.emptyLocationLabel
            }
            guard location.timeZone != nil else { throw SettingsTransferError.invalidTimeZone(location.timeZoneID) }
        }
        if let color = preferences.customAccent {
            guard [color.red, color.green, color.blue].allSatisfy({ $0.isFinite && (0...1).contains($0) }) else {
                throw SettingsTransferError.invalidAccent
            }
        }
    }
}

enum SettingsTransferError: LocalizedError, Equatable {
    case invalidFile, tooLarge, duplicateLocations, emptyLocationLabel, invalidAccent
    case unsupportedVersion(Int)
    case invalidTimeZone(String)

    var errorDescription: String? {
        switch self {
        case .invalidFile: "Choose a valid Horologium settings JSON file. Your current settings have not changed."
        case .tooLarge: "Settings files must be 2 MB or smaller."
        case .duplicateLocations: "This file contains duplicate location identifiers. Your current settings have not changed."
        case .emptyLocationLabel: "Each imported location must have a name."
        case .invalidAccent: "The custom accent color in this file is invalid."
        case .unsupportedVersion(let version): "This file uses settings format \(version). This version of Horologium supports format 1. Try updating Horologium."
        case .invalidTimeZone(let identifier): "This Mac does not recognize the time zone “\(identifier)”. Your current settings have not changed."
        }
    }
}
