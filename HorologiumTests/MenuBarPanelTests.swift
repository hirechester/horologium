import AppKit
import XCTest
@testable import Horologium

final class MenuBarPanelTests: XCTestCase {
    @MainActor func testCloseWindowMenuUsesNativeCommandWAction() {
        let application = NSApplication.shared
        let previousMenu = application.mainMenu
        let delegate = AppDelegate()
        delegate.configureMenu()
        defer { application.mainMenu = previousMenu }
        let fileMenu = application.mainMenu!.items.first { $0.title == "File" }!.submenu!
        let closeItem = fileMenu.items.first { $0.keyEquivalent == "w" }!
        XCTAssertEqual(closeItem.keyEquivalentModifierMask, .command)
        XCTAssertEqual(closeItem.action, #selector(NSWindow.performClose(_:)))
        XCTAssertNil(closeItem.target) // macOS routes the action to the current window.

        // Exercise the native close action without relying on the test runner
        // being granted foreground keyboard focus by the desktop session.
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 540, height: 600),
                              styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.orderFront(nil)
        defer { window.close() }
        XCTAssertTrue(window.isVisible)
        XCTAssertTrue(application.sendAction(closeItem.action!, to: window, from: closeItem))
        XCTAssertFalse(window.isVisible)
    }

    @MainActor func testOutsideClickMonitorLeavesStatusItemToggleInControl() {
        let controller = NSViewController()
        controller.view = NSView(frame: NSRect(x: 0, y: 0, width: 352, height: 100))
        let item = NSRect(x: 900, y: 876, width: 100, height: 24)
        let dropdown = MenuBarPanel(controller: controller) {
            (item: item, screen: NSRect(x: 0, y: 50, width: 1440, height: 826))
        }
        var dismissals = 0
        dropdown.onDismiss = { dismissals += 1 }
        dropdown.show()
        defer { dropdown.dismiss() }

        // A global or local notification of the status-item press must not
        // dismiss early and turn the intended close into another open.
        dropdown.dismissForOutsideClick(at: NSPoint(x: 950, y: 888), insidePanel: false)
        XCTAssertTrue(dropdown.isPresented)
        XCTAssertEqual(dismissals, 0)
        dropdown.dismissForOutsideClick(at: NSPoint(x: 950, y: 800), insidePanel: true)
        XCTAssertTrue(dropdown.isPresented)

        // The status-item action closes the existing panel exactly once.
        dropdown.dismiss()
        XCTAssertFalse(dropdown.isPresented)
        XCTAssertEqual(dismissals, 1)
        dropdown.dismissForOutsideClick(at: NSPoint(x: 950, y: 888), insidePanel: false)
        XCTAssertFalse(dropdown.isPresented)
        XCTAssertEqual(dismissals, 1)

        // A genuine outside click must still dismiss on the next opening.
        dropdown.show()
        dropdown.dismissForOutsideClick(at: NSPoint(x: 50, y: 50), insidePanel: false)
        XCTAssertFalse(dropdown.isPresented)
        XCTAssertEqual(dismissals, 2)
    }

    @MainActor func testPanelStaysBelowItemAndKeepsTopEdgeWhenContentGrows() {
        let screen = NSRect(x: 0, y: 50, width: 1440, height: 826)
        let item = NSRect(x: 900, y: 876, width: 100, height: 24)
        let short = MenuBarPanel.frame(contentSize: NSSize(width: 352, height: 400), item: item, screen: screen)
        let tall = MenuBarPanel.frame(contentSize: NSSize(width: 352, height: 600), item: item, screen: screen)
        XCTAssertEqual(short.midX, item.midX)
        XCTAssertEqual(short.maxY, item.minY - 6)
        XCTAssertEqual(tall.maxY, short.maxY)
        XCTAssertEqual(tall.height, 600)
    }

    @MainActor func testPanelClampsToBothEdgesAndNegativeOriginDisplay() {
        let screen = NSRect(x: -1920, y: -100, width: 1920, height: 1056)
        for x in [screen.minX, screen.maxX - 40] {
            let frame = MenuBarPanel.frame(contentSize: NSSize(width: 352, height: 650),
                                           item: NSRect(x: x, y: screen.maxY, width: 40, height: 24), screen: screen)
            XCTAssertGreaterThanOrEqual(frame.minX, screen.minX + 6)
            XCTAssertLessThanOrEqual(frame.maxX, screen.maxX - 6)
            XCTAssertGreaterThanOrEqual(frame.minY, screen.minY + 6)
            XCTAssertLessThanOrEqual(frame.maxY, screen.maxY - 6)
        }
    }

    @MainActor func testPanelFitsSmallScreens() {
        let screen = NSRect(x: 0, y: 0, width: 320, height: 500)
        let frame = MenuBarPanel.frame(contentSize: NSSize(width: 352, height: 700),
                                       item: NSRect(x: 100, y: 500, width: 40, height: 24), screen: screen)
        XCTAssertTrue(screen.contains(frame))
        XCTAssertEqual(frame.width, 308)
        XCTAssertEqual(frame.height, 488)
    }
}
