import Charts
import PhotosUI
import SwiftData
import SwiftUI

struct HomeView: View {
    @Binding var tab: AppTab
    @Binding var showVoice: Bool
    let showsVoiceButton: Bool
    @Binding var showQuickRecord: Bool

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

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let prefix = hour < 11 ? "早上好" : hour < 14 ? "中午好" : hour < 18 ? "下午好" : "晚上好"
        return "\(prefix)，\(settings.ownerName)"
    }

    private var handlingItems: [HomeHandlingItem] {
        let todoItems = summary.todos.map { todo in
            HomeHandlingItem(
                id: "todo-\(todo.notificationID)",
                date: todo.dueDate ?? todo.createdAt,
                time: todo.dueDate.map(Fmt.time) ?? "今天",
                title: visible(todo.title, fallback: "待办事项"),
                subtitle: visible(todo.detail, fallback: todo.priorityLevel.label),
                tone: todo.priority >= TodoPriority.high.rawValue ? .urgent : .normal,
                route: .todo
            )
        }
        let deliveryItems = summary.deliveries.map { item in
            HomeHandlingItem(
                id: "delivery-\(item.notificationID)",
                date: item.updatedAt,
                time: "配送",
                title: visible(item.content, fallback: "客户配送"),
                subtitle: [visible(item.customer, fallback: ""), visible(item.roomOrAddress, fallback: "")]
                    .filter { !$0.isEmpty }.joined(separator: " · "),
                tone: item.statusEnum == .delivering ? .accent : .normal,
                route: .customer
            )
        }
        let expiryItems = summary.pendingExpiry.map { item in
            let days = item.daysLeft()
            return HomeHandlingItem(
                id: "expiry-\(item.notificationID)",
                date: item.expiryDate,
                time: days <= 0 ? "今天" : "\(days)天",
                title: "\(visible(item.name, fallback: "临期商品")) × \(item.quantity)",
                subtitle: days < 0 ? "已临期" : days == 0 ? "今天临期" : "即将临期",
                tone: days <= 0 ? .urgent : .warning,
                route: .expiry
            )
        }
        return (todoItems + deliveryItems + expiryItems)
            .sorted { $0.date < $1.date }
            .prefix(5).map { $0 }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 28) {
                header
                revenue
                businessCounts
                handlingList
                Button {
                    showQuickRecord = true
                } label: {
                    Label("快速记录", systemImage: "square.and.pencil")
                        .font(.subheadline.weight(.medium))
                }
                .buttonStyle(.bordered)
                .tint(V21.brandGreen)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 28)
        }
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .navigationBarHidden(true)
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

    private var header: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .center, spacing: 10) {
                Text("你的小掌柜")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 8)
                if weatherModel.snapshot != nil {
                    WeatherPill(model: weatherModel, palette: AppTheme.palette(named: settings.appThemeName)) {
                        showWeatherSheet = true
                    }
                }
                Button { showAvatarSheet = true } label: { HomeAvatar(settings: settings) }
                    .buttonStyle(.plain)
                    .frame(minWidth: 44, minHeight: 44)
                    .accessibilityLabel("更换头像")
            }
            Text(greeting)
                .font(.title3)
                .foregroundStyle(.secondary)
            Text(Date(), format: .dateTime.month().day().weekday(.wide).locale(Locale(identifier: "zh_CN")))
                .font(.subheadline)
                .foregroundStyle(.tertiary)
        }
    }

    private var revenue: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("今日营业额")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            HStack(alignment: .bottom, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(Fmt.money(summary.revenue))
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                    revenueChange
                }
                Spacer(minLength: 4)
                if summary.trend.contains(where: { $0.value > 0 }) {
                    HomeSparkline(points: summary.trend)
                        .frame(width: 112, height: 42)
                }
            }
            HStack(spacing: 8) {
                Text("本月 \(Fmt.money(monthRevenue))")
                Text("目标 \(Fmt.money(monthGoal))")
                Spacer(minLength: 4)
                Text("\(Int((goalProgress * 100).rounded()))%")
                    .monospacedDigit()
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            ProgressView(value: goalProgress)
                .tint(V21.brandGreen)
                .scaleEffect(x: 1, y: 0.55, anchor: .center)
        }
        .padding(18)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    @ViewBuilder
    private var revenueChange: some View {
        if let change = summary.changePercent {
            Label {
                Text("\(String(format: "%.1f", abs(change)))% 较昨日")
            } icon: {
                Image(systemName: change >= 0 ? "arrow.up.right" : "arrow.down.right")
            }
            .font(.footnote.weight(.medium))
            .foregroundStyle(change >= 0 ? V21.brandGreen : Color.red)
        } else {
            Text("暂无昨日对比").font(.footnote).foregroundStyle(.secondary)
        }
    }

    private var businessCounts: some View {
        HStack(spacing: 0) {
            HomeCountButton(value: summary.todos.count, label: "待办") { tab = .todo }
            Divider().frame(height: 34)
            HomeCountButton(value: summary.deliveries.count, label: "配送") { route = .customer }
            Divider().frame(height: 34)
            HomeCountButton(value: summary.pendingExpiry.count, label: "临期") { route = .expiry }
        }
        .padding(.vertical, 4)
    }

    private var handlingList: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("今天需要处理").font(.title3.bold())
                Spacer()
                Button("查看全部") { tab = .todo }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            VStack(spacing: 0) {
                if handlingItems.isEmpty {
                    Text("今天没有待处理事项")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 16)
                } else {
                    ForEach(Array(handlingItems.enumerated()), id: \.element.id) { index, item in
                        Button { open(item.route) } label: { HomeHandlingRow(item: item) }
                            .buttonStyle(.plain)
                        if index < handlingItems.count - 1 { Divider().padding(.leading, 58) }
                    }
                }
            }
            .padding(.horizontal, 16)
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private func open(_ destination: HomeItemRoute) {
        switch destination {
        case .todo: tab = .todo
        case .customer: route = .customer
        case .expiry: route = .expiry
        }
    }

    private func visible(_ value: String, fallback: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.lowercased().hasPrefix("xzg-") else { return fallback }
        return trimmed
    }
}

