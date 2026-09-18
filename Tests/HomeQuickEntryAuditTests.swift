import XCTest

/// V3.3 真机 hotfix 首页 / AI 页结构审计：
/// - 首页中部重复的「问小掌柜…」AI 大卡必须移除（底部 Dock 已有永久「小掌柜」入口）；
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
