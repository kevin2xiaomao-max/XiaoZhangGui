import SwiftUI
import SwiftData
import PhotosUI

/// 首页只负责经营信息的空间层级；数据和动作继续复用现有模型与仓库。
struct HomeView: View {
    @Binding var tab: AppTab
    @Binding var showVoice: Bool
    let showsVoiceButton: Bool

    @Environment(AppSettings.self) private var settings
    @Environment(\.modelContext) private var context
    @Query private var todos: [Todo]
    @Query private var performances: [Performance]
    @Query private var expenses: [Expense]
    @Query private var expiryItems: [ExpiryItem]
    @Query private var customers: [CustomerRequest]
    @Query private var memos: [Memo]
    @State private var showAvatarSheet = false
    @State private var showWeatherSheet = false
    @State private var selectedAvatarItem: PhotosPickerItem?
    @State private var weatherModel = WeatherViewModel()
    @State private var assistantOutput = BusinessAssistantOutput.empty
    private let assistantEngine = BusinessAssistantEngine()

    private var stats: HomeStats {
        HomeStats.compute(todos: todos, performances: performances, expiryItems: expiryItems, monthGoal: settings.monthGoal)
    }

    private var yesterdayRevenue: Double {
        let date = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        return performances.filter { $0.date.isSameDay(as: date) }.reduce(0) { $0 + $1.amount }
    }

    private var revenueChange: Double? {
        guard yesterdayRevenue > 0 else { return nil }
        return (stats.todayRevenue - yesterdayRevenue) / yesterdayRevenue * 100
    }

    private var overdueCount: Int {
        todos.filter { !$0.isCompleted && ($0.dueDate?.isBeforeToday ?? false) }.count
    }

    private var deliveryCount: Int { customers.filter { $0.statusEnum == .delivering }.count }
    private var hasAlert: Bool { stats.urgentExpiryCount > 0 || overdueCount > 0 || deliveryCount > 0 }
    /// 旧演示数据只允许在显式 UI Demo 环境开启；普通 Simulator 与真机均读取 SwiftData。
    private var isMockPreview: Bool { RuntimeMode.allowsMockData }
    private var displayRevenue: Double { isMockPreview ? 2680 : stats.todayRevenue }
    private var displayTodoCount: Int { isMockPreview ? 4 : stats.todayTodos.count }
    private var displayExpiryCount: Int { isMockPreview ? 1 : stats.urgentExpiryCount }
    private var displayCustomerCount: Int { isMockPreview ? 2 : customers.count }
    private var displayUnreadCount: Int { isMockPreview ? 3 : overdueCount }
    private var displayGoalPercent: Int { isMockPreview ? 68 : stats.goalProgressPercent }
    private var displayRevenueChange: Double? { isMockPreview ? 12.6 : revenueChange }
    private var themePalette: AppThemePalette { AppTheme.palette(named: settings.appThemeName) }
    private let mockTodos = [("09:30", "供应商送货"), ("11:00", "清点饮料库存"), ("15:00", "联系饮料供应商"), ("18:30", "盘点冰柜"), ("21:00", "核对今日营业额")]
    private let mockDeliveries = [("302别墅", "矿泉水2箱＋冰块2袋", "18:30"), ("208房", "可乐2瓶＋薯片3包", "19:10"), ("16栋05房", "泡面4桶＋饮料", "20:00"), ("温泉酒店前台", "矿泉水1箱", "20:30")]
    private let mockTemporary = [("鲜牛奶 ×6", "明天退货", 0), ("三明治 ×4", "今晚处理", 1), ("面包 ×8", "剩2天", 2), ("酸奶 ×5", "剩3天", 2), ("泳裤 ×2", "待退供应商", 1)]

