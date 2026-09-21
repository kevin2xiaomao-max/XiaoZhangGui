import XCTest

final class SaveReliabilityTests: XCTestCase {
    private let editors = [
        "XiaoZhangGui/Features/Todo/TodoEditorSheet.swift",
        "XiaoZhangGui/Features/Customer/CustomerEditorSheet.swift",
        "XiaoZhangGui/Features/Expiry/ExpiryEditorSheet.swift",
        "XiaoZhangGui/Features/Performance/MoneyEditorSheet.swift",
        "XiaoZhangGui/Features/Memo/MemoEditorSheet.swift"
    ]

    func testAllBusinessEditorsKeepFailureVisibleAndRetryable() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        for path in editors {
            let source = try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
            XCTAssertTrue(source.contains("@State private var saveError: String?"), path)
            XCTAssertTrue(source.contains(".alert(\"保存失败\""), path)
            XCTAssertTrue(source.contains("Button(\"重试\") { save() }"), path)
            XCTAssertTrue(source.contains("saveError = "), path)
            XCTAssertTrue(source.contains("Haptic.error()"), path)
        }
    }

    func testDismissOnlyAppearsAfterRepositorySuccessBlock() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        for path in editors {
            let source = try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
            let saveStart = try XCTUnwrap(source.range(of: "private func save()"))
            let saveSource = String(source[saveStart.lowerBound...])
            XCTAssertTrue(saveSource.contains("try "), path)
            XCTAssertTrue(saveSource.contains("Haptic.success()\n            dismiss()"), path)
            XCTAssertTrue(saveSource.contains("catch {\n            Haptic.error()"), path)
        }
    }
}
