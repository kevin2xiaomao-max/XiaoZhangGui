import XCTest

/// V3.3 真机 hotfix 首页 / AI 页结构审计：
/// - 首页中部重复的「问小掌柜…」AI 大卡必须移除（底部 Dock 已有永久「小掌柜」入口）；
/// - 右上角必须保留麦克风「一句话快速记录」入口并继续弹出 QuickRecord；
/// - V3.6.1 使用自定义悬浮底栏（V36FloatingTabBar），AI 页必须始终隐藏系统 TabBar；
///   曾用 showVoicePanel 三元表达式在语音面板关闭时把系统栏设回 visible，导致双底栏 P0，
///   该三元表达式不得回归。
///
/// 说明：纯 SwiftUI 视图层级在逻辑测试中不做渲染比对，这里直接审计被测源码
/// （xcodebuild test 在同一工作区运行，#filePath 可定位到仓库内源文件）。
final class HomeQuickEntryAuditTests: XCTestCase {

    private func repositoryRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // Tests/
            .appendingPathComponent("..")
            .standardized
    }

    private func source(_ relativePath: String) throws -> String {
        try String(
            contentsOf: repositoryRoot().appendingPathComponent(relativePath),
            encoding: .utf8
        )
    }

    func testHomeHasNoDuplicateAssistantCard() throws {
        let home = try source("XiaoZhangGui/Features/Home/HomeView.swift")
        XCTAssertFalse(
            home.contains("问小掌柜"),
            "首页中部重复的「问小掌柜…」AI 卡必须移除"
        )
        XCTAssertFalse(
            home.contains("assistantEntry"),
            "重复 AI 卡的视图实现必须一并删除"
        )
    }

    func testHomeHeaderKeepsMicQuickRecordEntry() throws {
        let home = try source("XiaoZhangGui/Features/Home/HomeView.swift")
        XCTAssertTrue(
            home.contains("mic.fill"),
            "右上角快速记录入口必须使用麦克风图标"
        )
        XCTAssertTrue(
            home.contains("showQuickRecord = true"),
            "麦克风必须继续弹出 QuickRecord 半屏面板"
        )
    }

    func testAIChatViewAlwaysHidesSystemTabBar_NoDoubleBottomBar() throws {
        let aiChat = try source("XiaoZhangGui/Features/Assistant/AI/UI/AIChatView.swift")
        XCTAssertTrue(
            aiChat.contains(".toolbar(.hidden, for: .tabBar)"),
            "V36 自定义悬浮底栏下，系统 TabBar 必须始终隐藏，语音面板展示/关闭均不得恢复"
        )
        XCTAssertFalse(
            aiChat.contains("showVoicePanel ? .hidden : .visible"),
            "旧三元表达式在语音面板关闭时把系统 TabBar 设回 visible，是双底栏 P0 的根因，不得回归"
        )
    }

    func testQuickRecordSaveGateIsTrimmedNonEmpty() throws {
        let sheet = try source("XiaoZhangGui/Features/QuickRecord/QuickRecordSheet.swift")
        XCTAssertTrue(
            sheet.contains("QuickRecordSavePolicy.canSave"),
            "保存按钮必须以「trim 后非空」为唯一闸门，识别结果不得禁用保存"
        )
    }
}