private enum HomeRoute: Hashable { case customer, expiry }
private enum HomeItemRoute { case todo, customer, expiry }
private enum HomeItemTone { case normal, accent, warning, urgent }

private struct HomeHandlingItem {
    let id: String
    let date: Date
    let time: String
    let title: String
    let subtitle: String
    let tone: HomeItemTone
    let route: HomeItemRoute
}

private struct HomeHandlingRow: View {
    let item: HomeHandlingItem
    var body: some View {
        HStack(spacing: 12) {
            Text(item.time)
                .font(.caption.monospacedDigit())
                .foregroundStyle(toneColor)
                .frame(width: 46, alignment: .leading)
            VStack(alignment: .leading, spacing: 3) {
                Text(item.title).font(.body).foregroundStyle(.primary).lineLimit(2)
                if !item.subtitle.isEmpty {
                    Text(item.subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            Image(systemName: "chevron.right").font(.caption2.weight(.semibold)).foregroundStyle(.tertiary)
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    private var toneColor: Color {
        switch item.tone {
        case .normal: return .secondary
        case .accent: return V21.brandGreen
        case .warning: return .orange
        case .urgent: return .red
        }
    }
}

private struct HomeCountButton: View {
    let value: Int
    let label: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Text("\(value)").font(.title2.weight(.semibold)).foregroundStyle(.primary).monospacedDigit()
                Text(label).font(.caption).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 52)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct HomeSparkline: View {
    let points: [TrendPoint]
    var body: some View {
        Chart(points) { point in
            LineMark(x: .value("日期", point.date), y: .value("营业额", point.value))
                .interpolationMethod(.catmullRom)
                .foregroundStyle(V21.brandGreen)
                .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartLegend(.hidden)
        .accessibilityLabel("最近七日营业额趋势")
    }
}

private struct HomeAvatar: View {
    let settings: AppSettings
    var body: some View {
        Group {
            if let data = settings.avatarImageData, let image = UIImage(data: data) {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Text(settings.avatarEmoji).font(.title3)
            }
        }
        .frame(width: 38, height: 38)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: Circle())
        .clipShape(Circle())
        .overlay(Circle().stroke(Color(uiColor: .separator).opacity(0.35), lineWidth: 0.5))
    }
}

private struct AvatarPickerSheet: View {
    let settings: AppSettings
    @Binding var selectedItem: PhotosPickerItem?
    @State private var customEmoji = ""
    private let emojis = ["😀", "😎", "🥰", "🐼", "🐶", "🏪", "☕️"]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("我的头像").font(.headline)
            HStack(spacing: 8) {
                ForEach(emojis, id: \.self) { emoji in
                    Button(emoji) { settings.avatarImageData = nil; settings.avatarEmoji = emoji }
                        .font(.title2).frame(minWidth: 40, minHeight: 44)
                }
            }
            TextField("自定义 Emoji", text: $customEmoji).textFieldStyle(.roundedBorder).onSubmit(addEmoji)
            Button("添加", action: addEmoji).disabled(customEmoji.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            PhotosPicker(selection: $selectedItem, matching: .images) { Label("从相册选择", systemImage: "photo") }
                .onChange(of: selectedItem) { _, item in
                    guard let item else { return }
                    Task {
                        if let data = try? await item.loadTransferable(type: Data.self) { settings.avatarImageData = data }
                    }
                }
            Spacer()
        }
        .padding(20)
    }

    private func addEmoji() {
        let value = customEmoji.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        settings.avatarImageData = nil
        settings.avatarEmoji = String(value.prefix(2))
        customEmoji = ""
    }
}
