import XCTest
import SwiftUI
@testable import XiaoZhangGui

/// V3.8 PR-D：UI 一致性 + 动态字体 + 工程质量收口测试。
final class V38QualityCloseoutTests: XCTestCase {

    // MARK: - C1 · 待办空态副文案按 tab 区分（真实业务断言）

    func testEmptyMessageIsTabSpecific() {
        let messages = TodoTab.allCases.map { TodoFilter.emptyMessage(for: $0) }
        XCTAssertEqual(messages.count, TodoTab.allCases.count)
        XCTAssertTrue(messages.allSatisfy { !$0.isEmpty }, "每个 tab 都必须有非空行动指引")
        // 副文案必须 tab 间可区分（原先所有 tab 共用同一句）。
        XCTAssertEqual(Set(messages).count, TodoTab.allCases.count, "各 tab 副文案不得重复")
        XCTAssertTrue(TodoFilter.emptyMessage(for: .today).contains("+"), "今天 tab 应指向新增入口")
    }

    // MARK: - C1 · 金额输入有效性（真实解析断言，含边界与非法输入）

    func testMoneyAmountParsing() {
        XCTAssertEqual(MoneyAmountText.parse("680"), 680)
        XCTAssertEqual(MoneyAmountText.parse("680.5"), 680.5)
        XCTAssertEqual(MoneyAmountText.parse("1,200"), 1200, "千分位逗号应被容忍")
        XCTAssertNil(MoneyAmountText.parse("0"), "0 无效")
        XCTAssertNil(MoneyAmountText.parse("-5"), "负数无效")
        XCTAssertNil(MoneyAmountText.parse("abc"), "非数字无效")
        XCTAssertNil(MoneyAmountText.parse(""), "空串无效")
        XCTAssertNil(MoneyAmountText.parse("6.8.0"), "多点号无效")
    }

    func testMoneyAmountInvalidHintPolicy() {
        XCTAssertFalse(MoneyAmountText.needsInvalidHint(""), "未输入不提示")
        XCTAssertFalse(MoneyAmountText.needsInvalidHint("  "), "纯空白不提示")
        XCTAssertFalse(MoneyAmountText.needsInvalidHint("12"), "有效金额不提示")
        XCTAssertTrue(MoneyAmountText.needsInvalidHint("0"), "0 需要提示")
        XCTAssertTrue(MoneyAmountText.needsInvalidHint("abc"), "非数字需要提示")
        XCTAssertTrue(MoneyAmountText.needsInvalidHint("-3"), "负数需要提示")
    }

    // MARK: - C3 · 动态字体语义化（源码契约）

    func testV371TypographyUsesSemanticStyles() throws {
        let source = try source("XiaoZhangGui/DesignSystem/V371/V371DesignSystem.swift")
        // 截取 Typography 段（到下一个 MARK 之前），只审该段。
        guard let start = source.range(of: "enum Typography {"),
              let end = source[source.startIndex...].range(of: "// MARK: - Shadow") else {
            return XCTFail("Typography 段定位失败")
        }
        let segment = String(source[start.lowerBound..<end.lowerBound])
        XCTAssertTrue(segment.contains(".subheadline"), "heroTitle 必须 subheadline 语义化")
        XCTAssertTrue(segment.contains(".headline"), "sectionTitle 必须 headline 语义化")
        XCTAssertTrue(segment.contains(".callout"), "rowTitle 必须 callout 语义化")
        XCTAssertTrue(segment.contains(".footnote"), "rowSubtitle/time 必须 footnote 语义化")
        XCTAssertTrue(segment.contains(".caption"), "badge/quickAction 必须 caption 语义化")
        // 除展示型 heroNumber 外，Typography 段不得再出现固定字号。
        let fixedSizes = segment.components(separatedBy: ".system(size:").count - 1
        XCTAssertEqual(fixedSizes, 1, "Typography 仅允许 heroNumber（展示型）保留固定字号")
    }

