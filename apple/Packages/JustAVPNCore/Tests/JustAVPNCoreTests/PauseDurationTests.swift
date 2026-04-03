import XCTest
@testable import JustAVPNCore

final class PauseDurationTests: XCTestCase {

    func testRawValues() {
        XCTAssertEqual(PauseDuration.fiveMinutes.rawValue, 300)
        XCTAssertEqual(PauseDuration.fifteenMinutes.rawValue, 900)
        XCTAssertEqual(PauseDuration.oneHour.rawValue, 3600)
    }

    func testLabels() {
        XCTAssertEqual(PauseDuration.fiveMinutes.label, "5 minutes")
        XCTAssertEqual(PauseDuration.fifteenMinutes.label, "15 minutes")
        XCTAssertEqual(PauseDuration.oneHour.label, "1 hour")
    }

    func testAllCases() {
        XCTAssertEqual(PauseDuration.allCases.count, 3)
    }

    func testIdentifiable() {
        for duration in PauseDuration.allCases {
            XCTAssertEqual(duration.id, duration.rawValue)
        }
    }
}
