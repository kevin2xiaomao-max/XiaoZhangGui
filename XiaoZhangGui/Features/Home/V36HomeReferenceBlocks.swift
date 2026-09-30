import SwiftUI

struct V36QuickActions: View {
    var onRecord: () -> Void
    var onStock: () -> Void
    var onMore: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            pill("记账", "plus", filled: true, action: onRecord)
            pill("入库", "shippingbox", filled: false, action: onStock)
            pill("更多", "square.grid.2x2", filled: false, action: onMore)
        }
        .accessibilityElement(children: .contain)
    }

    private func pill(_ title: String, _ icon: String, filled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(filled ? Color.white : V32.textPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background(
                Capsule()
                    .fill(filled ? V32.brand : V32.card)
                    .overlay(Capsule().strokeBorder(filled ? Color.clear : V32.cardOutline, lineWidth: 1))
            )
        }
        .buttonStyle(V32PressButtonStyle())
        .accessibilityLabel(title)
    }
}

struct V36RecentContact: Identifiable {
    let id: String
    let title: String
}

struct V36RecentContactsRail: View {
    let contacts: [V36RecentContact]
    var onAdd: () -> Void
    var onOpen: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            V32SectionHeader("最近往来") {
                V32SectionAction(text: "全部", action: onOpen)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    contactCell(title: "添加", systemName: "plus", filled: false, action: onAdd)
                    ForEach(contacts.prefix(6)) { contact in
                        contactCell(title: contact.title, initial: String(contact.title.prefix(1)), action: onOpen)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private func contactCell(title: String, systemName: String? = nil, initial: String? = nil, filled: Bool = true, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 5) {
                ZStack {
                    Circle()
                        .fill(filled ? V32.brandSoft : V32.pageBGSecondary)
                        .overlay(Circle().strokeBorder(V32.cardOutline, lineWidth: 1))
                    if let systemName {
                        Image(systemName: systemName)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(V32.brand)
                    } else if let initial {
                        Text(initial)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(V32.brand)
                    }
                }
                .frame(width: 44, height: 44)
                Text(title)
                    .v32Text(.caption)
                    .foregroundStyle(V32.textSecondary)
                    .lineLimit(1)
                    .frame(width: 48)
            }
        }
        .buttonStyle(V32PressButtonStyle())
        .accessibilityLabel(title)
    }
}

struct V36IncomeOutcomePair: View {
    let income: Double
    let goal: Double
    var onTap: () -> Void

    private var progress: Double {
        goal > 0 ? min(max(income / goal, 0), 1) : 0
    }

    var body: some View {
        HStack(spacing: 10) {
            card(title: "本月收入", value: Fmt.money(income), icon: "arrow.down.left")
            card(title: "本月目标", value: Fmt.money(goal), icon: "arrow.up.right", caption: "\(Int((progress * 100).rounded()))%")
        }
    }

    private func card(title: String, value: String, icon: String, caption: String? = nil) -> some View {
        Button(action: onTap) {
            V32Card(padding: 13, radius: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(V32.brand)
                        .frame(width: 24, height: 24)
                        .background(Circle().fill(V32.brandSoft))
                    Text(title)
                        .v32Text(.caption)
                        .foregroundStyle(V32.textTertiary)
                    Text(value)
                        .font(.title3.weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(V32.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    if let caption {
                        Text(caption)
                            .v32Text(.caption)
                            .foregroundStyle(V32.textTertiary)
                    }
                }
            }
        }
        .buttonStyle(V32PressButtonStyle())
        .accessibilityLabel("\(title) \(value)")
    }
}
