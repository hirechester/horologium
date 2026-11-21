import AppKit

/// A native floating panel without NSPopover's anchor arrow.
@MainActor
final class MenuBarPanel: NSObject, NSWindowDelegate {
    private final class KeyPanel: NSPanel {
        override var canBecomeKey: Bool { true }
        override var canBecomeMain: Bool { false }
        var onCancel: (() -> Void)?
        override func cancelOperation(_ sender: Any?) { onCancel?() }
    }

    private let panel: KeyPanel
    private let controller: NSViewController
    private let anchor: () -> (item: NSRect, screen: NSRect)?
    private var sizeObservation: NSKeyValueObservation?
    private var localMonitor: Any?
    private var globalMonitor: Any?
    private(set) var isPresented = false

    init(controller: NSViewController, anchor: @escaping () -> (item: NSRect, screen: NSRect)?) {
        self.controller = controller
        self.anchor = anchor
        panel = KeyPanel(contentRect: .zero, styleMask: [.borderless], backing: .buffered, defer: false)
        super.init()
        panel.isReleasedWhenClosed = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.level = .popUpMenu
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.animationBehavior = .utilityWindow
        panel.contentViewController = controller
        panel.delegate = self
        panel.onCancel = { [weak self] in self?.dismiss() }
        sizeObservation = controller.observe(\.preferredContentSize, options: [.new]) { [weak self] _, _ in
            Task { @MainActor in self?.updateFrame() }
        }
    }

    func show() {
        guard anchor() != nil else { return }
        isPresented = true
        updateFrame()
        panel.makeKeyAndOrderFront(nil)
        startMonitoring()
    }

    func dismiss() {
        guard isPresented else { return }
        isPresented = false
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        localMonitor = nil
        globalMonitor = nil
        panel.orderOut(nil)
    }

    func updateFrame() {
        guard isPresented, let anchor = anchor() else { return }
        controller.view.layoutSubtreeIfNeeded()
        let frame = Self.frame(contentSize: controller.view.fittingSize, item: anchor.item, screen: anchor.screen)
        if panel.frame != frame { panel.setFrame(frame, display: true) }
    }

    /// Screen coordinates support displays positioned above or left of the main display.
    static func frame(contentSize: NSSize, item: NSRect, screen: NSRect) -> NSRect {
        let margin: CGFloat = 6
        let width = min(contentSize.width, max(0, screen.width - margin * 2))
        let height = min(contentSize.height, max(0, screen.height - margin * 2))
        let x = min(max(item.midX - width / 2, screen.minX + margin), screen.maxX - width - margin)
        let top = min(item.minY - margin, screen.maxY - margin)
        let y = max(screen.minY + margin, top - height)
        return NSRect(x: x, y: y, width: width, height: height)
    }

    func windowDidResignKey(_ notification: Notification) {
        // Let the status item's mouse-up action toggle the panel closed.
        if NSEvent.pressedMouseButtons != 0, anchor()?.item.contains(NSEvent.mouseLocation) == true { return }
        dismiss()
    }

    private func startMonitoring() {
        guard localMonitor == nil else { return }
        let clicks: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: clicks) { [weak self] event in
            MainActor.assumeIsolated {
                guard let self else { return }
                if event.window !== self.panel && self.anchor()?.item.contains(NSEvent.mouseLocation) != true {
                    self.dismiss()
                }
            }
            return event
        }
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: clicks) { [weak self] _ in
            Task { @MainActor in self?.dismiss() }
        }
    }
}
