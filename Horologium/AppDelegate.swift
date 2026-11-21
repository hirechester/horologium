import AppKit
import Combine
import SwiftUI

@main
struct Horologium {
    @MainActor static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        withExtendedLifetime(delegate) { app.run() }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let store = AppStore()
    private let settingsNavigation = SettingsNavigation()
    private var statusItem: NSStatusItem!
    private let popover = NSPopover()
    private var settingsWindow: NSWindow?
    private var timer: Timer?
    private var subscriptions = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        configureMenu()
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.target = self
        statusItem.button?.action = #selector(statusItemClicked)
        _ = statusItem.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        statusItem.button?.setAccessibilityLabel("Horologium calendar and world clocks")
        statusItem.button?.font = .monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        popover.behavior = .transient
        let controller = NSHostingController(rootView: PopoverView(store: store) { [weak self] in self?.showLocationSettings() })
        controller.sizingOptions = [.preferredContentSize]
        popover.contentViewController = controller
        store.$now.combineLatest(store.$preferences).sink { [weak self] _, _ in
            // @Published sends before assignment; render on the next main run-loop turn.
            DispatchQueue.main.async {
                self?.updateTitle()
                self?.updateAppearance()
                self?.configureTimer()
            }
        }.store(in: &subscriptions)
        updateTitle()
        updateAppearance()
        configureTimer()
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(environmentChanged), name: NSWorkspace.didWakeNotification, object: nil)
        for name in [NSNotification.Name.NSSystemTimeZoneDidChange, NSLocale.currentLocaleDidChangeNotification,
                     NSNotification.Name.NSSystemClockDidChange] {
            NotificationCenter.default.addObserver(self, selector: #selector(environmentChanged), name: name, object: nil)
        }
    }

    private func configureTimer() {
        let interval: TimeInterval = store.preferences.showTime && store.preferences.showSeconds ? 1 : 60
        guard timer?.timeInterval != interval else { return }
        timer?.invalidate()
        let next = (Date().timeIntervalSince1970 / interval).rounded(.down) * interval + interval
        let timer = Timer(fire: Date(timeIntervalSince1970: next), interval: interval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.store.refresh() }
        }
        timer.tolerance = interval == 1 ? 0.05 : 0.5
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    @objc private func statusItemClicked() {
        let event = NSApplication.shared.currentEvent
        if event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true {
            popover.performClose(nil)
            guard let button = statusItem.button else { return }
            let menu = NSMenu()
            menu.addItem(withTitle: "Settings…", action: #selector(showSettings), keyEquivalent: ",").target = self
            menu.addItem(.separator())
            menu.addItem(withTitle: "Quit Horologium", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
            menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.minY), in: button)
        } else { togglePopover() }
    }

    private func updateAppearance() {
        let appearance: NSAppearance?
        switch store.preferences.appearance {
        case .system: appearance = nil
        case .light: appearance = NSAppearance(named: .aqua)
        case .dark: appearance = NSAppearance(named: .darkAqua)
        }
        if NSApplication.shared.appearance?.name != appearance?.name {
            NSApplication.shared.appearance = appearance
        }
    }

    private func updateTitle() {
        let title = store.menuTitle
        if statusItem.button?.title != title { statusItem.button?.title = title }
        statusItem.button?.image = title.isEmpty ? NSImage(systemSymbolName: "clock", accessibilityDescription: "Horologium") : nil
    }

    @objc private func environmentChanged() {
        timer?.invalidate()
        timer = nil
        configureTimer()
        store.refresh()
        store.objectWillChange.send()
        updateTitle()
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown { popover.performClose(nil) }
        else {
            store.returnToNow()
            NSApplication.shared.activate(ignoringOtherApps: true)
            if let view = popover.contentViewController?.view { popover.contentSize = view.fittingSize }
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    private func showLocationSettings() {
        settingsNavigation.tab = .locations
        showSettings()
    }

    @objc private func showSettings() {
        popover.performClose(nil)
        if settingsWindow == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 540, height: 600),
                                  styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
            window.title = "Horologium Settings"
            window.contentViewController = NSHostingController(rootView: SettingsView(store: store, navigation: settingsNavigation))
            window.isReleasedWhenClosed = false
            window.center()
            settingsWindow = window
        }
        NSApplication.shared.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    private func configureMenu() {
        let menu = NSMenu()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Horologium Settings…", action: #selector(showSettings), keyEquivalent: ",").target = self
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit Horologium", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        let appItem = NSMenuItem()
        appItem.submenu = appMenu
        menu.addItem(appItem)
        let editMenu = NSMenu(title: "Edit")
        for (title, action, key) in [("Undo", Selector(("undo:")), "z"), ("Cut", #selector(NSText.cut(_:)), "x"),
                                     ("Copy", #selector(NSText.copy(_:)), "c"), ("Paste", #selector(NSText.paste(_:)), "v"),
                                     ("Select All", #selector(NSText.selectAll(_:)), "a")] {
            editMenu.addItem(withTitle: title, action: action, keyEquivalent: key)
        }
        let editItem = NSMenuItem(title: "Edit", action: nil, keyEquivalent: "")
        editItem.submenu = editMenu
        menu.addItem(editItem)
        NSApplication.shared.mainMenu = menu
    }
}
