import SwiftUI
import SwiftData

private enum CalendarScope: String, CaseIterable {
    case weekly = "周"
    case monthly = "月"
}

struct CalendarView: View {
    @Query private var todos: [Todo]
    @Query private var performances: [Performance]
    @Query private var expenses: [Expense]
    @Query private var expiryItems: [ExpiryItem]
    @Query private var customers: [CustomerRequest]
    @Query private var memos: [Memo]

    private var calendar: Calendar {
        var c = Calendar.current
        c.firstWeekday = 2
        return c
    }

    @State private var currentMonth: Date = Date().startOfMonth
    @State private var selectedDate = Date()
    @State private var scope: CalendarScope = .weekly
    @State private var showReminderSheet = false

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
                VStack(alignment: .leading, spacing: 18) {
                    header
                    scopeAndWeek
                    if scope == .monthly {
                        weekdayHeader
                        monthGrid
                    }
                    reminderActions
                    dayDetail
                }
                .padding(.horizontal, V21Layout.pageMargin)
                .padding(.top, 12)
                .padding(.bottom, V21Layout.bottomDockContentGap)
            }
        }
        .navigationTitle("日历")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showReminderSheet) {
            TodoEditorSheet(todo: nil)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("日历")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(V21.textPrimary)
            HStack {
                Text(rangeLabel)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(V21.textTertiary)
                Spacer()
                Button {
                    Haptic.light()
                    selectedDate = Date()
                    currentMonth = Date().startOfMonth
                } label: {
                    Text("今天")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(V21.textPrimary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(V21.surfaceElevated))
                        .overlay(Capsule().strokeBorder(V21.divider.opacity(0.5), lineWidth: 0.6))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var rangeLabel: String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "zh_CN")
        fmt.dateFormat = "M月"
        if scope == .weekly {
            let days = weekDays
            guard let first = days.first, let last = days.last else { return fmt.string(from: selectedDate) }
            return "\(fmt.string(from: first)) – \(fmt.string(from: last))"
        }
        return currentMonth.formatted(.dateTime.year().month(.wide).locale(Locale(identifier: "zh_CN")))
    }

    private var scopeAndWeek: some View {
        VStack(spacing: 16) {
            HStack(spacing: 0) {
                scopeChip(.weekly)
                scopeChip(.monthly)
            }
            .padding(4)
            .background(Capsule().fill(V21.surfacePrimary))
            .overlay(Capsule().strokeBorder(V21.divider.opacity(0.4), lineWidth: 0.6))
            weekStrip
        }
        .padding(16)
        .background(V21.surfaceElevated, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(V21.divider.opacity(0.4), lineWidth: 0.6))
    }

    private func scopeChip(_ item: CalendarScope) -> some View {
        Button {
            withAnimation(.easeOut(duration: 0.18)) { scope = item }
            Haptic.light()
        } label: {
            Text(item.rawValue)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(scope == item ? V21.surfaceElevated : V21.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(Capsule().fill(scope == item ? V21.textPrimary : Color.clear))
        }
        .buttonStyle(.plain)
    }

    private var weekDays: [Date] {
        let cal = calendar
        let weekday = cal.component(.weekday, from: selectedDate)
        let offset = (weekday + 5) % 7
        let start = cal.date(byAdding: .day, value: -offset, to: cal.startOfDay(for: selectedDate)) ?? selectedDate
        return (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: start) }
    }

    private var weekStrip: some View {
        HStack(spacing: 0) {
            ForEach(weekDays, id: \.self) { day in
                let selected = day.isSameDay(as: selectedDate)
                let flags = CalendarAgenda.eventFlags(
                    date: day, todos: todos, performances: performances, expenses: expenses,
                    expiryItems: expiryItems, customers: customers, memos: memos
                )
                Button {
                    withAnimation(.easeOut(duration: 0.15)) {
                        selectedDate = day
                        currentMonth = day.startOfMonth
                    }
                    Haptic.light()
                } label: {
                    VStack(spacing: 6) {
                        Text(shortWeekday(day)).font(.system(size: 11, weight: .medium)).foregroundStyle(V21.textTertiary)
                        Text("\(calendar.component(.day, from: day))")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundStyle(selected ? V21.surfaceElevated : V21.textPrimary)
                            .frame(width: 36, height: 36)
                            .background(Circle().fill(selected ? V21.textPrimary : Color.clear))
                        Circle()
                            .fill(hasAny(flags) && !selected ? V21.textPrimary.opacity(0.35) : Color.clear)
                            .frame(width: 4, height: 4)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func hasAny(_ flags: CalendarAgenda.EventFlags) -> Bool {
        flags.hasRevenue || flags.hasTodo || flags.hasExpiry || flags.hasCustomer || flags.hasMemo
    }

    private func shortWeekday(_ date: Date) -> String {
        ["日", "一", "二", "三", "四", "五", "六"][Calendar.current.component(.weekday, from: date) - 1]
    }

    private var weekdayHeader: some View {
        HStack(spacing: 2) {
            ForEach(["一", "二", "三", "四", "五", "六", "日"], id: \.self) { day in
                Text(day).font(.system(size: 11, weight: .semibold)).foregroundStyle(V21.textTertiary).frame(maxWidth: .infinity).padding(.vertical, 6)
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
                            date: date, todos: todos, performances: performances, expenses: expenses,
                            expiryItems: expiryItems, customers: customers, memos: memos
                        )
                    ) {
                        withAnimation(.easeOut(duration: 0.15)) { selectedDate = date }
                        Haptic.light()
                    }
                } else {
                    Color.clear.aspectRatio(1, contentMode: .fit)
                }
            }
        }
    }

    private func gridDates(for month: Date) -> [Date?] {
        let monthStart = month.startOfMonth
        let daysInMonth = calendar.range(of: .day, in: .month, for: monthStart)?.count ?? 30
        let raw = calendar.component(.weekday, from: monthStart)
        let firstIndex = (raw + 5) % 7
        let totalCells = Int(ceil(Double(firstIndex + daysInMonth) / 7.0)) * 7
        var cells: [Date?] = Array(repeating: nil, count: totalCells)
        for day in 1...daysInMonth {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: monthStart) {
                cells[firstIndex + day - 1] = date
            }
        }
        return cells
    }

    private var reminderActions: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                showReminderSheet = true
                Haptic.light()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus").font(.system(size: 14, weight: .bold))
                    Text("设提醒").font(.system(size: 15, weight: .semibold))
                }
                .foregroundStyle(V21.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(style: StrokeStyle(lineWidth: 1.15, dash: [6, 5]))
                        .foregroundStyle(V21.dividerStrong.opacity(0.85))
                )
            }
            .buttonStyle(.plain)
            hintRow("person", "只给自己", "写进待办，仅本机可见")
            hintRow("storefront", "店内事项", "出现在首页提醒和今日待办")
            hintRow("shippingbox", "客户配送", "到客户页登记地址与时间")
        }
    }

    private func hintRow(_ symbol: String, _ title: String, _ subtitle: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol).font(.system(size: 14, weight: .semibold)).foregroundStyle(V21.textSecondary)
                .frame(width: 36, height: 36)
                .background(V21.surfacePrimary, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 15, weight: .semibold)).foregroundStyle(V21.textPrimary)
                Text(subtitle).font(.system(size: 12, weight: .medium)).foregroundStyle(V21.textTertiary)
            }
            Spacer()
        }
        .padding(14)
        .background(V21.surfaceElevated, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(V21.divider.opacity(0.4), lineWidth: 0.6))
    }

    private var detailCards: [(symbol: String, title: String, subtitle: String, trailing: String)] {
        var items: [(String, String, String, String)] = []
        if !dayData.revenues.isEmpty || !dayData.expenses.isEmpty {
            items.append(("yensign.circle", "营业额 / 收支", "收入 \(dayData.revenues.count) 笔 · 支出 \(dayData.expenses.count) 笔", "¥\(Fmt.groupedInt(dayData.revenueTotal))"))
        }
        for todo in dayData.todos.prefix(3) {
            items.append(("checkmark.circle", todo.title, todo.dueDate.map(Fmt.time) ?? "全天", ""))
        }
        for memo in dayData.memos.prefix(2) {
            items.append(("note.text", memo.title, "记录", ""))
        }
        for item in dayData.expiry.prefix(2) {
            items.append(("exclamationmark.triangle", "\(item.name) ×\(item.quantity)", "临期", ""))
        }
        for request in dayData.customers.prefix(2) {
            let info = CustomerDeliveryStorage.decode(request.customer)
            let time = info.deliveryTime.map(Fmt.time) ?? "待配送"
            let address = request.roomOrAddress.isBlank ? (info.legacyCustomer ?? "客户配送") : request.roomOrAddress
            items.append(("shippingbox", address, time, ""))
        }
        return items
    }

    private var dayDetail: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("\(calendar.component(.month, from: selectedDate))月\(calendar.component(.day, from: selectedDate))日 · \(selectedDate.weekdayLabel)")
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundStyle(V21.textPrimary)
            if detailCards.isEmpty {
                Text("当天暂无经营记录")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(V21.textTertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .background(V21.surfaceElevated, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            } else {
                VStack(spacing: 10) {
                    ForEach(Array(detailCards.enumerated()), id: \.offset) { _, item in
                        HStack(spacing: 12) {
                            Image(systemName: item.symbol).font(.system(size: 14, weight: .semibold)).foregroundStyle(V21.textSecondary)
                                .frame(width: 36, height: 36)
                                .background(V21.surfacePrimary, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.title).font(.system(size: 15, weight: .semibold)).foregroundStyle(V21.textPrimary).lineLimit(2)
                                Text(item.subtitle).font(.system(size: 12, weight: .medium)).foregroundStyle(V21.textTertiary).lineLimit(1)
                            }
                            Spacer()
                            if !item.trailing.isEmpty {
                                Text(item.trailing).font(.system(size: 15, weight: .semibold, design: .rounded)).foregroundStyle(V21.textPrimary)
                            }
                        }
                        .padding(14)
                        .background(V21.surfaceElevated, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(V21.divider.opacity(0.4), lineWidth: 0.6))
                    }
                }
            }
        }
    }
}

