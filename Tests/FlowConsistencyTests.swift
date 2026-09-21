import XCTest

final class FlowConsistencyTests: XCTestCase {
    private func source(_ path: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
    }

    func testCreateAndFailureLanguageStaysAlignedAcrossQuickVoiceAndEditors() throws {
        let quick = try source("XiaoZhangGui/Features/QuickRecord/QuickRecordSheet.swift")
        let voice = try source("XiaoZhangGui/Features/Voice/VoiceViewModel.swift")
        XCTAssertTrue(quick.contains("QuickCaptureSemantic.savedMessage"))
        XCTAssertTrue(quick.contains("QuickCaptureSemantic.failed"))
        XCTAssertTrue(voice.contains("QuickCaptureSemantic.failed"))

        for path in [
            "XiaoZhangGui/Features/Todo/TodoEditorSheet.swift",
            "XiaoZhangGui/Features/Customer/CustomerEditorSheet.swift",
            "XiaoZhangGui/Features/Expiry/ExpiryEditorSheet.swift",
            "XiaoZhangGui/Features/Performance/MoneyEditorSheet.swift",
            "XiaoZhangGui/Features/Memo/MemoEditorSheet.swift"
        ] {
            let editor = try source(path)
            XCTAssertTrue(editor.contains("Haptic.success()\n            dismiss()"), path)
            XCTAssertTrue(editor.contains("保存失败"), path)
        }
    }

    func testStateActionsUseTheExistingRepositoriesAndConsistentFeedback() throws {
        let todo = try source("XiaoZhangGui/Features/Todo/TodoView.swift")
        let schedule = try source("XiaoZhangGui/Features/Schedule/ScheduleView.swift")
        let expiry = try source("XiaoZhangGui/Features/Expiry/ExpiryView.swift")
        let customer = try source("XiaoZhangGui/Features/Customer/CustomerView.swift")

        XCTAssertTrue(todo.contains("TodoRepository(context: context).toggleComplete"))
        XCTAssertTrue(schedule.contains("TodoRepository(context: modelContext).toggleComplete"))
        XCTAssertTrue(expiry.contains("ExpiryRepository(context: context).toggleReturn"))
        XCTAssertTrue(customer.contains("CustomerRepository(context: context).advanceStatus"))
        XCTAssertTrue(todo.contains("Haptic.success()"))
        XCTAssertTrue(schedule.contains("Haptic.success()"))
        XCTAssertTrue(expiry.contains("Haptic.success()"))
        XCTAssertTrue(customer.contains("已完成配送"))
    }

    func testAICreateStillUsesActionCardConfirmation() throws {
        let aiSource = try source("XiaoZhangGui/Features/Assistant/AI/UI/ActionCardView.swift")
        let viewModel = try source("XiaoZhangGui/Features/Assistant/AI/UI/AIConversationViewModel.swift")
        let core = try source("XiaoZhangGui/Features/Assistant/AI/Core/AgentCore.swift")
        XCTAssertTrue(aiSource.contains("accessibilityIdentifier(\"ai.action-card.confirm\")"))
        XCTAssertTrue(aiSource.contains("onConfirm()"))
        XCTAssertTrue(aiSource.contains("待你确认"))
        XCTAssertFalse(aiSource.contains("onConfirm()\n                Haptic.success()"))
        XCTAssertTrue(core.contains("proposal.status = .confirmed"))
        XCTAssertTrue(viewModel.contains("if updated.status == .executed { Haptic.success() }"))
    }

    func testTodoCompletionFeedbackWaitsForRepositorySuccessAcrossEntryPoints() throws {
        for path in [
            "XiaoZhangGui/Features/Home/HomeView.swift",
            "XiaoZhangGui/Features/Schedule/ScheduleView.swift",
            "XiaoZhangGui/Features/Todo/TodoView.swift"
        ] {
            let source = try source(path)
            XCTAssertTrue(source.contains("try TodoRepository"), path)
            XCTAssertTrue(source.contains("Haptic.error()"), path)
            XCTAssertTrue(source.contains("状态未改变"), path)
        }
    }
}
