import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import PhotosUI

// MARK: - 我的（V32）：个人头部 + 经营数据入口 + 分组设置

struct ProfileView: View {
    @Binding var tab: AppTab
    @Binding var showVoice: Bool
    let showsVoiceButton: Bool

    @Environment(\.modelContext) private var context
    @Query private var performances: [Performance]
    @Query private var todos: [Todo]
    @Query private var memos: [Memo]
    @Query private var expenses: [Expense]
    @Query private var expiryItems: [ExpiryItem]
    @Query private var customers: [CustomerRequest]
    @Query private var goodsList: [Goods]

    @Bindable private var settings = AppSettings.shared
    @Bindable private var demo = DemoMode.shared

    @State private var shopDialog = false
    @State private var goalDialog = false
    @State private var themeDialog = false
    @State private var voiceDialog = false
    @State private var reminderDialog = false
    @State private var aboutDialog = false
    @State private var privacyDialog = false
    @State private var clearDialog = false
    @State private var showImporter = false
    @State private var toast: String?
    @State private var avatarDialog = false
    @State private var avatarItem: PhotosPickerItem?
    @State private var toolRoute: String?

    private var monthlyGoal: Double {
        demo.isEnabled ? DemoCatalog.monthlyGoal : settings.monthGoal
    }

    private var monthRange: (start: Date, end: Date) {
        let cal = Calendar.current
        let now = Date()
        let start = cal.dateInterval(of: .month, for: now)?.start ?? now.startOfDay
        let end = cal.date(byAdding: .month, value: 1, to: start) ?? now
        return (start, end)
    }

    private var monthRevenue: Double {
        let r = monthRange
        return performances
            .filter { $0.date >= r.start && $0.date < r.end }
            .reduce(0) { $0 + $1.amount }
    }

