import Charts
import PhotosUI
import SwiftData
import SwiftUI

// MARK: - 首页 · 今日经营驾驶舱（V32）

struct HomeView: View {
    @Binding var tab: AppTab
    @Binding var showVoice: Bool
    @Binding var showQuickRecord: Bool
    let showsVoiceButton: Bool

    @Environment(\.modelContext) private var modelContext
    @Environment(AppSettings.self) private var settings
    @Bindable private var demo = DemoMode.shared
    @Query private var todos: [Todo]
    @Query private var performances: [Performance]
    @Query private var expiryItems: [ExpiryItem]
    @Query private var customers: [CustomerRequest]
    @State private var route: HomeRoute?
    @State private var showAvatarSheet = false
    @State private var showWeatherSheet = false
    @State private var selectedAvatarItem: PhotosPickerItem?
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

    private var goalProgress: Double {
        guard monthGoal > 0 else { return 0 }
        return min(max(monthRevenue / monthGoal, 0), 1)
    }

    private var handlingItems: [HomeInboxItem] {
        HomeInbox.items(todos: summary.todos, deliveries: summary.deliveries, expiryItems: summary.pendingExpiry, limit: 4)
    }

    /// 配送中优先、待处理其次，最多 2 张横滑小卡
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
                heroCard
                if !topDeliveries.isEmpty {
                    deliverySection
                }
                todaySection
            }
            .padding(.horizontal, V32Layout.pageMargin)
            .padding(.top, 8)
            .padding(.bottom, V32Layout.bottomPad)
        }
        .scrollIndicators(.hidden)
        .v32PageBackground()
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(item: $route) { destination in
            switch destination {
            case .customer: CustomerView()
            case .expiry: ExpiryView()
            }
        }
        .sheet(isPresented: $showAvatarSheet) {
            AvatarPickerSheet(settings: settings, selectedItem: $selectedAvatarItem)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showWeatherSheet) {
            WeatherDetailSheet(model: weatherModel, palette: AppTheme.palette(named: settings.appThemeName))
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .task { weatherModel.loadIfNeeded() }
    }

    // MARK: 顶部：问候 / 日期 / 天气 / 快速记录 / 头像

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
            toolCircle("square.and.pencil") { showQuickRecord = true }
                .accessibilityLabel("快速记录")
            weatherButton
            Button { showAvatarSheet = true } label: { HomeAvatar(settings: settings) }
                .buttonStyle(.plain)
                .frame(width: V32Layout.toolCircle, height: V32Layout.toolCircle)
                .accessibilityLabel("更换头像")
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

    private func toolCircle(_ systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
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
        .buttonStyle(.plain)
        .accessibilityLabel(weatherModel.snapshot.map { "\($0.city)，\($0.roundedTemperature)度" } ?? "天气")
    }

    // MARK: 深墨绿主卡：今日营业额

    private var heroCard: some View {
        V32HeroCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("今日营业额")
                            .v32Text(.caption)
                            .foregroundStyle(V32.textOnHeroSecondary)
                        Text("¥" + Fmt.groupedAmount(summary.revenue))
                            .v32Text(.heroMoney)
                            .foregroundStyle(V32.textOnHero)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                        revenueChange
                    }
                    Spacer(minLength: 8)
                    if summary.trend.contains(where: { $0.value > 0 }) {
                        HomeSparkline(points: summary.trend)
                            .frame(width: 84, height: 34)
                            .padding(.top, 18)
                    }
                }

                Rectangle()
                    .fill(V32.dividerOnHero)
                    .frame(height: 1)

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 10) {
                        Text("本月 ¥\(Fmt.groupedAmount(monthRevenue))")
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                        Text("目标 ¥\(Fmt.groupedAmount(monthGoal))")
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                        Spacer(minLength: 4)
                        Text("\(Int((goalProgress * 100).rounded()))%")
                            .font(.system(size: 13, weight: .bold, design: .rounded).monospacedDigit())
                    }
                    .v32Text(.caption)
                    .foregroundStyle(V32.textOnHeroSecondary)

                    V32ProgressBar(progress: goalProgress, onHero: true)

                    Text(goalRemainText)
                        .v32Text(.caption)
                        .foregroundStyle(V32.textOnHeroSecondary)
                }
            }
        }
    }

    private var goalRemainText: String {
        guard monthGoal > 0 else { return "去「我的 → 月营业目标」设定目标" }
        let remain = monthGoal - monthRevenue
        if remain > 0 { return "距月目标还差 ¥\(Fmt.groupedAmount(remain))" }
        return "已完成月目标，继续保持"
    }

    @ViewBuilder
    private var revenueChange: some View {
        if let change = summary.changePercent {
            HStack(spacing: 3) {
                Image(systemName: change >= 0 ? "arrow.up.right" : "arrow.down.right")
                    .font(.system(size: 11, weight: .heavy))
                Text("\(String(format: "%.1f", abs(change)))% 较昨日")
                    .v32Text(.caption)
            }
            .foregroundStyle(change >= 0 ? V32.brandOnHero : V32.amberOnHero)
        } else {
            Text("暂无昨日对比")
                .v32Text(.caption)
                .foregroundStyle(V32.textOnHeroSecondary)
        }
    }

    // MARK: 客户配送横滑卡

    private var deliverySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            V32SectionHeader("客户配送") {
                V32SectionAction(text: "全部") { route = .customer }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: V32Layout.cardGap) {
                    ForEach(topDeliveries, id: \.persistentModelID) { request in
                        DeliveryCard(request: request)
                            .onTapGesture { route = .customer }
                    }
                }
            }
        }
    }

    // MARK: 今日事项（≤4，动作摘要）

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
                                showVoice = true
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

