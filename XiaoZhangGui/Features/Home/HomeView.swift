import Charts
import SwiftData
import SwiftUI

// MARK: - 首页 · 今日经营驾驶舱（V32）

struct HomeView: View {
    @Binding var tab: AppTab
    @Binding var showVoice: Bool
    @Binding var showQuickRecord: Bool
    let showsVoiceButton: Bool

    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(AppSettings.self) private var settings
    @Bindable private var demo = DemoMode.shared
    @Query private var todos: [Todo]
    @Query private var performances: [Performance]
    @Query private var expiryItems: [ExpiryItem]
    @Query private var customers: [CustomerRequest]
    @Query private var expenses: [Expense]
    @State private var route: HomeRoute?
    @State private var showUtilityDrawer = false
    @State private var showWeatherSheet = false
    @State private var weatherModel = WeatherViewModel()

    private var summary: TodaySummary {
        TodaySummary.build(performances: performances, todos: todos, customers: customers, expiryItems: expiryItems)
    }

    private var monthRevenue: Double {
        if demo.isEnabled { return DemoCatalog.monthlyRevenue }
        return performances
            .filter { $0.date >= Date().startOfMonth && $0.date <= Date().endOfDay }
            .reduce(0) { $0 + $1.amount }
    }

    private var monthGoal: Double {
        demo.isEnabled ? DemoCatalog.monthlyGoal : settings.monthGoal
    }

    private var recentRecords: [MoneyRecord] {
        MoneyRecord.merged(performances: performances, expenses: expenses, range: (Date().startOfMonth, Date().endOfDay))
    }

    private var handlingItems: [HomeInboxItem] {
        let stripIDs = Set(topDeliveries.map { "delivery-\($0.notificationID)" })
        return HomeInbox.items(todos: summary.todos, deliveries: summary.deliveries,
                               expiryItems: summary.pendingExpiry, limit: 4,
                               excludingDeliveryIDs: stripIDs)
    }

    private var todayCompletedCount: Int {
        let now = Date()
        let doneTodos = ScheduleAgenda.completedTodos(todos.filter(\.isCompleted), on: now).count
        let doneDeliveries = ScheduleAgenda.completedDeliveries(customers, on: now).count
        return doneTodos + doneDeliveries
    }