    private var monthCount: Int {
        let r = monthRange
        return performances.filter { $0.date >= r.start && $0.date < r.end }.count
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                profileHero
                businessEntry
                personalSection
                businessSection
                demoSection
                toolsSection
                dataSection
                Text("v\(appVersion)")
                    .v32Text(.caption)
                    .foregroundStyle(V32.textQuaternary)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 4)
            }
            .padding(.horizontal, V32Layout.pageMargin)
            .padding(.top, 8)
            .padding(.bottom, V32Layout.bottomPad)
        }
        .scrollIndicators(.hidden)
        .v32PageBackground()
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(item: $toolRoute) { route in
            switch route {
            case "calendar": CalendarView()
            case "performance": PerformanceView()
            case "customer": CustomerView()
            case "expiry": ExpiryView()
            case "goods": GoodsView()
            default: EmptyView()
            }
        }
        .overlay(alignment: .bottom) {
            if let toast {
                Text(toast)
                    .v32Text(.subhead)
                    .foregroundStyle(V32.textPrimary)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 11)
                    .background(Capsule().fill(V32.card).shadow(color: Color.black.opacity(0.12), radius: 10, y: 4))
                    .padding(.bottom, 12)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .sheet(isPresented: $shopDialog) { ShopEditSheet() }
        .sheet(isPresented: $avatarDialog) { AvatarProfileSheet(settings: settings, selectedItem: $avatarItem) }
        .sheet(isPresented: $goalDialog) { GoalEditSheet() }
        .sheet(isPresented: $themeDialog) { ThemeChoiceSheet() }
        .sheet(isPresented: $voiceDialog) {
            VoiceSettingsSheet(showVoice: $showVoice, showsVoiceButton: showsVoiceButton)
        }
        .sheet(isPresented: $reminderDialog) { ReminderSettingsSheet(settings: settings) }
        .sheet(isPresented: $aboutDialog) { AboutSheet() }
        .sheet(isPresented: $privacyDialog) {
            InfoSheet(title: "隐私说明", text: "店铺、客户、商品和营业数据默认仅保存在本机 SwiftData 数据库。麦克风仅在你主动开始语音识别时使用；图片仅在你拍照或选择相册时读取。导出数据必须由你在系统分享面板中确认。")
        }
        .confirmationDialog("清理缓存？", isPresented: $clearDialog, titleVisibility: .visible) {
            Button("确认清理") {
                URLCache.shared.removeAllCachedResponses()
                showToast("缓存已清理")
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("仅删除图片加载缓存和临时文件，不会删除商品、待办、客户或营业额数据。")
        }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json]) { result in
            restore(from: result)
        }
    }

    // MARK: 个人头部

    private var profileHero: some View {
        Button { shopDialog = true } label: {
            V32HeroCard {
                HStack(spacing: 14) {
                    avatar(size: 56)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(DisplayText.visible(settings.ownerName, fallback: "老板"))
                            .v32Text(.section)
                            .foregroundStyle(V32.textOnHero)
                            .lineLimit(1)
                        Text("\(DisplayText.visible(settings.shopName, fallback: "我的小店")) · 你的小掌柜")
                            .v32Text(.subhead)
                            .foregroundStyle(V32.textOnHeroSecondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(V32.textOnHeroSecondary)
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: 经营数据入口

    private var businessEntry: some View {
        Button {
            Haptic.light()
            toolRoute = "performance"
        } label: {
            V32Card(fill: V32.cardElevated) {
                HStack(spacing: 14) {
                    V32IconBubble(systemName: "chart.bar.fill", tone: .brand, size: 44, icon: 20)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("经营数据")
                            .v32Text(.headline)
                            .foregroundStyle(V32.textPrimary)
                        Text("本月 ¥\(Fmt.groupedAmount(monthRevenue)) · \(monthCount) 笔")
                            .v32Text(.caption)
                            .foregroundStyle(V32.textTertiary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(V32.textQuaternary)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: V32Radius.card, style: .continuous)
                    .strokeBorder(V32.brand.opacity(0.25), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: 分组

    private var personalSection: some View {
        settingsGroup("个性化") {
            ProfileRow(icon: "person.crop.circle", tone: .neutral,
                       title: "头像与 Emoji",
                       value: settings.avatarImageData == nil ? settings.avatarEmoji : "照片") {
                avatarDialog = true
            }
            divider
            ProfileRow(icon: "circle.lefthalf.filled", tone: .info,
                       title: "显示模式", value: settings.themeModeLabel) {
                themeDialog = true
            }
        }
    }

    private var businessSection: some View {
        settingsGroup("经营") {
            ProfileRow(icon: "scope", tone: .brand,
                       title: "月营业目标", value: Fmt.groupedInt(monthlyGoal)) {
                goalDialog = true
            }
            divider
            ProfileRow(icon: "bell", tone: .amber,
                       title: "提醒设置",
                       value: (settings.todoReminderEnabled || settings.expiryReminderEnabled) ? "已开启" : "已关闭") {
                reminderDialog = true
            }
        }
    }

    @ViewBuilder
    private var demoSection: some View {
        settingsGroup("演示") {
            ProfileToggleRow(icon: "wand.and.stars", tone: .info, title: "Demo Mode", isOn: $demo.isEnabled)
            if demo.isEnabled {
                divider
                ProfileRow(icon: "arrow.clockwise", tone: .neutral, title: "重置演示数据", value: "独立内存", chevron: false) {
                    demo.resetDemoData()
                    showToast("演示数据已重置")
                }
            }
        }
    }

    private var toolsSection: some View {
        settingsGroup("工具") {
            ProfileRow(icon: "calendar", tone: .info, title: "日程") { toolRoute = "calendar" }
            divider
            ProfileRow(icon: "shippingbox", tone: .brand, title: "客户配送") { toolRoute = "customer" }
            divider
            ProfileRow(icon: "clock.badge.exclamationmark", tone: .amber, title: "临期商品") { toolRoute = "expiry" }
            divider
            ProfileRow(icon: "tag", tone: .neutral, title: "货品") { toolRoute = "goods" }
        }
    }

    private var dataSection: some View {
        settingsGroup("数据与应用") {
            ProfileRow(icon: "banknote", tone: .brand,
                       title: "营业额记录", value: "\(performances.count) 条") {
                toolRoute = "performance"
            }
            divider
            ShareLink(item: exportJSON(), preview: SharePreview("你的小掌柜数据导出")) {
                ProfileRowLabel(icon: "square.and.arrow.down", tone: .neutral,
                                title: "数据备份", value: "JSON", chevron: false)
            }
            divider
            ProfileRow(icon: "arrow.clockwise", tone: .neutral, title: "数据恢复", value: "JSON", chevron: false) {
                showImporter = true
            }
            divider
            ProfileRow(icon: "paintbrush", tone: .neutral, title: "清理缓存") { clearDialog = true }
            divider
            ProfileRow(icon: "info.circle", tone: .info, title: "关于你的小掌柜") { aboutDialog = true }
            divider
            ProfileRow(icon: "lock.shield", tone: .neutral, title: "隐私说明") { privacyDialog = true }
        }
    }

    private var divider: some View {
        Rectangle().fill(V32.divider).frame(height: 1).padding(.leading, 48)
    }

    private func settingsGroup<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .v32Text(.caption)
                .foregroundStyle(V32.textTertiary)
                .padding(.leading, 4)
            V32Card(padding: 4) {
                VStack(spacing: 0) { content() }
            }
        }
    }

    private func avatar(size: CGFloat) -> some View {
        Group {
            if let data = settings.avatarImageData, let image = UIImage(data: data) {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Text(settings.avatarEmoji).font(.system(size: size * 0.5))
            }
        }
        .frame(width: size, height: size)
        .background(Circle().fill(V32.brandOnHero.opacity(0.18)))
        .clipShape(Circle())
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    private func showToast(_ text: String) {
        withAnimation(.easeOut(duration: 0.2)) { toast = text }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation(.easeIn(duration: 0.25)) { toast = nil }
        }
    }

    /// 逐实体手工映射为 JSON（SwiftData @Model 不可直接 Codable，语义对齐 Android ProfileViewModel.exportJson）
    private func exportJSON() -> String {
        var records: [[String: Any]] = []
        func record(_ type: String, _ dict: [String: Any?]) {
            var d = dict
            d["type"] = type
            if let data = try? JSONSerialization.data(withJSONObject: d, options: []),
               let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                records.append(obj)
            }
        }
        todos.forEach { record("todo", ["title": $0.title, "detail": $0.detail, "dueDate": $0.dueDate.map { $0.timeIntervalSince1970 * 1000 }, "priority": $0.priority, "isCompleted": $0.isCompleted]) }
        memos.forEach { record("memo", ["title": $0.title, "content": $0.content]) }
        performances.forEach { record("performance", ["amount": $0.amount, "note": $0.note, "date": $0.date.timeIntervalSince1970 * 1000]) }
        expenses.forEach { record("expense", ["amount": $0.amount, "category": $0.category, "note": $0.note, "date": $0.date.timeIntervalSince1970 * 1000]) }
        expiryItems.forEach { record("expiry", ["name": $0.name, "category": $0.category, "quantity": $0.quantity, "expiryDate": $0.expiryDate.timeIntervalSince1970 * 1000, "returnStatus": $0.returnStatus]) }
        customers.forEach { record("customer", ["customer": $0.customer, "roomOrAddress": $0.roomOrAddress, "phone": $0.phone, "content": $0.content, "status": $0.status]) }
        goodsList.forEach { record("goods", ["name": $0.name, "barcode": $0.barcode, "purchasePrice": $0.purchasePrice, "salePrice": $0.salePrice, "category": $0.category, "stock": $0.stock]) }

        let payload: [String: Any] = [
            "app": "xiao-zhang-gui",
            "version": 1,
            "exportedAt": Date().timeIntervalSince1970 * 1000,
            "records": records,
        ]
        if let data = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted]),
           let json = String(data: data, encoding: .utf8) {
            return json
        }
        return "{}"
    }

    private func restore(from result: Result<URL, Error>) {
        guard case .success(let url) = result else { return }
        let secured = url.startAccessingSecurityScopedResource()
        defer { if secured { url.stopAccessingSecurityScopedResource() } }
        do {
            let raw = try Data(contentsOf: url)
            guard let payload = try JSONSerialization.jsonObject(with: raw) as? [String: Any],
                  let records = payload["records"] as? [[String: Any]] else {
                throw NSError(domain: "restore", code: -1, userInfo: [NSLocalizedDescriptionKey: "无法读取备份文件"])
            }
            var count = 0
            let repo = TodoRepository(context: context)
            for item in records {
                let str = { (key: String) in item[key] as? String ?? "" }
                let num = { (key: String) in (item[key] as? NSNumber)?.doubleValue ?? 0 }
                let date = { (key: String) in Date(timeIntervalSince1970: (num(key)) / 1000) }
                switch str("type") {
                case "todo":
                    try repo.add(title: str("title"), detail: str("detail"), dueDate: item["dueDate"] != nil ? date("dueDate") : nil, priority: Int(num("priority")))
                case "memo":
                    try MemoRepository(context: context).add(title: str("title"), content: str("content"))
                case "performance":
                    try PerformanceRepository(context: context).add(amount: num("amount"), note: str("note"), date: date("date"))
                case "expense":
                    try ExpenseRepository(context: context).add(amount: num("amount"), category: str("category"), note: str("note"), date: date("date"))
                case "expiry":
                    try ExpiryRepository(context: context).add(name: str("name"), category: str("category"), quantity: Int(num("quantity")), expiryDate: date("expiryDate"))
                case "customer":
                    try CustomerRepository(context: context).add(customer: str("customer"), roomOrAddress: str("roomOrAddress"), phone: str("phone"), content: str("content"))
                case "goods":
                    try GoodsRepository(context: context).add(Goods(
                        name: str("name"),
                        category: str("category").isEmpty ? "其他" : str("category"),
                        barcode: str("barcode"),
                        stock: Int(num("stock")),
                        purchasePrice: num("purchasePrice"),
                        salePrice: num("salePrice")
                    ))
                default: continue
                }
                count += 1
            }
            Haptic.success()
            showToast("已恢复 \(count) 条记录")
            SnapshotSyncManager.refreshAll(context: context)
        } catch {
            showToast("恢复失败：\(error.localizedDescription)")
        }
    }
}

// MARK: - 设置行

private struct ProfileRow: View {
    let icon: String
    var tone: V32BubbleTone = .neutral
    let title: String
    var value: String = ""
    var chevron: Bool = true
    let action: () -> Void

    var body: some View {
        Button {
            Haptic.light()
            action()
        } label: {
            ProfileRowLabel(icon: icon, tone: tone, title: title, value: value, chevron: chevron)
        }
        .buttonStyle(.plain)
    }
}

struct ProfileRowLabel: View {
    let icon: String
    var tone: V32BubbleTone = .neutral
    let title: String
    var value: String = ""
    var chevron: Bool = true

    var body: some View {
        HStack(spacing: 12) {
            V32IconBubble(systemName: icon, tone: tone, size: 34, icon: 15)
            Text(title)
                .v32Text(.title)
                .foregroundStyle(V32.textPrimary)
                .lineLimit(1)
            Spacer(minLength: 8)
            if !value.isEmpty {
                Text(value)
                    .v32Text(.caption)
                    .foregroundStyle(V32.textTertiary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            if chevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(V32.textQuaternary)
            }
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 54)
        .contentShape(Rectangle())
    }
}

private struct ProfileToggleRow: View {
    let icon: String
    var tone: V32BubbleTone = .neutral
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 12) {
            V32IconBubble(systemName: icon, tone: tone, size: 34, icon: 15)
            Text(title)
                .v32Text(.title)
                .foregroundStyle(V32.textPrimary)
            Spacer()
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(V32.brand)
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 54)
    }
}

// MARK: - V32 Sheet 容器

private struct V32SheetChrome<Content: View>: View {
    let title: String
    var detents: Set<PresentationDetent> = [.medium]
    var doneTitle: String = "完成"
    let onDone: (() -> Void)?
    @ViewBuilder var content: Content

    init(_ title: String,
         detents: Set<PresentationDetent> = [.medium],
         doneTitle: String = "完成",
         onDone: (() -> Void)? = nil,
         @ViewBuilder content: () -> Content) {
        self.title = title
        self.detents = detents
        self.doneTitle = doneTitle
        self.onDone = onDone
        self.content = content()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ZStack {
                    Text(title)
                        .v32Text(.headline)
                        .foregroundStyle(V32.textPrimary)
                    HStack {
                        Spacer()
                        if let onDone {
                            Button(doneTitle, action: onDone)
                                .v32Text(.body)
                                .foregroundStyle(V32.brand)
                        }
                    }
                }
                content
            }
            .padding(.horizontal, V32Layout.pageMargin)
            .padding(.top, 14)
            .padding(.bottom, V32Layout.bottomPad)
        }
        .scrollIndicators(.hidden)
        .v32PageBackground()
        .v32Sheet(detents)
    }
}

// MARK: - 个人资料

private struct ShopEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    private let settings = AppSettings.shared
    @State private var shopName = ""
    @State private var ownerName = ""

    private var canSave: Bool {
        !shopName.trimmingCharacters(in: .whitespaces).isEmpty
        && !ownerName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        V32SheetChrome("个人资料") {
            V32Card {
                VStack(alignment: .leading, spacing: 12) {
                    TextField("店铺名称", text: $shopName)
                        .v32Text(.headline)
                        .foregroundStyle(V32.textPrimary)
                        .tint(V32.brand)
                    Rectangle().fill(V32.divider).frame(height: 1)
                    TextField("店主称呼", text: $ownerName)
                        .v32Text(.body)
                        .foregroundStyle(V32.textSecondary)
                        .tint(V32.brand)
                }
            }
            V32PrimaryButton(title: "保存", systemName: "checkmark") { save() }
                .disabled(!canSave)
                .opacity(canSave ? 1 : 0.5)
            Button("取消") { dismiss() }
                .v32Text(.body)
                .foregroundStyle(V32.textTertiary)
                .frame(maxWidth: .infinity)
        }
        .onAppear { shopName = settings.shopName; ownerName = settings.ownerName }
    }

    private func save() {
        let s = shopName.trimmingCharacters(in: .whitespaces)
        let o = ownerName.trimmingCharacters(in: .whitespaces)
        guard !s.isEmpty, !o.isEmpty else { return }
        settings.shopName = s
        settings.ownerName = o
        Haptic.success()
        dismiss()
    }
}

