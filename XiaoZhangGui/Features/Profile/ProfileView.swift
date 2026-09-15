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

    private var monthlyGoal: Double {
        demo.isEnabled ? DemoCatalog.monthlyGoal : settings.monthGoal
    }

    var body: some View {
        List {
            Section {
                Button { shopDialog = true } label: {
                    HStack(spacing: 14) {
                        shopAvatar
                        VStack(alignment: .leading, spacing: 3) {
                            Text(settings.ownerName)
                                .font(.headline)
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                            Text("\(settings.shopName) · 你的小掌柜")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Spacer(minLength: 8)
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }

            Section("个性化") {
                settingsButton("person.crop.circle", "头像与 Emoji", settings.avatarImageData == nil ? settings.avatarEmoji : "照片") { avatarDialog = true }
                settingsButton("circle.lefthalf.filled", "显示模式", settings.themeModeLabel) { themeDialog = true }
            }

            Section("经营") {
                settingsButton("scope", "月营业目标", Fmt.groupedInt(monthlyGoal)) { goalDialog = true }
                settingsButton("bell", "提醒设置", (settings.todoReminderEnabled || settings.expiryReminderEnabled) ? "已开启" : "已关闭") { reminderDialog = true }
            }

            Section("演示") {
                Toggle("Demo Mode", isOn: $demo.isEnabled)
                    .tint(V21.brandGreen)
                if demo.isEnabled {
                    Button {
                        demo.resetDemoData()
                        showToast("演示数据已重置")
                    } label: {
                        settingsLabel("arrow.clockwise", "重置演示数据", "独立内存")
                    }
                    .buttonStyle(.plain)
                }
            }

            Section("工具") {
                settingsButton("calendar", "日历", "") { toolRoute = "calendar" }
                settingsButton("shippingbox", "客户配送", "") { toolRoute = "customer" }
                settingsButton("clock.badge.exclamationmark", "临期商品", "") { toolRoute = "expiry" }
                settingsButton("tag", "货品", "") { toolRoute = "goods" }
            }

            Section("数据与应用") {
                settingsButton("banknote", "营业额记录", "\(performances.count) 条") { toolRoute = "performance" }
                ShareLink(item: exportJSON(), preview: SharePreview("你的小掌柜数据导出")) {
                    settingsLabel("square.and.arrow.down", "数据备份", "JSON")
                }
                settingsButton("arrow.clockwise", "数据恢复", "JSON") { showImporter = true }
                settingsButton("paintbrush", "清理缓存", "") { clearDialog = true }
                settingsButton("info.circle", "关于你的小掌柜", "") { aboutDialog = true }
                settingsButton("lock.shield", "隐私说明", "") { privacyDialog = true }
            }

            Section {
                Text("v\(appVersion)")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .listRowBackground(Color.clear)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .bottomDockPadding()
        .navigationTitle("我的")
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
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial, in: Capsule())
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

    private var shopAvatar: some View {
        Group {
            if let data = settings.avatarImageData, let image = UIImage(data: data) {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Text(settings.avatarEmoji).font(.title2)
            }
        }
        .frame(width: 52, height: 52)
        .background(V21.brandGreen.opacity(0.12), in: Circle())
        .clipShape(Circle())
    }

    private func settingsButton(_ icon: String, _ title: String, _ value: String, action: @escaping () -> Void) -> some View {
        Button {
            Haptic.light()
            action()
        } label: {
            settingsLabel(icon, title, value)
        }
        .buttonStyle(.plain)
    }

    private func settingsLabel(_ icon: String, _ title: String, _ value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(V21.brandGreen)
                .frame(width: 22)
            Text(title)
                .foregroundStyle(.primary)
                .lineLimit(1)
            Spacer(minLength: 8)
            if !value.isEmpty {
                Text(value)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
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

private struct ShopEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    private let settings = AppSettings.shared
    @State private var shopName = ""
    @State private var ownerName = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("店铺") {
                    TextField("店铺名称", text: $shopName)
                    TextField("店主称呼", text: $ownerName)
                }
            }
            .navigationTitle("个人资料")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        let s = shopName.trimmingCharacters(in: .whitespaces)
                        let o = ownerName.trimmingCharacters(in: .whitespaces)
                        guard !s.isEmpty, !o.isEmpty else { return }
                        settings.shopName = s
                        settings.ownerName = o
                        Haptic.success()
                        dismiss()
                    }
                    .disabled(shopName.trimmingCharacters(in: .whitespaces).isEmpty || ownerName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear { shopName = settings.shopName; ownerName = settings.ownerName }
        }
        .presentationDetents([.medium])
    }
}

private struct GoalEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    private let settings = AppSettings.shared
    @State private var text = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("目标金额") {
                    TextField("目标金额", text: $text)
                        .keyboardType(.decimalPad)
                }
            }
            .navigationTitle("月营业目标")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        if let value = Double(text), value > 0 {
                            settings.monthGoal = value
                            Haptic.success()
                            dismiss()
                        }
                    }
                    .disabled((Double(text) ?? 0) <= 0)
                }
            }
            .onAppear { text = String(Int(settings.monthGoal)) }
        }
        .presentationDetents([.medium])
    }
}

