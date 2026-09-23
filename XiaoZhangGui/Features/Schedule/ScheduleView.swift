import SwiftData
import SwiftUI

// MARK: - 日历（V3.7.1：Schedule + Calendar 合并）
//
// 结构（MD §7）：
// - 顶部蓝色 S2 masthead：月份标题 + 横向日期 strip，当前日白胶囊
// - 当日事件 GroupSurface：TimedRow（time/title/type-status/trailing 完成圈），allDay 事项为 WorkRow
// - 月历 Section：月份导航 + 状态点月历 + 当日详情行（整月能力保留，去玻璃卡，保留行 + hairline）
// - 当日经营摘要（数据口径不变）
//
// 数据复用 CalendarAgenda + ScheduleAgenda；计算语义零改动（§15 受保护核心）。

struct ScheduleView: View {
    @Query private var todos: [Todo]
    @Query private var performances: [Performance]
    @Query private var expenses: [Expense]
    @Query private var expiryItems: [ExpiryItem]
    @Query private var customers: [CustomerRequest]
    @Query private var memos: [Memo]

    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedDate = Date()
    @State private var currentMonth: Date = Date().startOfMonth
    @State private var expandedExpiry: Set<String> = []
    @State private var stateActionError: String?
    @State private var showCustomer = false
    @State private var showMemo = false
    @State private var showPerformance = false

    /// 周一起始（日程周条用）
    private var calendar: Calendar {
        var c = Calendar.current
        c.firstWeekday = 2 // 周一起始
        return c
    }

    /// 周日起始（月历网格用，对齐原 CalendarView / Android firstDayOfWeek = 0）
    private var monthCalendar: Calendar {
        var c = Calendar.current
        c.firstWeekday = 1
        return c
    }

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