// MARK: - 月目标

private struct GoalEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    private let settings = AppSettings.shared
    @State private var text = ""

    private var canSave: Bool { (Double(text) ?? 0) > 0 }

    var body: some View {
        V32SheetChrome("月营业目标") {
            V32Card {
                HStack(spacing: 8) {
                    Text("¥").v32Text(.headline).foregroundStyle(V32.textSecondary)
                    TextField("目标金额", text: $text)
                        .v32Text(.headline)
                        .foregroundStyle(V32.textPrimary)
                        .tint(V32.brand)
                        .keyboardType(.decimalPad)
                }
            }
            V32PrimaryButton(title: "保存", systemName: "checkmark") {
                if let value = Double(text), value > 0 {
                    settings.monthGoal = value
                    Haptic.success()
                    dismiss()
                }
            }
            .disabled(!canSave)
            .opacity(canSave ? 1 : 0.5)
            Button("取消") { dismiss() }
                .v32Text(.body)
                .foregroundStyle(V32.textTertiary)
                .frame(maxWidth: .infinity)
        }
        .onAppear { text = String(Int(settings.monthGoal)) }
    }
}

// MARK: - 提醒

private struct ReminderSettingsSheet: View {
    @Bindable var settings: AppSettings
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        V32SheetChrome("提醒设置", onDone: { dismiss() }) {
            V32Card(padding: 4) {
                VStack(spacing: 0) {
                    ProfileToggleRow(icon: "bell", tone: .brand, title: "待办提醒", isOn: $settings.todoReminderEnabled)
                    Rectangle().fill(V32.divider).frame(height: 1).padding(.leading, 48)
                    ProfileToggleRow(icon: "clock.badge.exclamationmark", tone: .amber, title: "临期退货提醒", isOn: $settings.expiryReminderEnabled)
                }
            }
        }
    }
}