    var body: some View {
        ZStack(alignment: .top) {
            SpatialHomeBackdrop()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    referenceHeader
                    referenceRevenueCard
                    assistantBriefing
                    todayTodoModule
                    deliveryModule
                    temporaryModule
                }
                .padding(.horizontal, V21Layout.pageMargin)
                .padding(.top, 16)
                .padding(.bottom, V21Layout.bottomDockContentGap)
            }
        }
        .navigationDestination(for: String.self) { route in
            switch route {
            case "memo": MemoView()
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
        .sheet(isPresented: $showWeatherSheet) {
            WeatherDetailSheet(model: weatherModel, palette: themePalette)
                .presentationDetents([.height(300)])
                .presentationDragIndicator(.visible)
        }
        .task {
            weatherModel.loadIfNeeded()
        }
        .task(id: assistantRefreshID) {
            assistantOutput = await assistantEngine.analyze(assistantInput)
        }
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
        var hasher = Hasher()
        hasher.combine(settings.monthGoal)
        performances.forEach { hasher.combine($0.amount); hasher.combine($0.date) }
        expenses.forEach { hasher.combine($0.amount); hasher.combine($0.date) }
        todos.forEach {
            hasher.combine($0.notificationID)
            hasher.combine($0.isCompleted)
            hasher.combine($0.priority)
            hasher.combine($0.dueDate)
            hasher.combine($0.completedAt)
        }
        memos.forEach { hasher.combine($0.createdAt); hasher.combine($0.updatedAt); hasher.combine($0.title); hasher.combine($0.content) }
        customers.forEach { hasher.combine($0.notificationID); hasher.combine($0.status); hasher.combine($0.updatedAt) }
        expiryItems.forEach { hasher.combine($0.notificationID); hasher.combine($0.returnStatus); hasher.combine($0.expiryDate) }
        hasher.combine(weatherModel.snapshot?.observedAt)
        return hasher.finalize()
    }

    private var recentRecords: [(title: String, detail: String, amount: Double, isExpense: Bool)] {
        if isMockPreview { return [("302别墅 · 送两箱矿泉水", "配送 · 18:30", 0, false)] }
        let income = performances.map { (title: $0.note.isBlank ? "营业额" : $0.note, detail: "收入 · \(Fmt.shortDateTime($0.date))", amount: $0.amount, isExpense: false) }
        let spending = expenses.map { (title: $0.note.isBlank ? $0.category : $0.note, detail: "支出 · \(Fmt.shortDateTime($0.date))", amount: $0.amount, isExpense: true) }
        return (income + spending).sorted { $0.detail > $1.detail }.prefix(4).map { $0 }
    }

    private var operatingHero: some View { referenceRevenueCard }

    private var todayTodoModule: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack { Text("今天待办").font(.system(size: 20, weight: .bold, design: .rounded)).foregroundColor(V21.textPrimary); Spacer(); Text("\(isMockPreview ? 5 : stats.todayTodos.count)件").font(.system(size: 13, weight: .semibold)).foregroundColor(V21.textTertiary) }
            VStack(alignment: .leading, spacing: 9) {
                if isMockPreview { ForEach(mockTodos.prefix(2), id: \.0) { item in todoRow(time: item.0, title: item.1) } }
                else if stats.todayTodos.isEmpty { Text("今天没有待办").font(AppTypography.body).foregroundColor(V21.textTertiary).padding(.vertical, 4) }
                else { ForEach(stats.todayTodos.prefix(2)) { todo in todoRow(time: todo.dueDate.map(Fmt.time) ?? "—", title: todo.title) } }
                Button("查看全部待办") { tab = .todo }.font(.system(size: 12, weight: .semibold)).foregroundColor(themePalette.accent).padding(.top, 3)
            }.frame(maxWidth: .infinity, alignment: .leading).padding(16).background(V21.surfacePrimary, in: RoundedRectangle(cornerRadius: 20, style: .continuous)).overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(V21.divider.opacity(0.7)))
        }.padding(.top, 12)
    }

    private func todoRow(time: String, title: String) -> some View { HStack(spacing: 10) { Text(time).font(.system(size: 13, weight: .semibold, design: .rounded)).foregroundColor(V21.textTertiary).frame(width: 48, alignment: .leading); Circle().fill(themePalette.accent).frame(width: 6, height: 6); Text(title).font(.system(size: 15, weight: .medium)).foregroundColor(V21.textPrimary).lineLimit(1); Spacer() } }

    private var deliveryModule: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack { Text("客户配送").font(.system(size: 20, weight: .bold, design: .rounded)).foregroundColor(V21.textPrimary); Spacer(); Text("\(isMockPreview ? 4 : customers.filter { $0.statusEnum != .done }.count)单").font(.system(size: 13, weight: .semibold)).foregroundColor(V21.textTertiary) }
            VStack(alignment: .leading, spacing: 9) {
                if isMockPreview { ForEach(mockDeliveries.prefix(2), id: \.0) { item in deliveryRow(address: item.0, content: item.1, time: item.2) } }
                else if customers.filter({ $0.statusEnum != .done }).isEmpty { Text("今天暂无配送").font(AppTypography.body).foregroundColor(V21.textTertiary).padding(.vertical, 4) }
                else { ForEach(customers.filter { $0.statusEnum != .done }.prefix(2)) { item in deliveryRow(address: item.roomOrAddress.isEmpty ? item.customer : item.roomOrAddress, content: item.content, time: "待配送") } }
                NavigationLink("查看全部配送", value: "customer").font(.system(size: 12, weight: .semibold)).foregroundColor(themePalette.accent).padding(.top, 3)
            }.frame(maxWidth: .infinity, alignment: .leading).padding(16).background(V21.surfacePrimary, in: RoundedRectangle(cornerRadius: 20, style: .continuous)).overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(V21.divider.opacity(0.7)))
        }.padding(.top, 12)
    }

    private func deliveryRow(address: String, content: String, time: String) -> some View { HStack(spacing: 9) { Image(systemName: "shippingbox.fill").font(.system(size: 14)).foregroundColor(V21.info); VStack(alignment: .leading, spacing: 2) { Text(address).font(.system(size: 14, weight: .semibold)).foregroundColor(V21.textPrimary).lineLimit(1); Text(content).font(.system(size: 12)).foregroundColor(V21.textTertiary).lineLimit(1) }; Spacer(); Text(time).font(.system(size: 12, weight: .medium, design: .rounded)).foregroundColor(V21.textSecondary) } }

    private var temporaryModule: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack { Text("临时商品").font(.system(size: 20, weight: .bold, design: .rounded)).foregroundColor(V21.textPrimary); Spacer(); Text("\(isMockPreview ? 5 : expiryItems.count)项").font(.system(size: 13, weight: .semibold)).foregroundColor(V21.textTertiary) }
            VStack(alignment: .leading, spacing: 9) {
                if isMockPreview { ForEach(mockTemporary.prefix(2), id: \.0) { item in temporaryRow(name: item.0, status: item.1, level: item.2) } }
                else if expiryItems.isEmpty { Text("暂无需要处理的临时商品").font(AppTypography.body).foregroundColor(V21.textTertiary).padding(.vertical, 4) }
                else { ForEach(expiryItems.prefix(2)) { item in temporaryRow(name: "\(item.name) ×\(item.quantity)", status: item.status.rawValue, level: item.daysLeft() <= 1 ? 0 : 2) } }
                NavigationLink("查看全部临时商品", value: "goods").font(.system(size: 12, weight: .semibold)).foregroundColor(themePalette.accent).padding(.top, 3)
            }.frame(maxWidth: .infinity, alignment: .leading).padding(16).background(V21.surfacePrimary, in: RoundedRectangle(cornerRadius: 20, style: .continuous)).overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(V21.divider.opacity(0.7)))
        }.padding(.top, 12)
    }

    private func temporaryRow(name: String, status: String, level: Int) -> some View { HStack(spacing: 9) { Circle().fill(level == 0 ? V21.danger : (level == 1 ? V21.warning : V21.info)).frame(width: 7, height: 7); Text(name).font(.system(size: 14, weight: .medium)).foregroundColor(V21.textPrimary); Spacer(); Text(status).font(.system(size: 12, weight: .medium)).foregroundColor(level == 0 ? V21.danger : V21.textTertiary) } }

    private var referenceHeader: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("你的小掌柜").font(AppTypography.pageTitle).foregroundColor(V21.textPrimary)
                Text("晚上好，掌柜 👋").font(.system(size: 14, weight: .medium)).foregroundColor(V21.textTertiary)
            }
            Spacer()
            HStack(spacing: 8) {
                WeatherPill(model: weatherModel, palette: themePalette) {
                    Haptic.light()
                    showWeatherSheet = true
                }
                Button { Haptic.light(); showAvatarSheet = true } label: {
                    AvatarBadge(settings: settings)
                }.buttonStyle(.plain)
            }
        }.padding(.top, 7).padding(.bottom, 16)
    }

    private var assistantBriefing: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 7) {
                Image(systemName: "sparkles")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(themePalette.accent)
                Text("今日经营简报")
                    .font(AppTypography.micro)
                    .foregroundColor(V21.textTertiary)
                Spacer()
                Text("本地整理")
                    .font(AppTypography.micro)
                    .foregroundColor(V21.textQuaternary)
            }

            Text(assistantSummaryText)
                .font(AppTypography.body)
                .foregroundColor(V21.textSecondary)
                .lineSpacing(3)
                .lineLimit(3)

            if let insight = assistantOutput.insights.first {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: insight.symbolName)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(insight.priority == .high ? V21.warning : themePalette.accent)
                        .frame(width: 16)
                    Text(insight.message)
                        .font(AppTypography.caption)
                        .foregroundColor(V21.textTertiary)
                        .lineLimit(2)
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(.vertical, 13)
        .overlay(alignment: .bottom) {
            Rectangle().fill(V21.divider).frame(height: 1)
        }
        .accessibilityElement(children: .combine)
    }

    private var assistantSummaryText: String {
        let statements = assistantOutput.summary.statements
        guard !statements.isEmpty else { return assistantOutput.summary.text }
        return statements.prefix(3).joined(separator: " ")
    }

    private var referenceRevenueCard: some View {
        BusinessMetricView(title: "今日营业额", value: "¥\(Fmt.groupedInt(displayRevenue))",
            detail: displayRevenueChange.map { "较昨日 \($0 >= 0 ? "↑" : "↓") \(String(format: "%.1f%%", abs($0))) · 目标完成 \(displayGoalPercent)%" } ?? "较昨日暂无对比数据 · 目标完成 \(displayGoalPercent)%",
            tint: displayRevenueChange.map { $0 >= 0 ? themePalette.accent : V21.danger } ?? V21.textTertiary)
    }

    private var referenceOverview: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack { Text("今日概览").font(.system(size: 19, weight: .semibold, design: .rounded)).foregroundColor(V21.textPrimary); Spacer(); Text(Date(), format: .dateTime.month().day().weekday(.wide)).font(.system(size: 12, weight: .medium)).foregroundColor(V21.textTertiary) }
            HStack(spacing: 8) {
                overviewChip("待办", "\(displayTodoCount)", "件", Color(hex: 0xF9DDE5))
                overviewChip("临期", "\(displayExpiryCount)", "项", Color(hex: 0xF7E8C9))
                overviewChip("客户需求", "\(displayCustomerCount)", "单", Color(hex: 0xD8F1E5))
                overviewChip("未读提醒", "\(displayUnreadCount)", "条", Color(hex: 0xDCEBFA))
            }
        }.padding(.top, 18)
    }

    private func overviewChip(_ title: String, _ value: String, _ unit: String, _ tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 7) { Text(title).font(.system(size: 11, weight: .medium)).foregroundColor(V21.textSecondary); HStack(alignment: .firstTextBaseline, spacing: 3) { Text(value).font(.system(size: 22, weight: .bold, design: .rounded)).foregroundColor(V21.textPrimary); Text(unit).font(.system(size: 11, weight: .medium)).foregroundColor(V21.textTertiary) } }.frame(maxWidth: .infinity, minHeight: 76, alignment: .leading).padding(.horizontal, 11).background(tint, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
    }

    private var referenceStatus: some View {
        VStack(alignment: .leading, spacing: 11) { Text("今日状态").font(.system(size: 19, weight: .semibold, design: .rounded)).foregroundColor(V21.textPrimary); HStack(spacing: 13) { Image(systemName: displayTodoCount == 0 ? "checkmark" : "clock").font(.system(size: 18, weight: .bold)).foregroundColor(themePalette.accent).frame(width: 42, height: 42).background(themePalette.accent.opacity(0.14), in: Circle()); VStack(alignment: .leading, spacing: 3) { Text(displayTodoCount == 0 ? "今天没有待处理事项" : "还有 \(displayTodoCount) 件事待处理").font(.system(size: 15, weight: .semibold)).foregroundColor(V21.textPrimary); if isMockPreview { Text("最近：15:00 联系饮料供应商").font(.system(size: 12)).foregroundColor(V21.textTertiary) } else if let next = stats.todayTodos.first { Text("最近：\(next.title)").font(.system(size: 12)).foregroundColor(V21.textTertiary) } else { Text("可以休息一下，或者记点事情").font(.system(size: 12)).foregroundColor(V21.textTertiary) } }; Spacer(); Button("查看待办") { tab = .todo }.font(.system(size: 12, weight: .semibold)).foregroundColor(V21.info).padding(.horizontal, 13).padding(.vertical, 8).background(V21.info.opacity(0.11), in: Capsule()) }.padding(15).background(Color.v21Dynamic(light: 0xFFFFFF, dark: 0x171A1D, lightAlpha: 0.96, darkAlpha: 1), in: RoundedRectangle(cornerRadius: 19, style: .continuous)).overlay(RoundedRectangle(cornerRadius: 19, style: .continuous).stroke(V21.divider.opacity(0.7))).shadow(color: .black.opacity(0.06), radius: 12, y: 5) }.padding(.top, 18)
    }

    private var referenceBottomColumns: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 10) { Text("快速操作").font(.system(size: 18, weight: .semibold, design: .rounded)).foregroundColor(V21.textPrimary); Button { Haptic.light(); tab = .performance } label: { Label("记收入", systemImage: "plus").font(.system(size: 14, weight: .semibold)).foregroundColor(.white).frame(maxWidth: .infinity, minHeight: 45).background(V21.brandGreen, in: RoundedRectangle(cornerRadius: 14, style: .continuous)) }.buttonStyle(.plain); quickMini("新待办", "checkmark.circle") { tab = .todo }; if showsVoiceButton { quickMini("语音记录", "mic.fill") { showVoice = true } }; Menu { NavigationLink("记录", value: "memo"); NavigationLink("日历", value: "calendar"); NavigationLink("客户配送", value: "customer"); NavigationLink("临期提醒", value: "expiry") } label: { Text("更多").font(.system(size: 12, weight: .medium)).foregroundColor(V21.textTertiary).frame(maxWidth: .infinity, minHeight: 30) }.buttonStyle(.plain) }.padding(15).frame(maxWidth: .infinity, alignment: .leading).background(Color.v21Dynamic(light: 0xFFFFFF, dark: 0x171A1D, lightAlpha: 0.96, darkAlpha: 1), in: RoundedRectangle(cornerRadius: 20, style: .continuous)).overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(V21.divider.opacity(0.7))).shadow(color: .black.opacity(0.045), radius: 10, y: 4)
            VStack(alignment: .leading, spacing: 10) { Text("最近记录").font(.system(size: 18, weight: .semibold, design: .rounded)).foregroundColor(V21.textPrimary); if recentRecords.isEmpty { Text("暂无记录").font(.system(size: 12)).foregroundColor(V21.textTertiary).padding(.vertical, 25) } else { ForEach(Array(recentRecords.prefix(3).enumerated()), id: \.offset) { _, record in HStack(spacing: 7) { Image(systemName: record.isExpense ? "arrow.down.left" : "arrow.up.right").font(.system(size: 10, weight: .bold)).foregroundColor(record.isExpense ? V21.danger : V21.brandGreen); Text(record.title).font(.system(size: 12, weight: .medium)).foregroundColor(V21.textSecondary).lineLimit(1); Spacer(); Text("\(record.isExpense ? "-" : "+")¥\(Fmt.groupedInt(record.amount))").font(.system(size: 11, weight: .semibold, design: .rounded)).foregroundColor(record.isExpense ? V21.danger : V21.brandGreen) } } } }.padding(15).frame(maxWidth: .infinity, alignment: .leading).background(Color.v21Dynamic(light: 0xFFFFFF, dark: 0x171A1D, lightAlpha: 0.96, darkAlpha: 1), in: RoundedRectangle(cornerRadius: 20, style: .continuous)).overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(V21.divider.opacity(0.7))).shadow(color: .black.opacity(0.045), radius: 10, y: 4)
        }.padding(.top, 20)
    }

    private var heroVisual: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("你的小掌柜").font(.system(size: 14, weight: .medium)).foregroundColor(.white.opacity(0.72))
                    Text("今日经营").font(.system(size: 28, weight: .bold, design: .rounded)).foregroundColor(.white)
                    Text(Date(), format: .dateTime.month().day().weekday(.wide)).font(.system(size: 13, weight: .medium)).foregroundColor(.white.opacity(0.62))
                }
                Spacer()
                Image(systemName: "sparkles").font(.system(size: 17, weight: .semibold)).foregroundColor(.white).frame(width: 42, height: 42).background(Circle().fill(.white.opacity(0.16))).overlay(Circle().stroke(.white.opacity(0.25)))
            }
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("¥").font(.system(size: 28, weight: .semibold, design: .rounded)).foregroundColor(.white.opacity(0.86))
                Text(Fmt.groupedInt(stats.todayRevenue)).font(.system(size: 62, weight: .bold, design: .rounded)).foregroundColor(.white).lineLimit(1).minimumScaleFactor(0.48)
            }.padding(.top, 25)
            HStack(spacing: 8) {
                if let change = revenueChange { Text("较昨日 \(change >= 0 ? "↑" : "↓") \(String(format: "%.1f%%", abs(change)))") .foregroundColor(.white.opacity(0.9)) }
                else { Text("较昨日暂无对比数据").foregroundColor(.white.opacity(0.62)) }
                Spacer(); Text("今日目标 \(stats.goalProgressPercent)%").foregroundColor(.white.opacity(0.72))
            }.font(.system(size: 13, weight: .medium)).padding(.top, 4)
        }
        .padding(22)
        .background {
            RoundedRectangle(cornerRadius: 30, style: .continuous).fill(LinearGradient(colors: [Color(hex: 0x2879F6), Color(hex: 0x6257D9), Color(hex: 0x8A49C7)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(RoundedRectangle(cornerRadius: 30, style: .continuous).fill(.white.opacity(0.05)))
        }
        .overlay(RoundedRectangle(cornerRadius: 30, style: .continuous).stroke(.white.opacity(0.16), lineWidth: 1))
        .shadow(color: Color(hex: 0x4E5ED7).opacity(0.22), radius: 20, y: 10)
    }

    private var overviewGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
            overviewCell("今日收入", Fmt.money(stats.todayRevenue), "chart.line.uptrend.xyaxis", Color(hex: 0xDCEBFF))
            overviewCell("待办事项", "\(stats.todayTodos.count) 件", "checkmark.circle.fill", Color(hex: 0xE8E0FF))
            overviewCell("临期提醒", "\(stats.urgentExpiryCount) 项", "clock.badge.exclamationmark", Color(hex: 0xFFF0D8))
            overviewCell("配送中", "\(deliveryCount) 单", "shippingbox.fill", Color(hex: 0xDDF5EC))
        }.padding(.top, 14)
    }

    private func overviewCell(_ title: String, _ value: String, _ icon: String, _ tint: Color) -> some View {
        HStack(spacing: 10) { Image(systemName: icon).font(.system(size: 16, weight: .semibold)).foregroundColor(V21.textPrimary).frame(width: 32, height: 32).background(tint, in: Circle()); VStack(alignment: .leading, spacing: 3) { Text(title).font(.system(size: 12, weight: .medium)).foregroundColor(V21.textTertiary); Text(value).font(.system(size: 16, weight: .semibold, design: .rounded)).foregroundColor(V21.textPrimary) }; Spacer(minLength: 0) }
            .padding(12).background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(V21.surfaceGlass)).overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(V21.divider.opacity(0.7)))
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 13) { HStack { Text("今日状态").font(.system(size: 18, weight: .semibold, design: .rounded)).foregroundColor(V21.textPrimary); Spacer(); Image(systemName: "arrow.up.right").font(.system(size: 13, weight: .semibold)).foregroundColor(V21.textTertiary) }; HStack(spacing: 0) { statusButton(value: stats.todayTodos.count, title: "待办") { tab = .todo }; statusButton(value: stats.urgentExpiryCount, title: "临期", destination: "expiry"); statusButton(value: deliveryCount, title: "配送", destination: "customer") } }
            .padding(18).background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(V21.surfacePrimary)).overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(V21.divider.opacity(0.75))).padding(.top, 14)
    }

    private var upcomingContent: some View {
        VStack(alignment: .leading, spacing: 13) { HStack { Text("接下来").font(.system(size: 20, weight: .bold, design: .rounded)).foregroundColor(V21.textPrimary); Spacer(); Button("查看全部") { tab = .todo }.font(.system(size: 13, weight: .semibold)).foregroundColor(V21.brandGreen) }
            if stats.todayTodos.isEmpty { HStack(spacing: 12) { Image(systemName: "sun.max").font(.system(size: 23, weight: .light)).foregroundColor(V21.brandGreen); VStack(alignment: .leading, spacing: 3) { Text("今天暂时没有安排").font(.system(size: 15, weight: .medium)).foregroundColor(V21.textSecondary); Text("可以休息一下，或者记点事情").font(.system(size: 13)).foregroundColor(V21.textTertiary) } }.padding(.vertical, 11) }
            else { ForEach(Array(stats.todayTodos.prefix(3).enumerated()), id: \.element.id) { _, todo in HStack(spacing: 10) { Button { Haptic.light(); withAnimation(.easeOut(duration: 0.2)) { try? TodoRepository(context: context).toggleComplete(todo) } } label: { Image(systemName: "circle").font(.system(size: 19)).foregroundColor(V21.textQuaternary) }.buttonStyle(.plain); if let due = todo.dueDate { Text(Fmt.time(due)).font(.system(size: 13, weight: .semibold, design: .rounded)).foregroundColor(V21.textTertiary).frame(width: 42, alignment: .leading) }; Text(todo.title).font(.system(size: 15, weight: .medium)).foregroundColor(V21.textPrimary).lineLimit(1); Spacer(); PriorityDot(level: todo.priority) } }
            }
        }.padding(.top, 22)
    }

    private var quickAndRecent: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 11) { Text("快速操作").font(.system(size: 18, weight: .semibold, design: .rounded)).foregroundColor(V21.textPrimary); Button { Haptic.light(); tab = .performance } label: { Label("记收入", systemImage: "plus").font(.system(size: 15, weight: .semibold)).foregroundColor(.white).frame(maxWidth: .infinity, minHeight: 48).background(V21.brandGreen, in: RoundedRectangle(cornerRadius: 15, style: .continuous)) }.buttonStyle(.plain); HStack { quickMini("新待办", "checkmark.circle") { tab = .todo }; if showsVoiceButton { quickMini("语音", "mic.fill") { showVoice = true } } }; Menu { NavigationLink("记录", value: "memo"); NavigationLink("日历", value: "calendar"); NavigationLink("客户配送", value: "customer"); NavigationLink("临期提醒", value: "expiry"); NavigationLink("临时商品", value: "goods") } label: { Label("更多", systemImage: "ellipsis").font(.system(size: 13, weight: .medium)).foregroundColor(V21.textSecondary).frame(maxWidth: .infinity, minHeight: 34) }.buttonStyle(.plain) }.frame(maxWidth: .infinity)
            VStack(alignment: .leading, spacing: 11) { Text("最近记录").font(.system(size: 18, weight: .semibold, design: .rounded)).foregroundColor(V21.textPrimary); if recentRecords.isEmpty { Text("暂无记录").font(.system(size: 13)).foregroundColor(V21.textTertiary).padding(.vertical, 23) } else { ForEach(Array(recentRecords.prefix(3).enumerated()), id: \.offset) { _, record in HStack(spacing: 8) { Image(systemName: record.isExpense ? "arrow.down.left" : "arrow.up.right").font(.system(size: 11, weight: .bold)).foregroundColor(record.isExpense ? V21.danger : V21.brandGreen); VStack(alignment: .leading, spacing: 2) { Text(record.title).font(.system(size: 13, weight: .medium)).foregroundColor(V21.textSecondary).lineLimit(1); Text(record.detail).font(.system(size: 10)).foregroundColor(V21.textQuaternary) }; Spacer(); Text("\(record.isExpense ? "-" : "+")¥\(Fmt.groupedInt(record.amount))").font(.system(size: 12, weight: .semibold, design: .rounded)).foregroundColor(record.isExpense ? V21.danger : V21.brandGreen) } } } }.frame(maxWidth: .infinity)
        }.padding(.top, 21).padding(.bottom, 12)
    }

    private func quickMini(_ title: String, _ icon: String, action: @escaping () -> Void) -> some View { Button { Haptic.light(); action() } label: { VStack(spacing: 5) { Image(systemName: icon).font(.system(size: 15, weight: .semibold)).foregroundColor(V21.brandGreen); Text(title).font(.system(size: 11, weight: .medium)).foregroundColor(V21.textSecondary) }.frame(maxWidth: .infinity, minHeight: 42).background(V21.surfaceGlass, in: RoundedRectangle(cornerRadius: 13, style: .continuous)) }.buttonStyle(.plain) }

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("今日经营")
                        .v21Style(.labelLarge)
                        .foregroundColor(V21.textSecondary)
                    Text(Date(), format: .dateTime.month().day().weekday(.wide))
                        .v21Style(.labelMedium)
                        .foregroundColor(V21.textTertiary)
                }
                Spacer()
                Image(systemName: "sparkles")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(V21.brandGreen)
                    .padding(11)
                    .background(Circle().fill(V21.brandGreen.opacity(0.1)))
            }

            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text("¥")
                    .font(.system(size: 27, weight: .semibold, design: .rounded))
                    .foregroundColor(V21.brandGreen)
                Text(Fmt.groupedInt(stats.todayRevenue))
                    .font(.system(size: 66, weight: .bold, design: .rounded))
                    .foregroundColor(V21.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.42)
                    .layoutPriority(1)
            }
            .padding(.top, 29)

            HStack(spacing: 10) {
                if let change = revenueChange {
                    Label(String(format: "较昨日 %@ %.1f%%", change >= 0 ? "↑" : "↓", abs(change)), systemImage: change >= 0 ? "arrow.up.right" : "arrow.down.right")
                        .foregroundColor(change >= 0 ? V21.brandGreen : V21.danger)
                } else {
                    Text("较昨日暂无对比数据").foregroundColor(V21.textTertiary)
                }
                Text("·").foregroundColor(V21.textQuaternary)
                Text("今日目标 \(stats.goalProgressPercent)%").foregroundColor(V21.textTertiary)
            }
            .v21Style(.labelMedium)
            .padding(.top, 10)
        }
        .frame(maxWidth: .infinity, minHeight: 292, alignment: .topLeading)
        .padding(.top, 14)
        .padding(.bottom, 25)
    }

    private var statusPanel: some View {
        HStack(spacing: 0) {
            statusButton(value: stats.todayTodos.count, title: "待办") { tab = .todo }
            statusButton(value: stats.urgentExpiryCount, title: "临期", destination: "expiry")
            statusButton(value: deliveryCount, title: "配送", destination: "customer")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(V21.surfaceGlass))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(V21.dividerHighlight.opacity(0.4), lineWidth: 1))
        .shadow(color: .black.opacity(0.1), radius: 18, y: 9)
        .offset(y: -4)
        .zIndex(2)
    }

    private func statusButton(value: Int, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { statusLabel(value: value, title: title) }
            .buttonStyle(.plain)
    }

    private func statusButton(value: Int, title: String, destination: String) -> some View {
        NavigationLink(value: destination) { statusLabel(value: value, title: title) }
            .buttonStyle(.plain)
    }

    private func statusLabel(value: Int, title: String) -> some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.system(size: 25, weight: .bold, design: .rounded))
                .foregroundColor(V21.textPrimary)
            Text(title).v21Style(.labelMedium).foregroundColor(V21.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    private var upcomingSheet: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(alignment: .firstTextBaseline) {
                Label("接下来", systemImage: "arrow.down.right")
                    .v21Style(.titleLarge)
                    .foregroundColor(V21.textPrimary)
                Spacer()
                Button("查看全部") { tab = .todo }
                    .v21Style(.labelMedium)
                    .foregroundColor(V21.brandGreen)
            }

            if stats.todayTodos.isEmpty {
                VStack(spacing: 9) {
                    Image(systemName: "sun.max")
                        .font(.system(size: 28, weight: .light))
                        .foregroundColor(V21.brandGreen.opacity(0.8))
                    Text("今天暂时没有安排")
                        .v21Style(.bodyLarge).fontWeight(.medium).foregroundColor(V21.textSecondary)
                    Text("可以休息一下，或者记点事情")
                        .v21Style(.bodyMedium).foregroundColor(V21.textTertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 25)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(stats.todayTodos.prefix(3).enumerated()), id: \.element.id) { index, todo in
                        HStack(alignment: .top, spacing: 12) {
                            Button {
                                Haptic.light()
                                withAnimation(.easeOut(duration: 0.2)) { try? TodoRepository(context: context).toggleComplete(todo) }
                            } label: {
                                Circle().strokeBorder(V21.dividerStrong, lineWidth: 1.5).frame(width: 21, height: 21)
                            }
                            .buttonStyle(.plain)
                            VStack(alignment: .leading, spacing: 5) {
                                Text(todo.title).v21Style(.bodyLarge).fontWeight(.medium).foregroundColor(V21.textPrimary).lineLimit(2)
                                HStack(spacing: 7) {
                                    if let due = todo.dueDate { Text(Fmt.time(due)) }
                                    PriorityDot(level: todo.priority)
                                    Text(todo.priorityLevel.label)
                                }
                                .v21Style(.labelMedium).foregroundColor(V21.textTertiary)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, 10)
                        if index < min(stats.todayTodos.count, 3) - 1 {
                            Rectangle().fill(V21.divider).frame(height: 1).padding(.leading, 33)
                        }
                    }
                }
            }
        }
        .padding(20)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .background(RoundedRectangle(cornerRadius: 28, style: .continuous).fill(V21.surfacePrimary))
        .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).strokeBorder(V21.divider.opacity(0.65), lineWidth: 1))
        .shadow(color: .black.opacity(0.07), radius: 16, y: 8)
        .padding(.top, 17)
    }

    private var quickActions: some View {
        VStack(alignment: .leading, spacing: 13) {
            Text("快速记录").v21Style(.titleLarge).foregroundColor(V21.textPrimary)
            HStack(alignment: .top, spacing: 10) {
                Button { Haptic.light(); tab = .performance } label: {
                    VStack(alignment: .leading, spacing: 14) {
                        Image(systemName: "plus.circle.fill").font(.system(size: 25, weight: .semibold)).foregroundColor(.white)
                        Text("记收入").v21Style(.bodyLarge).fontWeight(.semibold).foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity, minHeight: 108, alignment: .leading)
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(V21.brandGreenGradient))
                    .shadow(color: V21.brandGreen.opacity(0.2), radius: 12, y: 6)
                }
                .buttonStyle(.plain)

                VStack(spacing: 10) {
                    quickSecondary("新待办", icon: "checkmark.circle") { tab = .todo }
                    if showsVoiceButton { quickSecondary("语音记录", icon: "mic.fill") { showVoice = true } }
                }
                .frame(maxWidth: .infinity)

                Menu {
                    NavigationLink("记录", value: "memo")
                    NavigationLink("日历", value: "calendar")
                    NavigationLink("客户配送", value: "customer")
                    NavigationLink("临期提醒", value: "expiry")
                    NavigationLink("临时商品", value: "goods")
                } label: {
                    VStack(spacing: 10) {
                        Image(systemName: "ellipsis").font(.system(size: 19, weight: .bold)).foregroundColor(V21.brandGreen)
                        Text("更多").v21Style(.labelMedium).foregroundColor(V21.textSecondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 108)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(V21.divider, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 25)
        .padding(.bottom, 14)
    }

    private func quickSecondary(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button { Haptic.light(); action() } label: {
            HStack(spacing: 8) {
                Image(systemName: icon).font(.system(size: 16, weight: .semibold)).foregroundColor(V21.brandGreen)
                Text(title).v21Style(.labelMedium).foregroundColor(V21.textSecondary)
                Spacer()
            }
            .padding(.horizontal, 13)
            .frame(maxWidth: .infinity, minHeight: 49)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(V21.surfaceGlass))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(V21.divider, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var alertSheet: some View {
        NavigationLink(value: stats.urgentExpiryCount > 0 ? "expiry" : "customer") {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill").foregroundColor(V21.warning)
                VStack(alignment: .leading, spacing: 3) {
                    Text("需要处理").v21Style(.labelLarge).foregroundColor(V21.textPrimary)
                    Text(alertSummary).v21Style(.labelMedium).foregroundColor(V21.textTertiary)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundColor(V21.textQuaternary)
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(V21.warning.opacity(0.08)))
        }
        .buttonStyle(.plain)
        .padding(.bottom, 12)
    }

    private var alertSummary: String {
        var items: [String] = []
        if stats.urgentExpiryCount > 0 { items.append("临期 \(stats.urgentExpiryCount) 件") }
        if overdueCount > 0 { items.append("逾期待办 \(overdueCount) 件") }
        if deliveryCount > 0 { items.append("配送中 \(deliveryCount) 单") }
        return items.joined(separator: " · ")
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
                    Button { settings.avatarImageData = nil; settings.avatarEmoji = emoji } label: { Text(emoji).font(.system(size: 25)).frame(width: 38, height: 38).background(V21.surfaceGlass, in: Circle()) }.buttonStyle(.plain)
                }
            }
            HStack(spacing: 10) {
                TextField("输入自定义 Emoji", text: $customEmoji).textFieldStyle(.roundedBorder).frame(maxWidth: .infinity)
                Button("添加") { let value = customEmoji.trimmingCharacters(in: .whitespacesAndNewlines); if !value.isEmpty { settings.avatarImageData = nil; settings.avatarEmoji = String(value.prefix(2)); customEmoji = "" } }.font(.system(size: 13, weight: .semibold)).foregroundColor(V21.info)
            }
            PhotosPicker(selection: $selectedItem, matching: .images) { Label("从相册选择头像", systemImage: "photo.on.rectangle").font(.system(size: 14, weight: .medium)).foregroundColor(V21.info) }
                .onChange(of: selectedItem) { _, item in
                    guard let item else { return }
                    Task {
                        if let data = try? await item.loadTransferable(type: Data.self) { settings.avatarImageData = data }
                    }
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
                LinearGradient(colors: [.clear, V21.background.opacity(0.5)], startPoint: .top, endPoint: .bottom)
            }
            .ignoresSafeArea()
        }
    }
}

private extension Date {
    var isBeforeToday: Bool { self < Date().startOfDay }
}
