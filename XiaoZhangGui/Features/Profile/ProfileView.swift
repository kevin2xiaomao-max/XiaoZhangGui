import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import PhotosUI

// MARK: - 我的 / 设置（对齐 Android ProfileScreen：Hero + 月度双卡 + 分组设置 + 对话框）

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

    private var monthStart: Date {
        Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: Date())) ?? Date()
    }
    private var monthlyRevenue: Double {
        if demo.isEnabled { return DemoCatalog.monthlyRevenue }
        return performances.filter { $0.date >= monthStart }.reduce(0) { $0 + $1.amount }
    }
    private var monthlyGoal: Double {
        demo.isEnabled ? DemoCatalog.monthlyGoal : settings.monthGoal
    }
    private var goalProgress: Double {
        guard monthlyGoal > 0 else { return 0 }
        return min(max(monthlyRevenue / monthlyGoal, 0), 1)
    }

    var body: some View {
        List {
            // MARK: Hero（头像 + 店主名 + 店铺名）
            Section {
                heroCard
                    .padding(.vertical, 4)
                    .listRowInsets(EdgeInsets(top: 12, leading: 18, bottom: 12, trailing: 18))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }

            Section("个性化") {
                SettingRow(icon: "person.crop.circle", label: "头像与 Emoji", value: settings.avatarImageData == nil ? settings.avatarEmoji : "照片", isLast: false) { avatarDialog = true }
                SettingRow(icon: "paintpalette", label: "主题颜色", value: settings.appThemeName, isLast: false) { themeDialog = true }
                SettingRow(icon: "circle.lefthalf.filled", label: "显示模式", value: settings.themeModeLabel, isLast: true) { themeDialog = true }
            }

            Section("经营") {
                SettingRow(icon: "scope", label: "月营业目标", value: Fmt.groupedInt(monthlyGoal), isLast: false) { goalDialog = true }
                SettingRow(icon: "bell", label: "提醒设置", value: (settings.todoReminderEnabled || settings.expiryReminderEnabled) ? "已开启" : "已关闭", isLast: true) { reminderDialog = true }
            }

            Section("演示") {
                SwitchRow(label: "Demo Mode", isLast: !demo.isEnabled, binding: $demo.isEnabled)
                if demo.isEnabled {
                    SettingRow(icon: "arrow.clockwise", label: "重置演示数据", value: "独立内存", isLast: true) {
                        demo.resetDemoData()
                        showToast("演示数据已重置")
                    }
                }
            }

            Section("工具") {
                SettingRow(icon: "calendar", label: "日历", value: "", isLast: false) { toolRoute = "calendar" }
                SettingRow(icon: "shippingbox", label: "客户配送", value: "", isLast: false) { toolRoute = "customer" }
                SettingRow(icon: "clock.badge.exclamationmark", label: "临时商品", value: "", isLast: false) { toolRoute = "expiry" }
                SettingRow(icon: "tag", label: "货品", value: "", isLast: true) { toolRoute = "goods" }
            }

            Section("数据与应用") {
                SettingRow(icon: "banknote", label: "营业额记录", value: "\(performances.count) 条", isLast: false) { tab = .performance }
                ShareLink(item: exportJSON(), preview: SharePreview("你的小掌柜数据导出")) {
                    SettingRowCore(icon: "square.and.arrow.down", label: "数据备份", value: "JSON", showChevron: false, isLast: false)
                }
                .buttonStyle(.plain)
                SettingRow(icon: "arrow.clockwise", label: "数据恢复", value: "JSON", isLast: false) { showImporter = true }
                SettingRow(icon: "paintbrush", label: "清理缓存", value: "", isLast: false) { clearDialog = true }
                SettingRow(icon: "info.circle", label: "关于你的小掌柜", value: "", isLast: false) { aboutDialog = true }
                SettingRow(icon: "lock.shield", label: "隐私说明", value: "", isLast: true) { privacyDialog = true }
            }

            Section {
                Text("v\(appVersion)")
                    .v21Style(.labelSmall)
                    .foregroundColor(V21.textQuaternary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 12)
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(V21.background.ignoresSafeArea())
        .navigationTitle("我的")
        .navigationBarTitleDisplayMode(.large)
        .navigationDestination(item: $toolRoute) { route in
            switch route {
            case "calendar": CalendarView()
            case "customer": CustomerView()
            case "expiry": ExpiryView()
            case "goods": GoodsView()
            default: EmptyView()
            }
        }
        .overlay(alignment: .bottom) {
            if let toast {
                Text(toast)
                    .v21Style(.labelLarge)
                    .foregroundColor(V21.textPrimary)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 11)
                    .background(Capsule().fill(.ultraThinMaterial))
                    .overlay(Capsule().strokeBorder(V21.dividerStrong, lineWidth: 1))
                    .padding(.bottom, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        // 对话框
        .sheet(isPresented: $shopDialog) { ShopEditSheet() }
        .sheet(isPresented: $avatarDialog) { AvatarProfileSheet(settings: settings, selectedItem: $avatarItem) }
        .sheet(isPresented: $goalDialog) { GoalEditSheet() }
        .sheet(isPresented: $themeDialog) { ThemeChoiceSheet() }
        .sheet(isPresented: $voiceDialog) {
            VoiceSettingsSheet(
                showVoice: $showVoice,
                showsVoiceButton: showsVoiceButton
            )
        }
        .sheet(isPresented: $reminderDialog) { ReminderSettingsSheet(settings: settings) }
        .sheet(isPresented: $aboutDialog) { AboutSheet() }
        .sheet(isPresented: $privacyDialog) { InfoSheet(title: "隐私说明", text: "店铺、客户、商品和营业数据默认仅保存在本机 SwiftData 数据库。麦克风仅在你主动开始语音识别时使用；图片仅在你拍照或选择相册时读取。导出数据必须由你在系统分享面板中确认。") }
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

    // MARK: - 品牌 Hero

    private var heroCard: some View {
        HStack(spacing: 16) {
            Button { avatarDialog = true } label: {
                Group {
                    if let data = settings.avatarImageData, let image = UIImage(data: data) { Image(uiImage: image).resizable().aspectRatio(contentMode: .fill) }
                    else { Text(settings.avatarEmoji).font(.system(size: 31)).frame(maxWidth: .infinity, maxHeight: .infinity) }
                }.frame(width: 62, height: 62).background(AppTheme.palette(named: settings.appThemeName).accent.opacity(0.13), in: Circle()).clipShape(Circle()).overlay(Circle().stroke(AppTheme.palette(named: settings.appThemeName).accent.opacity(0.28), lineWidth: 1))
            }.buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text(settings.ownerName)
                    .font(AppTypography.cardTitle)
                    .foregroundColor(V21.textPrimary)
                Text("\(settings.shopName) · 你的小掌柜")
                    .font(AppTypography.body)
                    .foregroundColor(V21.textTertiary)
            }
            Spacer()
            Button {
                Haptic.light()
                shopDialog = true
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(V21.textQuaternary)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture { shopDialog = true }
    }

    // MARK: - 本月数据双卡片

    private var monthCards: some View {
        HStack(spacing: 12) {
            GlassSurface(radius: 16) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("本月营业额")
                        .v21Style(.labelMedium)
                        .foregroundColor(V21.textTertiary)
                    Text("¥\(Fmt.groupedInt(monthlyRevenue))")
                        .v21Style(.titleSection)
                        .foregroundColor(V21.textPrimary)
                        .padding(.top, 8)
                    Text("查看详情")
                        .v21Style(.labelSmall)
                        .foregroundColor(V21.brandGreen)
                        .padding(.top, 4)
                        .onTapGesture { tab = .performance }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            GlassSurface(radius: 16) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("月目标完成")
                        .v21Style(.labelMedium)
                        .foregroundColor(V21.textTertiary)
                    HStack(alignment: .bottom, spacing: 0) {
                        Text("\(Int((goalProgress * 100).rounded()))")
                            .v21Style(.titleSection)
                            .foregroundColor(V21.brandGreen)
                        Text("%")
                            .v21Style(.labelLarge)
                            .foregroundColor(V21.brandGreen)
                            .padding(.bottom, 3)
                    }
                    .padding(.top, 8)
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(V21.divider)
                            Capsule()
                                .fill(V21.brandGreen)
                                .frame(width: geo.size.width * goalProgress)
                        }
                    }
                    .frame(height: 4)
                    .padding(.top, 10)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.top, 20)
        .padding(.horizontal, V21Layout.pageMargin)
    }

    // MARK: - 工具

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

// MARK: - 设置行（List 行：系统自动提供分割线与 Liquid Glass 背景）

private struct SettingRow: View {
    let icon: String
    let label: String
    var value: String = ""
    var isLast: Bool
    var action: () -> Void

    var body: some View {
        Button {
            Haptic.light()
            action()
        } label: {
            SettingRowCore(icon: icon, label: label, value: value, showChevron: true, isLast: isLast)
        }
        .buttonStyle(.plain)
    }
}

private struct SettingRowCore: View {
    @Environment(AppSettings.self) private var settings
    let icon: String
    let label: String
    var value: String
    var showChevron: Bool
    var isLast: Bool

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(V21.surfacePrimary)
                .frame(width: 36, height: 36)
                .overlay {
                    Image(systemName: icon)
                        .font(.system(size: 15))
                        .foregroundColor(AppTheme.palette(named: settings.appThemeName).accent)
                }
            Text(label)
                .v21Style(.bodyLarge)
                .foregroundColor(V21.textPrimary)
            Spacer()
            if !value.isEmpty {
                Text(value)
                    .v21Style(.bodySmall)
                    .foregroundColor(V21.textTertiary)
                    .padding(.trailing, 4)
            }
            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(V21.textQuaternary)
            }
        }
        .padding(.vertical, 10)
    }
}

// MARK: - Switch 行

private struct SwitchRow: View {
    let label: String
    var isLast: Bool
    @Binding var binding: Bool

    var body: some View {
        HStack {
            Text(label)
                .v21Style(.bodyLarge)
                .foregroundColor(V21.textPrimary)
            Spacer()
            Toggle("", isOn: $binding)
                .labelsHidden()
                .tint(V21.brandGreen)
        }
        .padding(.vertical, 8)
    }
}

// MARK: - 店铺信息编辑

private struct ShopEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    private let settings = AppSettings.shared
    @State private var shopName = ""
    @State private var ownerName = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Button("取消") { dismiss() }
                Spacer()
                Text("个人资料").v21Style(.titleLarge)
                Spacer()
                Button("保存") {
                    let s = shopName.trimmingCharacters(in: .whitespaces)
                    let o = ownerName.trimmingCharacters(in: .whitespaces)
                    guard !s.isEmpty, !o.isEmpty else { return }
                    settings.shopName = s
                    settings.ownerName = o
                    Haptic.success()
                    dismiss()
                }
                .fontWeight(.semibold)
                .foregroundColor(!shopName.trimmingCharacters(in: .whitespaces).isEmpty && !ownerName.trimmingCharacters(in: .whitespaces).isEmpty ? V21.brandGreen : V21.textQuaternary)
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("店铺名称").v21Style(.labelMedium).foregroundColor(V21.textTertiary)
                TextField("店铺名称", text: $shopName)
                    .textFieldStyle(.plain)
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 12).fill(V21.surfacePrimary))
                    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(V21.dividerStrong, lineWidth: 1))
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("店主称呼").v21Style(.labelMedium).foregroundColor(V21.textTertiary)
                TextField("店主称呼", text: $ownerName)
                    .textFieldStyle(.plain)
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 12).fill(V21.surfacePrimary))
                    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(V21.dividerStrong, lineWidth: 1))
            }
            Spacer()
        }
        .padding(24)
        .background(V21.background.ignoresSafeArea())
        .onAppear { shopName = settings.shopName; ownerName = settings.ownerName }
        .preferredColorScheme(AppSettings.shared.colorScheme)
    }
}

