import SwiftUI
import SwiftData
import PhotosUI

/// Studio 首页：问候 / KPI / 营业额 / 客户头像 / 独立提醒卡。
struct HomeView: View {
    @Binding var tab: AppTab
    @Binding var showVoice: Bool
    let showsVoiceButton: Bool

    @Environment(AppSettings.self) private var settings
    @Query private var todos: [Todo]
    @Query private var performances: [Performance]
    @Query private var expenses: [Expense]
    @Query private var expiryItems: [ExpiryItem]
    @Query private var customers: [CustomerRequest]
    @Query private var memos: [Memo]
    @State private var showAvatarSheet = false
    @State private var selectedAvatarItem: PhotosPickerItem?
    @State private var weatherModel = WeatherViewModel()
    @State private var assistantOutput = BusinessAssistantOutput.empty
    private let assistantEngine = BusinessAssistantEngine()

    private var stats: HomeStats {
        HomeStats.compute(todos: todos, performances: performances, expiryItems: expiryItems, monthGoal: settings.monthGoal)
    }

    private var deliveryCount: Int { customers.filter { $0.statusEnum == .delivering }.count }
    private var overdueCount: Int { todos.filter { !$0.isCompleted && ($0.dueDate?.isBeforeToday ?? false) }.count }
    private var hasAlert: Bool { stats.urgentExpiryCount > 0 || overdueCount > 0 || deliveryCount > 0 }
    private var isMockPreview: Bool { RuntimeMode.allowsMockData }
    private var displayRevenue: Double { isMockPreview ? 2680 : stats.todayRevenue }
    private var displayTodoCount: Int { isMockPreview ? 4 : stats.todayTodos.count }
    private var displayCustomerCount: Int { isMockPreview ? 2 : customers.count }
    private var displayGoalPercent: Int { isMockPreview ? 68 : stats.goalProgressPercent }
    private var themePalette: AppThemePalette { AppTheme.palette(named: settings.appThemeName) }

    private var yesterdayRevenue: Double {
        let date = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        return performances.filter { $0.date.isSameDay(as: date) }.reduce(0) { $0 + $1.amount }
    }

    private var revenueChange: Double? {
        guard yesterdayRevenue > 0 else { return nil }
        return (stats.todayRevenue - yesterdayRevenue) / yesterdayRevenue * 100
    }

    private var displayRevenueChange: Double? { isMockPreview ? 12.6 : revenueChange }

