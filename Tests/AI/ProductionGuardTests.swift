import XCTest
@testable import XiaoZhangGui

/// Release 红线：live 环境缺真实依赖或误装 Mock / 预览执行器时，必须失败闭合，
/// 绝不允许 UI 显示「✓ 已记录」而实际只是 Mock 成功。
@MainActor
final class ProductionGuardTests: XCTestCase {

    private func stores() -> (InMemoryExecutionJournal, InMemoryPendingActionStore, InMemoryConversationStore) {
        (InMemoryExecutionJournal(), InMemoryPendingActionStore(), InMemoryConversationStore())
    }

    private func makeLive(
        provider: any AIProvider,
        fallback: (any AIProvider)? = nil,
        executor: any ToolExecuting
    ) throws -> AgentEnvironment {
        let (journal, pending, conversation) = stores()
        return try AgentEnvironment.makeLive(
            provider: provider,
            fallback: fallback,
            contextProvider: UnavailableBusinessContextProvider(),
            toolExecutor: executor,
            conversation: conversation,
            pending: pending,
            journal: journal
        )
    }

    func testLiveRejectsMockProvider() {
        XCTAssertThrowsError(
            try makeLive(provider: MockAIProvider(), executor: SuccessToolExecutor())
        ) { error in
            XCTAssertEqual(error as? AgentError, .notConfigured)
        }
    }

    func testLiveRejectsMockFallback() {
        let real = ScriptedAIProvider(id: "real", [.success(.text("ok"))])
        XCTAssertThrowsError(
            try makeLive(provider: real, fallback: MockAIProvider(id: "mock-fallback"),
                         executor: SuccessToolExecutor())
        ) { error in
            XCTAssertEqual(error as? AgentError, .notConfigured)
        }
    }

    func testLiveRejectsPreviewExecutor() {
        let real = ScriptedAIProvider(id: "real", [.success(.text("ok"))])
        XCTAssertThrowsError(
            try makeLive(provider: real, executor: PreviewToolExecutor())
        ) { error in
            XCTAssertEqual(error as? AgentError, .notConfigured)
        }
    }

    func testLiveBuildsWithRealProviderAndExecutor() throws {
        let real = ScriptedAIProvider(id: "real", [.success(.text("ok"))])
        let env = try makeLive(provider: real, executor: SuccessToolExecutor())
        XCTAssertEqual(env.gate, .live)
    }

    /// 预览装配必须保持 preview 闸门
    func testFoundationPreviewIsGated() {
        let env = AgentEnvironment.foundationPreview(
            conversation: InMemoryConversationStore(),
            pending: InMemoryPendingActionStore(),
            journal: InMemoryExecutionJournal())
        XCTAssertEqual(env.gate, .preview)
        XCTAssertTrue(env.toolExecutor is PreviewToolExecutor)
    }
}
