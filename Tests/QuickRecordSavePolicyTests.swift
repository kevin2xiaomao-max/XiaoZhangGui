import XCTest
@testable import XiaoZhangGui

/// V3.8 P0-A3：快捷记录提交闸门测试。
///
/// 修复前：保存仅以「文本非空」为闸门，保存成功到自动关闭的 0.6s 窗口内
/// 按钮仍可点击，快速双击会产生重复账目。
/// 修复后：idle → saving → saved / failed 状态机；saving 与 saved 拒绝提交，
/// failed 允许安全重试。
final class QuickRecordSavePolicyTests: XCTestCase {

    // MARK: - canSave（内容闸门，行为不变）

    func testCanSaveRequiresNonEmptyText() {
        XCTAssertFalse(QuickRecordSavePolicy.canSave(""))
        XCTAssertFalse(QuickRecordSavePolicy.canSave("   \n "))
        XCTAssertTrue(QuickRecordSavePolicy.canSave("今天美团680"))
    }

    // MARK: - canCommit（阶段闸门）

    func testIdleWithTextCanCommit() {
        XCTAssertTrue(QuickRecordSavePolicy.canCommit(text: "今天美团680", phase: .idle))
    }

    func testIdleWithoutTextCannotCommit() {
        XCTAssertFalse(QuickRecordSavePolicy.canCommit(text: "", phase: .idle))
        XCTAssertFalse(QuickRecordSavePolicy.canCommit(text: "  ", phase: .idle))
    }

    func testSavingRejectsDuplicateCommit() {
        XCTAssertFalse(
            QuickRecordSavePolicy.canCommit(text: "今天美团680", phase: .saving),
            "提交中必须拒绝再次提交（连点防重）"
        )
    }

    func testSavedRejectsCommitInDismissWindow() {
        XCTAssertFalse(
            QuickRecordSavePolicy.canCommit(text: "今天美团680", phase: .saved),
            "保存成功后的自动关闭窗口内必须拒绝重复提交（双击防重根因）"
        )
    }

    func testFailedAllowsSafeRetry() {
        XCTAssertTrue(
            QuickRecordSavePolicy.canCommit(text: "今天美团680", phase: .failed),
            "保存失败必须允许重试"
        )
    }

    func testFailedWithoutTextCannotRetry() {
        XCTAssertFalse(QuickRecordSavePolicy.canCommit(text: "", phase: .failed))
    }

    // MARK: - 源码契约：commit 必须走阶段闸门，按钮必须绑定 canCommit

    func testCommitAndButtonUsePhaseGate() throws {
        let source = try source("XiaoZhangGui/Features/QuickRecord/QuickRecordSheet.swift")
        XCTAssertTrue(
            source.contains("guard QuickRecordSavePolicy.canCommit(text: trimmed, phase: savePhase) else { return }"),
            "commit() 必须以 canCommit 阶段闸门开头（P0-A3 回归钉）"
        )
        XCTAssertTrue(
            source.contains(".disabled(!canCommit)"),
            "保存按钮必须绑定 canCommit（P0-A3 回归钉）"
        )
    }

    private func source(_ path: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
    }
}
