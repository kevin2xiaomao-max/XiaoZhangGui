import XCTest
@testable import XiaoZhangGui

final class AppDeepLinkTests: XCTestCase {
    private func route(_ string: String) -> AppDeepLink? {
        guard let url = URL(string: string) else { return nil }
        return AppDeepLink.route(url: url)
    }

    func testLegacyVoiceLinkPreserved() {
        XCTAssertEqual(route("xzg://voice"), .voice)
    }

    func testLegacyQuickRecordLinksPreserved() {
        XCTAssertEqual(route("xzg://quickrecord"), .quickRecord)
        XCTAssertEqual(route("xzg://quick"), .quickRecord)
    }

    func testAssistantChatLink() {
        XCTAssertEqual(route("xzg://ai"), .ai(voiceMode: false))
    }

    func testAssistantVoiceLink() {
        XCTAssertEqual(route("xzg://ai?mode=voice"), .ai(voiceMode: true))
    }

    func testUnknownHostIgnored() {
        XCTAssertNil(route("xzg://something-else"))
    }

    func testPureFunctionEntry() {
        XCTAssertEqual(
            AppDeepLink.route(host: "ai", queryItems: [URLQueryItem(name: "mode", value: "voice")]),
            .ai(voiceMode: true))
    }
}
