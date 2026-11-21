import ServiceManagement
import SwiftUI

@MainActor
final class SettingsNavigation: ObservableObject {
    @Published var tab: SettingsView.Tab
    init(tab: SettingsView.Tab = .general) { self.tab = tab }
}

struct SettingsView: View {
    @ObservedObject var store: AppStore
    @State private var selected: UUID?
    @State private var editor: LocationEditorState?
    @State private var loginEnabled = SMAppService.mainApp.status == .enabled
    @State private var loginError: String?

    enum Tab: String, CaseIterable { case general, menuBar, calendar, layout, locations, about }
    @ObservedObject private var navigation: SettingsNavigation
    @State private var selectedSection: DropdownSection?

    init(store: AppStore, initialTab: Tab = .general, navigation: SettingsNavigation? = nil) {
        self.store = store
        self.navigation = navigation ?? SettingsNavigation(tab: initialTab)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Picker("Settings category", selection: $navigation.tab) {
                Text("General").tag(Tab.general)
                Text("Menu Bar").tag(Tab.menuBar)
                Text("Calendar").tag(Tab.calendar)
                Text("Layout").tag(Tab.layout)
                Text("Locations").tag(Tab.locations)
                Text("About").tag(Tab.about)
            }.pickerStyle(.segmented).labelsHidden()
            Group {
                switch navigation.tab {
                case .general: general
                case .menuBar: menuBar
                case .calendar: calendar
                case .layout: layout
                case .locations: locations
                case .about: about
                }
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
            if let warning = store.storageWarning { Text(warning).font(.caption).foregroundStyle(.orange) }
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

    private var locations: some View {
        VStack(alignment: .leading, spacing: 14) {
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
                            Text("\(location.detail) · \(location.timeZoneDisplayName)").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Edit") { editor = LocationEditorState(location: location) }
                            .buttonStyle(.bordered)
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
            Spacer(minLength: 0)
        }.padding(16)
    }

    private var general: some View {
        Form {
            Picker("Clock format", selection: $store.preferences.clockFormat) {
                ForEach(ClockFormat.allCases) { Text($0.title).tag($0) }
            }
            Picker("Appearance", selection: $store.preferences.appearance) {
                ForEach(AppearanceMode.allCases) { Text($0.title).tag($0) }
            }
            Toggle("Start Horologium at login", isOn: Binding(get: { loginEnabled }, set: setLogin))
            if SMAppService.mainApp.status == .requiresApproval {
                Button("Allow in Login Items Settings…") { SMAppService.openSystemSettingsLoginItems() }
            }
            if let loginError { Text(loginError).foregroundStyle(.red).font(.caption) }
        }.formStyle(.grouped).scrollContentBackground(.hidden)
    }

    private var menuBar: some View {
        Form {
            Section("Show") {
                Toggle("Week number", isOn: $store.preferences.showWeekNumber)
                Toggle("Day of week", isOn: $store.preferences.showDayOfWeek)
                Toggle("Date", isOn: $store.preferences.showDate)
                Toggle("Month", isOn: $store.preferences.showMonth).disabled(!store.preferences.showDate)
                Toggle("Time", isOn: $store.preferences.showTime)
                Toggle("Seconds", isOn: $store.preferences.showSeconds).disabled(!store.preferences.showTime)
                Toggle("AM/PM symbols", isOn: $store.preferences.showAMPM)
                    .disabled(!store.preferences.showTime || store.preferences.clockFormat == .twentyFourHour)
            }
            Section {
                Text(store.menuTitle.isEmpty ? "Clock icon" : store.menuTitle)
                    .font(.system(.body, design: .monospaced)).accessibilityLabel("Menu bar preview")
            } header: { Text("Preview") }
        }.formStyle(.grouped).scrollContentBackground(.hidden).toggleStyle(.switch)
    }

    private var calendar: some View {
        Form {
            Picker("Start week on", selection: $store.preferences.weekStart) {
                ForEach(WeekStart.allCases) { Text($0.title).tag($0) }
            }
            Picker("Time travel interval", selection: $store.preferences.travelInterval) {
                ForEach(TravelInterval.allCases) { Text($0.title).tag($0) }
            }
        }.formStyle(.grouped).scrollContentBackground(.hidden)
    }

    private var layout: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Dropdown section order").font(.headline)
                Spacer()
                Text("Drag to reorder").font(.caption).foregroundStyle(.secondary)
            }
            List(selection: $selectedSection) {
                ForEach(store.preferences.sectionOrder) { section in
                    Text(section.title).padding(.vertical, 8).tag(section)
                }
                .onMove { store.preferences.sectionOrder.move(fromOffsets: $0, toOffset: $1) }
            }.frame(height: 170).clipShape(RoundedRectangle(cornerRadius: 8))
            HStack {
                Button { moveSection(-1) } label: { Image(systemName: "arrow.up") }
                    .disabled(sectionIndex == nil || sectionIndex == 0).accessibilityLabel("Move section up")
                Button { moveSection(1) } label: { Image(systemName: "arrow.down") }
                    .disabled(sectionIndex == nil || sectionIndex == 2).accessibilityLabel("Move section down")
                Spacer()
                Button("Reset Order") { store.preferences.sectionOrder = DropdownSection.allCases }
            }
            Spacer()
        }.padding(16)
    }

    private var about: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(nsImage: NSImage(contentsOf: Bundle.main.url(forResource: "Logo", withExtension: "png")!)!)
                .resizable().scaledToFit().frame(width: 110, height: 110)
            Text("Horologium").font(.largeTitle.weight(.semibold))
            Text("Version \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—") (build \(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"))")
                .font(.subheadline).foregroundStyle(.secondary)
            Text("Ardens").foregroundStyle(.secondary)
            Link("City data by GeoNames", destination: URL(string: "https://www.geonames.org/")!)
            Link("Creative Commons Attribution 4.0", destination: URL(string: "https://creativecommons.org/licenses/by/4.0/")!)
                .font(.caption).foregroundStyle(.secondary)
            Link("GitHub repository", destination: URL(string: "https://github.com/hirechester/horologium")!)
            Spacer()
        }.frame(maxWidth: .infinity).padding(16)
    }

    private var sectionIndex: Int? { store.preferences.sectionOrder.firstIndex { $0 == selectedSection } }
    private func moveSection(_ direction: Int) {
        guard let index = sectionIndex, store.preferences.sectionOrder.indices.contains(index + direction) else { return }
        store.preferences.sectionOrder.swapAt(index, index + direction)
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