    private var topDeliveries: [CustomerRequest] {
        Array(summary.deliveries.sorted { lhs, rhs in
            if lhs.statusEnum != rhs.statusEnum {
                return lhs.statusEnum == .delivering && rhs.statusEnum != .delivering
            }
            return lhs.updatedAt > rhs.updatedAt
        }.prefix(2))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: V32Layout.sectionGap) {
                header
                V35HomeRevenueHero(summary: summary, monthRevenue: monthRevenue, monthGoal: monthGoal) { route = .performance }
                    .modifier(V32HomeEntrance(delay: 0, reduceMotion: reduceMotion))
                V35HomeOverviewGrid(todoCount: summary.todos.count, expiryCount: summary.pendingExpiry.count, customerCount: summary.deliveries.count, focusCount: handlingItems.count)
                    .modifier(V32HomeEntrance(delay: 0.04, reduceMotion: reduceMotion))
                V35HomeFocusSection(items: handlingItems) { open($0.route) }
                    .modifier(V32HomeEntrance(delay: 0.06, reduceMotion: reduceMotion))
                V35HomeRecentRecords(records: recentRecords) { route = .transactions }
                    .modifier(V32HomeEntrance(delay: 0.08, reduceMotion: reduceMotion))
                if !topDeliveries.isEmpty {
                    deliverySection
                        .modifier(V32HomeEntrance(delay: 0.04, reduceMotion: reduceMotion))
                }
                todaySection
                    .modifier(V32HomeEntrance(delay: 0.08, reduceMotion: reduceMotion))
            }
            .padding(.horizontal, V32Layout.pageMargin)
            .padding(.top, 8)
        }
        .scrollIndicators(.hidden)
        .safeAreaPadding(.top, 12)
        .v32PageBackground()
        .v32PageBottomInset()
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { showUtilityDrawer = true } label: {
                    Image(systemName: "line.3.horizontal")
                }
                .accessibilityLabel("打开经营快捷中心")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button { showQuickRecord = true } label: {
                    Image(systemName: "mic.fill")
                }
                .accessibilityLabel("一句话快速记录")
            }
        }
        .navigationDestination(item: $route) { destination in
            switch destination {
            case .customer: CustomerView()
            case .expiry: ExpiryView()
            case .performance: PerformanceView()
            case .transactions: TransactionHistoryView()
            }
        }
        .sheet(isPresented: $showWeatherSheet) {
            WeatherDetailSheet(model: weatherModel)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .task { weatherModel.loadIfNeeded() }
        .overlay {
            if showUtilityDrawer {
                V35DrawerContainer(isPresented: $showUtilityDrawer) {
                    tab = .profile
                }
            }
        }
        .overlay(alignment: .leading) {
            if !showUtilityDrawer {
                Color.clear
                    .frame(width: 26)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 12)
                            .onEnded { value in
                                let width = UIScreen.main.bounds.width * 0.84
                                if V35DrawerGestureLogic.shouldOpen(
                                    translation: value.translation.width,
                                    predicted: value.predictedEndTranslation.width,
                                    width: width
                                ) {
                                    showUtilityDrawer = true
                                    Haptic.light()
                                }
                            }
                    )
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(greetingPrefix)
                    .v32Text(.body)
                    .foregroundStyle(V32.textSecondary)
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(ownerDisplayName)
                        .v32Text(.display)
                        .foregroundStyle(V32.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text("👋")
                        .font(.system(size: 24))
                }
                Text(Date(), format: .dateTime.month().day().weekday(.wide).locale(Locale(identifier: "zh_CN")))
                    .v32Text(.subhead)
                    .foregroundStyle(V32.textTertiary)
                    .padding(.top, 1)
            }
            Spacer(minLength: 4)
            weatherButton
        }
    }

    private var greetingPrefix: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 11 { return "早上好" }
        if hour < 14 { return "中午好" }
        if hour < 18 { return "下午好" }
        return "晚上好"
    }

    private var ownerDisplayName: String {
        let name = settings.ownerName.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? "老板" : name
    }

    private var weatherButton: some View {
        Button { showWeatherSheet = true } label: {
            HStack(spacing: 3) {
                Image(systemName: weatherModel.snapshot?.symbolName ?? "cloud.sun")
                    .font(.system(size: 15, weight: .semibold))
                if let weather = weatherModel.snapshot {
                    Text("\(weather.roundedTemperature)°")
                        .v32Text(.metricSmall)
                }
            }
            .foregroundStyle(V32.textSecondary)
            .padding(.horizontal, 8)
            .frame(minHeight: V32Layout.toolCircle)
            .background(
                Capsule()
                    .fill(V32.card)
                    .overlay(Capsule().strokeBorder(V32.cardOutline, lineWidth: 1))
            )
        }
        .buttonStyle(V32PressButtonStyle())
        .accessibilityLabel(weatherModel.snapshot.map { "\($0.city)，\($0.roundedTemperature)度" } ?? "天气")
    }

    private var deliverySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            V32SectionHeader("客户配送") {
                V32SectionAction(text: "全部") { route = .customer }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: V32Layout.cardGap) {
                    ForEach(topDeliveries, id: \.persistentModelID) { request in
                        Button {
                            route = .customer
                            Haptic.light()
                        } label: {
                            DeliveryCard(request: request)
                                .containerRelativeFrame(
                                    .horizontal,
                                    alignment: .center
                                ) { length, _ in
                                    max(220, (length - V32Layout.cardGap) / 1.175)
                                }
                        }
                        .buttonStyle(V32PressButtonStyle())
                        .accessibilityLabel("查看配送：\(request.displayTitle)")
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
        }
    }

    private var todaySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            V32SectionHeader("今日事项") {
                Text(handlingItems.isEmpty ? "" : "\(handlingItems.count) 项")
                    .v32Text(.subhead)
                    .foregroundStyle(V32.textTertiary)
            }

            if handlingItems.isEmpty {
                V32Card {
                    VStack(spacing: 12) {
                        V32EmptyState(
                            systemName: "checkmark.circle.fill",
                            title: "今天没有待处理事项",
                            message: nil
                        )
                        .padding(.vertical, 4)
                        if showsVoiceButton {
                            V32SecondaryButton(title: "语音记一笔", systemName: "mic.fill") {
                                showQuickRecord = true
                            }
                            .padding(.horizontal, 24)
                        }
                    }
                }
            } else {
                V32Card(padding: 4) {
                    VStack(spacing: 0) {
                        ForEach(Array(handlingItems.enumerated()), id: \.element.id) { index, item in
                            if index > 0 {
                                Rectangle()
                                    .fill(V32.divider)
                                    .frame(height: 1)
                                    .padding(.leading, 48)
                            }
                            HomeActionRow(item: item) {
                                toggleTodo(for: item)
                            }
                            .onTapGesture { open(item.route) }
                        }
                    }
                }
            }

            if todayCompletedCount > 0 {
                Button {
                    tab = .schedule
                    Haptic.light()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 13, weight: .semibold))
                        Text("今日已完成 \(todayCompletedCount) 项")
                            .v32Text(.subhead)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(V32.brand)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(V32PressButtonStyle())
            }
        }
    }

    private func toggleTodo(for item: HomeInboxItem) {
        guard item.route == .todo,
              let todo = summary.todos.first(where: { "todo-\($0.notificationID)" == item.id }) else { return }
        try? TodoRepository(context: modelContext).toggleComplete(todo)
        Haptic.light()
    }

    private func open(_ destination: HomeInboxItem.Route) {
        switch destination {
        case .todo: tab = .todo
        case .customer: route = .customer
        case .expiry: route = .expiry
        }
    }
}

