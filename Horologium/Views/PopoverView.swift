import SwiftUI

struct PopoverView: View {
    @ObservedObject var store: AppStore
    var openLocations: () -> Void
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(store.preferences.sectionOrder.enumerated()), id: \.element) { index, section in
                if index > 0 { Divider().padding(.vertical, 14) }
                switch section {
                case .calendar: CalendarView(store: store)
                case .timeTravel: timeTravel
                case .timeZones: clocks
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 18)
        .padding(.bottom, 12)
        .frame(width: 352)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.primary.opacity(0.12)))
        .focusable().focusEffectDisabled().focused($focused)
        .onAppear { focused = true }
        .onKeyPress(.leftArrow) { store.moveSelection(days: -1); return .handled }
        .onKeyPress(.rightArrow) { store.moveSelection(days: 1); return .handled }
        .onKeyPress(.upArrow) { store.moveSelection(days: -7); return .handled }
        .onKeyPress(.downArrow) { store.moveSelection(days: 7); return .handled }
        .onKeyPress(.space) { store.returnToNow(); return .handled }
        .modifier(AppAccent(preferences: store.preferences))
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
            Slider(value: Binding(get: { min(store.engine.step(for: store.displayedDate), store.engine.maximumStep(on: store.selectedDate)) },
                                  set: { store.travel(step: $0) }),
                   in: 0...store.engine.maximumStep(on: store.selectedDate))
                .controlSize(.small)
                .accessibilityLabel("Preview time on selected day")
                .accessibilityValue(ClockText.preview(store.displayedDate, format: store.preferences.clockFormat))
        }
    }

    @ViewBuilder private var clocks: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("WORLD CLOCKS").font(.system(size: 10, weight: .semibold)).tracking(1).foregroundStyle(.secondary)
                Spacer()
                Button(action: openLocations) { Image(systemName: "plus") }
                    .buttonStyle(.borderless).accessibilityLabel("Add location")
            }
            if store.locations.isEmpty {
                VStack(spacing: 6) {
                    Text("Keep your people in time.").font(.subheadline.weight(.medium))
                    Text("Add cities and give them names that mean something to you.")
                        .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    Button("Add Location", action: openLocations).padding(.top, 3)
                }.frame(maxWidth: .infinity).padding(.vertical, 10)
            } else if store.locations.count <= 4 {
                clockRows
            } else {
                ScrollView { clockRows }.frame(height: 220)
            }
        }
    }

    private var clockRows: some View {
        VStack(spacing: 12) {
            ForEach(store.locations) { location in
                ClockRow(location: location, date: store.displayedDate, format: store.preferences.clockFormat)
            }
        }.padding(.trailing, 3)
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
                    Text("\(zone.abbreviation(for: date) ?? location.timeZoneDisplayName) · \(TimeEngine.offset(of: zone, from: .autoupdatingCurrent, at: date))")
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
