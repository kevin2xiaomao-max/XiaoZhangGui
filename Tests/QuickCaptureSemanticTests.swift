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
        // 快速记录：真实保存按钮（saveButton）的文案必须为「确认保存」。
        // 不依赖旧版 title: 参数的固定写法——当前实现是按钮 label 上的 Text。
        XCTAssertEqual(
            saveButtonText(in: quickRecord), "确认保存",
            "快速记录保存按钮必须保留「确认保存」显式确认文案"
        )
        XCTAssertTrue(voice.contains("Text(\"确认保存\")"))
    }

    /// 提取 QuickRecordSheet.saveButton 计算属性内的第一个 Text 字面量。
    private func saveButtonText(in source: String) -> String? {
        guard let start = source.range(of: "private var saveButton") else { return nil }
        let tail = source[start.lowerBound...]
        var end = tail.endIndex
        for marker in ["\n    private ", "\n    func ", "\n    @", "\n}"] {
            if let range = tail.range(of: marker), range.lowerBound < end {
                end = range.lowerBound
            }
        }
        let region = String(tail[..<end])
        guard
            let open = region.range(of: "Text(\""),
            let close = region[open.upperBound...].firstIndex(of: "\"")
        else { return nil }
        return String(region[open.upperBound..<close])
    }

    private func source(_ path: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
    }
}
