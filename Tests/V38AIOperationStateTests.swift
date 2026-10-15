import XCTest
@testable import XiaoZhangGui

// MARK: - V38AIOperationMachine 单元测试（纯逻辑状态机）
//
// 锁定展示层安全规则：Failed 不得直接转 Verified、未确认不得转 Executing、
// 取消/失败保留草稿。全部纯内存，不碰 AI / Repository / SwiftData。

final class V38AIOperationStateTests: XCTestCase {

    // MARK: - 状态枚举完整性

    func testAllEightStatesPresent() {
        let states = V38AIOperationState.allCases
        XCTAssertEqual(states.count, 8)
        XCTAssertTrue(states.contains(.idle))
        XCTAssertTrue(states.contains(.listening))
        XCTAssertTrue(states.contains(.thinking))
        XCTAssertTrue(states.contains(.draftPreview))
        XCTAssertTrue(states.contains(.awaitingConfirmation))
        XCTAssertTrue(states.contains(.executing))
        XCTAssertTrue(states.contains(.verified))
        XCTAssertTrue(states.contains(.failed))
    }

    // MARK: - 合法转换表穷举

    /// 期望的全部 19 条合法转换（与 V38AIOperationMachine.canTransition 一致）。
    private var expectedLegalPairs: Set<String> {
        let pairs: [(V38AIOperationState, V38AIOperationState)] = [
            (.idle, .listening),
            (.listening, .thinking), (.listening, .idle),
            (.thinking, .draftPreview), (.thinking, .failed), (.thinking, .idle),
            (.draftPreview, .awaitingConfirmation), (.draftPreview, .thinking),
            (.draftPreview, .idle), (.draftPreview, .failed),
            (.awaitingConfirmation, .executing), (.awaitingConfirmation, .draftPreview),
            (.executing, .verified), (.executing, .failed),
            (.verified, .idle), (.verified, .listening),
            (.failed, .draftPreview), (.failed, .thinking), (.failed, .idle),
        ]
        return Set(pairs.map { "\($0.rawValue)->\($1.rawValue)" })
    }

    func testTransitionTableMatchesExpectedPairs() {
        var actual = Set<String>()
        for from in V38AIOperationState.allCases {
            for to in V38AIOperationState.allCases {
                if V38AIOperationMachine.canTransition(from: from, to: to) {
                    actual.insert("\(from.rawValue)->\(to.rawValue)")
                }
            }
        }
        XCTAssertEqual(actual, expectedLegalPairs, "合法转换表与期望集合不一致")
    }

    // MARK: - 核心安全规则

    func testHappyPathEndToEnd() throws {
        var m = V38AIOperationMachine()
        for next in [V38AIOperationState.listening, .thinking, .draftPreview,
                     .awaitingConfirmation, .executing, .verified, .idle] as [V38AIOperationState] {
            try m.advance(to: next)
        }
        XCTAssertEqual(m.state, .idle)
    }

    func testFailedCannotTransitionDirectlyToVerified() {
        var m = V38AIOperationMachine(state: .failed, draft: .placeholder)
        XCTAssertThrowsError(try m.advance(to: .verified)) { error in
            XCTAssertEqual(error as? V38AITransitionError,
                           V38AITransitionError(from: .failed, to: .verified))
        }
        XCTAssertEqual(m.state, .failed, "非法转换后状态必须不变")
    }

    func testExecutingRequiresConfirmation() {
        // 草稿预览态直接执行 → 非法。
        var fromDraft = V38AIOperationMachine(state: .draftPreview, draft: .placeholder)
        XCTAssertThrowsError(try fromDraft.advance(to: .executing))
        // 思考态直接执行 → 非法。
        var fromThinking = V38AIOperationMachine(state: .thinking)
        XCTAssertThrowsError(try fromThinking.advance(to: .executing))
        // 只有等待确认态可以进入执行。
        var confirmed = V38AIOperationMachine(state: .awaitingConfirmation, draft: .placeholder)
        XCTAssertNoThrow(try confirmed.advance(to: .executing))
        XCTAssertEqual(confirmed.state, .executing)
    }

