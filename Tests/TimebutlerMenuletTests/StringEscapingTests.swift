import XCTest
@testable import TimebutlerMenulet

final class StringEscapingTests: XCTestCase {
    func testJSEscapedEscapesQuotesBackslashesAndLineBreaks() {
        let input = "a\"b\\c\nd\re\tf"

        XCTAssertEqual(input.jsEscaped, "a\\\"b\\\\c\\nd\\re\\tf")
    }
}
