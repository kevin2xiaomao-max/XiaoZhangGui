import XCTest
@testable import XiaoZhangGui

/// V3.3 真机 hotfix：小掌柜短语音面板展示 / 聆听期间底部 Dock 必须隐藏，
/// 取消或关闭（含失败后「填入文字」）后必须恢复，面板不再被 Dock 压住。
@MainActor
final class AIVoiceDockTests: XCTestCase {

    private func makeModel() -> AIConversationViewModel {
        let (agent, _, _, _) = AITestFactory.preview()
        return AIConversationViewModel(agent: agent)
    }

    /// 语音面板展示（含聆听 / 失败态）时：Dock hidden
    func testDockHiddenWhileVoicePanelPresented() {
        let model = makeModel()
        XCTAssertFalse(model.isBottomDockHidden)
        model.startVoice()
        XCTAssertTrue(model.showVoicePanel)
        XCTAssertTrue(model.isBottomDockHidden)
        model.cancelVoice()
    }

    /// 取消语音后：Dock restored
    func testDockRestoredAfterVoiceCancelled() {
        let model = makeModel()
        model.startVoice()
        XCTAssertTrue(model.isBottomDockHidden)
        model.cancelVoice()
        XCTAssertFalse(model.showVoicePanel)
        XCTAssertFalse(model.isBottomDockHidden)
    }

    /// 失败后「填入文字」关闭面板：Dock restored
    func testDockRestoredAfterTranscriptRetainedToInput() {
        let model = makeModel()
        model.startVoice()
        XCTAssertTrue(model.isBottomDockHidden)
        model.retainVoiceTranscriptToInput()
        XCTAssertFalse(model.showVoicePanel)
        XCTAssertFalse(model.isBottomDockHidden)
    }
}