    func testVerifiedOnlyFromExecuting() {
        // 等待确认态直接宣告成功 → 非法（未执行不得宣告成功）。
        var awaiting = V38AIOperationMachine(state: .awaitingConfirmation, draft: .placeholder)
        XCTAssertThrowsError(try awaiting.advance(to: .verified))
        // 失败态直接宣告成功 → 非法。
        var failed = V38AIOperationMachine(state: .failed, draft: .placeholder)
        XCTAssertThrowsError(try failed.advance(to: .verified))
    }

    // MARK: - 草稿语义

    func testCancelKeepsDraft() throws {
        var m = V38AIOperationMachine()
        try m.advance(to: .listening)
        try m.advance(to: .thinking)
        try m.advance(to: .draftPreview)
        try m.advance(to: .awaitingConfirmation)
        XCTAssertNotNil(m.draft)
        // 取消 → 退回草稿预览，草稿保留。
        try m.advance(to: .draftPreview)
        XCTAssertEqual(m.state, .draftPreview)
        XCTAssertNotNil(m.draft, "取消必须保留草稿")
    }

    func testFailedRetryKeepsDraft() throws {
        var m = V38AIOperationMachine()
        try m.advance(to: .listening)
        try m.advance(to: .thinking)
        try m.advance(to: .draftPreview)
        try m.advance(to: .awaitingConfirmation)
        try m.advance(to: .executing)
        // 执行失败 → 失败态，草稿保留。
        try m.advance(to: .failed)
        XCTAssertNotNil(m.draft)
        // 重试 → 草稿预览，草稿仍在。
        try m.advance(to: .draftPreview)
        XCTAssertNotNil(m.draft, "失败重试必须保留草稿")
    }

    func testVerifiedConsumesDraft() throws {
        var m = V38AIOperationMachine()
        try m.advance(to: .listening)
        try m.advance(to: .thinking)
        try m.advance(to: .draftPreview)
        try m.advance(to: .awaitingConfirmation)
        try m.advance(to: .executing)
        XCTAssertNotNil(m.draft)
        try m.advance(to: .verified)
        XCTAssertNil(m.draft, "已确认后草稿视为已消费，不再携带")
    }

    func testIdleClearsDraft() throws {
        var m = V38AIOperationMachine(state: .failed, draft: .placeholder)
        try m.advance(to: .idle)
        XCTAssertNil(m.draft)
    }

    func testDraftPreviewMountsPlaceholderWhenEmpty() throws {
        var m = V38AIOperationMachine(state: .thinking)
        XCTAssertNil(m.draft)
        try m.advance(to: .draftPreview)
        XCTAssertEqual(m.draft, .placeholder)
    }

    // MARK: - 派生展示属性

    func testDerivedFlags() {
        XCTAssertTrue(V38AIOperationMachine(state: .draftPreview).needsUserDecision)
        XCTAssertTrue(V38AIOperationMachine(state: .awaitingConfirmation).needsUserDecision)
        XCTAssertFalse(V38AIOperationMachine(state: .thinking).needsUserDecision)

        XCTAssertTrue(V38AIOperationMachine(state: .listening).isInProgress)
        XCTAssertTrue(V38AIOperationMachine(state: .thinking).isInProgress)
        XCTAssertTrue(V38AIOperationMachine(state: .executing).isInProgress)
        XCTAssertFalse(V38AIOperationMachine(state: .verified).isInProgress)

        XCTAssertTrue(V38AIOperationMachine(state: .verified).isTerminal)
        XCTAssertTrue(V38AIOperationMachine(state: .failed).isTerminal)
        XCTAssertFalse(V38AIOperationMachine(state: .executing).isTerminal)
    }

    // MARK: - 错误携带上下文

    func testIllegalTransitionErrorCarriesContext() {
        let err = V38AITransitionError(from: .idle, to: .verified)
        XCTAssertEqual(err.from, .idle)
        XCTAssertEqual(err.to, .verified)
        XCTAssertFalse(V38AIOperationMachine.canTransition(from: .idle, to: .verified))
    }
}
