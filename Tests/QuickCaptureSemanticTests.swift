import XCTest
@testable import XiaoZhangGui

final class QuickCaptureSemanticTests: XCTestCase {
    func testSharedStatusLanguage() {
        XCTAssertEqual(QuickCaptureSemantic.listening, "正在听…")
        XCTAssertEqual(QuickCaptureSemantic.processing, "正在整理…")
        XCTAssertEqual(QuickCaptureSemantic.ready, "请确认将保存的内容")
        XCTAssertEqual(QuickCaptureSemantic.saving, "正在保存…")
        XCTAssertEqual(QuickCaptureSemantic.savedMessage(destination: "营业额"), "已保存到：营业额")
        XCTAssertEqual(QuickCaptureSemantic.failed, "保存失败，请重试")
    }

    func testQuickRecordFailureKeepsTheSheetOpen() throws {
        let source = try source("XiaoZhangGui/Features/QuickRecord/QuickRecordSheet.swift")
        XCTAssertTrue(source.contains("errorMessage = QuickCaptureSemantic.failed"))
        XCTAssertFalse(source.contains("catch {\n            Haptic.error()\n            dismiss()"))
    }

    func testCreateFlowsKeepExplicitConfirmationLanguage() throws {
        let quickRecord = try source("XiaoZhangGui/Features/QuickRecord/QuickRecordSheet.swift")
        let voice = try source("XiaoZhangGui/Features/Voice/VoiceView.swift")
        XCTAssertTrue(quickRecord.contains("title: \"确认保存\""))
        XCTAssertTrue(voice.contains("Text(\"确认保存\")"))
    }

    private func source(_ path: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
    }
}
