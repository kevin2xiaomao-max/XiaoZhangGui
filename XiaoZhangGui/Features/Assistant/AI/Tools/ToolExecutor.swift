import Foundation

// MARK: - V3.3 Lite · Tool 执行接缝
//
// AI → ToolRouter（本协议）→ Repository 是未来唯一写库路径；
// Provider / AgentCore 永远不直接持有 ModelContext。
//
// Foundation：App target 只装配 PreviewToolExecutor——任何 CREATE 确认都只返回
// 「预览、未保存」，绝不触碰 SwiftData。能返回成功的 MockToolExecutor 仅存在于
// 测试 target。FINAL 的真实 ToolRouter 必须做：权限校验 → 参数校验 →
// toolCallID / 指纹幂等 → Repository 写入 → Journal 记录。

enum ToolExecutionResult: Equatable, Sendable {
    /// Foundation 预览：未写库
    case previewNotPersisted(ToolCall)
    /// FINAL：真实落库成功
    case executed(recordID: String, summary: String)
    /// 幂等折叠：与已有调用 / 业务指纹重复
    case duplicate(existingToolCallID: String)
    /// 执行失败（可重试，不丢 ActionCard）
    case failed(String)
}

protocol ToolExecuting: Sendable {
    func execute(_ call: ToolCall) async -> ToolExecutionResult
}

/// Foundation 唯一在 App 内装配的执行器：无 ModelContext、无 Repository 引用。
struct PreviewToolExecutor: ToolExecuting {
    func execute(_ call: ToolCall) async -> ToolExecutionResult {
        // 写闸门：无论调用方如何，预览执行器绝不落库。
        return .previewNotPersisted(call)
    }
}

// MARK: - 参数校验（纯函数，可单测）

enum ToolArgumentValidator {
    /// 返回缺失 / 非法字段的中文说明；空数组表示可出确认卡。
    static func validate(_ call: ToolCall) -> [String] {
        guard ToolCatalog.isRegistered(call.name) else {
            return ["当前版本不支持该操作：\(call.name.rawValue)"]
        }
        switch call.arguments {
        case .recordRevenue(let a):
            var errors: [String] = []
            guard let amount = a.amount, amount > 0 else { errors.append("缺少有效金额") }
            return errors
        case .createTodo(let a):
            guard let title = a.title?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !title.isEmpty else { return ["缺少待办标题"] }
            return []
        case .createMemo(let a):
            var errors: [String] = []
            if (a.title ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                errors.append("缺少备忘标题")
            }
            if (a.content ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                errors.append("缺少备忘内容")
            }
            return errors
        case .createDelivery(let a):
            let hasCustomer = !(a.customer ?? "").isEmpty
            let hasContent = !(a.content ?? "").isEmpty || !(a.goodsName ?? "").isEmpty
            if !hasCustomer && !hasContent { return ["缺少配送客户 / 房号或商品"] }
            return []
        case .searchRecords:
            return []
        }
    }
}