    private var scheduleDay: ScheduleDay {
        let undated = todos.filter { !$0.isCompleted && $0.dueDate == nil }
        var day = ScheduleAgenda.make(from: dayData, undatedTodos: undated)
        // P1-1：已完成项按 completedAt 归属当天（与首页「今日已完成」同一事实源），
        // 分类逻辑在 ScheduleAgenda 纯函数内（可单测）；
        // 不改 CalendarAgenda.dayData / eventFlags 口径。
        let done = ScheduleAgenda.completedTodosForDay(
            todos.filter(\.isCompleted), date: selectedDate, calendar: calendar
        )
        day.timedEvents += done.timed

        // P1-1：补齐「当天完成、但配送时间不在今天」的 done 配送（去重 dayData 已收录项），
        // 保证首页今日完成计数点进来后每一项都能在当天日程追踪到。
        let existingDeliveryIDs = Set(
            day.timedEvents.map(\.id)
            + day.allDay.deliveries.map { "delivery-\($0.notificationID)" }
        )
        let doneDeliveries = ScheduleAgenda.completedDeliveriesForDay(
            customers,
            date: selectedDate,
            alreadyIncludedIDs: existingDeliveryIDs,
            calendar: calendar
        )
        day.timedEvents += doneDeliveries.timed
        day.timedEvents.sort { $0.date < $1.date }
        day.allDay.todos += done.allDay
        day.allDay.deliveries += doneDeliveries.allDay
        return day
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: V371.Space.section) {
                masthead
                timelineSection
                allDaySection
                monthSection
                summarySection
            }
            .padding(.horizontal, V371.Space.page)
            .padding(.top, 8)
            .animation(V32Motion.animation(V32Motion.resolve(.fade, reduceMotion: reduceMotion)), value: selectedDate)
        }
        .scrollIndicators(.hidden)
        .v371Canvas()
        .v371DockInset()
        .alert("操作失败", isPresented: Binding(get: { stateActionError != nil }, set: { if !$0 { stateActionError = nil } })) {
            Button("知道了", role: .cancel) { stateActionError = nil }
        } message: { Text(stateActionError ?? "事项状态未改变，请重试") }
        .navigationTitle("日历")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $showCustomer) { CustomerView() }
        .navigationDestination(isPresented: $showMemo) { MemoView() }
        .navigationDestination(isPresented: $showPerformance) { PerformanceView() }
        .onChange(of: selectedDate) { _, newValue in
            // 周条选中跨月日期时，月历网格跟随到该月（仅视图状态同步，不改计算语义）
            currentMonth = newValue.startOfMonth
        }
    }

    // MARK: - S2 顶部 masthead（月份标题 + 日期 strip，当前日白胶囊）

    private var monthTitle: String {
        selectedDate.formatted(.dateTime.year().month(.wide).locale(Locale(identifier: "zh_CN")))
    }

    private var masthead: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center) {
                Text("日历")
                    .font(V371.Type.heroTitle)
                    .foregroundStyle(V371.Colors.heroText)
                Text(monthTitle)
                    .font(V371.Type.badge)
                    .foregroundStyle(V371.Colors.heroText)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.white.opacity(0.22), in: Capsule(style: .continuous))
                Spacer(minLength: 8)
                Button("今天") {
                    Haptic.selection()
                    selectedDate = Date()
                }
                .font(V371.Type.badge)
                .foregroundStyle(V371.Colors.heroText)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(.white.opacity(0.22), in: Capsule(style: .continuous))
                .buttonStyle(.plain)
                .frame(minHeight: 44)
                .accessibilityLabel("回到今天")
            }

            HStack(spacing: 2) {
                ForEach(weekDays, id: \.self) { date in
                    mastheadDayCell(date)
                }
            }
        }
        .padding(20)
        .background(
            LinearGradient(
                colors: [V371.Colors.heroTop, V371.Colors.heroBottom],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .clipShape(RoundedRectangle(cornerRadius: V371.Radius.hero, style: .continuous))
        )
        .shadow(color: V371.Shadow.hero.color, radius: V371.Shadow.hero.radius,
                y: V371.Shadow.hero.y)
    }

    /// 本周日期（周一~周日）
    private var weekDays: [Date] {
        guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: selectedDate)?.start else { return [] }
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: weekStart) }
    }

    private func mastheadDayCell(_ date: Date) -> some View {
        let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
        let weekday = calendar.component(.weekday, from: date)
        let symbols = ["日", "一", "二", "三", "四", "五", "六"]
        let day = calendar.component(.day, from: date)

        return Button {
            Haptic.selection()
            selectedDate = date
        } label: {
            VStack(spacing: 6) {
                Text(symbols[weekday - 1])
                    .font(V371.Type.badge)
                    .foregroundStyle(V371.Colors.heroText)
                Text("\(day)")
                    .font(V371.Type.sectionTitle)
                    .fontWeight(date.isToday ? .bold : .medium)
                    .foregroundStyle(isSelected ? V371.Colors.blue : V371.Colors.heroText)
                    .frame(width: 40, height: 40)
                    .background(
                        Capsule(style: .continuous)
                            .fill(isSelected ? Color.white : Color.clear)
                    )
            }
            .frame(maxWidth: .infinity, minHeight: 64)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(calendar.component(.month, from: date))月\(day)日星期\(symbols[weekday - 1])")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - 当日事件（TimedRow）

    @ViewBuilder
    private var timelineSection: some View {
        if !scheduleDay.timedEvents.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader("当日时间")
                GroupSurface {
                    ForEach(Array(scheduleDay.timedEvents.enumerated()), id: \.element.id) { index, event in
                        if index > 0 { V371Divider() }
                        timedEventRow(event)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func timedEventRow(_ event: ScheduleEvent) -> some View {
        switch event {
        case .todo(let todo):
            TimedRow(
                time: Fmt.time(event.date),
                title: eventTitle(event),
                subtitle: eventSubtitle(event),
                accent: todo.isCompleted ? V371.Colors.gray : V371.Colors.blue,
                action: { toggleTodo(todo) }
            ) {
                Image(systemName: todo.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(todo.isCompleted ? V371.Colors.green : V371.Colors.textTertiary)
                    .frame(width: 44, height: 44)
                    .accessibilityHidden(true)
            }
            .accessibilityHint(todo.isCompleted ? "已完成，轻点标记为未完成" : "轻点标记为完成")
        case .delivery(_, let date):
            TimedRow(
                time: Fmt.time(date),
                title: eventTitle(event),
                subtitle: eventSubtitle(event),
                accent: V371.Colors.blue,
                action: { showCustomer = true }
            ) {
                V371Chevron()
            }
            .accessibilityHint("轻点查看客户配送")
        }
    }

    // MARK: - 全天事项（WorkRow）

    /// 全天事项分组（ViewBuilder 内不允许局部 let，上提到计算属性）
    private var allDayTodos: [Todo] { scheduleDay.allDay.todos }
    private var allDayDeliveries: [CustomerRequest] { scheduleDay.allDay.deliveries }
    private var allDayExpiry: [ExpiryItem] { scheduleDay.allDay.expiry }
    private var allDayMemos: [Memo] { scheduleDay.allDay.memos }

    @ViewBuilder
    private var allDaySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("全天事项") {
                if !scheduleDay.allDay.isEmpty {
                    Text(allDayCount)
                        .font(V371.Type.rowSubtitle)
                        .foregroundStyle(V371.Colors.textTertiary)
                }
            }

            if scheduleDay.allDay.isEmpty && scheduleDay.timedEvents.isEmpty {
                EmptyState(icon: "sun.max", title: "该日期暂无事项", message: "这一天还没有安排")
            } else if !scheduleDay.allDay.isEmpty {
                GroupSurface {
                    VStack(spacing: 0) {
                        ForEach(allDayTodos, id: \.persistentModelID) { todo in
                            allDayTodoRow(todo)
                            if todo.persistentModelID != allDayTodos.last?.persistentModelID
                                || !allDayDeliveries.isEmpty || !allDayExpiry.isEmpty || !allDayMemos.isEmpty {
                                V371Divider()
                            }
                        }
                        ForEach(allDayDeliveries, id: \.persistentModelID) { request in
                            allDayDeliveryRow(request)
                            if request.persistentModelID != allDayDeliveries.last?.persistentModelID
                                || !allDayExpiry.isEmpty || !allDayMemos.isEmpty {
                                V371Divider()
                            }
                        }
                        ForEach(allDayExpiry, id: \.persistentModelID) { item in
                            expiryRow(item)
                            if item.persistentModelID != allDayExpiry.last?.persistentModelID || !allDayMemos.isEmpty {
                                V371Divider()
                            }
                        }
                        ForEach(allDayMemos, id: \.persistentModelID) { memo in
                            allDayMemoRow(memo)
                            if memo.persistentModelID != allDayMemos.last?.persistentModelID {
                                V371Divider()
                            }
                        }
                    }
                }
            }
        }
    }

    private var allDayCount: String {
        let n = scheduleDay.allDay.todos.count
            + scheduleDay.allDay.deliveries.count
            + scheduleDay.allDay.expiry.count
            + scheduleDay.allDay.memos.count
        return "\(n) 项"
    }

    private func allDayTodoRow(_ todo: Todo) -> some View {
        WorkRow(
            icon: todo.isCompleted ? "checkmark.circle.fill" : "circle",
            iconColor: todo.isCompleted ? V371.Colors.green : V371.Colors.blue,
            title: DisplayText.visible(todo.title, fallback: "待办事项"),
            subtitle: (todo.priority >= TodoPriority.high.rawValue && !todo.isCompleted) ? "高优先级" : nil,
            action: { toggleTodo(todo) }
        ) {
            EmptyView()
        }
        .accessibilityHint(todo.isCompleted ? "已完成，轻点标记为未完成" : "轻点标记为完成")
    }

    private func allDayDeliveryRow(_ request: CustomerRequest) -> some View {
        let done = request.statusEnum == .done
        return WorkRow(
            icon: done ? "checkmark.circle.fill" : "box.truck.fill",
            iconColor: done ? V371.Colors.green : V371.Colors.blue,
            title: request.displayTitle,
            subtitle: request.displaySubtitle.isEmpty ? "客户配送" : request.displaySubtitle,
            action: { showCustomer = true }
        ) {
            V371Chevron()
        }
    }

    private func allDayMemoRow(_ memo: Memo) -> some View {
        WorkRow(
            icon: "note.text",
            iconColor: V371.Colors.gray,
            title: memo.title,
            subtitle: memo.content,
            action: { showMemo = true }
        ) {
            V371Chevron()
        }
    }

    /// 临期行默认折叠，点击展开备注/照片
    private func expiryRow(_ item: ExpiryItem) -> some View {
        let isExpanded = expandedExpiry.contains(item.notificationID)
        let days = item.daysLeft(from: selectedDate)

        return VStack(spacing: 0) {
            WorkRow(
                icon: "hourglass",
                iconColor: V371.Colors.orange,
                title: "\(DisplayText.visible(item.name, fallback: "临期商品")) × \(item.quantity)",
                subtitle: expiryHint(days),
                action: {
                    withAnimation(V32Motion.animation(V32Motion.resolve(.spring, reduceMotion: reduceMotion))) {
                        if isExpanded { expandedExpiry.remove(item.notificationID) } else { expandedExpiry.insert(item.notificationID) }
                    }
                }
            ) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(V371.Colors.textTertiary)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    .frame(width: 44, height: 44)
                    .accessibilityHidden(true)
            }

            if isExpanded {
                VStack(alignment: .leading, spacing: 10) {
                    if !item.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(DisplayText.visible(item.note, fallback: "退货备注"))
                            .font(V371.Type.rowSubtitle)
                            .foregroundStyle(V371.Colors.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: V371.Radius.control, style: .continuous)
                                    .fill(V371.Colors.groupSecondary)
                            )
                    }
                    if let data = item.imageData, let image = UIImage(data: data) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity)
                            .frame(height: 140)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: V371.Radius.control, style: .continuous))
                    }
                }
                .padding(.horizontal, V371.Space.rowPadding)
                .padding(.bottom, 12)
            }
        }
    }

    private func expiryHint(_ days: Int) -> String {
        if days < 0 { return "已临期 \(abs(days)) 天" }
        if days == 0 { return "今天临期" }
        return "\(days) 天后到期"
    }

    private func toggleTodo(_ todo: Todo) {
        let wasCompleted = todo.isCompleted
        do {
            try TodoRepository(context: modelContext).toggleComplete(todo)
            if !wasCompleted { Haptic.success() }
        } catch {
            Haptic.error()
            stateActionError = "事项状态未改变，请重试。"
        }
    }

    // MARK: - 月历 Section（月份导航 + 状态点月历 + 当日详情；整月能力保留）

    private var monthSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("月历")
            GroupSurface {
                VStack(spacing: 0) {
                    monthNavigator
                        .padding(.horizontal, V371.Space.rowPadding)
                        .padding(.top, 10)
                        .padding(.bottom, 4)
                    weekdayHeader
                        .padding(.horizontal, V371.Space.rowPadding)
                    monthGrid
                        .padding(.horizontal, V371.Space.rowPadding)
                        .padding(.vertical, 6)
                    V371Divider(leading: 0)
                    dayDetail
                        .padding(.bottom, 6)
                }
            }
        }
    }

    private var monthNavigator: some View {
        HStack {
            monthButton("chevron.left", label: "上个月") {
                withAnimation(V32Motion.animation(V32Motion.resolve(.fade, reduceMotion: reduceMotion))) {
                    currentMonth = monthCalendar.date(byAdding: .month, value: -1, to: currentMonth) ?? currentMonth
                }
            }
            Spacer()
            Text(currentMonth, format: .dateTime.year().month(.wide).locale(Locale(identifier: "zh_CN")))
                .font(V371.Type.sectionTitle)
                .foregroundStyle(V371.Colors.textPrimary)
            Spacer()
            monthButton("chevron.right", label: "下个月") {
                withAnimation(V32Motion.animation(V32Motion.resolve(.fade, reduceMotion: reduceMotion))) {
                    currentMonth = monthCalendar.date(byAdding: .month, value: 1, to: currentMonth) ?? currentMonth
                }
            }
        }
    }

    private func monthButton(_ icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button {
            Haptic.light()
            action()
        } label: {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(V371.Colors.textSecondary)
                .frame(width: 44, height: 44)
                .background(Circle().fill(V371.Colors.groupSecondary))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private var weekdayHeader: some View {
        HStack(spacing: 2) {
            ForEach(["日", "一", "二", "三", "四", "五", "六"], id: \.self) { day in
                Text(day)
                    .font(V371.Type.rowSubtitle)
                    .foregroundStyle(V371.Colors.textTertiary)
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
                    ScheduleCalendarDayCell(
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
                        withAnimation(V32Motion.animation(V32Motion.resolve(.fade, reduceMotion: reduceMotion))) {
                            selectedDate = date
                        }
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
        let daysInMonth = monthCalendar.range(of: .day, in: .month, for: monthStart)?.count ?? 30
        let firstWeekday = monthCalendar.component(.weekday, from: monthStart) - 1 // 0 = 周日
        let totalCells = Int(ceil(Double(firstWeekday + daysInMonth) / 7.0)) * 7

        var cells: [Date?] = Array(repeating: nil, count: totalCells)
        for day in 1...daysInMonth {
            if let date = monthCalendar.date(byAdding: .day, value: day - 1, to: monthStart) {
                cells[firstWeekday + day - 1] = date
            }
        }
        return cells
    }

    // MARK: - 当日详情（去玻璃卡，保留行 + hairline）

    private var detailItems: [ScheduleDetailItem] {
        var items: [ScheduleDetailItem] = []
        if !dayData.revenues.isEmpty || !dayData.expenses.isEmpty {
            items.append(ScheduleDetailItem(
                dotColor: V371.Colors.green,
                label: "营业额 / 收支",
                sublabel: "收入 \(dayData.revenues.count) 笔 · 支出 \(dayData.expenses.count) 笔",
                rightText: "¥\(Fmt.groupedInt(dayData.revenueTotal))",
                rightColor: V371.Colors.blue
            ))
        }
        if !dayData.todos.isEmpty {
            let summary = dayData.todos.prefix(2).map { todo in
                // P1-3：nil / 00:00 → 全天，不出现 00:00
                "\(DayTimeLabel.label(todo.dueDate, unscheduledText: "全天")) \(todo.title)"
            }.joined(separator: " · ")
            items.append(ScheduleDetailItem(dotColor: V371.Colors.blue, label: "待办事项", sublabel: summary, rightText: "", rightColor: V371.Colors.textPrimary))
        }
        if !dayData.memos.isEmpty {
            let summary = dayData.memos.prefix(2).map(\.title).joined(separator: " · ")
            items.append(ScheduleDetailItem(dotColor: V371.Colors.textTertiary, label: "记录", sublabel: summary, rightText: "", rightColor: V371.Colors.textPrimary))
        }
        if !dayData.expiry.isEmpty {
            let summary = dayData.expiry.prefix(2).map { "\($0.name) ×\($0.quantity)" }.joined(separator: " · ")
            items.append(ScheduleDetailItem(dotColor: V371.Colors.orange, label: "临期提醒", sublabel: summary, rightText: "", rightColor: V371.Colors.textPrimary))
        }
        if !dayData.customers.isEmpty {
            let summary = dayData.customers.prefix(2).map { request in
                let info = CustomerDeliveryStorage.decode(request.customer)
                // P1-2：只表达配送时间，不与状态冲突
                let time = info.deliveryTime.map(Fmt.time) ?? "未设配送时间"
                let address = DisplayText.visible(request.roomOrAddress, fallback: DisplayText.visible(info.legacyCustomer ?? "", fallback: "客户配送"))
                return "\(time) \(address)"
            }.joined(separator: " · ")
            items.append(ScheduleDetailItem(dotColor: V371.Colors.gray, label: "客户需求", sublabel: summary, rightText: "", rightColor: V371.Colors.textPrimary))
        }
        return items
    }

    private var dayDetail: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("\(calendar.component(.month, from: selectedDate))月\(calendar.component(.day, from: selectedDate))日 · \(scheduleWeekdayText(selectedDate))")
                .font(V371.Type.rowTitle)
                .foregroundStyle(V371.Colors.textPrimary)
                .padding(.horizontal, V371.Space.rowPadding)
                .padding(.vertical, 12)

            if detailItems.isEmpty {
                Text("当天暂无经营记录")
                    .font(V371.Type.rowSubtitle)
                    .foregroundStyle(V371.Colors.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, V371.Space.rowPadding)
                    .padding(.bottom, 14)
            } else {
                ForEach(Array(detailItems.enumerated()), id: \.offset) { index, item in
                    if index > 0 { V371Divider(leading: V371.Space.rowPadding) }
                    HStack(spacing: 10) {
                        Circle()
                            .fill(item.dotColor)
                            .frame(width: 8, height: 8)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.label)
                                .font(V371.Type.rowTitle)
                                .foregroundStyle(V371.Colors.textPrimary)
                            Text(item.sublabel)
                                .font(V371.Type.rowSubtitle)
                                .foregroundStyle(V371.Colors.textTertiary)
                                .lineLimit(1)
                        }
                        Spacer(minLength: 8)
                        if !item.rightText.isEmpty {
                            Text(item.rightText)
                                .font(V371.Type.rowTitle)
                                .foregroundStyle(item.rightColor)
                        }
                    }
                    .padding(.horizontal, V371.Space.rowPadding)
                    .padding(.vertical, 12)
                    .frame(minHeight: 44)
                }
            }
        }
    }

    private func scheduleWeekdayText(_ date: Date) -> String {
        let symbols = ["星期日", "星期一", "星期二", "星期三", "星期四", "星期五", "星期六"]
        let index = Calendar.current.component(.weekday, from: date) - 1
        guard symbols.indices.contains(index) else { return "" }
        return symbols[index]
    }

    // MARK: - 当日经营摘要（不逐笔列流水；数据口径不变）

    /// ViewBuilder 内不允许局部 let 声明，摘要数据上提到计算属性。
    private var summaryData: ScheduleDaySummary { scheduleDay.summary }

    @ViewBuilder
    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("当日经营")
            GroupSurface {
                WorkRow(
                    icon: "chart.bar.fill",
                    iconColor: V371.Colors.green,
                    title: "收支概览",
                    subtitle: "收入 ¥\(Fmt.groupedAmount(summaryData.revenue)) · 支出 ¥\(Fmt.groupedAmount(summaryData.expense))",
                    action: { showPerformance = true }
                ) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("¥" + Fmt.groupedAmount(summaryData.net))
                            .font(V371.Type.rowTitle)
                            .foregroundStyle(V371.Colors.textPrimary)
                        Text("净额")
                            .font(V371.Type.rowSubtitle)
                            .foregroundStyle(V371.Colors.textTertiary)
                    }
                }
            }
        }
    }

    // MARK: - 事件展示辅助（语义沿用原 ScheduleView）

    private func eventTitle(_ event: ScheduleEvent) -> String {
        switch event {
        case .todo(let todo): return DisplayText.visible(todo.title, fallback: "待办事项")
        case .delivery(let request, _): return request.displayTitle
        }
    }

    private func eventSubtitle(_ event: ScheduleEvent) -> String {
        switch event {
        case .todo(let todo):
            return DisplayText.visible(todo.detail, fallback: todo.priorityLevel.label)
        case .delivery(let request, _):
            let parts = [
                request.displayCustomerName,
                DisplayText.visible(request.roomOrAddress),
                request.statusEnum.rawValue
            ].filter { !$0.isEmpty }
            return parts.joined(separator: " · ")
        }
    }
}

