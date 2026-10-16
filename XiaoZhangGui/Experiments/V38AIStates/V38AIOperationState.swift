import Foundation

// MARK: - V3.8 AI Safety UX · 只读操作状态机（展示层隔离）
//
// Debug-only 隔离原型（Experiments/V38AIStates），不接入生产 AI 界面。
// 纯逻辑：不调真实 AI、不写库、不删数据、不依赖任何 AgentCore / ToolExecutor /
// ModelRouter / Repository / Models / SwiftData 文件。
// 状态流（Docs/02 设计与交互升级说明·AI 交互仅展示层先走）：
//   Idle → Listening → Thinking → DraftPreview → AwaitingConfirmation → Executing → Verified / Failed

/// 只读 AI 操作的八个展示态。
enum V38AIOperationState: String, CaseIterable, Sendable, Equatable {
    /// 静置：等待用户开口（语音/文字）。
    case idle
    /// 正在收音（演示态，不开启真实麦克风）。
    case listening
    /// AI 处理中（展示用原生 ProgressView，不接入真实 AI）。
    case thinking
    /// 草稿预览：before/after 待确认卡片。
    case draftPreview
    /// 等待用户明确确认。**未确认不得进入 Executing**。
    case awaitingConfirmation
    /// 已确认后的执行态（演示：模拟写入与落库回读）。
    case executing
    /// 落库回读成功后的确认态。终态之一。
    case verified
    /// 失败态：必须可重试、必须保留草稿，**不得直接转 Verified**。
    case failed
}

/// 演示用的草稿载体：纯展示数据，禁止持久化、禁止写入业务数据。
struct V38AIOperationDraft: Equatable, Sendable {
    var title: String
    var beforeText: String
    var afterText: String
    var note: String?

    /// 占位示例（纯静态假数据，用于预览与截图）。
    static let placeholder = V38AIOperationDraft(
        title: "记一笔（演示）",
        beforeText: "今天营业收入：—",
        afterText: "微信收入 68 元（待确认，不真实写入）",
        note: "确认后才会写入，落库回读后才报告成功"
    )
}

/// 非法转换错误：仅用于测试与演示诊断，不触及生产日志链。
struct V38AITransitionError: Error, Equatable {
    let from: V38AIOperationState
    let to: V38AIOperationState
}

/// 纯逻辑状态机：转换合法性由静态转换表唯一决定。
///
/// 核心安全规则（展示层约定，测试锁定）：
/// 1. `failed` 不得直接转 `verified`（必须经 executing 重走一遍）。
/// 2. `executing` 只能从 `awaitingConfirmation` 进入（未确认不得执行）。
/// 3. `verified` 只能从 `executing` 进入（未执行不得宣告成功）。
/// 4. 取消/失败保留草稿：`awaitingConfirmation` 取消 → `draftPreview`；
///    `failed` 重试 → `draftPreview` / `thinking`，草稿不丢失。
/// 5. `verified`/`failed` 确认关闭后回到 `idle` 并清空已消费的草稿。
struct V38AIOperationMachine: Equatable, Sendable {
    private(set) var state: V38AIOperationState
    private(set) var draft: V38AIOperationDraft?

    init(state: V38AIOperationState = .idle, draft: V38AIOperationDraft? = nil) {
        self.state = state
        self.draft = draft
    }

    /// 合法转换表。纯函数：输入两个状态，输出是否允许。
    static func canTransition(from: V38AIOperationState, to: V38AIOperationState) -> Bool {
        switch from {
        case .idle:
            // 只有开口/开始才离开静置态。
            return to == .listening
        case .listening:
            // 收到输入进入思考；用户取消回到静置。
            return to == .thinking || to == .idle
        case .thinking:
            // 产出草稿、出错失败，或用户取消。
            return to == .draftPreview || to == .failed || to == .idle
        case .draftPreview:
            // 展示卡片等待确认；可退回思考重新生成；可放弃回到静置。
            return to == .awaitingConfirmation || to == .thinking || to == .idle || to == .failed
        case .awaitingConfirmation:
            // 用户确认才进入执行；取消保留草稿退回预览。
            return to == .executing || to == .draftPreview
        case .executing:
            // 只有执行态能进入已确认态；失败可重试。
            return to == .verified || to == .failed
        case .verified:
            // 终态：确认后归零，开启新一轮。
            return to == .idle || to == .listening
        case .failed:
            // 终态之一：失败不得直接转已确认；重试保留草稿；关闭归零。
            return to == .draftPreview || to == .thinking || to == .idle
        }
    }

    /// 执行一次转换；非法转换抛出 `V38AITransitionError`，状态不变。
    ///
    /// 语义：
    /// - 进入 `.draftPreview` 且当前无草稿时，挂载传入的占位草稿（演示用）；
    /// - 进入 `.verified` 即完成一次写入确认，草稿视为已消费，不再携带；
    /// - 回到 `.idle` 时清空展示草稿（新一轮从空白开始）。
    mutating func advance(to next: V38AIOperationState, draft: V38AIOperationDraft? = nil) throws {
        guard Self.canTransition(from: state, to: next) else {
            throw V38AITransitionError(from: state, to: next)
        }
        state = next
        switch next {
        case .draftPreview:
            if self.draft == nil { self.draft = draft ?? .placeholder }
        case .verified:
            // 已确认即视为写入完成，草稿不再保留。
            self.draft = nil
        case .idle:
            self.draft = nil
        default:
            break
        }
    }

    // MARK: - 派生展示属性（纯函数，供 CardView 使用）

    /// 是否处于用户需要做决定的状态（草稿预览/等待确认）。
    var needsUserDecision: Bool {
        state == .draftPreview || state == .awaitingConfirmation
    }

    /// 是否处于进行中的状态（展示加载指示）。
    var isInProgress: Bool {
        state == .listening || state == .thinking || state == .executing
    }

    /// 是否为终态（已确认/失败：展示关闭或重试入口）。
    var isTerminal: Bool {
        state == .verified || state == .failed
    }
}
