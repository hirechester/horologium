import AppKit
import SwiftUI
import XCTest
@testable import Horologium

final class VisualPreviewTests: XCTestCase {
    @MainActor func testRenderAppVisuals() throws {
        let name = "HorologiumVisualTests.\(UUID())"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let now = ISO8601DateFormatter().date(from: "2026-11-21T15:30:00Z")!
        let store = AppStore(defaults: defaults, clock: { now })
        store.preferences.clockFormat = .twentyFourHour
        store.locations = [
            SavedLocation(label: "London office", detail: "England, United Kingdom", timeZoneID: "Europe/London", emoji: "🇬🇧", sourceName: "London"),
            SavedLocation(label: "Tokyo", detail: "Tokyo, Japan", timeZoneID: "Asia/Tokyo", emoji: "🇯🇵", sourceName: "Tokyo"),
            SavedLocation(label: "San Francisco", detail: "California, United States", timeZoneID: "America/Los_Angeles", emoji: "🇺🇸", sourceName: "San Francisco")
        ]
        try render(PopoverView(store: store, openLocations: {}), name: "01-calendar-and-world-clocks", width: 352)
        store.travel(step: 32)
        try render(PopoverView(store: store, openLocations: {}), name: "02-time-travel", width: 352)
        try render(SettingsView(store: store), name: "03-settings", width: 540)
        try render(SettingsView(store: store, initialTab: .menuBar), name: "08-menu-bar-settings", width: 540)
        try render(SettingsView(store: store, initialTab: .calendar), name: "09-calendar-settings", width: 540)
        try render(SettingsView(store: store, initialTab: .layout), name: "10-layout-settings", width: 540)
        try render(SettingsView(store: store, initialTab: .locations), name: "11-location-settings", width: 540)
        try render(PopoverView(store: store, openLocations: {}), name: "05-dark-mode", width: 352, dark: true)
        try render(EmojiPicker(selection: .constant("🇬🇧"), initialCatalog: try EmojiCatalog.bundled()), name: "06-native-emoji-picker", width: 370)
        try render(LocationEditor(existing: store.locations[0], initialCities: try CityCatalog.bundled().search("London"), onSave: { _ in }), name: "07-custom-location", width: 520)
        store.preferences.sectionOrder = [.timeZones, .calendar, .timeTravel]
        try render(PopoverView(store: store, openLocations: {}), name: "12-reordered-sections", width: 352)
        store.preferences.sectionOrder = DropdownSection.allCases
        // Also render the empty first-launch state, without changing the real app's settings.
        store.locations = []
        store.returnToNow()
        try render(PopoverView(store: store, openLocations: {}), name: "04-first-launch", width: 352)
    }

    @MainActor private func render<V: View>(_ content: V, name: String, width: CGFloat, dark: Bool = false) throws {
        let view = NSHostingView(rootView: content.environment(\.colorScheme, dark ? .dark : .light))
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: width, height: 800),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        window.contentView = view
        let size = view.fittingSize
        XCTAssertEqual(size.width, width, accuracy: 1)
        XCTAssertGreaterThan(size.height, 300)
        XCTAssertLessThanOrEqual(size.height, 800)
        window.setContentSize(size)
        view.frame = NSRect(origin: .zero, size: size)
        view.layoutSubtreeIfNeeded()
        let bitmap = try XCTUnwrap(view.bitmapImageRepForCachingDisplay(in: view.bounds))
        view.cacheDisplay(in: view.bounds, to: bitmap)
        let image = NSImage(size: size)
        image.addRepresentation(bitmap)
        let attachment = XCTAttachment(image: image)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        // Preview artifacts are deliberately outside the source tree.
        let output = URL(fileURLWithPath: "/tmp/horologium-previews", isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        try XCTUnwrap(bitmap.representation(using: .png, properties: [:])).write(to: output.appendingPathComponent(name + ".png"))
        window.close()
    }
}
