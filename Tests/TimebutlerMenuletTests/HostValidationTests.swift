import XCTest
@testable import TimebutlerMenulet

final class HostValidationTests: XCTestCase {
    func testTrustedLoginURLAcceptsAppHost() throws {
        let url = try XCTUnwrap(URL(string: "https://app.timebutler.com/login"))
        XCTAssertTrue(TimebutlerHost.isTrustedLoginURL(url))
    }

    func testTrustedLoginURLRejectsLookalikeHost() throws {
        let url = try XCTUnwrap(URL(string: "https://timebutler.com.evil.example/login"))
        XCTAssertFalse(TimebutlerHost.isTrustedLoginURL(url))
    }

    func testTrustedLoginURLIsCaseInsensitive() throws {
        let url = try XCTUnwrap(URL(string: "https://APP.TIMEBUTLER.COM/login"))
        XCTAssertTrue(TimebutlerHost.isTrustedLoginURL(url))
    }

    func testCookieDomainAcceptsBoundedTimebutlerDomainOnly() {
        XCTAssertTrue(TimebutlerHost.isTrustedCookieDomain(".timebutler.com"))
        XCTAssertTrue(TimebutlerHost.isTrustedCookieDomain("app.timebutler.com"))
        XCTAssertFalse(TimebutlerHost.isTrustedCookieDomain("timebutler.com.evil.example"))
    }
}
