import XCTest
@testable import TimebutlerMenulet

final class BreakRulesTests: XCTestCase {
    func testNoBreakRequiredAtOrBelowSixHours() {
        XCTAssertEqual(BreakRules.requiredBreakSeconds(workedSeconds: 0), 0)
        XCTAssertEqual(BreakRules.requiredBreakSeconds(workedSeconds: 5 * 3600 + 59 * 60), 0)
        XCTAssertEqual(BreakRules.requiredBreakSeconds(workedSeconds: 6 * 3600), 0)
    }

    func testThirtyMinutesRequiredAboveSixUpToNineHours() {
        XCTAssertEqual(BreakRules.requiredBreakSeconds(workedSeconds: 6 * 3600 + 1), 30 * 60)
        XCTAssertEqual(BreakRules.requiredBreakSeconds(workedSeconds: 7 * 3600), 30 * 60)
        XCTAssertEqual(BreakRules.requiredBreakSeconds(workedSeconds: 8 * 3600 + 59 * 60), 30 * 60)
        XCTAssertEqual(BreakRules.requiredBreakSeconds(workedSeconds: 9 * 3600), 30 * 60)
    }

    func testFortyFiveMinutesRequiredAboveNineHours() {
        XCTAssertEqual(BreakRules.requiredBreakSeconds(workedSeconds: 9 * 3600 + 1), 45 * 60)
        XCTAssertEqual(BreakRules.requiredBreakSeconds(workedSeconds: 10 * 3600), 45 * 60)
        XCTAssertEqual(BreakRules.requiredBreakSeconds(workedSeconds: 24 * 3600), 45 * 60)
    }

    func testShortfallIsZeroWhenBreakMeetsRequirement() {
        XCTAssertEqual(
            BreakRules.shortfallSeconds(workedSeconds: 7 * 3600, accumulatedBreakSeconds: 30 * 60),
            0
        )
        XCTAssertEqual(
            BreakRules.shortfallSeconds(workedSeconds: 5 * 3600, accumulatedBreakSeconds: 0),
            0
        )
        XCTAssertEqual(
            BreakRules.shortfallSeconds(workedSeconds: 10 * 3600, accumulatedBreakSeconds: 60 * 60),
            0
        )
    }

    func testShortfallReflectsMissingMinutesInTier1() {
        // Worked 7h, paused 20m → owe 10m.
        XCTAssertEqual(
            BreakRules.shortfallSeconds(workedSeconds: 7 * 3600, accumulatedBreakSeconds: 20 * 60),
            10 * 60
        )
    }

    func testShortfallReflectsMissingMinutesInTier2() {
        // Worked 10h, paused 30m → owe 15m (tier-2 requires 45m).
        XCTAssertEqual(
            BreakRules.shortfallSeconds(workedSeconds: 10 * 3600, accumulatedBreakSeconds: 30 * 60),
            15 * 60
        )
    }

    func testShortfallFromClockStatusUsesAccumulatedBreak() throws {
        let json = """
        {
          "status": "running",
          "startTimestamp": 1753700400000,
          "pauseTimestamp": null,
          "workTimeElapsedSeconds": 25200,
          "breakElapsedSeconds": 0,
          "accumulatedBreakSeconds": 1200,
          "waitSeconds": null,
          "isBusinessTripActive": false
        }
        """
        let status = try JSONDecoder().decode(ClockStatus.self, from: Data(json.utf8))
        XCTAssertEqual(BreakRules.shortfallSeconds(from: status), 10 * 60)
    }
}
