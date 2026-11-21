import AppKit
import XCTest
@testable import Horologium

final class MenuBarPanelTests: XCTestCase {
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