// MARK: - 月目标编辑

private struct GoalEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    private let settings = AppSettings.shared
    @State private var text = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Button("取消") { dismiss() }
                Spacer()
                Text("月营业目标").v21Style(.titleLarge)
                Spacer()
                Button("保存") {
                    if let value = Double(text), value > 0 {
                        settings.monthGoal = value
                        Haptic.success()
                        dismiss()
                    }
                }
                .fontWeight(.semibold)
                .foregroundColor((Double(text) ?? 0) > 0 ? V21.brandGreen : V21.textQuaternary)
            }
            TextField("目标金额", text: $text)
                .keyboardType(.decimalPad)
                .textFieldStyle(.plain)
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 12).fill(V21.surfacePrimary))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(V21.dividerStrong, lineWidth: 1))
            Spacer()
        }
        .padding(24)
        .background(V21.background.ignoresSafeArea())
        .onAppear { text = String(Int(settings.monthGoal)) }
        .preferredColorScheme(AppSettings.shared.colorScheme)
    }
}

private struct ReminderSettingsSheet: View {
    @Bindable var settings: AppSettings
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack { Text("提醒设置").font(AppTypography.pageTitle); Spacer(); Button("完成") { dismiss() }.foregroundColor(AppTheme.palette(named: settings.appThemeName).accent) }
            Toggle("待办提醒", isOn: $settings.todoReminderEnabled)
            Toggle("临期退货提醒", isOn: $settings.expiryReminderEnabled)
            Spacer()
        }.padding(24).background(V21.background.ignoresSafeArea()).tint(AppTheme.palette(named: settings.appThemeName).accent)
    }
}