private enum HomeRoute: Hashable { case customer, expiry }

// MARK: - 配送横滑小卡

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
                    Text(info.deliveryTime.map(Fmt.time) ?? "待配送")
                        .v32Text(.caption)
                }
                .foregroundStyle(V32.textTertiary)
            }
            .frame(width: V32Layout.hCardWidth, alignment: .leading)
        }
    }
}

// MARK: - 今日事项行（圆形勾选）

private struct HomeActionRow: View {
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

// MARK: - 七日火花线（hero 内）

private struct HomeSparkline: View {
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

// MARK: - 头像

private struct HomeAvatar: View {
    let settings: AppSettings
    var body: some View {
        Group {
            if let data = settings.avatarImageData, let image = UIImage(data: data) {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Text(settings.avatarEmoji).font(.system(size: 17))
            }
        }
        .frame(width: V32Layout.toolCircle, height: V32Layout.toolCircle)
        .background(V32.card, in: Circle())
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(V32.cardOutline, lineWidth: 1))
    }
}

// MARK: - 头像选择 Sheet（功能保留）

private struct AvatarPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let settings: AppSettings
    @Binding var selectedItem: PhotosPickerItem?
    @State private var customEmoji = ""
    private let emojis = ["😀", "😎", "🥰", "🐼", "🐶", "🏪", "☕️"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                VStack(alignment: .leading, spacing: 10) {
                    V32SectionHeader("选择 Emoji")
                    V32Card {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 10) {
                            ForEach(emojis, id: \.self) { emoji in
                                Button {
                                    settings.avatarImageData = nil
                                    settings.avatarEmoji = emoji
                                    Haptic.light()
                                } label: {
                                    Text(emoji)
                                        .font(.system(size: 22))
                                        .frame(width: 48, height: 48)
                                        .background(
                                            Circle().fill(settings.avatarImageData == nil && settings.avatarEmoji == emoji
                                                         ? V32.brandSoft : V32.pageBGSecondary)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    V32Card {
                        TextField("自定义 Emoji", text: $customEmoji)
                            .v32Text(.body)
                            .foregroundStyle(V32.textPrimary)
                            .tint(V32.brand)
                            .onSubmit(addEmoji)
                    }
                }
                V32SecondaryButton(title: "从相册选择", systemName: "photo") { showPhotoPicker = true }
            }
            .padding(.horizontal, V32Layout.pageMargin)
            .padding(.top, 14)
            .padding(.bottom, V32Layout.bottomPad)
        }
        .scrollIndicators(.hidden)
        .v32PageBackground()
        .v32Sheet([.medium])
        .photosPicker(isPresented: $showPhotoPicker, selection: $selectedItem, matching: .images)
        .onChange(of: selectedItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) { settings.avatarImageData = data }
            }
        }
    }

    @State private var showPhotoPicker = false

    private var header: some View {
        ZStack {
            Text("我的头像").v32Text(.headline).foregroundStyle(V32.textPrimary)
            HStack {
                Button("完成") { dismiss() }
                    .v32Text(.body)
                    .foregroundStyle(V32.textTertiary)
                Spacer()
            }
        }
    }

    private func addEmoji() {
        let value = customEmoji.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        settings.avatarImageData = nil
        settings.avatarEmoji = String(value.prefix(2))
        customEmoji = ""
    }
}
