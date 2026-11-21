import SwiftUI

private actor CitySearchService {
    static let shared = CitySearchService()
    private var catalog: CityCatalog?
    func search(_ query: String) throws -> [City] {
        if catalog == nil { catalog = try CityCatalog.bundled() }
        return catalog!.search(query)
    }
}

struct LocationEditor: View {
    let existing: SavedLocation?
    var onSave: (SavedLocation) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var emoji: String?
    @State private var showingEmojiPicker = false
    @State private var mode = 0
    @State private var query = ""
    @State private var label: String
    @State private var chosen: SavedLocation?
    @State private var results: [City] = []
    @State private var loading = false
    @State private var error: String?

    init(existing: SavedLocation?, initialCities: [City] = [], onSave: @escaping (SavedLocation) -> Void) {
        self.existing = existing
        _results = State(initialValue: initialCities)
        self.onSave = onSave
        _label = State(initialValue: existing?.label == existing?.sourceName ? "" : (existing?.label ?? ""))
        _emoji = State(initialValue: existing?.emoji)
        _chosen = State(initialValue: existing)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(existing == nil ? "Add Location" : "Edit Location").font(.title2.weight(.semibold))
            Text("Find a city, then name it for a place or a person.").font(.subheadline).foregroundStyle(.secondary)
            Picker("Location source", selection: $mode) {
                Text("City search").tag(0)
                Text("Time zone").tag(1)
            }.pickerStyle(.segmented)
            TextField(mode == 0 ? "Search cities, regions, or countries" : "Search time zones", text: $query)
                .textFieldStyle(.roundedBorder).accessibilityLabel("Search locations")
            Group {
                if mode == 0 {
                    List(results) { city in
                        resultButton(name: city.name, detail: city.detail, zoneID: city.timeZoneID,
                                     selected: chosen?.timeZoneID == city.timeZoneID && chosen?.detail == city.detail && chosen?.label == city.name) {
                            chosen = city.location
                        }
                    }
                    .overlay {
                        if loading { ProgressView() }
                        else if let error {
                            ContentUnavailableView("City catalog unavailable", systemImage: "exclamationmark.triangle",
                                                   description: Text(error + " Use the Time zone tab instead."))
                        } else if results.isEmpty {
                            ContentUnavailableView.search(text: query)
                        }
                    }
                } else {
                    List(manualZones, id: \.self) { zoneID in
                        resultButton(name: zoneID.replacingOccurrences(of: "_", with: " "), detail: "", zoneID: zoneID,
                                     selected: chosen?.timeZoneID == zoneID) {
                            chosen = SavedLocation(label: zoneID.components(separatedBy: "/").last!.replacingOccurrences(of: "_", with: " "),
                                                   detail: "Custom time zone", timeZoneID: zoneID, sourceName: zoneID.components(separatedBy: "/").last!.replacingOccurrences(of: "_", with: " "))
                        }
                    }
                }
            }.frame(height: 230).clipShape(RoundedRectangle(cornerRadius: 8))
            if let chosen {
                Text("Selected: \(chosen.label) · \(chosen.timeZoneDisplayName)")
                    .font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Emoji").font(.caption).foregroundStyle(.secondary)
                    Button { showingEmojiPicker = true } label: {
                        Text(emoji ?? "＋").font(.system(size: 20)).frame(width: 48, height: 32)
                    }
                    .buttonStyle(.plain)
                    .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(.secondary.opacity(0.25)))
                    .accessibilityLabel("Choose location emoji")
                    .popover(isPresented: $showingEmojiPicker) { EmojiPicker(selection: $emoji) }
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Custom label (optional)").font(.caption).foregroundStyle(.secondary)
                    TextField(chosen?.sourceName ?? chosen?.label ?? "City name", text: $label)
                        .textFieldStyle(.plain).padding(.horizontal, 8).frame(height: 32)
                        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 6))
                        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(.secondary.opacity(0.25)))
                        .accessibilityLabel("Custom location label")
                }
            }
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button(existing == nil ? "Add" : "Save") { save() }
                    .keyboardShortcut(.defaultAction).disabled(chosen?.timeZone == nil)
            }
        }
        .padding(24).frame(width: 520)
        .background(Color(nsColor: .windowBackgroundColor))
        .task(id: query) {
            loading = results.isEmpty
            do {
                try await Task.sleep(for: .milliseconds(120))
                let matches = try await CitySearchService.shared.search(query)
                try Task.checkCancellation()
                results = matches
                error = nil
                loading = false
            } catch is CancellationError {
                // The next search owns the loading state.
            } catch {
                self.error = error.localizedDescription
                loading = false
            }
        }
    }

    private var manualZones: [String] {
        (["UTC"] + TimeZone.knownTimeZoneIdentifiers.filter { $0 != "UTC" })
            .filter { query.isEmpty || $0.replacingOccurrences(of: "_", with: " ").localizedCaseInsensitiveContains(query) }
    }

    private func resultButton(name: String, detail: String, zoneID: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(name).fontWeight(.medium)
                    Text([detail, SavedLocation.displayTimeZone(zoneID)].filter { !$0.isEmpty }.joined(separator: " · "))
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if selected { Image(systemName: "checkmark.circle.fill").foregroundStyle(.tint) }
            }.padding(.vertical, 3).contentShape(Rectangle())
        }.buttonStyle(.plain)
    }

    private func save() {
        guard var location = chosen, location.timeZone != nil else { return }
        location.id = existing?.id ?? UUID()
        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
        location.label = trimmed.isEmpty ? (location.sourceName ?? location.label) : trimmed
        location.emoji = emoji
        onSave(location)
        dismiss()
    }
}
