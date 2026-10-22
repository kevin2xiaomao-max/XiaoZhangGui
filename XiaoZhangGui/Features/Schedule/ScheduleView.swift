import SwiftData
import SwiftUI

// MARK: - 日历（V3.8 重建 R3：Editorial + 日期锚点 Motion）
//
// 结构（MD §7 + `Docs/V38-Page-Motion-Spec.md` §3）：
// - 顶部 editorial 月份标题 + 当日事件/全天事项平面列表（细分割线）
// - 月历 Section：月份导航 + 月/周密度 chips + 状态点月历 + 当日详情行
// - 密度切换：选中格为几何锚点（matchedGeometryEffect 选中环滑移），
//   布局由 `V38ScheduleLayout` 纯函数决定，`selectedDate` 绝不漂移
// - 当日经营摘要（数据口径不变）
//
// 数据复用 CalendarAgenda + ScheduleAgenda；计算语义零改动（§15 受保护核心）。
// V3.8 改动仅限展示层与密度状态，业务链（toggle/导航路由/数据派生）与 V3.7.1 一致。

struct ScheduleView: View {
    @Query private var todos: [Todo]
    @Query private var performances: [Performance]
    @Query private var expenses: [Expense]
    @Query private var expiryItems: [ExpiryItem]
    @Query private var customers: [CustomerRequest]
    @Query private var memos: [Memo]

    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var selectedDate = Date()
    @State private var currentMonth: Date = Date().startOfMonth
    /// V3.8 R3：月/周展示密度（纯视图状态；周密度只取月网格中选中日期
    /// 所在的既有周行，不构造周数据，不影响 selectedDate 语义）。
    @State private var density: V38ScheduleDensity = .month
    /// V3.8 R3：选中环 matched-geometry 命名空间（Spec §3 日期锚点）。
    @Namespace private var selectionAnchor
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
                V371ScrollEndMarker(identifier: V371AccessibilityID.scrollEndCalendar)
            }
            .padding(.horizontal, V371.Space.page)
            .padding(.top, 8)
            .padding(.bottom, V371.Space.section)
            .animation(V371.Motion.animation(V371.Motion.resolve(.fade, reduceMotion: reduceMotion)), value: selectedDate)
        }
        .scrollIndicators(.hidden)
        .accessibilityIdentifier(V371AccessibilityID.screenCalendar)
        .v371Canvas()
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

    // MARK: - Editorial 顶部（月标题 + 轻量周日期 strip）

    private var masthead: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 3) {
                Text(selectedDate, format: .dateTime.month(.wide).day().locale(Locale(identifier: "zh_CN")))
                    .font(.system(size: 30, weight: .bold, design: .default))
                    .foregroundStyle(V371.Colors.textPrimary)
                Text(scheduleWeekdayText(selectedDate))
                    .font(.subheadline)
                    .foregroundStyle(V371.Colors.textTertiary)
            }
            Spacer(minLength: 8)
            Button("今天") {
                Haptic.selection()
                selectedDate = Date()
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(V38ScheduleStyle.accent)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.thinMaterial, in: Capsule(style: .continuous))
            .buttonStyle(.plain)
            .frame(minHeight: 44)
            .accessibilityLabel("回到今天")
        }
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
            // V3.8 R3：切换日期时事项列表 contentChange 交叉淡入，不整列闪烁（Spec §3）
            .transition(.opacity)
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
                        .font(V371.Typography.rowSubtitle)
                        .foregroundStyle(V371.Colors.textTertiary)
                }
            }

            if scheduleDay.allDay.isEmpty && scheduleDay.timedEvents.isEmpty {
                HStack(spacing: 12) {
                    Image(systemName: "sun.max")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(V371.Colors.textTertiary)
                        .frame(width: 36, height: 36)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("该日期暂无事项")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(V371.Colors.textPrimary)
                        Text("这一天还没有安排")
                            .font(.footnote)
                            .foregroundStyle(V371.Colors.textTertiary)
                    }
                }
                .padding(.vertical, 8)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("该日期暂无事项")
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
                    withAnimation(V371.Motion.animation(V371.Motion.resolve(.spring, reduceMotion: reduceMotion))) {
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
                            .font(V371.Typography.rowSubtitle)
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
            VStack(spacing: 0) {
                monthNavigator
                    .padding(.bottom, 4)
                if dynamicTypeSize.isAccessibilitySize {
                    accessibleMonthList
                        .padding(.vertical, 6)
                } else {
                    densityChips
                        .padding(.bottom, 2)
                    weekdayHeader
                    monthGrid
                        .padding(.vertical, 6)
                }
                V371Divider(leading: 0)
                dayDetail
                    .padding(.bottom, 6)
            }
        }
    }

    // MARK: - V3.8 R3 月/周密度切换（chip 样式）

    /// 月/周密度 chips。只切换网格展示密度：
    /// 周密度展示月网格中选中日期所在的既有周行，`selectedDate` 不变、
    /// 选中格位置不变（Spec §3 锚点模型，实现见 `V38ScheduleLayout`）。
    private var densityChips: some View {
        HStack {
            Spacer(minLength: 8)
            HStack(spacing: 2) {
                densityChip(.month, title: "月", label: "月视图")
                densityChip(.week, title: "周", label: "周视图")
            }
            .padding(3)
            .background(Capsule(style: .continuous).fill(V371.Colors.groupSecondary))
        }
    }

    private func densityChip(_ value: V38ScheduleDensity, title: String, label: String) -> some View {
        let isActive = density == value
        return Button {
            Haptic.selection()
            withAnimation(V38MotionTokens.animation(for: .contentChange, reduceMotion: reduceMotion)) {
                density = value
            }
        } label: {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isActive ? Color.white : V371.Colors.textSecondary)
                .padding(.horizontal, 16)
                .frame(minHeight: 36)
                .background {
                    if isActive {
                        Capsule(style: .continuous).fill(V38ScheduleStyle.accent)
                    }
                }
                .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(.vertical, 4) // 命中区 ≥44pt（36 + 上下各 4）
        .accessibilityLabel(label)
        .accessibilityAddTraits(isActive ? .isSelected : [])
        .accessibilityIdentifier(value == .month ? "v38.schedule.density.month" : "v38.schedule.density.week")
    }

    private var monthNavigator: some View {
        HStack {
            monthButton("chevron.left", label: density == .week ? "上一周" : "上个月") {
                navigatePeriod(by: -1)
            }
            Spacer()
            // 周密度下标题跟随选中日期所在月；月密度下为网格月份。
            Text(density == .week ? selectedDate : currentMonth, format: .dateTime.year().month(.wide).locale(Locale(identifier: "zh_CN")))
                .font(V371.Typography.sectionTitle)
                .foregroundStyle(V371.Colors.textPrimary)
            Spacer()
            monthButton("chevron.right", label: density == .week ? "下一周" : "下个月") {
                navigatePeriod(by: 1)
            }
        }
    }

    /// 周期导航：月密度按月移动网格（选中日期不变，V3.7.1 原行为）；
    /// 周密度按周移动选中日期（标准周视图行为，月份由 onChange 同步跟随）。
    private func navigatePeriod(by direction: Int) {
        withAnimation(V38MotionTokens.animation(for: .contentChange, reduceMotion: reduceMotion)) {
            switch density {
            case .month:
                currentMonth = monthCalendar.date(byAdding: .month, value: direction, to: currentMonth) ?? currentMonth
            case .week:
                selectedDate = calendar.date(byAdding: .day, value: 7 * direction, to: selectedDate) ?? selectedDate
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
                    .font(V371.Typography.rowSubtitle)
                    .foregroundStyle(V371.Colors.textTertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
        }
    }

    /// V3.8 R3 网格：按周行渲染（不用 LazyVGrid），密度形态由
    /// `V38ScheduleLayout` 纯函数决定 —— 选中格 (row, col) 在月/周密度下
    /// 恒定，选中行上方行保留高度（ghost）、下方行收起（collapsed），
    /// 容器高度过渡不引起选中格位移（Spec §3 锚点 ≤1pt）。
    private var monthGrid: some View {
        // 周密度锚定选中日期所在月；月密度展示导航月份（V3.7.1 原语义）。
        let gridMonth = density == .week ? selectedDate : currentMonth
        let rows = V38ScheduleLayout.rows(
            month: gridMonth,
            calendar: monthCalendar,
            selectedDate: selectedDate,
            density: density
        )
        return VStack(spacing: 4) {
            ForEach(rows, id: \.index) { row in
                weekRowView(row)
            }
        }
        .accessibilityIdentifier("v38.schedule.grid")
    }

    @ViewBuilder
    private func weekRowView(_ row: V38ScheduleLayout.WeekRow) -> some View {
        HStack(spacing: 2) {
            ForEach(Array(row.cells.enumerated()), id: \.offset) { _, date in
                if let date {
                    dayCell(date)
                } else {
                    Color.clear
                        .frame(maxWidth: .infinity)
                        .frame(height: V38ScheduleStyle.cellHeight)
                }
            }
        }
        .frame(height: row.presentation == .collapsed ? 0 : V38ScheduleStyle.cellHeight)
        .opacity(row.presentation == .full ? 1 : 0)
        .clipped()
        .allowsHitTesting(row.presentation == .full)
        .accessibilityHidden(row.presentation != .full)
    }

    /// V3.8 R3 日期格：大日期数字 + 真实事项状态点；
    /// 今日 = 经营绿实心圆；选中 = 选中环（matchedGeometryEffect 以格为锚滑移）。
    @ViewBuilder
    private func dayCell(_ date: Date) -> some View {
        let isSelected = date.isSameDay(as: selectedDate)
        let isToday = date.isToday
        let flags = eventFlags(for: date)
        Button {
            withAnimation(V38ScheduleStyle.selectionAnimation(reduceMotion: reduceMotion)) {
                selectedDate = date
            }
            Haptic.light()
        } label: {
            ZStack {
                if isToday {
                    Circle().fill(V38ScheduleStyle.accent)
                        .frame(width: 40, height: 40)
                } else if isSelected {
                    Circle().fill(V38ScheduleStyle.accent.opacity(0.12))
                        .frame(width: 40, height: 40)
                }
                if isSelected {
                    // 选中环：全网格唯一实例，切换选中日期时滑到新格，格子 frame 不变。
                    Circle()
                        .strokeBorder(isToday ? Color.white : V38ScheduleStyle.accent, lineWidth: 1.5)
                        .frame(width: 40, height: 40)
                        .matchedGeometryEffect(id: "v38.schedule.selectionRing", in: selectionAnchor)
                }
                VStack(spacing: 2) {
                    Text("\(monthCalendar.component(.day, from: date))")
                        .font(isSelected || isToday ? V38ScheduleStyle.dayNumberFontEmphasized : V38ScheduleStyle.dayNumberFont)
                        .foregroundStyle(isToday ? Color.white : (isSelected ? V371.Colors.textPrimary : V371.Colors.textSecondary))
                    HStack(spacing: 2) {
                        if flags.hasRevenue { ScheduleEventDot(color: V371.Colors.green) }
                        if flags.hasTodo { ScheduleEventDot(color: V371.Colors.blue) }
                        if flags.hasExpiry { ScheduleEventDot(color: V371.Colors.orange) }
                        if flags.hasCustomer { ScheduleEventDot(color: V371.Colors.gray) }
                        if flags.hasMemo { ScheduleEventDot(color: V371.Colors.textTertiary) }
                    }
                    .frame(height: 4)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: V38ScheduleStyle.cellHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(calendarAccessibilityLabel(date: date, flags: flags))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("v38.schedule.day.\(Self.isoDateString(date))")
    }

    /// UI 测试定位用的稳定日期标识（yyyy-MM-dd，本地时区）。
    private static func isoDateString(_ date: Date) -> String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    /// 辅助功能字号改用纵向日期列表，避免七列网格挤压；日期选择与详情仍复用同一状态。
    private var accessibleMonthList: some View {
        LazyVStack(spacing: 0) {
            ForEach(monthDates(for: currentMonth), id: \.self) { date in
                let flags = eventFlags(for: date)
                Button {
                    withAnimation(V371.Motion.animation(V371.Motion.resolve(.fade, reduceMotion: reduceMotion))) {
                        selectedDate = date
                    }
                    Haptic.light()
                } label: {
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(date, format: .dateTime.day().weekday(.wide).locale(Locale(identifier: "zh_CN")))
                                .font(V371.Typography.rowTitle)
                                .foregroundStyle(V371.Colors.textPrimary)
                            Text(flags.accessibilitySummary)
                                .font(V371.Typography.rowSubtitle)
                                .foregroundStyle(V371.Colors.textSecondary)
                                .multilineTextAlignment(.leading)
                        }
                        Spacer(minLength: 8)
                        if date.isSameDay(as: selectedDate) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(V371.Colors.blue)
                                .accessibilityHidden(true)
                        }
                    }
                    .padding(.horizontal, V371.Space.rowPadding)
                    .padding(.vertical, 12)
                    .frame(minHeight: 60)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(calendarAccessibilityLabel(date: date, flags: flags))
                .accessibilityAddTraits(date.isSameDay(as: selectedDate) ? .isSelected : [])

                if date != monthDates(for: currentMonth).last { V371Divider() }
            }
        }
    }

    private func monthDates(for month: Date) -> [Date] {
        V38ScheduleLayout.gridDates(month: month, calendar: monthCalendar).compactMap { $0 }
    }

    private func eventFlags(for date: Date) -> CalendarAgenda.EventFlags {
        CalendarAgenda.eventFlags(
            date: date,
            todos: todos,
            performances: performances,
            expenses: expenses,
            expiryItems: expiryItems,
            customers: customers,
            memos: memos
        )
    }

    private func calendarAccessibilityLabel(date: Date, flags: CalendarAgenda.EventFlags) -> String {
        let dateText = date.formatted(.dateTime.month().day().weekday(.wide).locale(Locale(identifier: "zh_CN")))
        let todayText = date.isToday ? "，今天" : ""
        return "\(dateText)\(todayText)，\(flags.accessibilitySummary)"
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
                .font(V371.Typography.rowTitle)
                .foregroundStyle(V371.Colors.textPrimary)
                .padding(.horizontal, V371.Space.rowPadding)
                .padding(.vertical, 12)

            if detailItems.isEmpty {
                Text("当天暂无经营记录")
                    .font(V371.Typography.rowSubtitle)
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
                                .font(V371.Typography.rowTitle)
                                .foregroundStyle(V371.Colors.textPrimary)
                            Text(item.sublabel)
                                .font(V371.Typography.rowSubtitle)
                                .foregroundStyle(V371.Colors.textTertiary)
                                .lineLimit(1)
                        }
                        Spacer(minLength: 8)
                        if !item.rightText.isEmpty {
                            Text(item.rightText)
                                .font(V371.Typography.rowTitle)
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
                            .font(V371.Typography.rowTitle)
                            .foregroundStyle(V371.Colors.textPrimary)
                        Text("净额")
                            .font(V371.Typography.rowSubtitle)
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

// MARK: - 事项状态点（日期格内，颜色沿用 V371 语义色：收入/待办/临期/客户/备忘）

private struct ScheduleEventDot: View {
    let color: Color
    var body: some View {
        Circle().fill(color).frame(width: 4, height: 4)
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
