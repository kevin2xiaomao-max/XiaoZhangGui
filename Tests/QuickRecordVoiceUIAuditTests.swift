import XCTest

/// V3.3 真机 hotfix：QuickRecordSheet 监听态 UI 审计。
///
/// 真机问题：开始监听后同时出现两个麦克风（监听状态卡 + 「一句话」右侧按钮），
/// 且监听麦克风带 repeatForever 缩放动画持续跳动。
/// 修复要求：监听期间头部麦克风整体不渲染，全屏唯一麦克风入口是监听状态卡；
/// 停止 / 取消移入状态卡；全程静态样式；所有结束路径由 voice.status 驱动 UI 恢复。
///
/// 说明：纯 SwiftUI 视图层级在逻辑测试中不做渲染比对，这里直接审计被测源码
/// （xcodebuild test 在同一工作区运行，#filePath 可定位到仓库内源文件）。
final class QuickRecordVoiceUIAuditTests: XCTestCase {

    private func sheetSource() throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // Tests/
            .appendingPathComponent("..")
            .standardized
        return try String(
            contentsOf: root.appendingPathComponent("XiaoZhangGui/Features/QuickRecord/QuickRecordSheet.swift"),
            encoding: .utf8
        )
    }

    /// idle 时头部 mic.fill 正常渲染；listening 时头部麦克风按钮绝对不渲染。
    func testMicVisibleWhenIdleAndHiddenWhileListening() throws {
        let sheet = try sheetSource()
        XCTAssertTrue(
            sheet.contains("if !voice.isListening {"),
            "监听期间「一句话」右侧麦克风按钮必须整体不渲染"
        )
        XCTAssertTrue(
            sheet.contains("mic.fill"),
            "非监听态必须保留 mic.fill 入口"
        )
        XCTAssertFalse(
            sheet.contains(#"voice.isListening ? "stop.fill" : "mic.fill""#),
            "头部按钮不得再承担监听态切换（停止职责已移入监听状态卡）"
        )
    }

    /// 监听状态卡在非 idle 时可见，是监听期间全屏唯一麦克风视觉入口。
    func testListeningStateCardVisible() throws {
        let sheet = try sheetSource()
        XCTAssertTrue(
            sheet.contains("if voice.status != .idle {"),
            "监听状态卡必须在非 idle 时展示"
        )
        XCTAssertTrue(
            sheet.contains("正在听…说一件事"),
            "「正在听…说一件事」监听标题必须保留"
        )
    }

    /// 监听麦克风禁止 repeatForever scale / bounce / pulse 动画与布局抖动。
    func testNoRepeatForeverPulseAnimation() throws {
        let sheet = try sheetSource()
        XCTAssertFalse(
            sheet.contains(".repeatForever("),
            "QuickRecord 监听 UI 禁止 repeatForever 脉冲动画"
        )
        XCTAssertFalse(
            sheet.contains("scaleEffect"),
            "禁止 scaleEffect 造成图标跳动 / 布局抖动"
        )
    }

    /// 停止 / 取消在状态卡内；所有结束路径（手动停止、静音自动结束、取消、
    /// recognition final、权限拒绝、speech error）都把 voice.status 置为
    /// 非 listening，由同一状态驱动：状态卡消失、头部 mic 恢复、文字留在输入框。
    func testStopAndCancelWiredAndAllEndPathsRestoreNonListeningUI() throws {
        let sheet = try sheetSource()
        XCTAssertTrue(
            sheet.contains("voice.stop()"),
            "监听状态卡必须提供手动停止（stop → final → 非监听态）"
        )
        XCTAssertTrue(
            sheet.contains("voice.cancel()"),
            "监听状态卡必须提供取消"
        )
        XCTAssertTrue(
            sheet.contains("onChange(of: voice.liveTranscript)"),
            "partial / final 转写必须继续写入输入框"
        )
        // 录音器全部结束分支：.idle（final / 取消）、.empty、.denied、.failed。
        XCTAssertTrue(sheet.contains("self.status = .idle"), "recognition final / 取消必须回到非监听态")
        XCTAssertTrue(sheet.contains("self.status = .empty"), "静音无内容结束必须回到非监听态")
        XCTAssertTrue(sheet.contains("self.status = .denied"), "权限拒绝必须回到非监听态")
        XCTAssertTrue(sheet.contains("self.status = .failed"), "speech error 必须回到非监听态")
    }
}
