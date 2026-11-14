import XCTest
@testable import USOSGlassSGH

final class CampusTests: XCTestCase {
    func testOAuthPublishedRFC5849Vector() {
        // RFC 5849 section 3.4.1.1, including duplicate and encoded parameters.
        let pairs = [("b5", "=%3D"), ("a3", "a"), ("c@", ""), ("a2", "r b"), ("c2", ""), ("a3", "2 q"),
            ("oauth_consumer_key", "9djdj82h48djs9d2"), ("oauth_token", "kkk9d7dh3k39sjv7"),
            ("oauth_signature_method", "HMAC-SHA1"), ("oauth_timestamp", "137131201"), ("oauth_nonce", "7d8f3e4a")]
        XCTAssertEqual(OAuth1.signature(method: "POST", url: "http://example.com/request", parameters: pairs,
            consumerSecret: "j49sk3j29djd", tokenSecret: "dh893hdasih9"), "r6/TJjbCOr97/+UU0NsvSne7s5g=")
    }
    func testEncodingAndTokenParsing() throws {
        XCTAssertEqual(OAuth1.encode("a+b /&="), "a%2Bb%20%2F%26%3D")
        let token = try OAuth1.token(from: Data("oauth_token=a%2Bb&oauth_token_secret=c%3Dd&oauth_callback_confirmed=true".utf8), requireCallback: true)
        XCTAssertEqual(token.key, "a+b"); XCTAssertEqual(token.secret, "c=d")
        XCTAssertThrowsError(try OAuth1.token(from: Data("oauth_token=x".utf8)))
        XCTAssertThrowsError(try OAuth1.token(from: Data("oauth_token=x&oauth_token_secret=y&oauth_callback_confirmed=false".utf8), requireCallback: true))
    }
    func testWarsawTimeAndUnknownActivity() throws {
        let data = Data(#"{"start_time":"2026-11-16 09:00:00","end_time":"2026-11-16 10:30:00","name":{"en":"Special meeting"},"type":"future-type"}"#.utf8)
        let e = try JSONDecoder().decode(APIEvent.self, from: data).model()
        XCTAssertEqual(e.title, "Special meeting")
        XCTAssertEqual(e.end.timeIntervalSince(e.start), 5400)
        XCTAssertEqual(CampusTime.string(e.start, "HH:mm"), "09:00")
        XCTAssertEqual(ISO8601DateFormatter().string(from: e.start), "2026-11-16T08:00:00Z")
        XCTAssertFalse(e.isDemo)
    }
    func testInvalidEventDoesNotSilentlyDisappear() throws {
        let data = Data(#"{"start_time":"bad","end_time":"bad","name":{"pl":"Test"}}"#.utf8)
        let e = try JSONDecoder().decode(APIEvent.self, from: data)
        XCTAssertThrowsError(try e.model())
    }
    func testGradesSupportNumericAndStringIDsAndPassSymbols() throws {
        let data = Data(#"[{"value_symbol":"ZAL","passes":true,"exam_id":123,"exam_session_number":"1","course_edition":null},{"value_symbol":"4,5","passes":true,"exam_id":"456","exam_session_number":2,"course_edition":{"course_name":{"pl":"Ekonomia"},"term_id":"2026Z"}}]"#.utf8)
        let grades = try JSONDecoder().decode([CampusGrade].self, from: data)
        XCTAssertEqual(grades[0].id, "123:1"); XCTAssertNil(grades[0].numeric)
        XCTAssertEqual(grades[1].numeric, 4.5); XCTAssertEqual(grades[1].title, "Ekonomia")
    }
    func testDemoUsesSelectedWeekAndMondayStart() {
        let date = CampusTime.parse("2026-11-18 10:00:00")!
        let week = CampusTime.week(date)
        XCTAssertEqual(CampusTime.string(week, "yyyy-MM-dd"), "2026-11-16")
        let events = DemoData.events(week: week)
        XCTAssertEqual(events.count, 10)
        XCTAssertTrue(events.allSatisfy { $0.isDemo && $0.start >= week && $0.end > $0.start })
        XCTAssertEqual(Set(events.map(\.id)).count, events.count)
    }
}
