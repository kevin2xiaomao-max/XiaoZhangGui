import XCTest
@testable import XiaoZhangGui

/// 成功装饰必须服从真实执行结果，不能把预览确认和幂等跳过当成落库。
final class V400RecordedStampTests: XCTestCase {
    private func card(_ status: ProposalStatus, preview: Bool = false,
                      acknowledged: Bool = false) -> ActionCardView {
        let call = ToolCall(id: ToolCall.makeID(), name: .createMemo,
                            arguments: .createMemo(MemoArguments(title: "测试", content: "测试")))
        return ActionCardView(
            proposal: ActionProposal(call: call, status: status, isPreviewOnly: preview,
                                     previewAcknowledged: acknowledged),
            onConfirm: {}, onModify: {}, onCancel: {})
    }

    func testSuccessfulLiveExecutionShowsStamp() {
        XCTAssertTrue(card(.executed).showsRecordedStamp)
    }

    func testEveryUnsuccessfulStateHidesStamp() {
        for status in [ProposalStatus.pending, .confirmed, .cancelled, .failed, .duplicate] {
            XCTAssertFalse(card(status).showsRecordedStamp, "\(status) 不得显示保存成功")
        }
    }

    func testPreviewNeverClaimsRecordedEvenWithExecutedStatus() {
        XCTAssertFalse(card(.executed, preview: true).showsRecordedStamp)
        XCTAssertFalse(card(.executed, acknowledged: true).showsRecordedStamp)
        XCTAssertFalse(card(.confirmed, preview: true, acknowledged: true).showsRecordedStamp)
    }
}