private enum HomeRoute: Hashable { case customer, expiry, performance, transactions }

private struct V32HomeEntrance: ViewModifier {
    let delay: Double
    let reduceMotion: Bool
    @State private var appeared = false

    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .offset(y: reduceMotion ? 0 : (appeared ? 0 : 8))
            .animation(
                V32Motion.animation(V32Motion.resolve(.fade, reduceMotion: reduceMotion))?.delay(delay),
                value: appeared
            )
            .onAppear { if !appeared { appeared = true } }
    }
}

private struct DeliveryCard: View {
    let request: CustomerRequest

    private var info: CustomerDeliveryInfo { CustomerDeliveryStorage.decode(request.customer) }

    var body: some View {
        V32Card(padding: 14) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 8) {
                    V32IconBubble(systemName: "box.truck.fill", tone: .brand, size: 34, icon: 15)
                    Spacer(minLength: 0)
                    V32StatusPill(text: request.statusEnum.rawValue,
                                  status: request.statusEnum == .delivering ? .delivering : .pending)
                }

                Text(request.displayTitle)
                    .v32Text(.headline)
                    .foregroundStyle(V32.textPrimary)
                    .lineLimit(2)

                Text(request.displaySubtitle.isEmpty ? "客户配送" : request.displaySubtitle)
                    .v32Text(.subhead)
                    .foregroundStyle(V32.textSecondary)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 11, weight: .semibold))
                    Text(info.deliveryTime.map(Fmt.time) ?? "未设配送时间")
                        .v32Text(.caption)
                }
                .foregroundStyle(V32.textTertiary)
            }
        }
    }
}

struct HomeActionRow: View {
    let item: HomeInboxItem
    let onTodoToggle: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            leading
            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .v32Text(.title)
                    .foregroundStyle(V32.textPrimary)
                    .lineLimit(2)
                if !item.subtitle.isEmpty {
                    Text(item.subtitle)
                        .v32Text(.caption)
                        .foregroundStyle(V32.textTertiary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 6)
            Text(item.time)
                .v32Text(.caption)
                .foregroundStyle(V32.textTertiary)
                .lineLimit(1)
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(V32.textQuaternary)
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 60)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var leading: some View {
        switch item.route {
        case .todo:
            V32Checkbox(checked: false, action: onTodoToggle)
        case .customer:
            V32IconBubble(systemName: "box.truck.fill", tone: .brand, size: 34, icon: 15)
        case .expiry:
            V32IconBubble(systemName: "hourglass", tone: .amber, size: 34, icon: 15)
        }
    }
}

struct HomeSparkline: View {
    let points: [TrendPoint]
    var body: some View {
        Chart(points) { point in
            LineMark(x: .value("日期", point.date), y: .value("营业额", point.value))
                .interpolationMethod(.catmullRom)
                .foregroundStyle(V32.brandOnHero)
                .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartLegend(.hidden)
        .accessibilityLabel("最近七日营业额趋势")
    }
}
