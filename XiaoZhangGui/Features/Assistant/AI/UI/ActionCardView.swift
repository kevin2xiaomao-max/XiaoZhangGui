import SwiftUI

// MARK: - 小掌柜动作确认卡（ActionCard）
//
// 所有 CREATE 必须经此卡用户确认；Foundation 阶段确认也只标记「已预览」，
// 绝不真实写库（PreviewToolExecutor 写闸门）。UI 保持 Apple 原生、轻量。

struct ActionCardView: View {
    let proposal: ActionProposal
    let onConfirm: () -> Void
    let onModify: () -> Void
    let onCancel: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        V32Card {
            VStack(alignment: .leading, spacing: 12) {
                header
                fields
                if proposal.isPreviewOnly {
                    previewBanner
                }
                if let result = proposal.resultText, !result.isEmpty {
                    resultRow(result)
                }
                actions
            }
        }
        .transition(.opacity.combined(with: reduceMotion ? .identity : .move(edge: .bottom)))
        .animation(V32Motion.animation(V32Motion.resolve(.spring, reduceMotion: reduceMotion)),
                   value: proposal.status)
        .animation(V32Motion.animation(V32Motion.resolve(.fade, reduceMotion: reduceMotion)),
                   value: proposal.previewAcknowledged)
        .accessibilityIdentifier("ai.action-card")
    }

    private var header: some View {
        HStack(spacing: 10) {
            V32IconBubble(systemName: Self.icon(for: proposal.call.name), tone: .brand)
            VStack(alignment: .leading, spacing: 2) {
                Text(Self.title(for: proposal.call.name))
                    .v32Text(.headline)
                    .foregroundStyle(V32.textPrimary)
                Text(statusCaption)
                    .v32Text(.caption)
                    .foregroundStyle(V32.textTertiary)
            }
            Spacer(minLength: 0)
        }
    }

    private var fields: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(proposal.call.arguments.fieldRows.enumerated()), id: \.offset) { _, row in
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(row.label)
                        .v32Text(.subhead)
                        .foregroundStyle(V32.textTertiary)
                        .frame(minWidth: 56, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .layoutPriority(1)
                    Text(row.value)
                        .v32Text(.body)
                        .foregroundStyle(V32.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .layoutPriority(0)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: V32Radius.inset, style: .continuous)
                .fill(V32.cardInset)
        )
    }

    private var previewBanner: some View {
        HStack(spacing: 7) {
            Image(systemName: "eye")
                .font(.system(size: 12, weight: .semibold))
            Text("预览版：点击确认也不会真实保存，正式版才会写入")
                .v32Text(.caption)
            Spacer(minLength: 0)
        }
        .foregroundStyle(V32.amber)
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: V32Radius.inset, style: .continuous)
                .fill(V32.amberSoft)
        )
    }

    private func resultRow(_ text: String) -> some View {
        HStack(spacing: 7) {
            Image(systemName: proposal.status == .failed ? "exclamationmark.triangle" : "checkmark.circle.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(proposal.status == .failed ? V32.danger : V32.brand)
            Text(text)
                .v32Text(.subhead)
                .foregroundStyle(V32.textSecondary)
            Spacer(minLength: 0)
        }
    }

    private var actions: some View {
        let resolved = proposal.status != .pending || proposal.previewAcknowledged
        return VStack(spacing: 9) {
            V32PrimaryButton(title: confirmTitle, systemName: "checkmark") {
                onConfirm()
                Haptic.success()
            }
            .disabled(resolved)
            .opacity(resolved ? 0.55 : 1)
            .accessibilityIdentifier("ai.action-card.confirm")

            HStack(spacing: 10) {
                V32SecondaryButton(title: "修改", systemName: "pencil") { onModify() }
                    .disabled(resolved)
                V32SecondaryButton(title: "不记录", systemName: "xmark") { onCancel() }
                    .disabled(resolved)
            }
        }
    }

    private var confirmTitle: String {
        if proposal.previewAcknowledged { return "已预览（未保存）" }
        switch proposal.status {
        case .executed: return "已记录"
        case .duplicate: return "已跳过重复项"
        case .failed: return "执行失败"
        default: return proposal.isPreviewOnly ? "确认（仅预览）" : "确认记录"
        }
    }

    private var statusCaption: String {
        switch proposal.status {
        case .pending: return proposal.isPreviewOnly ? "Foundation 预览 · 不写库" : "待你确认"
        case .confirmed: return "已确认"
        case .executed: return "已保存"
        case .duplicate: return "重复，已跳过"
        case .failed: return "失败，可重试"
        case .cancelled: return "已取消"
        }
    }

    static func icon(for tool: ToolName) -> String {
        switch tool {
        case .recordRevenue: return "yensign.circle.fill"
        case .createTodo: return "checkmark.circle.fill"
        case .createMemo: return "note.text"
        case .createDelivery: return "box.truck.fill"
        case .searchRecords: return "magnifyingglass.circle.fill"
        }
    }

    static func title(for tool: ToolName) -> String {
        switch tool {
        case .recordRevenue: return "记录营业额"
        case .createTodo: return "新建待办"
        case .createMemo: return "新建备忘"
        case .createDelivery: return "新建配送"
        case .searchRecords: return "查询经营记录"
        }
    }
}
