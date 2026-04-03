import XCTest
@testable import JustAVPNCore

final class APIErrorTests: XCTestCase {

    func testInvalidResponseDescription() {
        let error = APIError.invalidResponse
        XCTAssertEqual(error.errorDescription, "Invalid response from server")
    }

    func testServerErrorDescription() {
        let error = APIError.serverError(403, "forbidden")
        XCTAssertEqual(error.errorDescription, "Server error (403): forbidden")
    }
}
