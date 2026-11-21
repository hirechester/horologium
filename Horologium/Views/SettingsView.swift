import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: AppStore
    @State private var selected: UUID?
    @State private var editor: LocationEditorState?
    @State private var loginEnabled = SMAppService.mainApp.status == .enabled
    @State private var loginError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                Image(nsImage: NSImage(contentsOf: Bundle.main.url(forResource: "Logo", withExtension: "png")!)!).resizable().scaledToFit().frame(width: 48, height: 48)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Horologium").font(.title2.weight(.semibold))
                    Text("A little perspective on your day.").foregroundStyle(.secondary)
                }
            }
            HStack {
                Text("Locations").font(.headline)
                Spacer()
                Text("Drag to reorder").font(.caption).foregroundStyle(.secondary)
            }
            List(selection: $selected) {
                ForEach(store.locations) { location in
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(location.displayLabel).fontWeight(.medium)
                            Text("\(location.detail) · \(location.timeZoneID)").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Edit") { editor = LocationEditorState(location: location) }
                            .buttonStyle(.borderless)
                    }.padding(.vertical, 3).tag(location.id)
                }
                .onMove { store.locations.move(fromOffsets: $0, toOffset: $1) }
                .onDelete { store.locations.remove(atOffsets: $0) }
            }
            .overlay {
                if store.locations.isEmpty {
                    ContentUnavailableView("Your world clocks", systemImage: "globe.europe.africa",
                                           description: Text("Add a city or a custom time zone to get started."))
                }
            }
            .frame(height: 185)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            HStack {
                Button { editor = LocationEditorState(location: nil) } label: { Label("Add Location", systemImage: "plus") }
                Button {
                    store.locations.removeAll { $0.id == selected }
                    selected = nil
                } label: { Label("Remove", systemImage: "minus") }.disabled(selected == nil)
                Spacer()
                Button { moveSelected(-1) } label: { Image(systemName: "arrow.up") }
                    .disabled(selectedIndex == nil || selectedIndex == 0).accessibilityLabel("Move location up")
                Button { moveSelected(1) } label: { Image(systemName: "arrow.down") }
                    .disabled(selectedIndex == nil || selectedIndex == store.locations.count - 1).accessibilityLabel("Move location down")
            }
            Divider()
            Form {
                Picker("Clock format", selection: $store.preferences.clockFormat) {
                    ForEach(ClockFormat.allCases) { Text($0.title).tag($0) }
                }.frame(maxWidth: 300)
                Picker("Appearance", selection: $store.preferences.appearance) {
                    ForEach(AppearanceMode.allCases) { Text($0.title).tag($0) }
                }.frame(maxWidth: 300)
                Toggle("Show date in the menu bar", isOn: $store.preferences.showDate)
                Toggle("Start Horologium at login", isOn: Binding(get: { loginEnabled }, set: setLogin))
                if SMAppService.mainApp.status == .requiresApproval {
                    Button("Allow in Login Items Settings…") { SMAppService.openSystemSettingsLoginItems() }
                }
                if let loginError { Text(loginError).foregroundStyle(.red).font(.caption) }
            }
            if let warning = store.storageWarning { Text(warning).font(.caption).foregroundStyle(.orange) }
            Spacer(minLength: 0)
            HStack {
                Text("Version 1.0 · All settings stay on this Mac").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Link("City data: GeoNames", destination: URL(string: "https://www.geonames.org/")!).font(.caption)
            }
        }
        .padding(24).frame(width: 540, height: 600)
        .background(Color(nsColor: .windowBackgroundColor))
        .sheet(item: $editor) { state in
            LocationEditor(existing: state.location) { location in
                if let index = store.locations.firstIndex(where: { $0.id == location.id }) { store.locations[index] = location }
                else { store.add(location) }
                selected = location.id
            }
        }
        .onAppear { loginEnabled = SMAppService.mainApp.status == .enabled }
    }

    private var selectedIndex: Int? { store.locations.firstIndex { $0.id == selected } }

    private func moveSelected(_ direction: Int) {
        guard let index = selectedIndex, store.locations.indices.contains(index + direction) else { return }
        store.locations.swapAt(index, index + direction)
    }

    private func setLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
            loginEnabled = SMAppService.mainApp.status == .enabled
            loginError = nil
        } catch {
            loginEnabled = SMAppService.mainApp.status == .enabled
            loginError = error.localizedDescription
        }
    }
}

private struct LocationEditorState: Identifiable {
    let id = UUID()
    let location: SavedLocation?
}
