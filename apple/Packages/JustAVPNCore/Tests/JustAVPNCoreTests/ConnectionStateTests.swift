import XCTest
@testable import JustAVPNCore

final class ConnectionStateTests: XCTestCase {

    // MARK: - isActive

    func testIsActive_Connected() {
        let state = ConnectionState.connected(since: Date())
        XCTAssertTrue(state.isActive)
    }

    func testIsActive_Connecting() {
        XCTAssertTrue(ConnectionState.connecting.isActive)
    }

    func testIsActive_Disconnected() {
        XCTAssertFalse(ConnectionState.disconnected.isActive)
    }

    func testIsActive_Disconnecting() {
        XCTAssertFalse(ConnectionState.disconnecting.isActive)
    }

    func testIsActive_Paused() {
        let state = ConnectionState.paused(resumeAt: Date().addingTimeInterval(300))
        XCTAssertFalse(state.isActive)
    }

    func testIsActive_Error() {
        XCTAssertFalse(ConnectionState.error("fail").isActive)
    }

    // MARK: - statusText

    func testStatusText_Disconnected() {
        XCTAssertEqual(ConnectionState.disconnected.statusText, "Disconnected")
    }

    func testStatusText_Connecting() {
        XCTAssertEqual(ConnectionState.connecting.statusText, "Connecting...")
    }

    func testStatusText_Connected() {
        XCTAssertEqual(ConnectionState.connected(since: Date()).statusText, "Connected")
    }

    func testStatusText_Disconnecting() {
        XCTAssertEqual(ConnectionState.disconnecting.statusText, "Disconnecting...")
    }

    func testStatusText_Error() {
        let state = ConnectionState.error("timeout")
        XCTAssertEqual(state.statusText, "Error: timeout")
    }

    func testStatusText_Paused() {
        let state = ConnectionState.paused(resumeAt: Date().addingTimeInterval(125)) // ~2:05
        let text = state.statusText
        XCTAssertTrue(text.hasPrefix("Paused ("), "got: \(text)")
    }

    func testStatusText_PausedExpired() {
        let state = ConnectionState.paused(resumeAt: Date().addingTimeInterval(-10))
        XCTAssertEqual(state.statusText, "Paused (0:00)")
    }

    // MARK: - Equatable

    func testEquatable() {
        XCTAssertEqual(ConnectionState.disconnected, ConnectionState.disconnected)
        XCTAssertEqual(ConnectionState.connecting, ConnectionState.connecting)
        XCTAssertNotEqual(ConnectionState.disconnected, ConnectionState.connecting)
        XCTAssertEqual(ConnectionState.error("a"), ConnectionState.error("a"))
        XCTAssertNotEqual(ConnectionState.error("a"), ConnectionState.error("b"))
    }
}
