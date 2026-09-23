import XCTest

/// V3.7.1（2026-09-23 重写，原 V3.3 hotfix 审计已按 MD STEP 7 标记过时）：
/// - V3.7.1 冻结 IA：AI 不再是底部 Tab，首页保留**唯一紧凑入口**
///   （AICommandEntry，「✦ 问小掌柜…」），不得内嵌完整 AI 对话 UI；
/// - 右上角必须保留麦克风「一句话快速记录」入口并继续弹出 QuickRecord；
/// - 小掌柜短语音面板展示时必须隐藏底部 Tab 栏（Dock）。
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

    /// V3.7.1：AI 不再是 Tab，首页必须且只能有一个紧凑 AI 入口。
    func testHomeHasExactlyOneCompactAssistantEntry() throws {
        let home = try source("XiaoZhangGui/Features/Home/HomeView.swift")
        XCTAssertTrue(
            home.contains("AICommandEntry"),
            "V3.7.1 首页必须保留唯一的紧凑 AI 入口（AICommandEntry）"
        )
        XCTAssertFalse(
            home.contains("AIChatView"),
            "首页不得内嵌完整 AI 对话视图"
        )
        XCTAssertEqual(
            home.components(separatedBy: "AICommandEntry").count - 1, 1,
            "紧凑 AI 入口在首页只能出现一次"
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

    func testAIChatViewHidesTabBarWhileVoicePanelPresented() throws {
        let aiChat = try source("XiaoZhangGui/Features/Assistant/AI/UI/AIChatView.swift")
        XCTAssertTrue(
            aiChat.contains(".toolbar(model.showVoicePanel ? .hidden : .visible, for: .tabBar)"),
            "短语音面板展示期间必须隐藏底部 Tab 栏，关闭后恢复"
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