struct CalendarDayCell: View {
    let date: Date
    let isToday: Bool
    let isSelected: Bool
    let flags: CalendarAgenda.EventFlags
    var onTap: () -> Void

    private var dayNumber: Int { Calendar.current.component(.day, from: date) }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 2) {
                Text("\(dayNumber)")
                    .font(.system(size: 14, weight: isToday || isSelected ? .bold : .medium, design: .rounded))
                    .foregroundStyle(isSelected || isToday ? V21.surfaceElevated : V21.textSecondary)
                HStack(spacing: 2) {
                    if flags.hasRevenue { Circle().fill(V21.brandGreen).frame(width: 4, height: 4) }
                    if flags.hasTodo { Circle().fill(V21.info).frame(width: 4, height: 4) }
                    if flags.hasExpiry { Circle().fill(V21.warning).frame(width: 4, height: 4) }
                    if flags.hasCustomer { Circle().fill(V21.textQuaternary).frame(width: 4, height: 4) }
                    if flags.hasMemo { Circle().fill(V21.textTertiary).frame(width: 4, height: 4) }
                }
                .frame(height: 4)
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(1, contentMode: .fit)
            .background {
                if isSelected || isToday { Circle().fill(V21.textPrimary) }
            }
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }
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
                Text(label).v21Style(.bodyMedium).fontWeight(.medium).foregroundColor(V21.textPrimary)
                Text(sublabel).v21Style(.labelSmall).foregroundColor(V21.textTertiary)
            }
            Spacer()
            if !rightText.isEmpty {
                Text(rightText).v21Style(.titleSmall).fontWeight(.semibold).foregroundColor(rightColor)
            }
        }
        .padding(.vertical, 10)
    }
}

struct DividerLine: View {
    var body: some View { Rectangle().fill(V21.divider).frame(height: 1) }
}

extension Date {
    var weekdayLabel: String {
        ["星期日", "星期一", "星期二", "星期三", "星期四", "星期五", "星期六"][Calendar.current.component(.weekday, from: self) - 1]
    }
}
