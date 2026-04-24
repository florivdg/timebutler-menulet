import XCTest
@testable import TimebutlerMenulet

final class HTMLScraperTests: XCTestCase {
    func testParseWorkingStatus() {
        let html = #"<div id="time-clock" data-paused="0" data-running="1" data-dauersec="3600" data-pausesec="300"></div>"#

        guard case .working(let start, let origin) = HTMLScraper.parseStatus(from: html) else {
            return XCTFail("Expected working status")
        }

        XCTAssertNotNil(start)
        XCTAssertLessThan(origin.timeIntervalSinceNow, 0)
    }

    func testParsePausedStatus() {
        let html = #"<div id="time-clock" data-paused="1" data-running="0" data-dauersec="3600" data-pausesec="120"></div>"#

        guard case .paused(let start, let origin) = HTMLScraper.parseStatus(from: html) else {
            return XCTFail("Expected paused status")
        }

        XCTAssertNotNil(start)
        XCTAssertLessThan(origin.timeIntervalSinceNow, 0)
    }

    func testParseCheckedOutStatus() {
        let html = #"<div id="time-clock" data-paused="0" data-running="0" data-dauersec="0" data-pausesec="0"></div>"#

        XCTAssertEqual(HTMLScraper.parseStatus(from: html), .checkedOut)
    }

    func testParseMissingWidgetReturnsNil() {
        XCTAssertNil(HTMLScraper.parseStatus(from: "<html></html>"))
    }
}
