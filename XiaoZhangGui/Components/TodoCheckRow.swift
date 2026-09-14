import SwiftUI

struct TodoCheckRow: View {
    let todo: Todo
    var showsDate: Bool = false
    var onToggle: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Button {
                Haptic.light()
                withAnimation(.easeOut(duration: 0.2)) { onToggle() }
            } label: {
                ZStack {
                    if todo.isCompleted {
                        Circle().fill(V21.brandGreen)
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                    } else {
                        Circle()
                            .strokeBorder(Color(.separator), lineWidth: 1.5)
                    }
                }
                .frame(width: 22, height: 22)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(todo.isCompleted ? "恢复为未完成" : "标记为已完成")

            VStack(alignment: .leading, spacing: 2) {
                Text(DisplayText.visible(todo.title, fallback: "待办事项"))
                    .font(.body)
                    .foregroundStyle(todo.isCompleted ? Color.secondary : Color.primary)
                    .strikethrough(todo.isCompleted, color: .secondary)
                    .lineLimit(2)
                if !todo.detail.isEmpty {
                    Text(DisplayText.visible(todo.detail))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            if let due = todo.dueDate {
                Text(showsDate ? Fmt.monthDayTime(due) : Fmt.time(due))
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}
