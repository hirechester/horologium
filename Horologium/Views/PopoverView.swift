import SwiftUI

struct PopoverView: View {
    @ObservedObject var store: AppStore
    var openSettings: () -> Void
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "clock").foregroundStyle(.tint)
                Text("Horologium").font(.system(.subheadline, design: .rounded, weight: .semibold))
                Spacer()
                if store.previewDate != nil {
                    Text("PREVIEW").font(.system(size: 9, weight: .bold)).tracking(1)
                        .foregroundStyle(.tint)
                } else {
                    Circle().fill(.green).frame(width: 5, height: 5)
                    Text("Live").font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding(.bottom, 18)
            CalendarView(store: store)
            Divider().padding(.vertical, 14)
            timeTravel
            Divider().padding(.vertical, 14)
            clocks
            Divider().padding(.top, 12)
            HStack {
                Button(action: openSettings) { Label("Settings", systemImage: "gearshape") }
                    .keyboardShortcut(",", modifiers: .command)
                Spacer()
                Button("Quit") { NSApplication.shared.terminate(nil) }
                    .keyboardShortcut("q", modifiers: .command)
            }
            .font(.caption).buttonStyle(.borderless).foregroundStyle(.secondary).padding(.top, 12)
        }
        .padding(18)
        .frame(width: 352)
        .background(.regularMaterial)
        .focusable().focusEffectDisabled().focused($focused)
        .onAppear { focused = true }
        .onKeyPress(.leftArrow) { store.moveSelection(days: -1); return .handled }
        .onKeyPress(.rightArrow) { store.moveSelection(days: 1); return .handled }
        .onKeyPress(.upArrow) { store.moveSelection(days: -7); return .handled }
        .onKeyPress(.downArrow) { store.moveSelection(days: 7); return .handled }
        .onKeyPress(.space) { store.returnToNow(); return .handled }
    }

    private var timeTravel: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("TIME TRAVEL").font(.system(size: 10, weight: .semibold)).tracking(1).foregroundStyle(.secondary)
                Spacer()
                Button("Now") { store.returnToNow() }
                    .font(.caption.weight(.medium)).buttonStyle(.borderless)
                    .disabled(store.previewDate == nil)
            }
            Text(ClockText.date(store.displayedDate) + " · " + ClockText.preview(store.displayedDate, format: store.preferences.clockFormat))
                .font(.system(size: 11)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.8)
            Slider(value: Binding(get: { store.engine.step(for: store.displayedDate) },
                                  set: { store.travel(step: $0) }),
                   in: 0...store.engine.maximumStep(on: store.selectedDate), step: 1)
                .controlSize(.small)
                .accessibilityLabel("Preview time on selected day")
                .accessibilityValue(ClockText.preview(store.displayedDate, format: store.preferences.clockFormat))
            HStack {
                Text("Start of day")
                Spacer()
                Text("End of day")
            }.font(.system(size: 9)).foregroundStyle(.tertiary)
        }
    }

    @ViewBuilder private var clocks: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("WORLD CLOCKS").font(.system(size: 10, weight: .semibold)).tracking(1).foregroundStyle(.secondary)
                Spacer()
                Button(action: openSettings) { Image(systemName: "plus") }
                    .buttonStyle(.borderless).accessibilityLabel("Add location")
            }
            if store.locations.isEmpty {
                VStack(spacing: 6) {
                    Text("Keep your people in time.").font(.subheadline.weight(.medium))
                    Text("Add cities and give them names that mean something to you.")
                        .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    Button("Add Location", action: openSettings).padding(.top, 3)
                }.frame(maxWidth: .infinity).padding(.vertical, 10)
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(store.locations) { location in
                            ClockRow(location: location, date: store.displayedDate, format: store.preferences.clockFormat)
                        }
                    }.padding(.trailing, 3)
                }.frame(height: min(CGFloat(store.locations.count) * 51, 220))
            }
        }
    }
}

private struct ClockRow: View {
    let location: SavedLocation
    let date: Date
    let format: ClockFormat

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 3) {
                Text(location.displayLabel).font(.system(size: 13, weight: .medium)).lineLimit(1)
                if let zone = location.timeZone {
                    Text("\(zone.abbreviation(for: date) ?? zone.identifier) · \(TimeEngine.offset(of: zone, from: .autoupdatingCurrent, at: date))")
                        .font(.system(size: 10)).foregroundStyle(.secondary)
                } else {
                    Text("Time zone unavailable — edit in Settings").font(.caption2).foregroundStyle(.orange)
                }
            }
            Spacer(minLength: 8)
            if let zone = location.timeZone {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(ClockText.time(date, zone: zone, format: format))
                        .font(.system(size: 19, weight: .regular, design: .rounded)).monospacedDigit()
                    Text(ClockText.date(date, zone: zone, template: "EEE MMM d"))
                        .font(.system(size: 10)).foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}
