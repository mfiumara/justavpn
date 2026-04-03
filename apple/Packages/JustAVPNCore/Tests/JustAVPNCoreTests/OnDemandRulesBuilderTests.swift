import XCTest
import NetworkExtension
@testable import JustAVPNCore

final class OnDemandRulesBuilderTests: XCTestCase {

    func testBothDisabled() {
        let builder = OnDemandRulesBuilder(killSwitch: false, autoConnect: false)
        let result = builder.build()
        XCTAssertTrue(result.rules.isEmpty)
        XCTAssertFalse(result.enabled)
    }

    func testKillSwitchOnly() {
        let builder = OnDemandRulesBuilder(killSwitch: true, autoConnect: false)
        let result = builder.build()
        XCTAssertEqual(result.rules.count, 1)
        XCTAssertTrue(result.enabled)
        XCTAssertTrue(result.rules.first is NEOnDemandRuleConnect)
    }

    func testAutoConnectOnly() {
        let builder = OnDemandRulesBuilder(killSwitch: false, autoConnect: true)
        let result = builder.build()
        XCTAssertEqual(result.rules.count, 1)
        XCTAssertTrue(result.enabled)
        XCTAssertTrue(result.rules.first is NEOnDemandRuleConnect)
    }

    func testBothEnabled() {
        let builder = OnDemandRulesBuilder(killSwitch: true, autoConnect: true)
        let result = builder.build()
        XCTAssertEqual(result.rules.count, 1)
        XCTAssertTrue(result.enabled)
    }

    func testDefaultInit() {
        let builder = OnDemandRulesBuilder()
        let result = builder.build()
        XCTAssertTrue(result.rules.isEmpty)
        XCTAssertFalse(result.enabled)
    }
}
