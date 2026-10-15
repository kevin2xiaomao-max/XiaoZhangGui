import XCTest
@testable import XiaoZhangGui

/// `Docs/V38-Page-Motion-Spec.md` §2 / G5：待办勾选状态机的转换规则。
/// 纯逻辑测试，不碰 Repository / SwiftData。
final class V38PageMotionStateTests: XCTestCase {

    func testInitialIdleUnchecked() {
        let s = V38PageMotionState(isDone: false)
        XCTAssertEqual(s.phase, .idle(isDone: false))
        XCTAssertFalse(s.showsChecked)
        XCTAssertFalse(s.isSaving)
        XCTAssertNil(s.failureMessage)
    }

    func testRequestToggleEntersSavingNotChecked() {
        var s = V38PageMotionState(isDone: false)
        s.requestToggle()
        XCTAssertEqual(s.phase, .saving(intendedDone: true))
        // G5：保存成功前不许展示完成态
        XCTAssertFalse(s.showsChecked)
        XCTAssertTrue(s.isSaving)
    }

    func testSaveSucceededOnlyFromSaving() {
        var s = V38PageMotionState(isDone: false)
        s.saveSucceeded() // 非 saving 态的成功回执必须被忽略
        XCTAssertEqual(s.phase, .idle(isDone: false))
        XCTAssertFalse(s.showsChecked)

        s.requestToggle()
        s.saveSucceeded()
        XCTAssertEqual(s.phase, .idle(isDone: true))
        XCTAssertTrue(s.showsChecked)
    }

    func testSaveFailedKeepsRetryable() {
        var s = V38PageMotionState(isDone: false)
        s.requestToggle()
        s.saveFailed()
        XCTAssertEqual(s.phase, .failed(intendedDone: true))
        XCTAssertFalse(s.showsChecked) // 失败不宣告成功
        XCTAssertNotNil(s.failureMessage)

        // 重试走同一入口
        s.requestToggle()
        XCTAssertEqual(s.phase, .saving(intendedDone: true))
        s.saveSucceeded()
        XCTAssertTrue(s.showsChecked)
    }

    func testSaveFailedOnlyFromSaving() {
        var s = V38PageMotionState(isDone: true)
        s.saveFailed() // 非 saving 态的失败回执必须被忽略
        XCTAssertEqual(s.phase, .idle(isDone: true))
        XCTAssertTrue(s.showsChecked)
    }

    func testDismissFailureRestoresPreviousConfirmedState() {
        var s = V38PageMotionState(isDone: false)
        s.requestToggle()
        s.saveFailed()
        s.dismissFailure()
        XCTAssertEqual(s.phase, .idle(isDone: false))

        // 已完成行取消勾选失败 → 回到已完成
        var s2 = V38PageMotionState(isDone: true)
        s2.requestToggle() // 意图取消
        s2.saveFailed()
        s2.dismissFailure()
        XCTAssertEqual(s2.phase, .idle(isDone: true))
        XCTAssertTrue(s2.showsChecked)
    }

    func testRapidDoubleToggleIgnoredWhileSaving() {
        // G4 鲁棒性：saving 中连点不产生第二个在途保存
        var s = V38PageMotionState(isDone: false)
        s.requestToggle()
        s.requestToggle()
        s.requestToggle()
        XCTAssertEqual(s.phase, .saving(intendedDone: true))
        s.saveSucceeded()
        XCTAssertEqual(s.phase, .idle(isDone: true))
    }

    func testUncheckFlow() {
        var s = V38PageMotionState(isDone: true)
        s.requestToggle()
        XCTAssertEqual(s.phase, .saving(intendedDone: false))
        // saving 期间不展示任何完成态，由 isSaving 驱动"保存中" spinner（实现契约：
        // 只有 idle(isDone: true) 才是"已完成"）
        XCTAssertTrue(s.isSaving)
        XCTAssertFalse(s.showsChecked)
        s.saveSucceeded()
        XCTAssertEqual(s.phase, .idle(isDone: false))
        XCTAssertFalse(s.showsChecked)
    }
}