private struct AvatarProfileSheet: View {
    @Bindable var settings: AppSettings
    @Binding var selectedItem: PhotosPickerItem?
    @Environment(\.dismiss) private var dismiss
    private let emojis = ["👨🏻‍💼", "👩🏻‍💼", "🧑🏻‍🍳", "😎", "🐱", "🐼", "🏪", "☕️"]
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("个性头像").font(AppTypography.pageTitle).foregroundColor(V21.textPrimary)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 14) {
                ForEach(emojis, id: \.self) { emoji in
                    Button { settings.avatarEmoji = emoji; settings.avatarImageData = nil; dismiss() } label: { Text(emoji).font(.system(size: 30)).frame(maxWidth: .infinity).padding(.vertical, 10).background(V21.surfaceGlass, in: RoundedRectangle(cornerRadius: 14)) }.buttonStyle(.plain)
                }
            }
            PhotosPicker(selection: $selectedItem, matching: .images) { Label("从相册选择头像", systemImage: "photo.on.rectangle").font(AppTypography.bodyMedium).foregroundColor(AppTheme.palette(named: settings.appThemeName).accent).frame(maxWidth: .infinity, alignment: .leading) }
                .onChange(of: selectedItem) { _, item in Task { if let data = try? await item?.loadTransferable(type: Data.self) { settings.avatarImageData = data; dismiss() } } }
            Spacer()
        }.padding(24).background(V21.background.ignoresSafeArea())
    }
}

