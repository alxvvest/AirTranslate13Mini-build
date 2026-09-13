import XCTest
@testable import AirTranslate13Mini

final class TranscriptTests: XCTestCase {
    func testConversationLineStoresTranslation() {
        let line = ConversationLine(spanish: "Hola", english: "Hello", createdAt: .now)
        XCTAssertEqual(line.spanish, "Hola")
        XCTAssertEqual(line.english, "Hello")
    }
}
