import XCTest
@testable import TimebutlerMenulet

final class ClockStatusDecodingTests: XCTestCase {
    private func decode(_ json: String) throws -> ClockStatus {
        try JSONDecoder().decode(ClockStatus.self, from: Data(json.utf8))
    }

    func testIdleDecodesToIdle() throws {
        let json = """
        {
          "status": "idle",
          "startTimestamp": null,
          "pauseTimestamp": null,
          "workTimeElapsedSeconds": 0,
          "breakElapsedSeconds": 0,
          "accumulatedBreakSeconds": 0,
          "waitSeconds": null,
          "isBusinessTripActive": false
        }
        """
        let s = try decode(json)
        XCTAssertEqual(s.status, .idle)
        XCTAssertNil(s.startDate)
        XCTAssertEqual(s.toWorkStatus(), .idle)
    }

    func testRunningKeepsStartTimestamp() throws {
        let json = """
        {
          "status": "running",
          "startTimestamp": 1753700400000,
          "pauseTimestamp": null,
          "workTimeElapsedSeconds": 120,
          "breakElapsedSeconds": 0,
          "accumulatedBreakSeconds": 0,
          "waitSeconds": null,
          "isBusinessTripActive": false
        }
        """
        let s = try decode(json)
        XCTAssertEqual(s.status, .running)
        let expected = Date(timeIntervalSince1970: 1753700400)
        XCTAssertEqual(s.startDate, expected)
        if case .running(let started) = s.toWorkStatus() {
            XCTAssertEqual(started, expected)
        } else {
            XCTFail("Expected .running")
        }
    }

    func testPausedCarriesBothTimestamps() throws {
        let json = """
        {
          "status": "paused",
          "startTimestamp": 1753700400000,
          "pauseTimestamp": 1753704000000,
          "workTimeElapsedSeconds": 60,
          "breakElapsedSeconds": 30,
          "accumulatedBreakSeconds": 30,
          "waitSeconds": null,
          "isBusinessTripActive": false
        }
        """
        let s = try decode(json)
        if case .paused(let started, let paused) = s.toWorkStatus() {
            XCTAssertEqual(started, Date(timeIntervalSince1970: 1753700400))
            XCTAssertEqual(paused, Date(timeIntervalSince1970: 1753704000))
        } else {
            XCTFail("Expected .paused")
        }
    }

    func testWaitingMapsToWaitingState() throws {
        let json = """
        {
          "status": "waiting",
          "startTimestamp": 1753700400000,
          "pauseTimestamp": null,
          "workTimeElapsedSeconds": 0,
          "breakElapsedSeconds": 0,
          "accumulatedBreakSeconds": 0,
          "waitSeconds": 45,
          "isBusinessTripActive": false
        }
        """
        let s = try decode(json)
        XCTAssertEqual(s.status, .waiting)
        XCTAssertEqual(s.waitSeconds, 45)
        if case .waiting(let started) = s.toWorkStatus() {
            XCTAssertEqual(started, Date(timeIntervalSince1970: 1753700400))
        } else {
            XCTFail("Expected .waiting")
        }
    }

    func testIsBusinessTripActiveIsOptional() throws {
        let json = """
        {
          "status": "idle",
          "startTimestamp": null,
          "pauseTimestamp": null,
          "workTimeElapsedSeconds": 0,
          "breakElapsedSeconds": 0,
          "accumulatedBreakSeconds": 0,
          "waitSeconds": null
        }
        """
        let s = try decode(json)
        XCTAssertEqual(s.status, .idle)
        XCTAssertNil(s.isBusinessTripActive)
    }
}