// MARK: - 月历日期格（今日蓝色实心 / 选中描边 / 状态点）
// 由原 CalendarView.CalendarDayCell 移植，仅换 V371 语义色；改名避免与 CalendarView.swift 重定义冲突。

private struct ScheduleCalendarDayCell: View {
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
                    .font(V371.Type.rowSubtitle)
                    .fontWeight(isToday ? .bold : .medium)
                    .foregroundStyle(
                        isToday ? Color.white :
                        (isSelected ? V371.Colors.textPrimary : V371.Colors.textSecondary)
                    )
                HStack(spacing: 2) {
                    if flags.hasRevenue { EventDot(color: V371.Colors.green) }
                    if flags.hasTodo { EventDot(color: V371.Colors.blue) }
                    if flags.hasExpiry { EventDot(color: V371.Colors.orange) }
                    if flags.hasCustomer { EventDot(color: V371.Colors.gray) }
                    if flags.hasMemo { EventDot(color: V371.Colors.textTertiary) }
                }
                .frame(height: 4)
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(1, contentMode: .fit)
            .background {
                ZStack {
                    if isToday {
                        Circle().fill(V371.Colors.blue)
                    } else if isSelected {
                        Circle().fill(V371.Colors.groupSecondary)
                    }
                }
            }
            .overlay {
                if isSelected && !isToday {
                    Circle().strokeBorder(V371.Colors.blue.opacity(0.55), lineWidth: 1.2)
                }
            }
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(dayNumber)日")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private struct EventDot: View {
        let color: Color
        var body: some View {
            Circle().fill(color).frame(width: 4, height: 4)
        }
    }
}

// MARK: - 当日详情行模型

private struct ScheduleDetailItem {
    let dotColor: Color
    let label: String
    let sublabel: String
    let rightText: String
    let rightColor: Color
}
