import SwiftUI

// MARK: - 待办勾选行（首页 Floating Sheet 使用）

struct TodoCheckRow: View {
    let todo: Todo
    var onToggle: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            // 勾选圆
            Button {
                Haptic.light()
                withAnimation(.easeOut(duration: 0.2)) { onToggle() }
            } label: {
                ZStack {
                    if todo.isCompleted {
                        Circle()
                            .fill(V21.brandGreen)
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    } else {
                        Circle()
                            .strokeBorder(V21.dividerHighlight, lineWidth: 1.5)
                    }
                }
                .frame(width: 22, height: 22)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(todo.isCompleted ? "恢复为未完成" : "标记为已完成")

            VStack(alignment: .leading, spacing: 5) {
                Text(todo.title)
                    .v21Style(.bodyLarge)
                    .fontWeight(.medium)
                    .foregroundColor(todo.isCompleted ? V21.textTertiary : V21.textPrimary)
                    .strikethrough(todo.isCompleted, color: V21.textTertiary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 6) {
                    if let due = todo.dueDate {
                        Text(Fmt.time(due))
                            .v21Style(.labelMedium)
                            .foregroundColor(V21.textTertiary)
                        Spacer(minLength: 10)
                    }
                    PriorityDot(level: todo.priority)
                    Text(todo.priorityLevel.label)
                        .v21Style(.labelMedium)
                        .foregroundColor(V21.textTertiary)
                }
            }
        }
        .contentShape(Rectangle())
    }
}