private struct ReminderSettingsSheet: View {
    @Bindable var settings: AppSettings
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            Form {
                Toggle("待办提醒", isOn: $settings.todoReminderEnabled)
                Toggle("临期退货提醒", isOn: $settings.expiryReminderEnabled)
            }
            .navigationTitle("提醒设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } } }
            .tint(V21.brandGreen)
        }
        .presentationDetents([.medium])
    }
}

private struct AvatarProfileSheet: View {
    @Bindable var settings: AppSettings
    @Binding var selectedItem: PhotosPickerItem?
    @Environment(\.dismiss) private var dismiss
    private let emojis = ["👨🏻‍💼", "👩🏻‍💼", "🧑🏻‍🍳", "😎", "🐱", "🐼", "🏪", "☕️"]
    var body: some View {
        NavigationStack {
            Form {
                Section("Emoji") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 14) {
                        ForEach(emojis, id: \.self) { emoji in
                            Button {
                                settings.avatarEmoji = emoji
                                settings.avatarImageData = nil
                                dismiss()
                            } label: {
                                Text(emoji).font(.system(size: 30)).frame(maxWidth: .infinity).padding(.vertical, 8)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                Section {
                    PhotosPicker(selection: $selectedItem, matching: .images) {
                        Label("从相册选择头像", systemImage: "photo.on.rectangle")
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
            .navigationTitle("个性头像")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("关闭") { dismiss() } } }
        }
        .presentationDetents([.medium])
    }
}

private struct ThemeChoiceSheet: View {
    @Environment(\.dismiss) private var dismiss
    private let settings = AppSettings.shared
    private let options: [(key: String, label: String)] = [
        ("system", "跟随系统"), ("light", "浅色模式"), ("dark", "深色模式"),
    ]

    var body: some View {
        NavigationStack {
            List {
                ForEach(options, id: \.key) { option in
                    Button {
                        settings.themeMode = option.key
                        Haptic.light()
                        dismiss()
                    } label: {
                        HStack {
                            Text(option.label).foregroundStyle(.primary)
                            Spacer()
                            if settings.themeMode == option.key {
                                Image(systemName: "checkmark")
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(V21.brandGreen)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle("显示模式")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("关闭") { dismiss() } } }
        }
        .presentationDetents([.medium])
    }
}

private struct VoiceSettingsSheet: View {
    @Binding var showVoice: Bool
    let showsVoiceButton: Bool
    @Environment(\.dismiss) private var dismiss
    @Bindable private var settings = AppSettings.shared

    var body: some View {
        NavigationStack {
            Form {
                Section("识别语言") {
                    Picker("识别语言", selection: $settings.voiceLanguage) {
                        Text("普通话").tag("普通话")
                        Text("粤语").tag("粤语")
                    }
                    .pickerStyle(.segmented)
                }
                Section {
                    Text("语音识别由系统提供，录音仅用于实时识别，不会保存音频。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                if showsVoiceButton {
                    Section {
                        if #available(iOS 26.0, *) {
                            Button("测试语音") {
                                dismiss()
                                showVoice = true
                            }
                            .buttonStyle(.glassProminent)
                            .tint(V21.brandGreen)
                        } else {
                            Button("测试语音") {
                                dismiss()
                                showVoice = true
                            }
                        }
                    }
                }
            }
            .navigationTitle("语音输入设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } } }
        }
        .presentationDetents([.medium])
    }
}

private struct AboutSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Spacer(minLength: 20)
                Image(systemName: "storefront")
                    .font(.system(size: 40, weight: .medium))
                    .foregroundStyle(V21.brandGreen)
                    .frame(width: 64, height: 64)
                    .background(.ultraThinMaterial, in: Circle())

                Text("你的小掌柜")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)

                Text("v\(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "3.0.2")")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer(minLength: 16)

                Text("本次更新：UI 精修 · 语音界面紧凑化 · 长列表安全区优化")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(.tertiary)
                    }
                    .accessibilityLabel("关闭")
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .presentationDetents([.height(260)])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(24)
    }
}

private struct InfoSheet: View {
    let title: String
    let text: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section { Text(text).foregroundStyle(.secondary) }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("关闭") { dismiss() } } }
        }
        .presentationDetents([.medium])
    }
}
