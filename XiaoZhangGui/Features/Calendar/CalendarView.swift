import SwiftUI
import SwiftData

// MARK: - 日历页（V32：月份导航 + 状态点月历 + 当日聚合详情；整月能力保留）
// 聚合 营业额/待办/临期/客户需求；派生层 CalendarAgenda 零改动

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
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: V32Layout.sectionGap) {
                V32PageHeader("日历", subtitle: "营业额 · 待办 · 临期 · 客户需求一览")
                monthNavigator
                V32Card {
                    VStack(spacing: 4) {
                        weekdayHeader
                        monthGrid
                    }
                }
                dayDetail
            }
            .padding(.horizontal, V32Layout.pageMargin)
            .padding(.top, 8)
            .padding(.bottom, V32Layout.bottomPad)
        }
        .v32PageBackground()
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: - 月份导航

    private var monthNavigator: some View {
        HStack {
            monthButton("chevron.left") {
                currentMonth = calendar.date(byAdding: .month, value: -1, to: currentMonth) ?? currentMonth
            }
            Spacer()
            Text(currentMonth, format: .dateTime.year().month(.wide).locale(Locale(identifier: "zh_CN")))
                .v32Text(.section)
                .foregroundStyle(V32.textPrimary)
            Spacer()
            monthButton("chevron.right") {
                currentMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth) ?? currentMonth
            }
        }
    }

    private func monthButton(_ icon: String, action: @escaping () -> Void) -> some View {
        Button {
            Haptic.light()
            action()
        } label: {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(V32.textSecondary)
                .frame(width: 36, height: 36)
                .background(Circle().fill(V32.card))
                .overlay(Circle().strokeBorder(V32.cardOutline, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: - 星期标题 + 月历网格

    private var weekdayHeader: some View {
        HStack(spacing: 2) {
            ForEach(["日", "一", "二", "三", "四", "五", "六"], id: \.self) { day in
                Text(day)
                    .v32Text(.caption)
                    .foregroundStyle(V32.textTertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
        }
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
                dotColor: V32.brand,
                label: "营业额 / 收支",
                sublabel: "收入 \(dayData.revenues.count) 笔 · 支出 \(dayData.expenses.count) 笔",
                rightText: "¥\(Fmt.groupedInt(dayData.revenueTotal))",
                rightColor: V32.brand
            ))
        }
        if !dayData.todos.isEmpty {
            let summary = dayData.todos.prefix(2).map { todo in
                "\(todo.dueDate.map(Fmt.time) ?? "—") \(todo.title)"
            }.joined(separator: " · ")
            items.append(CalendarDetailItem(dotColor: V32.info, label: "待办事项", sublabel: summary, rightText: "", rightColor: V32.textPrimary))
        }
        if !dayData.memos.isEmpty {
            let summary = dayData.memos.prefix(2).map(\.title).joined(separator: " · ")
            items.append(CalendarDetailItem(dotColor: V32.textTertiary, label: "记录", sublabel: summary, rightText: "", rightColor: V32.textPrimary))
        }
        if !dayData.expiry.isEmpty {
            let summary = dayData.expiry.prefix(2).map { "\($0.name) ×\($0.quantity)" }.joined(separator: " · ")
            items.append(CalendarDetailItem(dotColor: V32.amber, label: "临期提醒", sublabel: summary, rightText: "", rightColor: V32.textPrimary))
        }
        if !dayData.customers.isEmpty {
            let summary = dayData.customers.prefix(2).map { request in
                let info = CustomerDeliveryStorage.decode(request.customer)
                let time = info.deliveryTime.map(Fmt.time) ?? "待配送"
                let address = DisplayText.visible(request.roomOrAddress, fallback: DisplayText.visible(info.legacyCustomer ?? "", fallback: "客户配送"))
                return "\(time) \(address)"
            }.joined(separator: " · ")
            items.append(CalendarDetailItem(dotColor: V32.neutral, label: "客户需求", sublabel: summary, rightText: "", rightColor: V32.textPrimary))
        }
        return items
    }

    private var dayDetail: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("\(calendar.component(.month, from: selectedDate))月\(calendar.component(.day, from: selectedDate))日 · \(selectedDate.weekdayLabel)")
                .v32Text(.headline)
                .foregroundStyle(V32.textPrimary)

            V32Card {
                if detailItems.isEmpty {
                    Text("当天暂无经营记录")
                        .v32Text(.subhead)
                        .foregroundStyle(V32.textTertiary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(detailItems.enumerated()), id: \.offset) { index, item in
                            if index > 0 { Rectangle().fill(V32.divider).frame(height: 1) }
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
            }
        }
    }
}

// MARK: - 日期格（今日墨绿实心 / 选中卡片色 + 描边 / 状态点）

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
                    .v32Text(.subhead)
                    .fontWeight(isToday ? .bold : .medium)
                    .foregroundStyle(
                        isToday ? Color.white :
                        (isSelected ? V32.textPrimary : V32.textSecondary)
                    )
                HStack(spacing: 2) {
                    if flags.hasRevenue { EventDot(color: V32.brand) }
                    if flags.hasTodo { EventDot(color: V32.info) }
                    if flags.hasExpiry { EventDot(color: V32.amber) }
                    if flags.hasCustomer { EventDot(color: V32.neutral) }
                    if flags.hasMemo { EventDot(color: V32.textTertiary) }
                }
                .frame(height: 4)
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(1, contentMode: .fit)
            .background {
                ZStack {
                    if isToday {
                        Circle().fill(V32.hero)
                    } else if isSelected {
                        Circle().fill(V32.cardElevated)
                    }
                }
            }
            .overlay {
                if isSelected && !isToday {
                    Circle().strokeBorder(V32.brand.opacity(0.55), lineWidth: 1.2)
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

// MARK: - 详情行

private struct CalendarDetailItem {
    let dotColor: Color
    let label: String
    let sublabel: String
    let rightText: String
    let rightColor: Color
}

private struct CalendarDetailRow: View {
    let dotColor: Color
    let label: String
    let sublabel: String
    let rightText: String
    let rightColor: Color

    var body: some View {
        HStack(spacing: 10) {
            Circle().fill(dotColor).frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .v32Text(.title)
                    .foregroundStyle(V32.textPrimary)
                Text(sublabel)
                    .v32Text(.caption)
                    .foregroundStyle(V32.textTertiary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            if !rightText.isEmpty {
                Text(rightText)
                    .v32Text(.headline)
                    .foregroundStyle(rightColor)
            }
        }
        .padding(.vertical, 12)
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
