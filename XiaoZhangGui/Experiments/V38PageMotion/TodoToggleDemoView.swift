import SwiftUI

/// 待办勾选反馈演示（Debug-only 隔离组件）。
///
/// 对应 `Docs/V38-Page-Motion-Spec.md` §2 与 G5 铁律：
/// 点按 → 先进入"保存中"（转圈，不宣告成功）→ 模拟持久化回执 →
/// 成功才渲染完成态；失败回弹 + 保留重试。保存为模拟延迟，
/// 不碰 Repository / SwiftData。
///
/// 状态机见 `V38PageMotionState`（纯逻辑，有单元测试）。
struct TodoToggleDemoView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var rows: [DemoRow] = [
        DemoRow(title: "演示：盘点库存"),
        DemoRow(title: "演示：给供货商打电话"),
        DemoRow(title: "演示：更新价签", isDone: true),
    ]
    @State private var simulateFailure = false
    @State private var feedbackTick = 0

    private struct DemoRow: Identifiable {
        let id = UUID()
        let title: String
        var motion: V38PageMotionState
        init(title: String, isDone: Bool = false) {
            self.title = title
            self.motion = V38PageMotionState(isDone: isDone)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                failureSwitch
                progressLine
                ForEach($rows) { $row in
                    demoRow($row)
                }
                disclaimer
            }
            .padding(20)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("勾选反馈演示")
        .navigationBarTitleDisplayMode(.inline)
        .sensoryFeedback(.impact(weight: .light), trigger: feedbackTick)
        .accessibilityIdentifier("v38.page.todo.demo")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("V3.8 · 勾选状态回执")
                .font(.system(size: 28, weight: .semibold, design: .rounded))
            Text("成功 UI 只在「保存成功」后出现（G5）")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }

    private var failureSwitch: some View {
        Toggle("演示：模拟保存失败", isOn: $simulateFailure)
            .tint(.red)
            .accessibilityIdentifier("v38.page.todo.simulateFailure")
    }

    private var progressLine: some View {
        let done = rows.filter { $0.motion.showsChecked }.count
        return Text("已完成 \(done) / \(rows.count)（演示计数）")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .contentTransition(.numericText())
            .accessibilityIdentifier("v38.page.todo.progress")
    }

    @ViewBuilder
    private func demoRow(_ row: Binding<DemoRow>) -> some View {
        let motion = row.wrappedValue.motion
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 14) {
                toggleButton(row)
                Text(row.wrappedValue.title)
                    .font(.body)
                    .strikethrough(motion.showsChecked)
                    .foregroundStyle(motion.showsChecked ? .secondary : .primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .frame(minHeight: 60)
            .padding(.horizontal, 16)
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20))
            .opacity(motion.showsChecked ? 0.6 : 1.0)
            .accessibilityIdentifier("v38.page.todo.row.\(row.wrappedValue.id.uuidString.prefix(8))")

            if let msg = motion.failureMessage {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                    Text(msg).font(.footnote).foregroundStyle(.red)
                    Spacer()
                    Button("重试") { toggle(row) }
                        .font(.footnote).bold()
                        .accessibilityIdentifier("v38.page.todo.retry")
                    Button("放弃") {
                        withAnimation(pressAnimation) { row.wrappedValue.motion.dismissFailure() }
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 20)
                .transition(.opacity)
            }
        }
    }

    @ViewBuilder
    private func toggleButton(_ row: Binding<DemoRow>) -> some View {
        let motion = row.wrappedValue.motion
        Button { toggle(row) } label: {
            ZStack {
                if motion.isSaving {
                    ProgressView()
                        .controlSize(.small)
                } else if motion.showsChecked {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.green)
                        .transition(.scale)
                } else {
                    Image(systemName: "circle")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                        .transition(.scale)
                }
            }
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(motion.isSaving)
        .accessibilityIdentifier("v38.page.todo.toggle")
        .accessibilityLabel(row.wrappedValue.title)
        .accessibilityValue(motion.isSaving ? "正在保存" : (motion.showsChecked ? "已完成" : "未完成"))
    }

    private var pressAnimation: Animation? {
        V38MotionLabTokens.animation(for: .press, reduceMotion: reduceMotion)
    }

    private func toggle(_ row: Binding<DemoRow>) {
        feedbackTick += 1
        withAnimation(pressAnimation) {
            row.wrappedValue.motion.requestToggle()
        }
        guard row.wrappedValue.motion.isSaving else { return }
        let shouldFail = simulateFailure
        // 模拟异步持久化回执（延迟 0.7s）。生产接入时替换为真实 Repository 回调。
        Task {
            try? await Task.sleep(nanoseconds: 700_000_000)
            await MainActor.run {
                withAnimation(V38MotionLabTokens.animation(for: .contentChange, reduceMotion: reduceMotion)) {
                    if shouldFail {
                        row.wrappedValue.motion.saveFailed()
                    } else {
                        row.wrappedValue.motion.saveSucceeded()
                    }
                }
            }
        }
    }
}

#if DEBUG
#Preview("Todo Toggle / Light") {
    NavigationStack { TodoToggleDemoView() }
        .preferredColorScheme(.light)
}

#Preview("Todo Toggle / Dark") {
    NavigationStack { TodoToggleDemoView() }
        .preferredColorScheme(.dark)
}
#endif
