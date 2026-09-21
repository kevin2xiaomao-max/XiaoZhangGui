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
        XCTAssertTrue(home.contains("V32Motion.resolve(.fade, reduceMotion: reduceMotion)"))
        XCTAssertTrue(drawer.contains("reduceMotion ? .easeOut(duration: 0.16)"))
        XCTAssertTrue(todo.contains("V32Motion.resolve(.spring, reduceMotion: reduceMotion)"))
        XCTAssertTrue(schedule.contains("V32Motion.resolve(.spring, reduceMotion: reduceMotion)"))
        XCTAssertTrue(customer.contains("reduceMotion ? nil : V32Motion.softSpring"))
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
