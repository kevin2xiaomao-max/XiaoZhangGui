import SwiftData
import SwiftUI

// MARK: - 日程（V32）：周条 + 当日时间轴 + 全天事项 + 经营摘要
// 数据复用 CalendarAgenda + ScheduleAgenda；完整月历为二级入口（CalendarView）。

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
    @State private var expandedExpiry: Set<String> = []

    private var calendar: Calendar {
        var c = Calendar.current
        c.firstWeekday = 2 // 周一起始
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
        // b27 T20：已完成项保留在时间线/全天区，分类逻辑在 ScheduleAgenda 纯函数内（可单测）；
        // 不改 CalendarAgenda.dayData / eventFlags 口径。
        let done = ScheduleAgenda.completedTodosForDay(
            todos.filter(\.isCompleted), date: selectedDate, calendar: calendar
        )
        day.timedEvents += done.timed
        day.timedEvents.sort { $0.date < $1.date }
        day.allDay.todos += done.allDay
        return day
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: V32Layout.sectionGap) {
                header
                weekStrip
                timelineSection
                allDaySection
                summarySection
            }
            .padding(.horizontal, V32Layout.pageMargin)
            .padding(.top, 8)
            .animation(V32Motion.animation(V32Motion.resolve(.fade, reduceMotion: reduceMotion)), value: selectedDate)
        }
        .scrollIndicators(.hidden)
        .v32PageBackground()
        .v32PageBottomInset()
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: 顶部

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("日程")
                    .v32Text(.pageTitle)
                    .foregroundStyle(V32.textPrimary)
                Text("今日事，今日毕")
                    .v32Text(.subhead)
                    .foregroundStyle(V32.textTertiary)
            }
            Spacer()
            NavigationLink {
                CalendarView()
            } label: {
                Image(systemName: "calendar")
                    .font(.system(size: V32Layout.toolIcon, weight: .semibold))
                    .foregroundStyle(V32.textSecondary)
                    .frame(width: V32Layout.toolCircle, height: V32Layout.toolCircle)
                    .background(
                        Circle()
                            .fill(V32.card)
                            .overlay(Circle().strokeBorder(V32.cardOutline, lineWidth: 1))
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("完整月历")
        }
    }

    private var monthLabel: some View {
        HStack(spacing: 6) {
            Text(selectedDate, format: .dateTime.year().month(.wide).locale(Locale(identifier: "zh_CN")))
                .v32Text(.headline)
                .foregroundStyle(V32.textPrimary)
        }
    }

    // MARK: 周条（周一~周日，选中为深墨绿圆角块）

    private var weekDays: [Date] {
        guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: selectedDate)?.start else { return [] }
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: weekStart) }
    }

    private var weekStrip: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                monthLabel
                Spacer()
                monthArrow("chevron.left") { shiftMonth(-1) }
                monthArrow("chevron.right") { shiftMonth(1) }
            }

            HStack(spacing: 6) {
                ForEach(weekDays, id: \.self) { date in
                    weekDayCell(date)
                }
            }
        }
    }

    private func monthArrow(_ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(V32.textSecondary)
                .frame(width: 30, height: 30)
                .background(
                    Circle()
                        .fill(V32.card)
                        .overlay(Circle().strokeBorder(V32.cardOutline, lineWidth: 1))
                )
        }
        .buttonStyle(.plain)
    }

    private func weekDayCell(_ date: Date) -> some View {
        let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
        let isToday = date.isToday
        let weekday = calendar.component(.weekday, from: date)
        let symbols = ["日", "一", "二", "三", "四", "五", "六"]
        let day = calendar.component(.day, from: date)

        return Button {
            selectedDate = date
            Haptic.light()
        } label: {
            VStack(spacing: 6) {
                Text(symbols[weekday - 1])
                    .v32Text(.caption)
                Text("\(day)")
                    .v32Text(.headline)
            }
            .foregroundStyle(isSelected ? Color.white : (isToday ? V32.brand : V32.textSecondary))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(isSelected ? V32.hero : Color.clear)
            )
            .overlay(alignment: .bottom) {
                if isToday && !isSelected {
                    Circle()
                        .fill(V32.brand)
                        .frame(width: 4, height: 4)
                        .padding(.bottom, 3)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func shiftMonth(_ value: Int) {
        if let date = calendar.date(byAdding: .month, value: value, to: selectedDate) {
            selectedDate = date
        }
    }

    // MARK: 时间轴

    @ViewBuilder
    private var timelineSection: some View {
        if !scheduleDay.timedEvents.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                V32SectionHeader("时间")
                VStack(spacing: V32Layout.listRowGap) {
                    ForEach(scheduleDay.timedEvents) { event in
                        timelineRow(event)
                    }
                }
            }
        }
    }

    private func timelineRow(_ event: ScheduleEvent) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Text(Fmt.time(event.date))
                .v32Text(.subhead)
                .foregroundStyle(V32.textTertiary)
                .frame(width: 46, alignment: .trailing)
            switch event {
            case .delivery:
                NavigationLink { CustomerView() } label: {
                    timelineCard(event, chevron: true)
                }
                .buttonStyle(.plain)
            case .todo:
                timelineCard(event, chevron: false)
            }
        }
    }

    private func isCompletedTodo(_ event: ScheduleEvent) -> Bool {
        if case .todo(let todo) = event { return todo.isCompleted }
        return false
    }

    private func timelineCard(_ event: ScheduleEvent, chevron: Bool) -> some View {
        let done = isCompletedTodo(event)
        return V32Card {
            HStack(spacing: 12) {
                eventIcon(event)
                VStack(alignment: .leading, spacing: 3) {
                    Text(eventTitle(event))
                        .v32Text(.title)
                        .foregroundStyle(done ? V32.textTertiary : V32.textPrimary)
                        .strikethrough(done, color: V32.textQuaternary)
                        .lineLimit(2)
                    Text(eventSubtitle(event))
                        .v32Text(.caption)
                        .foregroundStyle(V32.textTertiary)
                        .lineLimit(1)
                }
                Spacer(minLength: 4)
                if chevron {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(V32.textQuaternary)
                }
            }
        }
    }

    // MARK: 全天事项

    @ViewBuilder
    private var allDaySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            V32SectionHeader("全天事项") {
                if !scheduleDay.allDay.isEmpty {
                    Text(allDayCount)
                        .v32Text(.subhead)
                        .foregroundStyle(V32.textTertiary)
                }
            }

            if scheduleDay.allDay.isEmpty && scheduleDay.timedEvents.isEmpty {
                V32Card {
                    V32EmptyState(systemName: "sun.max", title: "这天没有安排", message: "好好经营，也别忘了休息")
                }
            } else if !scheduleDay.allDay.isEmpty {
                V32Card(padding: 4) {
                    VStack(spacing: 0) {
                        ForEach(scheduleDay.allDay.todos, id: \.persistentModelID) { todo in
                            allDayTodoRow(todo)
                        }
                        ForEach(scheduleDay.allDay.deliveries, id: \.persistentModelID) { request in
                            NavigationLink { CustomerView() } label: {
                                iconRow(
                                    icon: "box.truck.fill", tone: .brand,
                                    title: request.displayTitle,
                                    subtitle: request.displaySubtitle.isEmpty ? "客户配送" : request.displaySubtitle
                                )
                            }
                            .buttonStyle(.plain)
                        }
                        ForEach(scheduleDay.allDay.expiry, id: \.persistentModelID) { item in
                            expiryRow(item)
                        }
                        ForEach(scheduleDay.allDay.memos, id: \.persistentModelID) { memo in
                            NavigationLink { MemoView() } label: {
                                iconRow(icon: "note.text", tone: .neutral, title: memo.title, subtitle: memo.content)
                            }
                            .buttonStyle(.plain)
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
        HStack(spacing: 12) {
            V32Checkbox(checked: todo.isCompleted) {
                try? TodoRepository(context: modelContext).toggleComplete(todo)
                Haptic.light()
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(DisplayText.visible(todo.title, fallback: "待办事项"))
                    .v32Text(.title)
                    .foregroundStyle(todo.isCompleted ? V32.textTertiary : V32.textPrimary)
                    .strikethrough(todo.isCompleted, color: V32.textQuaternary)
                if todo.priority >= TodoPriority.high.rawValue && !todo.isCompleted {
                    Text("高优先级")
                        .v32Text(.caption)
                        .foregroundStyle(V32.amber)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 54)
    }

    private func iconRow(icon: String, tone: V32BubbleTone, title: String, subtitle: String) -> some View {
        HStack(spacing: 12) {
            V32IconBubble(systemName: icon, tone: tone, size: 34, icon: 15)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .v32Text(.title)
                    .foregroundStyle(V32.textPrimary)
                    .lineLimit(2)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .v32Text(.caption)
                        .foregroundStyle(V32.textTertiary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 4)
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(V32.textQuaternary)
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 54)
        .contentShape(Rectangle())
    }

    /// 临期卡默认折叠，点击展开备注/照片
    private func expiryRow(_ item: ExpiryItem) -> some View {
        let isExpanded = expandedExpiry.contains(item.notificationID)
        let days = item.daysLeft(from: selectedDate)

        return VStack(spacing: 0) {
            Button {
                withAnimation(reduceMotion ? nil : V32Motion.softSpring) {
                    if isExpanded { expandedExpiry.remove(item.notificationID) } else { expandedExpiry.insert(item.notificationID) }
                }
            } label: {
                HStack(spacing: 12) {
                    V32IconBubble(systemName: "hourglass", tone: .amber, size: 34, icon: 15)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("\(DisplayText.visible(item.name, fallback: "临期商品")) × \(item.quantity)")
                            .v32Text(.title)
                            .foregroundStyle(V32.textPrimary)
                            .lineLimit(1)
                        Text(expiryHint(days))
                            .v32Text(.caption)
                            .foregroundStyle(V32.amber)
                    }
                    Spacer(minLength: 4)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(V32.textQuaternary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .padding(.horizontal, 12)
                .frame(minHeight: 54)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 10) {
                    if !item.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(DisplayText.visible(item.note, fallback: "退货备注"))
                            .v32Text(.subhead)
                            .foregroundStyle(V32.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: V32Radius.inset, style: .continuous)
                                    .fill(V32.cardInset)
                            )
                    }
                    if let data = item.imageData, let image = UIImage(data: data) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity)
                            .frame(height: 140)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: V32Radius.inset, style: .continuous))
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }
        }
    }

    private func expiryHint(_ days: Int) -> String {
        if days < 0 { return "已临期 \(abs(days)) 天" }
        if days == 0 { return "今天临期" }
        return "\(days) 天后到期"
    }

    // MARK: 当日经营摘要（不逐笔列流水）

    @ViewBuilder
    private var summarySection: some View {
        let s = scheduleDay.summary
        VStack(alignment: .leading, spacing: 12) {
            V32SectionHeader("当日经营")
            NavigationLink { PerformanceView() } label: {
                V32Card {
                    HStack(spacing: 8) {
                        V32MetricCell(label: "当日收入", value: "¥" + Fmt.groupedAmount(s.revenue))
                        divider
                        V32MetricCell(label: "当日支出", value: "¥" + Fmt.groupedAmount(s.expense))
                        divider
                        V32MetricCell(label: "净额", value: "¥" + Fmt.groupedAmount(s.net))
                    }
                }
            }
            .buttonStyle(.plain)
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(V32.divider)
            .frame(width: 1, height: 34)
    }

    // MARK: 事件展示辅助

    @ViewBuilder
    private func eventIcon(_ event: ScheduleEvent) -> some View {
        switch event {
        case .todo:
            V32IconBubble(systemName: "checkmark.circle.fill", tone: .brand, size: 38, icon: 17)
        case .delivery:
            V32IconBubble(systemName: "box.truck.fill", tone: .brand, size: 38, icon: 17)
        }
    }

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