// MARK: - 显示模式选择

private struct ThemeChoiceSheet: View {
    @Environment(\.dismiss) private var dismiss
    private let settings = AppSettings.shared

    private let options: [(key: String, label: String)] = [
        ("system", "跟随系统"), ("light", "浅色模式"), ("dark", "深色模式"),
    ]
    private let themeOptions = AppTheme.all

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("显示模式")
                .v21Style(.titleLarge)
                .padding(.bottom, 12)
            ForEach(options, id: \.key) { option in
                Button {
                    settings.themeMode = option.key
                    Haptic.light()
                    dismiss()
                } label: {
                    HStack {
                        Text(option.label)
                            .v21Style(.bodyLarge)
                            .foregroundColor(V21.textPrimary)
                        Spacer()
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(settings.themeMode == option.key ? V21.brandGreen : .clear)
                    }
                    .padding(.vertical, 12)
                }
                .buttonStyle(.plain)
            }
            Divider().padding(.vertical, 8)
            Text("外观与主题").v21Style(.titleLarge).padding(.bottom, 8)
            ForEach(themeOptions, id: \.name) { option in
                Button {
                    settings.appThemeName = option.name
                    Haptic.light()
                } label: {
                    HStack(spacing: 12) {
                        Capsule().fill(option.heroGradient).frame(width: 42, height: 22)
                        Text("\(option.name)\(option.name == "Blue Purple" ? "｜蓝紫" : option.name == "Graphite" ? "｜石墨黑" : option.name == "Glacier Blue" ? "｜冰川蓝" : option.name == "Emerald" ? "｜翡翠绿" : "｜珊瑚")").v21Style(.bodyLarge).foregroundColor(V21.textPrimary)
                        Spacer()
                        Image(systemName: "checkmark").font(.system(size: 14, weight: .semibold)).foregroundColor(settings.appThemeName == option.name ? option.accent : .clear)
                    }.padding(.vertical, 9)
                }.buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(24)
        .background(V21.background.ignoresSafeArea())
        .preferredColorScheme(AppSettings.shared.colorScheme)
    }
}

