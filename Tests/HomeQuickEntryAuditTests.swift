import XCTest
import Foundation

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
        // 只统计真实组件调用：先剔除 // 行注释，再匹配「类型名 + (/{」
        // 的调用语法。注释中提及类型名不计入——历史误判即源于文件头注释。
        let codeOnly = home
            .components(separatedBy: .newlines)
            .map { line -> String in
                guard let commentStart = line.range(of: "//") else { return line }
                return String(line[..<commentStart.lowerBound])
            }
            .joined(separator: "\n")
        let pattern = try NSRegularExpression(pattern: #"AICommandEntry\s*[\({]"#)
        let matches = pattern.matches(
            in: codeOnly,
            range: NSRange(codeOnly.startIndex..., in: codeOnly)
        )
        XCTAssertEqual(
            matches.count, 1,
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
        let rootView = try source("XiaoZhangGui/App/RootView.swift")
        // V3.7.1：系统 TabBar 由 RootView 在 TabView 级别统一隐藏；
        // AIChatView 禁止复写 tabBar 可见性——旧三元表达式曾把 ai.input
        // 挤出无障碍树（V3.6.1 同因），此处断言该禁区不回归。
        XCTAssertFalse(
            aiChat.contains("for: .tabBar"),
            "AIChatView 不得复写系统 TabBar 可见性（a11y 回归禁区）"
        )
        XCTAssertTrue(
            rootView.contains(".toolbar(.hidden, for: .tabBar)"),
            "RootView 必须在 TabView 级别兜底隐藏系统 TabBar"
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
