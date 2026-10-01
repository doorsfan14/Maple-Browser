import XCTest
@testable import MapleCore

final class MapleURLTests: XCTestCase {
    func testURLIsKept() {
        XCTAssertEqual(MapleURL.destination(for: "https://example.com")?.absoluteString, "https://example.com")
    }

    func testDomainGetsHTTPS() {
        XCTAssertEqual(MapleURL.destination(for: "example.com")?.absoluteString, "https://example.com")
    }

    func testSearchGetsGoogle() {
        XCTAssertEqual(MapleURL.destination(for: "Maple Browser")?.absoluteString,
                       "https://www.google.com/search?q=Maple%20Browser")
    }
}