// MARK: - 语音设置

private struct VoiceSettingsSheet: View {
    @Binding var showVoice: Bool
    let showsVoiceButton: Bool
    @Environment(\.dismiss) private var dismiss
    @Bindable private var settings = AppSettings.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("语音输入设置").v21Style(.titleLarge)
            VStack(alignment: .leading, spacing: 6) {
                Text("识别语言").v21Style(.labelMedium).foregroundColor(V21.textTertiary)
                Picker("识别语言", selection: $settings.voiceLanguage) {
                    Text("普通话").tag("普通话")
                    Text("粤语").tag("粤语")
                }
                .pickerStyle(.segmented)
            }
            Text("语音识别由系统提供，录音仅用于实时识别，不会保存音频。")
                .v21Style(.bodySmall)
                .foregroundColor(V21.textTertiary)
            if showsVoiceButton {
                if #available(iOS 26.0, *) {
                    // iOS 26+: Liquid Glass prominent 按钮
                    Button {
                        dismiss()
                        showVoice = true
                    } label: {
                        Text("测试语音")
                            .v21Style(.labelLarge)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                    }
                    .buttonStyle(.glassProminent)
                    .tint(AppTheme.palette(named: settings.appThemeName).accent)
                } else {
                    // iOS 18+: 自绘品牌渐变按钮
                    Button {
                        dismiss()
                        showVoice = true
                    } label: {
                        Text("测试语音")
                            .v21Style(.labelLarge)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(RoundedRectangle(cornerRadius: 14).fill(V21.brandGreenGradient))
                    }
                    .buttonStyle(.plain)
                }
            }
            Spacer()
        }
        .padding(24)
        .background(V21.background.ignoresSafeArea())
        .preferredColorScheme(AppSettings.shared.colorScheme)
    }
}

// MARK: - 关于

private struct AboutSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(V21.brandGreen.opacity(0.12))
                        .frame(width: 72, height: 72)
                        .overlay {
                            Image(systemName: "storefront")
                                .font(.system(size: 34))
                                .foregroundColor(V21.brandGreen)
                        }
                    Text("你的小掌柜").v21Style(.titleLarge)
                    Text("v\(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "3.0.0")")
                        .v21Style(.bodyMedium)
                        .foregroundColor(V21.textTertiary)
                    Text("生意好帮手，经营管理更轻松")
                        .v21Style(.bodyMedium)
                        .foregroundColor(V21.textSecondary)
                        .padding(.bottom, 12)

                    aboutSection("本次更新 3.0", rows: [
                        "扫呗 CSV / Excel 导入，重复账单自动跳过",
                        "业绩支持日 / 周 / 月趋势",
                        "一句话快速记录，写入现有模块",
                        "今日汇总与经营日报",
                        "首页 / 业绩 / 待办改用系统列表",
                    ], bullet: true)

                    aboutSection("历史版本", rows: ["V1.1.0", "V1.0.3", "V1.0.2", "V1.0.1", "V1.0.0"])
                }
                .padding(.horizontal, V21Layout.pageMargin)
                .padding(.top, V21Layout.spaceXL)
                .padding(.bottom, 32)
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("关闭") { dismiss() }
                        .foregroundColor(V21.brandGreen)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .background(V21.background.ignoresSafeArea())
        .preferredColorScheme(AppSettings.shared.colorScheme)
    }

    private func aboutSection(_ title: String, rows: [String], bullet: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .v21Style(.titleMedium)
                .foregroundColor(V21.textPrimary)
            ForEach(rows, id: \.self) { row in
                Text(bullet ? "• \(row)" : row)
                    .v21Style(.bodyMedium)
                    .foregroundColor(V21.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: V21Layout.radiusLG, style: .continuous)
                .fill(V21.surfaceGlass)
        }
    }
}

// MARK: - 通用信息弹窗

private struct InfoSheet: View {
    let title: String
    let text: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title).v21Style(.titleLarge)
            Text(text)
                .v21Style(.bodyMedium)
                .foregroundColor(V21.textSecondary)
            Spacer()
            Button("关闭") { dismiss() }
                .v21Style(.labelLarge)
                .foregroundColor(V21.brandGreen)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(24)
        .background(V21.background.ignoresSafeArea())
        .preferredColorScheme(AppSettings.shared.colorScheme)
    }
}
