import SwiftUI

struct V35HomeOverviewGrid: View {
    let todoCount: Int
    let expiryCount: Int
    let customerCount: Int
    let focusCount: Int

    init(todoCount: Int, expiryCount: Int, customerCount: Int, focusCount: Int) {
        self.todoCount = todoCount
        self.expiryCount = expiryCount
        self.customerCount = customerCount
        self.focusCount = focusCount
    }

    /// 兼容旧调用方。新代码请传 focusCount（今日待处理件数），不要再把待办数当成未读。
    init(todoCount: Int, expiryCount: Int, customerCount: Int, unreadCount: Int) {
        self.init(todoCount: todoCount, expiryCount: expiryCount, customerCount: customerCount, focusCount: unreadCount)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            V32SectionHeader("今日概览")
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                item("待办", todoCount, "checkmark.circle", V32.brand)
                item("临期", expiryCount, "clock.badge.exclamationmark", V32.amber)
                item("客户需求", customerCount, "person.2", V32.info)
                item("待处理", focusCount, "bell", V32.neutral)
            }
        }
    }

    private func item(_ title: String, _ count: Int, _ icon: String, _ color: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).foregroundStyle(color)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.caption).foregroundStyle(V32.textSecondary)
                Text("\(count)").font(.title3.bold()).monospacedDigit().foregroundStyle(V32.textPrimary)
            }
            Spacer()
        }
        .padding(13)
        .background(V32.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(V32.cardOutline, lineWidth: 1))
    }
}
