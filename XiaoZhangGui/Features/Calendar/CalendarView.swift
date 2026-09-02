import SwiftUI
import SwiftData

// MARK: - 日历页（V2.1：月份导航 + 状态点月历 + 当日聚合详情）
// 语义对齐 Android CalendarScreen；聚合 营业额/待办/临期/客户需求

struct CalendarView: View {
    @Query private var todos: [Todo]
    @Query private var performances: [Performance]
    @Query private var expenses: [Expense]
    @Query private var expiryItems: [ExpiryItem]
    @Query private var customers: [CustomerRequest]
    @Query private var memos: [Memo]

    /// 周日为一周起点（对齐 Android firstDayOfWeek = 0）
    private var calendar: Calendar {
        var c = Calendar.current
        c.firstWeekday = 1
        return c
    }

    @State private var currentMonth: Date = Date().startOfMonth
    @State private var selectedDate = Date()

    private var dayData: CalendarDayData {
        CalendarAgenda.dayData(
            date: selectedDate,
            todos: todos,
            performances: performances,
            expenses: expenses,
            expiryItems: expiryItems,
            customers: customers,
            memos: memos
        )
    }

    var body: some View {
        PageBackground {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    titleSection
                    monthNavigator
                    weekdayHeader
                        .padding(.top, 8)
                    monthGrid
                        .padding(.top, 4)
                    dayDetail
                        .padding(.top, V21Layout.spaceXXL)

                }
            }
        }
        .navigationTitle("日历")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("日历")
                .v21Style(.titlePage)
                .foregroundColor(V21.textPrimary)
            Text("营业额 · 待办 · 临期 · 客户需求一览")
                .v21Style(.bodyMedium)
                .foregroundColor(V21.textTertiary)
        }
        .padding(.top, 12)
        .padding(.horizontal, V21Layout.pageMargin)
    }

    // MARK: - 月份导航

    private var monthNavigator: some View {
        HStack {
            monthButton("chevron.left") {
                currentMonth = calendar.date(byAdding: .month, value: -1, to: currentMonth) ?? currentMonth
            }
            Spacer()
            Text(currentMonth, format: .dateTime.year().month(.wide).locale(Locale(identifier: "zh_CN")))
                .v21Style(.titleLarge)
                .fontWeight(.semibold)
                .foregroundColor(V21.textPrimary)
            Spacer()
            monthButton("chevron.right") {
                currentMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth) ?? currentMonth
            }
        }
        .padding(.horizontal, V21Layout.pageMargin)
        .padding(.vertical, 8)
    }

    private func monthButton(_ icon: String, action: @escaping () -> Void) -> some View {
        Button {
            Haptic.light()
            action()
        } label: {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(V21.textTertiary)
                .frame(width: 32, height: 32)
                .background {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(V21.surfaceGlass)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(V21.dividerStrong, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
    }

    // MARK: - 星期标题 + 月历网格

    private var weekdayHeader: some View {
        HStack(spacing: 2) {
            ForEach(["日", "一", "二", "三", "四", "五", "六"], id: \.self) { day in
                Text(day)
                    .v21Style(.labelSmall)
                    .fontWeight(.semibold)
                    .foregroundColor(V21.textTertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
        }
        .padding(.horizontal, 20)
    }

    private var monthGrid: some View {
        let days = gridDates(for: currentMonth)
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 7), spacing: 4) {
            ForEach(days.indices, id: \.self) { index in
                if let date = days[index] {
                    CalendarDayCell(
                        date: date,
                        isToday: date.isToday,
                        isSelected: date.isSameDay(as: selectedDate),
                        flags: CalendarAgenda.eventFlags(
                            date: date,
                            todos: todos,
                            performances: performances,
                            expenses: expenses,
                            expiryItems: expiryItems,
                            customers: customers,
                            memos: memos
                        )
                    ) {
                        withAnimation(.easeOut(duration: 0.15)) { selectedDate = date }
                        Haptic.light()
                    }
                } else {
                    Color.clear
                        .aspectRatio(1, contentMode: .fit)
                }
            }
        }
        .padding(.horizontal, 20)
    }

    /// 当月网格日期（首尾补 nil 空位，总格数为 7 的倍数）
    private func gridDates(for month: Date) -> [Date?] {
        let monthStart = month.startOfMonth
        let daysInMonth = calendar.range(of: .day, in: .month, for: monthStart)?.count ?? 30
        let firstWeekday = calendar.component(.weekday, from: monthStart) - 1 // 0 = 周日
        let totalCells = Int(ceil(Double(firstWeekday + daysInMonth) / 7.0)) * 7

        var cells: [Date?] = Array(repeating: nil, count: totalCells)
        for day in 1...daysInMonth {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: monthStart) {
                cells[firstWeekday + day - 1] = date
            }
        }
        return cells
    }

    // MARK: - 当日详情

    private var detailItems: [CalendarDetailItem] {
        var items: [CalendarDetailItem] = []
        if !dayData.revenues.isEmpty || !dayData.expenses.isEmpty {
            items.append(CalendarDetailItem(
                dotColor: V21.brandGreen,
                label: "营业额 / 收支",
                sublabel: "收入 \(dayData.revenues.count) 笔 · 支出 \(dayData.expenses.count) 笔",
                rightText: "¥\(Fmt.groupedInt(dayData.revenueTotal))",
                rightColor: V21.brandGreen
            ))
        }
        if !dayData.todos.isEmpty {
            let summary = dayData.todos.prefix(2).map { todo in
                "\(todo.dueDate.map(Fmt.time) ?? "—") \(todo.title)"
            }.joined(separator: " · ")
            items.append(CalendarDetailItem(dotColor: V21.info, label: "待办事项", sublabel: summary, rightText: "", rightColor: V21.textPrimary))
        }
        if !dayData.memos.isEmpty {
            let summary = dayData.memos.prefix(2).map(\.title).joined(separator: " · ")
            items.append(CalendarDetailItem(dotColor: V21.textTertiary, label: "记录", sublabel: summary, rightText: "", rightColor: V21.textPrimary))
        }
        if !dayData.expiry.isEmpty {
            let summary = dayData.expiry.prefix(2).map { "\($0.name) ×\($0.quantity)" }.joined(separator: " · ")
            items.append(CalendarDetailItem(dotColor: V21.warning, label: "临期提醒", sublabel: summary, rightText: "", rightColor: V21.textPrimary))
        }
        if !dayData.customers.isEmpty {
            let summary = dayData.customers.prefix(2).map { request in
                let info = CustomerDeliveryStorage.decode(request.customer)
                let time = info.deliveryTime.map(Fmt.time) ?? "待配送"
                let address = request.roomOrAddress.isBlank ? (info.legacyCustomer ?? "客户配送") : request.roomOrAddress
                return "\(time) \(address)"
            }.joined(separator: " · ")
            items.append(CalendarDetailItem(dotColor: V21.textQuaternary, label: "客户需求", sublabel: summary, rightText: "", rightColor: V21.textPrimary))
        }
        return items
    }

    private var dayDetail: some View {
        GlassSurface {
            VStack(alignment: .leading, spacing: 0) {
                Text("\(calendar.component(.month, from: selectedDate))月\(calendar.component(.day, from: selectedDate))日 · \(selectedDate.weekdayLabel)")
                    .v21Style(.titleSmall)
                    .fontWeight(.semibold)
                    .foregroundColor(V21.textPrimary)
                    .padding(.bottom, 12)

                if detailItems.isEmpty {
                    Text("当天暂无经营记录")
                        .v21Style(.bodyMedium)
                        .foregroundColor(V21.textTertiary)
                        .padding(.vertical, 10)
                } else {
                    ForEach(Array(detailItems.enumerated()), id: \.offset) { index, item in
                        if index > 0 { DividerLine() }
                        CalendarDetailRow(
                            dotColor: item.dotColor,
                            label: item.label,
                            sublabel: item.sublabel,
                            rightText: item.rightText,
                            rightColor: item.rightColor
                        )
                    }
                }
            }
            .padding(18)
        }
        .padding(.horizontal, V21Layout.pageMargin)
    }
}

// MARK: - 日期格（今日绿底 / 选中玻璃底 + 描边 / 状态点）

struct CalendarDayCell: View {
    let date: Date
    let isToday: Bool
    let isSelected: Bool
    let flags: CalendarAgenda.EventFlags
    var onTap: () -> Void

    private var dayNumber: Int {
        Calendar.current.component(.day, from: date)
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 2) {
                Text("\(dayNumber)")
                    .v21Style(.bodySmall)
                    .fontWeight(isToday ? .bold : .medium)
                    .foregroundColor(
                        isToday ? .white :
                        (isSelected ? V21.textPrimary : V21.textSecondary)
                    )
                HStack(spacing: 2) {
                    if flags.hasRevenue { EventDot(color: V21.brandGreen) }
                    if flags.hasTodo { EventDot(color: V21.info) }
                    if flags.hasExpiry { EventDot(color: V21.warning) }
                    if flags.hasCustomer { EventDot(color: V21.textQuaternary) }
                    if flags.hasMemo { EventDot(color: V21.textTertiary) }
                }
                .frame(height: 4)
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(1, contentMode: .fit)
            .background {
                ZStack {
                    if isToday {
                        Circle().fill(V21.brandGreen)
                    } else if isSelected {
                        Circle().fill(V21.surfaceElevated)
                    }
                }
            }
            .overlay {
                if isSelected && !isToday {
                    Circle().strokeBorder(V21.dividerHighlight, lineWidth: 1)
                }
            }
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }

    private struct EventDot: View {
        let color: Color
        var body: some View {
            Circle().fill(color).frame(width: 4, height: 4)
        }
    }
}

// MARK: - 详情行 + 分割线

private struct CalendarDetailItem {
    let dotColor: Color
    let label: String
    let sublabel: String
    let rightText: String
    let rightColor: Color
}

struct CalendarDetailRow: View {
    let dotColor: Color
    let label: String
    let sublabel: String
    let rightText: String
    let rightColor: Color

    var body: some View {
        HStack {
            Circle().fill(dotColor).frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .v21Style(.bodyMedium)
                    .fontWeight(.medium)
                    .foregroundColor(V21.textPrimary)
                Text(sublabel)
                    .v21Style(.labelSmall)
                    .foregroundColor(V21.textTertiary)
            }
            Spacer()
            if !rightText.isEmpty {
                Text(rightText)
                    .v21Style(.titleSmall)
                    .fontWeight(.semibold)
                    .foregroundColor(rightColor)
            }
        }
        .padding(.vertical, 10)
    }
}

struct DividerLine: View {
    var body: some View {
        Rectangle().fill(V21.divider).frame(height: 1)
    }
}

extension Date {
    /// "星期X"
    var weekdayLabel: String {
        let symbols = ["星期日", "星期一", "星期二", "星期三", "星期四", "星期五", "星期六"]
        let index = Calendar.current.component(.weekday, from: self) - 1
        return symbols[index]
    }
}
