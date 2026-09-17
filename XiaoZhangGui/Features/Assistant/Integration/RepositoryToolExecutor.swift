import Foundation
import SwiftData

// MARK: - V3.3 Lite · AI 工具真实执行器（AI 层之外，唯一允许写业务库的 AI 入口）
//
// 架构红线：
// - 本文件在 AI 目录之外，是 AI ToolCall → 现有 Repository 的唯一桥；
// - Provider / AgentCore / ActionCardView / IntentRouter 都不持有 ModelContext；
// - 不新写第二套保存逻辑，全部调用既有 Repository（内部已做 save + 通知 + 快照刷新）；
// - 执行前双重幂等预检（toolCallID + 业务指纹），重复确认 / 重试 / 崩溃恢复都不会写第二次；
// - 只支持 4 个 CREATE；searchRecords 是 READ，不应到达这里；UPDATE / DELETE 未注册。

@MainActor
final class RepositoryToolExecutor: ToolExecuting {
    private let context: ModelContext
    private let journal: any ExecutionJournaling

    init(context: ModelContext, journal: any ExecutionJournaling) {
        self.context = context
        self.journal = journal
    }

    func execute(_ call: ToolCall) async -> ToolExecutionResult {
        // 幂等预检：只认 executed 状态（pending / failed 不算已执行）
        let entries = await journal.entries()
        if entries.contains(where: { $0.toolCallID == call.id && $0.status == ProposalStatus.executed.rawValue }) {
            return .duplicate(existingToolCallID: call.id)
        }
        let fingerprint = ToolIdempotency.fingerprint(for: call)
        if entries.contains(where: { $0.fingerprint == fingerprint && $0.status == ProposalStatus.executed.rawValue }) {
            return .duplicate(existingToolCallID: call.id)
        }

        // 防御性二次校验（AgentCore 已校验一次，执行层不允许写入非法数据）
        guard ToolArgumentValidator.validate(call).isEmpty else {
            return .failed("参数不完整，已阻止写入")
        }

        let result: ToolExecutionResult
        do {
            result = try perform(call)
        } catch {
            return .failed("保存失败：\(error.localizedDescription)")
        }

        // 真实写库成功后，由唯一执行入口把账本推进为 executed（替换 pending 记录），
        // 保证崩溃恢复 / 重放 / 重复回调时判重生效。
        if case .executed(let recordID, _) = result {
            await journal.markExecuted(JournalEntry(
                toolCallID: call.id,
                fingerprint: fingerprint,
                toolName: call.name.rawValue,
                status: ProposalStatus.executed.rawValue,
                recordID: recordID,
                createdAt: .now))
        }
        return result
    }

    private func perform(_ call: ToolCall) throws -> ToolExecutionResult {
        switch call.arguments {
        case .recordRevenue(let args):
            return try executeRevenue(call, args)
        case .createTodo(let args):
            return try executeTodo(call, args)
        case .createMemo(let args):
            return try executeMemo(call, args)
        case .createDelivery(let args):
            return try executeDelivery(call, args)
        case .searchRecords:
            // READ 由 AgentCore 本地聚合回答，永远不应走到执行器
            return .failed("查询类操作不经过写库执行器")
        }
    }

    // MARK: 营业额

    private func executeRevenue(_ call: ToolCall, _ args: RevenueArguments) throws -> ToolExecutionResult {
        guard let amount = args.amount, amount > 0 else {
            return .failed("营业额金额缺失或无效")
        }
        let source = args.source?.trimmingCharacters(in: .whitespaces)
        let note = [source, args.note]
            .compactMap { $0?.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        let finalNote = note.isEmpty ? "小掌柜" : note
        try PerformanceRepository(context: context).add(
            amount: amount,
            note: finalNote,
            date: args.date ?? Date(),
            incomeSource: IncomeSource.from(note: source ?? args.note ?? "")
        )
        return .executed(recordID: call.id, summary: "已记录营业额 \(money(amount))\(source.map { "（\($0)）" } ?? "")")
    }

    // MARK: 待办

    private func executeTodo(_ call: ToolCall, _ args: TodoArguments) throws -> ToolExecutionResult {
        guard let title = args.title?.trimmingCharacters(in: .whitespacesAndNewlines),
              !title.isEmpty else {
            return .failed("待办标题缺失")
        }
        let priority = min(max(args.priority ?? 0, 0), 2)
        try TodoRepository(context: context).add(
            title: title,
            detail: args.detail?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
            dueDate: args.dueDate,
            priority: priority
        )
        return .executed(recordID: call.id, summary: "已新建待办：\(title)")
    }

    // MARK: 备忘

    private func executeMemo(_ call: ToolCall, _ args: MemoArguments) throws -> ToolExecutionResult {
        guard let title = args.title?.trimmingCharacters(in: .whitespacesAndNewlines),
              !title.isEmpty else {
            return .failed("备忘标题缺失")
        }
        let content = args.content?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            ? args.content!
            : title
        try MemoRepository(context: context).add(title: title, content: content)
        return .executed(recordID: call.id, summary: "已新建备忘：\(title)")
    }

    // MARK: 配送

    private func executeDelivery(_ call: ToolCall, _ args: DeliveryArguments) throws -> ToolExecutionResult {
        let customer = args.customer?.trimmingCharacters(in: .whitespaces) ?? ""
        let room = args.roomOrAddress?.trimmingCharacters(in: .whitespaces)
            ?? (customer.isEmpty ? "" : customer)
        let phone = args.phone?.trimmingCharacters(in: .whitespaces) ?? ""

        var content = args.content?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if content.isEmpty {
            content = [args.goodsName, args.quantity]
                .compactMap { $0?.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
                .joined(separator: "")
        }
        var parts = content.isEmpty ? [] : [content]
        if let timeText = args.deliveryTimeText?.trimmingCharacters(in: .whitespaces), !timeText.isEmpty {
            parts.append("（\(timeText)）")
        }
        if let note = args.note?.trimmingCharacters(in: .whitespacesAndNewlines), !note.isEmpty {
            parts.append(note)
        }
        let finalContent = parts.joined(separator: " ")

        guard !customer.isEmpty || !finalContent.isEmpty else {
            return .failed("配送缺少客户与商品信息")
        }

        try CustomerRepository(context: context).add(
            customer: customer,
            roomOrAddress: room,
            phone: phone,
            content: finalContent
        )
        let who = customer.isEmpty ? "" : "\(customer) "
        return .executed(recordID: call.id, summary: "已新建配送：\(who)\(finalContent)".trimmingCharacters(in: .whitespaces))
    }

    // MARK: 工具

    private func money(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 0
        let text = formatter.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value)
        return "¥\(text)"
    }
}