    func testHomeDisplayNumbersScaleWithDynamicType() throws {
        let source = try source("XiaoZhangGui/Features/Home/HomeView.swift")
        XCTAssertTrue(
            source.contains("@ScaledMetric(relativeTo: .largeTitle) private var heroAmountSize"),
            "首页 Hero 金额必须随动态字体缩放（P-C3 回归钉）"
        )
        XCTAssertTrue(
            source.contains("@ScaledMetric(relativeTo: .largeTitle) private var dateNumberSize"),
            "首页日期大数字必须随动态字体缩放"
        )
        // PR-E 后 Hero 金额改为经 V39HeroCard 参数传入缩放字号，日期数字走
        // V38HomeStyle.scaledDateNumber 助手；断言“缩放值确实流入渲染”，而非旧调用形态。
        XCTAssertTrue(
            source.contains("heroAmountSize: heroAmountSize")
                && source.contains("scaledDateNumber(size: dateNumberSize)"),
            "展示型大数字必须通过缩放后的字号构造"
        )
    }

    // MARK: - C4 · 日志统一（无裸 print）

    func testNoBarePrintInProductionTargets() throws {
        // 主 target 中不再允许裸 print（指纹算法字符串除外——那是数据，不是日志）。
        let files = [
            "XiaoZhangGui/Services/LiveActivityManager.swift",
            "XiaoZhangGui/Features/Goods/GoodsView.swift",
            "XiaoZhangGui/DesignSystem/V32/Theme/ThemeStore.swift",
            "XiaoZhangGui/Features/Assistant/AI/Core/AgentCore.swift",
        ]
        for path in files {
            let source = try source(path)
            XCTAssertFalse(
                source.contains("\n        print(") || source.contains("\n            print(") || source.contains("\n                print("),
                "\(path) 不得再出现裸 print（统一 AppLog，隐私可控）"
            )
        }
    }

    // MARK: - C4 · 死代码不复活 + 生产文件迁出实验目录

    func testDeletedDeadCodeFilesStayDeleted() {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // Tests/
            .appendingPathComponent("..")
            .standardized
        let deleted = [
            "XiaoZhangGui/DesignSystem/BusinessComponents.swift",
            "XiaoZhangGui/DesignSystem/V21Components.swift",
            "XiaoZhangGui/DesignSystem/V21Font.swift",
            "XiaoZhangGui/DesignSystem/V21Spacing.swift",
            "XiaoZhangGui/DesignSystem/FloatingDock-UNUSED.md", // 占位防误删语义,FloatingDock.swift 本体保留(Haptic/AppTab 定义)
            "XiaoZhangGui/DesignSystem/V32/V32Components.swift",
            "XiaoZhangGui/Components/TrendChart.swift",
        ]
        for rel in deleted where !rel.hasSuffix("UNUSED.md") {
            XCTAssertFalse(
                FileManager.default.fileExists(atPath: repoRoot.appendingPathComponent(rel).path),
                "\(rel) 是已验证零引用死代码，不得复活"
            )
        }
    }

    func testProductionStateMachineLivesOutsideExperiments() {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("..")
            .standardized
        XCTAssertTrue(
            FileManager.default.fileExists(
                atPath: repoRoot.appendingPathComponent("XiaoZhangGui/DesignSystem/V38/Motion/V38PageMotionState.swift").path
            ),
            "生产状态机必须住在正式目录 DesignSystem/V38/Motion/"
        )
        XCTAssertFalse(
            FileManager.default.fileExists(
                atPath: repoRoot.appendingPathComponent("XiaoZhangGui/Experiments/V38PageMotion/V38PageMotionState.swift").path
            ),
            "Experiments 不得混入生产文件（易被误清理）"
        )
    }

    func testCapabilityGateIsDebugOnly() throws {
        let source = try source("XiaoZhangGui/DesignSystem/V38/Motion/V38CapabilityGate.swift")
        XCTAssertTrue(source.hasPrefix("#if DEBUG") || source.contains("#if DEBUG"),
                      "仅测试引用的实验门控必须整文件 #if DEBUG（Release 剥离）")
    }

    // MARK: - C1 · 裸动效清理（源码契约）

    func testTodoShakeUsesMotionToken() throws {
        let source = try source("XiaoZhangGui/Features/Todo/TodoView.swift")
        XCTAssertFalse(
            source.contains(".easeInOut(duration: 0.32)"),
            "不得绕过 Motion Token 写裸时长（V371 注释明令的纪律）"
        )
        XCTAssertTrue(
            source.contains("reduceMotion ? nil : V38MotionTokens.animation(for: .contentChange, reduceMotion: false), value: shakeTrigger"),
            "抖动触发动画必须走 contentChange token（含 Reduce Motion 降级）"
        )
    }

    private func source(_ path: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
    }
}
