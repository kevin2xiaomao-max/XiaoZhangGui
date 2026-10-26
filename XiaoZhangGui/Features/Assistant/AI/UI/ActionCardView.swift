import SwiftUI

// MARK: - 小掌柜动作确认卡（ActionCard · V3.7.1 Presentation 重构）
//
// 所有 CREATE 必须经此卡用户确认；Foundation 阶段确认也只标记「已预览」，
// 绝不真实写库（PreviewToolExecutor 写闸门）。确认流程、文案、状态机原样保留，
// 只换 UI：GroupSurface + editorial rows，内容区 solid、不做 material。

struct ActionCardView: View {
    let proposal: ActionProposal
    let onConfirm: () -> Void
    let onModify: () -> Void
    let onCancel: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isCollapsed = false

    /// 预览确认、失败和幂等跳过都不是一次真实记录成功。
    var showsRecordedStamp: Bool {
        proposal.status == .executed && !proposal.isPreviewOnly && !proposal.previewAcknowledged
    }

    var body: some View {
        // V4.0 收据式确认卡：纸面容器（GroupSurface 的 group 底改走 paperAdaptive，
        // 圆角与内边距与原 GroupSurface 一致；不改 GroupSurface 本身，避免波及其他页）。
        VStack(alignment: .leading, spacing: 12) {
            header
            if !isCollapsed { fields }
            if proposal.isPreviewOnly {
                previewBanner
            }
            if let result = proposal.resultText, !result.isEmpty {
                resultRow(result)
            }
            // V4.0 收据式确认卡：字段与操作之间用发丝虚线分隔（A 基因）。
            if showsRecordedStamp {
                Button {
                    withAnimation(reduceMotion ? nil : V32Motion.standard) {
                        isCollapsed.toggle()
                    }
                } label: {
                    Label(isCollapsed ? "展开记录详情" : "收起记录详情",
                          systemImage: isCollapsed ? "chevron.down" : "chevron.up")
                        .font(.subheadline)
                        .frame(minHeight: 44)
                }
                .foregroundStyle(V400Tokens.greenInk)
                .accessibilityIdentifier("ai.action-card.details")
            }
            if !isCollapsed {
                dashedSeparator
                actions
            }
        }
        .padding(V371.Space.rowPadding)
        .background(
            RoundedRectangle(cornerRadius: V371.Radius.group, style: .continuous)
                .fill(V400Tokens.paperAdaptive)
        )
        .transition(.opacity.combined(with: reduceMotion ? .identity : .move(edge: .bottom)))
        .animation(reduceMotion ? nil : V32Motion.standard,
                   value: proposal.status)
        .animation(reduceMotion ? nil : V32Motion.quick,
                   value: proposal.previewAcknowledged)
        .task(id: showsRecordedStamp) {
            guard showsRecordedStamp else { isCollapsed = false; return }
            if !reduceMotion {
                do { try await Task.sleep(for: .milliseconds(400)) }
                catch { return }
            }
            withAnimation(reduceMotion ? nil : V32Motion.standard) { isCollapsed = true }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("ai.action-card")
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: Self.icon(for: proposal.call.name))
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(toneColor)
                .frame(width: 36, height: 36)
                .background(V371.Colors.tinted(toneColor), in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(Self.title(for: proposal.call.name))
                    .font(.headline)
                    .foregroundStyle(V371.Colors.textPrimary)
                Text(statusCaption)
                    .font(.caption)
                    .foregroundStyle(V371.Colors.textTertiary)
            }
            Spacer(minLength: 0)
            if showsRecordedStamp {
                Text("已记")
                    .font(.caption.weight(.bold))
                    .tracking(1)
                    .foregroundStyle(V400Tokens.greenInk)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(V400Tokens.brandGreen, lineWidth: 1.5)
                    )
                    .rotationEffect(.degrees(-8))
                    .accessibilityLabel("已记录，保存成功")
                    .accessibilityIdentifier("ai.action-card.recorded-stamp")
            } else {
                StatusBadge(statusBadgeText, color: statusBadgeColor)
            }
        }
    }

    private var toneColor: Color {
        switch proposal.status {
        case .failed: return V371.Colors.red
        case .executed: return V371.Colors.green
        case .duplicate, .cancelled: return V371.Colors.gray
        default: return V371.Colors.blue
        }
    }

    private var statusBadgeText: String {
        switch proposal.status {
        case .pending: return proposal.isPreviewOnly ? "预览" : "待你确认"
        case .confirmed: return "正在保存…"
        case .executed: return "已保存"
        case .duplicate: return "已跳过"
        case .failed: return "失败"
        case .cancelled: return "已取消"
        }
    }

    private var statusBadgeColor: Color {
        switch proposal.status {
        case .failed: return V371.Colors.red
        case .executed: return V371.Colors.green
        case .duplicate, .cancelled: return V371.Colors.gray
        case .confirmed: return V371.Colors.orange
        case .pending: return V371.Colors.blue
        }
    }

    private var fields: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(proposal.call.arguments.fieldRows.enumerated()), id: \.offset) { _, row in
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(row.label)
                        .font(.subheadline)
                        .foregroundStyle(V371.Colors.textTertiary)
                        .frame(minWidth: 56, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .layoutPriority(1)
                    Text(row.value)
                        // V4.0:仅「金额」行用衬线 tabular-nums（Georgia），其他字段行保持正文字体。
                        .font(row.label == "金额" ? V400Tokens.serifAmount(size: 17, relativeTo: .body) : .body)
                        .foregroundStyle(V371.Colors.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .layoutPriority(0)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var previewBanner: some View {
        HStack(spacing: 7) {
            Image(systemName: "eye")
                .font(.system(size: 12, weight: .semibold))
            Text("预览版：点击确认也不会真实保存，正式版才会写入")
                .font(.caption)
            Spacer(minLength: 0)
        }
        .foregroundStyle(V371.Colors.orange)
        .padding(.vertical, 4)
    }

    private var dashedSeparator: some View {
        GeometryReader { geo in
            Path { path in
                path.move(to: .zero)
                path.addLine(to: CGPoint(x: geo.size.width, y: 0))
            }
            .stroke(style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
            .foregroundStyle(V371.Colors.divider)
        }
        .frame(height: 1)
        .accessibilityHidden(true)
    }

    private func resultRow(_ text: String) -> some View {
        HStack(spacing: 7) {
            Image(systemName: proposal.status == .failed ? "exclamationmark.triangle" : "checkmark.circle.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(proposal.status == .failed ? V371.Colors.red : V371.Colors.green)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(V371.Colors.textSecondary)
            Spacer(minLength: 0)
        }
    }

    private var actions: some View {
        let resolved = (proposal.status != .pending && proposal.status != .failed) || proposal.previewAcknowledged
        return VStack(spacing: 9) {
            Button {
                Haptic.light()
                onConfirm()
            } label: {
                Label(confirmTitle, systemImage: "checkmark")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(
                        Capsule(style: .continuous)
                            // V4.0 04 §6.2:确认主按钮 #146B52（白字）；已决态仍为灰。
                            .fill(resolved ? V371.Colors.gray.opacity(0.4) : V400Tokens.primaryButton)
                    )
            }
            .buttonStyle(.plain)
            .disabled(resolved)
            .opacity(resolved ? 0.75 : 1)
            .accessibilityIdentifier("ai.action-card.confirm")

            HStack(spacing: 10) {
                Button {
                    Haptic.light()
                    onModify()
                } label: {
                    Label("修改", systemImage: "pencil")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(V371.Colors.blue)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(
                            Capsule(style: .continuous)
                                .fill(V371.Colors.tinted(V371.Colors.blue))
                        )
                }
                .buttonStyle(.plain)
                .disabled(resolved)
                Button {
                    Haptic.light()
                    onCancel()
                } label: {
                    Label("不记录", systemImage: "xmark")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(V371.Colors.textSecondary)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(
                            Capsule(style: .continuous)
                                .fill(V371.Colors.groupSecondary)
                        )
                }
                .buttonStyle(.plain)
                .disabled(resolved)
            }
        }
    }

    private var confirmTitle: String {
        if proposal.previewAcknowledged { return "已预览（未保存）" }
        switch proposal.status {
        case .executed: return "已记录"
        case .duplicate: return "已跳过重复项"
        case .failed: return "重试保存"
        default: return proposal.isPreviewOnly ? "确认（仅预览）" : "确认记录"
        }
    }

    private var statusCaption: String {
        switch proposal.status {
        case .pending: return proposal.isPreviewOnly ? "Foundation 预览 · 不写库" : "待你确认"
        case .confirmed: return "正在保存…"
        case .executed: return "已保存"
        case .duplicate: return "重复，已跳过"
        case .failed: return "失败，可重试"
        case .cancelled: return "已取消"
        }
    }

    static func icon(for tool: ToolName) -> String {
        switch tool {
        case .recordRevenue: return "yensign.circle.fill"
        case .recordExpense: return "creditcard.fill"
        case .completeTodo: return "checkmark.seal.fill"
        case .advanceDelivery: return "truck.box.fill"
        case .createTodo: return "checkmark.circle.fill"
        case .createMemo: return "note.text"
        case .createDelivery: return "box.truck.fill"
        case .searchRecords: return "magnifyingglass.circle.fill"
        }
    }

    static func title(for tool: ToolName) -> String {
        switch tool {
        case .recordRevenue: return "记录营业额"
        case .recordExpense: return "记录支出"
        case .completeTodo: return "完成待办"
        case .advanceDelivery: return "推进配送"
        case .createTodo: return "新建待办"
        case .createMemo: return "新建备忘"
        case .createDelivery: return "新建配送"
        case .searchRecords: return "查询经营记录"
        }
    }
}
