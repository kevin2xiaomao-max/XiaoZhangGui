import SwiftUI

/// V3.8 Pages PoC —— 待办「勾选反馈」演示（Debug-only 隔离组件）。
///
/// 规格依据：`Docs/V38-Page-Motion-Spec.md` §2 与 G5 铁律
/// 「持久化完成之前不宣告成功；失败保持可操作并保留重试」。
/// 演示要点：
///   1. 点击圆圈 → 按压缩小回执 → 「保存中」态 → 持久化成功后行沉降到底部，列表无跳动；
///   2. 打开「模拟持久化失败」：保存失败 → 不播放成功态 → 行保持可操作 + 错误提示，再点即重试；
///   3. Reduce Motion 开启时：直接状态切换，无位移/缩放。
///
/// 行状态由 `V38PageMotionState`（纯逻辑状态机）驱动；持久化用演示延时模拟。
/// 纯演示：不读真实待办、不触碰 Todo 生产页面、不写库。仅通过 SwiftUI Preview 打开。
struct V38TodoCheckFeedbackPreview: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private struct DemoTodo: Identifiable {
        let id: Int
        let title: String
        var state = V38PageMotionState()
    }

    @State private var todos: [DemoTodo] = [
        DemoTodo(id: 0, title: "补饮料（演示）"),
        DemoTodo(id: 1, title: "客户回访（演示）"),
        DemoTodo(id: 2, title: "盘点库存（演示）"),
        DemoTodo(id: 3, title: "临期检查（演示）"),
        DemoTodo(id: 4, title: "对账（演示）"),
        DemoTodo(id: 5, title: "备货（演示）"),
    ]
    @State private var simulateFailure = false
    @State private var pressingId: Int?

    /// 未完成在前、已完成沉底；同组保持原序，保证重排无跳动。
    private var orderedTodos: [DemoTodo] {
        todos.sorted {
            let aDone = $0.state.showsChecked
            let bDone = $1.state.showsChecked
            if aDone != bDone { return !aDone }
            return $0.id < $1.id
        }
    }

    private var doneCount: Int { todos.filter { $0.state.showsChecked }.count }

    private var reorderAnimation: Animation? {
        reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.86)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            progressRow
            failureToggle
            todoList
            footerNote
            Spacer()
        }
        .padding(20)
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("待办勾选演示")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - 头部与进度

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("V3.8 · 待办勾选反馈演示")
                .font(.system(size: 26, weight: .semibold, design: .rounded))
            Text("勾选 → 保存中回执 → 成功后行沉降；失败不宣告成功。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }

    private var progressRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("今日待办")
                    .font(.subheadline).foregroundStyle(.secondary)
                Spacer()
                Text("\(doneCount)/\(todos.count)")
                    .font(.headline.monospacedDigit())
                    .contentTransition(.numericText())
                    .accessibilityIdentifier("v38.pages.todo.progress")
            }
            ProgressView(value: Double(doneCount), total: Double(todos.count))
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.28), value: doneCount)
        }
        .padding(14)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    private var failureToggle: some View {
        Toggle("模拟持久化失败", isOn: $simulateFailure)
            .font(.subheadline)
            .accessibilityIdentifier("v38.pages.todo.simulateFailure")
    }

    // MARK: - 待办列表

    private var todoList: some View {
        VStack(spacing: 8) {
            ForEach(orderedTodos) { todo in
                todoRow(todo)
            }
        }
        .animation(reorderAnimation, value: orderedTodos.map(\.id))
        .animation(reorderAnimation, value: doneCount)
    }

    private func todoRow(_ todo: DemoTodo) -> some View {
        HStack(spacing: 14) {
            checkCircle(for: todo)
            VStack(alignment: .leading, spacing: 2) {
                Text(todo.title)
                    .font(.body)
                    .strikethrough(todo.state.showsChecked)
                    .foregroundStyle(todo.state.showsChecked ? .secondary : .primary)
                if let message = todo.state.failureMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .accessibilityIdentifier("v38.pages.todo.failureNote")
                } else if todo.state.isSaving {
                    Text("保存中…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
        .opacity(todo.state.showsChecked ? 0.75 : 1.0)
    }

    private func checkCircle(for todo: DemoTodo) -> some View {
        Button {
            toggle(todo)
        } label: {
            ZStack {
                Circle()
                    .strokeBorder(todo.state.showsChecked ? Color.clear : Color.secondary, lineWidth: 2)
                    .background(
                        Circle().fill(todo.state.showsChecked ? Color.accentColor : Color.clear)
                    )
                    .frame(width: 30, height: 30)
                if todo.state.isSaving {
                    ProgressView()
                        .scaleEffect(0.7)
                } else if todo.state.showsChecked {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .scaleEffect(pressingId == todo.id ? 0.88 : 1.0)
        }
        .buttonStyle(.plain)
        .frame(minWidth: 44, minHeight: 44)
        .contentShape(Rectangle())
        .accessibilityIdentifier("v38.pages.todo.toggle.\(todo.id)")
        .accessibilityLabel("\(todo.title)，\(todo.state.showsChecked ? "已完成" : todo.state.isSaving ? "保存中" : "未完成")")
    }

    // MARK: - 勾选流程（演示用延时模拟持久化）

    private func toggle(_ todo: DemoTodo) {
        guard let index = todos.firstIndex(where: { $0.id == todo.id }) else { return }
        guard !todos[index].state.isSaving else { return } // 在途保存中忽略连点（G4）

        // 1) 按压回执
        if !reduceMotion {
            withAnimation(.easeOut(duration: 0.18)) { pressingId = todo.id }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { pressingId = nil }
        }

        // 2) 进入 saving 态：UI 只允许展示"保存中"，不许展示成功态（G5）
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) {
            todos[index].state.requestToggle()
        }

        // 3) 演示持久化回执
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            withAnimation(reorderAnimation) {
                if simulateFailure {
                    todos[index].state.saveFailed()
                } else {
                    todos[index].state.saveSucceeded()
                }
            }
        }
    }

    // MARK: - 底部说明

    private var footerNote: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("纯演示，不读真实数据", systemImage: "eye.slash")
            Text("验收对照（Spec §2 / G5）：成功态只在持久化回执后渲染；失败保持可操作，再点即重试；在途保存中连点被忽略。生产接入 NOT RUN。")
                .foregroundStyle(.secondary)
        }
        .font(.footnote)
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }
}

#if DEBUG
#Preview("待办勾选 · Light") {
    NavigationStack { V38TodoCheckFeedbackPreview() }
        .preferredColorScheme(.light)
}

#Preview("待办勾选 · Dark") {
    NavigationStack { V38TodoCheckFeedbackPreview() }
        .preferredColorScheme(.dark)
}
#endif
