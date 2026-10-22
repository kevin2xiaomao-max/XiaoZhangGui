import XCTest

final class Phase52AccessibilityMotionTests: XCTestCase {
    private func source(_ path: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
    }

    func testReduceMotionBranchesRemainExplicitForCoreInteractions() throws {
        let home = try source("XiaoZhangGui/Features/Home/HomeView.swift")
        let drawer = try source("XiaoZhangGui/Features/Home/V35SideUtilityDrawer.swift")
        let todo = try source("XiaoZhangGui/Features/Todo/TodoView.swift")
        let schedule = try source("XiaoZhangGui/Features/Schedule/ScheduleView.swift")
        let customer = try source("XiaoZhangGui/Features/Customer/CustomerView.swift")
        // V3.8 重建：Home 使用生产级 V38MotionTokens（Reduce Motion 时返回 nil，即静态呈现）。
        XCTAssertTrue(
            home.contains("V38MotionTokens.animation(for:") && home.contains("reduceMotion: reduceMotion"),
            "Home 必须显式处理 Reduce Motion（V38MotionTokens）"
        )
        XCTAssertTrue(drawer.contains("reduceMotion ? .easeOut(duration: 0.16)"))
        // V3.8 重建 R2：Todo 使用生产级 V38MotionTokens（Reduce Motion 时返回 nil，即静态呈现）。
        XCTAssertTrue(
            todo.contains("V38MotionTokens.animation(for:") && todo.contains("reduceMotion: reduceMotion"),
            "Todo 必须显式处理 Reduce Motion（V38MotionTokens）"
        )
        XCTAssertTrue(schedule.contains("V371.Motion.resolve(.spring, reduceMotion: reduceMotion)"))
        XCTAssertTrue(customer.contains("reduceMotion ? nil : V371.Motion.spring"))
    }

    func testCoreRowsKeepAccessibleHitTargetsAndStateLabels() throws {
        let drawer = try source("XiaoZhangGui/Features/Home/V35SideUtilityDrawer.swift")
        let todo = try source("XiaoZhangGui/Features/Todo/TodoView.swift")
        let actionCard = try source("XiaoZhangGui/Features/Assistant/AI/UI/ActionCardView.swift")
        XCTAssertTrue(drawer.contains("frame(minHeight: 44)"))
        XCTAssertTrue(todo.contains("accessibilityLabel(\"删除待办\")"))
        XCTAssertTrue(actionCard.contains("正在保存…"))
        XCTAssertTrue(actionCard.contains("重试保存"))
    }

    func testRapidInteractionGuardsRemainInPlace() throws {
        let todo = try source("XiaoZhangGui/Features/Todo/TodoView.swift")
        let ai = try source("XiaoZhangGui/Features/Assistant/AI/UI/AIConversationViewModel.swift")
        let card = try source("XiaoZhangGui/Features/Assistant/AI/UI/ActionCardView.swift")
        XCTAssertTrue(todo.contains("guard !togglingIDs.contains(pid) else { return }"))
        XCTAssertTrue(ai.contains("if updated.status == .executed"))
        XCTAssertTrue(card.contains("proposal.status != .failed"))
    }
}