    var body: some View {
        ZStack(alignment: .top) {
            SpatialHomeBackdrop()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    studioHeader
                    studioKPI
                    studioRevenue
                    assistantBriefing
                    studioClients
                    studioReminders
                    studioUpcoming
                }
                .padding(.horizontal, V21Layout.pageMargin)
                .padding(.top, 16)
                .padding(.bottom, V21Layout.bottomDockContentGap)
            }
        }
        .navigationDestination(for: String.self) { route in
            switch route {
            case "expiry": ExpiryView()
            case "calendar": CalendarView()
            case "customer": CustomerView()
            case "goods": GoodsView()
            default: EmptyView()
            }
        }
        .sheet(isPresented: $showAvatarSheet) {
            AvatarPickerSheet(settings: settings, selectedItem: $selectedAvatarItem)
                .presentationDetents([.height(285)])
                .presentationDragIndicator(.visible)
        }
        .task { weatherModel.loadIfNeeded() }
        .task(id: assistantRefreshID) {
            assistantOutput = await assistantEngine.analyze(assistantInput)
        }
    }

    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 11 { return "早上好，掌柜" }
        if hour < 14 { return "中午好，掌柜" }
        if hour < 18 { return "下午好，掌柜" }
        return "晚上好，掌柜"
    }

    private var studioHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(greetingText)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(V21.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(Date(), format: .dateTime.month().day().weekday(.wide).locale(Locale(identifier: "zh_CN")))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(V21.textTertiary)
            }
            Spacer(minLength: 8)
            Button { Haptic.light(); tab = .todo } label: {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "bell")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(V21.textSecondary)
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(V21.surfaceElevated))
                        .overlay(Circle().strokeBorder(V21.divider.opacity(0.7), lineWidth: 0.6))
                    if hasAlert {
                        Circle().fill(V21.danger).frame(width: 8, height: 8).offset(x: -2, y: 2)
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(hasAlert ? "待办提醒，有未处理事项" : "待办提醒")
            Button { Haptic.light(); showAvatarSheet = true } label: {
                AvatarBadge(settings: settings)
            }
            .buttonStyle(.plain)
        }
    }

    private var studioKPI: some View {
        HStack(spacing: 0) {
            kpi("\(displayCustomerCount)", "客户")
            Rectangle().fill(V21.divider.opacity(0.8)).frame(width: 1, height: 36)
            kpi("\(displayTodoCount)", "今日到期")
            Rectangle().fill(V21.divider.opacity(0.8)).frame(width: 1, height: 36)
            kpi("\(isMockPreview ? 3 : deliveryCount)", "配送中")
        }
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
        .background(V21.surfaceElevated, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(V21.divider.opacity(0.45), lineWidth: 0.6))
        .shadow(color: Color.black.opacity(0.04), radius: 16, y: 8)
    }

    private func kpi(_ value: String, _ label: String) -> some View {
        VStack(spacing: 6) {
            Text(value).font(.system(size: 28, weight: .semibold, design: .rounded).monospacedDigit()).foregroundStyle(V21.textPrimary)
            Text(label).font(.system(size: 11, weight: .medium)).foregroundStyle(V21.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    private var studioRevenue: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("今日营业额").font(.system(size: 13, weight: .medium)).foregroundStyle(V21.textTertiary)
                Spacer()
                Text("目标 \(displayGoalPercent)%").font(.system(size: 12, weight: .semibold, design: .rounded)).foregroundStyle(themePalette.accent)
            }
            Text("¥\(Fmt.groupedInt(displayRevenue))")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(V21.textPrimary)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(displayRevenueChange.map { "较昨日 \($0 >= 0 ? "↑" : "↓") \(String(format: "%.1f%%", abs($0)))" } ?? "较昨日暂无对比")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(displayRevenueChange.map { $0 >= 0 ? themePalette.accent : V21.danger } ?? V21.textTertiary)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(V21.surfaceElevated, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(V21.divider.opacity(0.45), lineWidth: 0.6))
        .shadow(color: Color.black.opacity(0.04), radius: 16, y: 8)
    }

    private var activeCustomers: [CustomerRequest] {
        customers.filter { $0.statusEnum != .done }.sorted { $0.updatedAt > $1.updatedAt }
    }

    private var studioClients: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("客户").font(.system(size: 20, weight: .bold, design: .rounded)).foregroundStyle(V21.textPrimary)
                Spacer()
                NavigationLink(value: "customer") {
                    Text("管理").font(.system(size: 13, weight: .semibold)).foregroundStyle(V21.textTertiary)
                }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    if isMockPreview {
                        clientCard("302别墅", "配送", nil)
                        clientCard("208房", "待送", nil)
                    } else {
                        ForEach(Array(activeCustomers.prefix(5))) { request in
                            NavigationLink(value: "customer") {
                                clientCard(
                                    request.roomOrAddress.isEmpty ? (request.customer.isEmpty ? "客户" : request.customer) : request.roomOrAddress,
                                    request.content.isEmpty ? request.statusEnum.rawValue : request.content,
                                    request.imageData
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            NavigationLink(value: "customer") {
                HStack(spacing: 6) {
                    Image(systemName: "plus").font(.system(size: 13, weight: .semibold))
                    Text("添加客户配送").font(.system(size: 14, weight: .medium))
                }
                .foregroundStyle(V21.textSecondary)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(style: StrokeStyle(lineWidth: 1.15, dash: [6, 5]))
                        .foregroundStyle(V21.dividerStrong.opacity(0.8))
                )
            }
            .buttonStyle(.plain)
        }
    }

    private func clientCard(_ title: String, _ subtitle: String, _ imageData: Data?) -> some View {
        VStack(spacing: 0) {
            ZStack {
                if let imageData, let image = UIImage(data: imageData) {
                    Image(uiImage: image).resizable().scaledToFill()
                } else {
                    LinearGradient(colors: [themePalette.accent.opacity(0.18), V21.info.opacity(0.10)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    Text(String(title.prefix(1))).font(.system(size: 28, weight: .semibold, design: .rounded)).foregroundStyle(V21.textSecondary)
                }
            }
            .frame(width: 104, height: 92)
            .clipped()
            VStack(spacing: 1) {
                Text(title).font(.system(size: 12, weight: .semibold)).foregroundStyle(V21.textPrimary).lineLimit(1)
                Text(subtitle).font(.system(size: 10, weight: .medium)).foregroundStyle(V21.textTertiary).lineLimit(1)
            }
            .padding(.horizontal, 8).padding(.vertical, 8).frame(maxWidth: .infinity).background(V21.surfaceElevated)
        }
        .frame(width: 104)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(V21.divider.opacity(0.4), lineWidth: 0.6))
    }

    private var expiryPreview: [ExpiryItem] {
        Array(expiryItems.filter { $0.status == .pending }.prefix(2))
    }

    private var studioReminders: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("提醒").font(.system(size: 20, weight: .bold, design: .rounded)).foregroundStyle(V21.textPrimary)
            if isMockPreview {
                reminderCard("checkmark.circle", "供应商送货", "今日 · 09:30")
            } else if stats.todayTodos.isEmpty && expiryPreview.isEmpty {
                reminderCard("checkmark.circle", "今天没有待处理事项", "可以先记一笔或查看日历")
            } else {
                ForEach(stats.todayTodos.prefix(3)) { todo in
                    Button { tab = .todo } label: {
                        reminderCard("checkmark.circle", todo.title, todo.dueDate.map { "今日 · \(Fmt.time($0))" } ?? "今日 · 全天")
                    }
                    .buttonStyle(.plain)
                }
                ForEach(expiryPreview) { item in
                    NavigationLink(value: "expiry") {
                        reminderCard("exclamationmark.triangle", "\(item.name) ×\(item.quantity)", item.status.rawValue)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func reminderCard(_ symbol: String, _ title: String, _ subtitle: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(themePalette.accent)
                .frame(width: 36, height: 36)
                .background(themePalette.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 15, weight: .semibold)).foregroundStyle(V21.textPrimary).lineLimit(2)
                Text(subtitle).font(.system(size: 12, weight: .medium)).foregroundStyle(V21.textTertiary).lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(V21.surfaceElevated, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(V21.divider.opacity(0.4), lineWidth: 0.6))
    }

    private var studioUpcoming: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("今日动态").font(.system(size: 20, weight: .bold, design: .rounded)).foregroundStyle(V21.textPrimary)
                Spacer()
                NavigationLink(value: "calendar") {
                    Text("日历").font(.system(size: 13, weight: .semibold)).foregroundStyle(V21.textTertiary)
                }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(Array(activeCustomers.prefix(4))) { request in
                        NavigationLink(value: "customer") {
                            coverCard(request.statusEnum.rawValue, request.roomOrAddress.isEmpty ? request.content : request.roomOrAddress, request.imageData)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func coverCard(_ title: String, _ subtitle: String, _ imageData: Data?) -> some View {
        ZStack(alignment: .bottomLeading) {
            Group {
                if let imageData, let image = UIImage(data: imageData) {
                    Image(uiImage: image).resizable().scaledToFill()
                } else {
                    LinearGradient(colors: [V21.textPrimary.opacity(0.78), V21.textPrimary.opacity(0.35)], startPoint: .bottom, endPoint: .top)
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 11, weight: .semibold)).foregroundStyle(.white.opacity(0.8))
                Text(subtitle).font(.system(size: 15, weight: .semibold)).foregroundStyle(.white).lineLimit(2)
            }
            .padding(12)
        }
        .frame(width: 168, height: 118)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var assistantInput: BusinessAssistantInput {
        BusinessAssistantInput(
            monthGoal: settings.monthGoal,
            performances: performances,
            expenses: expenses,
            todos: todos,
            memos: memos,
            customers: customers,
            expiryItems: expiryItems,
            weather: weatherModel.snapshot
        )
    }

    private var assistantRefreshID: Int {
        todos.count + customers.count + expiryItems.count + performances.count
    }

    private var assistantBriefing: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 7) {
                Image(systemName: "sparkles").font(.system(size: 12, weight: .semibold)).foregroundColor(themePalette.accent)
                Text("今日经营简报").font(AppTypography.micro).foregroundColor(V21.textTertiary)
                Spacer()
                Text("本地整理").font(AppTypography.micro).foregroundColor(V21.textQuaternary)
            }
            Text(assistantSummaryText)
                .font(AppTypography.body)
                .foregroundColor(V21.textSecondary)
                .lineSpacing(3)
                .lineLimit(3)
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
    }

    private var assistantSummaryText: String {
        let statements = assistantOutput.summary.statements
        guard !statements.isEmpty else { return assistantOutput.summary.text }
        return statements.prefix(3).joined(separator: " ")
    }
}

private struct AvatarBadge: View {
    let settings: AppSettings
    var body: some View {
        Group {
            if let data = settings.avatarImageData, let image = UIImage(data: data) {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Text(settings.avatarEmoji).font(.system(size: 23))
            }
        }
        .frame(width: 42, height: 42)
        .background(Circle().fill(V21.info.opacity(0.12)))
        .clipShape(Circle())
        .overlay(Circle().stroke(V21.info.opacity(0.16), lineWidth: 1))
    }
}

private struct AvatarPickerSheet: View {
    let settings: AppSettings
    @Binding var selectedItem: PhotosPickerItem?
    @State private var customEmoji = ""
    private let emojis = ["😀", "😎", "🥰", "🐼", "🐶", "🏪", "☕️"]

    var body: some View {
        VStack(alignment: .leading, spacing: 17) {
            Text("我的头像").font(.system(size: 20, weight: .semibold, design: .rounded)).foregroundColor(V21.textPrimary)
            HStack(spacing: 14) {
                ForEach(emojis, id: \.self) { emoji in
                    Button { settings.avatarImageData = nil; settings.avatarEmoji = emoji } label: {
                        Text(emoji).font(.system(size: 25)).frame(width: 38, height: 38).background(V21.surfaceGlass, in: Circle())
                    }.buttonStyle(.plain)
                }
            }
            PhotosPicker(selection: $selectedItem, matching: .images) {
                Label("从相册选择头像", systemImage: "photo.on.rectangle").font(.system(size: 14, weight: .medium)).foregroundColor(V21.info)
            }
            .onChange(of: selectedItem) { _, item in
                guard let item else { return }
                Task { if let data = try? await item.loadTransferable(type: Data.self) { settings.avatarImageData = data } }
            }
        }
        .padding(.horizontal, 24).padding(.top, 8)
    }
}

private struct SpatialHomeBackdrop: View {
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                V21.background
                RadialGradient(colors: [V21.brandGreen.opacity(0.13), .clear], center: UnitPoint(x: 0.12, y: 0.05), startRadius: 0, endRadius: proxy.size.width * 0.9)
                RadialGradient(colors: [V21.info.opacity(0.07), .clear], center: UnitPoint(x: 0.94, y: 0.27), startRadius: 0, endRadius: proxy.size.width * 0.72)
            }
            .ignoresSafeArea()
        }
    }
}

private extension Date {
    var isBeforeToday: Bool { self < Date().startOfDay }
}