// MARK: - 头像

private struct AvatarProfileSheet: View {
    @Bindable var settings: AppSettings
    @Binding var selectedItem: PhotosPickerItem?
    @Environment(\.dismiss) private var dismiss
    private let emojis = ["👨🏻‍💼", "👩🏻‍💼", "🧑🏻‍🍳", "😎", "🐱", "🐼", "🏪", "☕️"]
    var body: some View {
        V32SheetChrome("个性头像", doneTitle: "关闭", onDone: { dismiss() }) {
            V32Card {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 14) {
                    ForEach(emojis, id: \.self) { emoji in
                        Button {
                            settings.avatarEmoji = emoji
                            settings.avatarImageData = nil
                            Haptic.light()
                            dismiss()
                        } label: {
                            Text(emoji)
                                .font(.system(size: 30))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Circle().fill(V32.pageBGSecondary))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            PhotosPicker(selection: $selectedItem, matching: .images) {
                Label("从相册选择头像", systemImage: "photo.on.rectangle")
                    .v32Text(.body)
                    .foregroundStyle(V32.brand)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(Capsule().fill(V32.brandSoft))
            }
            .onChange(of: selectedItem) { _, item in
                Task {
                    if let data = try? await item?.loadTransferable(type: Data.self) {
                        settings.avatarImageData = data
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - 显示模式

private struct ThemeChoiceSheet: View {
    @Environment(\.dismiss) private var dismiss
    private let settings = AppSettings.shared
    private let options: [(key: String, label: String, icon: String)] = [
        ("system", "跟随系统", "circle.lefthalf.filled"),
        ("light", "浅色模式", "sun.max"),
        ("dark", "深色模式", "moon.stars"),
    ]

    var body: some View {
        V32SheetChrome("显示模式", doneTitle: "关闭", onDone: { dismiss() }) {
            V32Card(padding: 4) {
                VStack(spacing: 0) {
                    ForEach(Array(options.enumerated()), id: \.element.key) { index, option in
                        if index > 0 { Rectangle().fill(V32.divider).frame(height: 1).padding(.leading, 48) }
                        Button {
                            settings.themeMode = option.key
                            Haptic.light()
                            dismiss()
                        } label: {
                            HStack(spacing: 12) {
                                V32IconBubble(systemName: option.icon, tone: .info, size: 34, icon: 15)
                                Text(option.label)
                                    .v32Text(.title)
                                    .foregroundStyle(V32.textPrimary)
                                Spacer()
                                if settings.themeMode == option.key {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(V32.brand)
                                }
                            }
                            .padding(.horizontal, 12)
                            .frame(minHeight: 54)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

// MARK: - 语音设置

private struct VoiceSettingsSheet: View {
    @Binding var showVoice: Bool
    let showsVoiceButton: Bool
    @Environment(\.dismiss) private var dismiss
    @Bindable private var settings = AppSettings.shared

    var body: some View {
        V32SheetChrome("语音输入设置", onDone: { dismiss() }) {
            VStack(alignment: .leading, spacing: 12) {
                Text("识别语言")
                    .v32Text(.caption)
                    .foregroundStyle(V32.textTertiary)
                    .padding(.leading, 4)
                V32SegmentedPicker(
                    tabs: ["普通话", "粤语"],
                    selectionIndex: Binding(
                        get: { settings.voiceLanguage == "粤语" ? 1 : 0 },
                        set: { settings.voiceLanguage = $0 == 1 ? "粤语" : "普通话" }
                    )
                )
            }
            V32Card {
                Text("语音识别由系统提供，录音仅用于实时识别，不会保存音频。")
                    .v32Text(.caption)
                    .foregroundStyle(V32.textTertiary)
            }
            if showsVoiceButton {
                V32PrimaryButton(title: "测试语音", systemName: "mic.fill") {
                    dismiss()
                    showVoice = true
                }
            }
        }
    }
}

// MARK: - 关于

private struct AboutSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                Spacer(minLength: 24)
                V32IconBubble(systemName: "storefront", tone: .brand, size: 64, icon: 28)
                Text("你的小掌柜")
                    .v32Text(.section)
                    .foregroundStyle(V32.textPrimary)
                Text("v\(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "3.0.2")")
                    .v32Text(.caption)
                    .foregroundStyle(V32.textTertiary)
                V32Card {
                    Text("本次更新：UI 精修 · 语音界面紧凑化 · 长列表安全区优化")
                        .v32Text(.subhead)
                        .foregroundStyle(V32.textSecondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }
                Spacer(minLength: 8)
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(V32.textQuaternary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("关闭")
            }
            .padding(.horizontal, V32Layout.pageMargin)
            .padding(.bottom, V32Layout.bottomPad)
        }
        .scrollIndicators(.hidden)
        .v32PageBackground()
        .v32Sheet([.height(320)])
    }
}

// MARK: - 信息说明

private struct InfoSheet: View {
    let title: String
    let text: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        V32SheetChrome(title, doneTitle: "关闭", onDone: { dismiss() }) {
            V32Card {
                Text(text)
                    .v32Text(.subhead)
                    .foregroundStyle(V32.textSecondary)
            }
        }
    }
}
