import SwiftUI
import SwiftData
import PhotosUI
import UniformTypeIdentifiers

// MARK: - 我的：个人身份与分组设置（V3.7.1 分组设置页）
//
// 视觉：SectionHeader + GroupSurface + WorkRow + 行内 hairline（V371Divider）。
// 全部正式设置逐项保留：个人资料（店铺信息）、显示模式、外观（主题色）、
// 背景风格、壁纸、语音输入、月营业目标、提醒设置、Demo Mode、数据备份、
// 数据恢复、清理缓存、关于、隐私说明。
// 壁纸 / 主题色 / 背景风格确认是正式产品功能（ThemeStore 全局生效、
// 首页 Hero 与侧边栏均消费 palette，壁纸落盘持久化），非旧 demo，入口全部保留。

struct ProfileView: View {
    // V3.7.1：tab 绑定已删除（全仓确认无使用）；从首页右上角进入，无参构造。
    @Binding var showVoice: Bool = .constant(false)
    let showsVoiceButton: Bool = false

    @Environment(\.modelContext) private var context

    @Bindable private var settings = AppSettings.shared
    @Bindable private var demo = DemoMode.shared
    @Environment(ThemeStore.self) private var themeStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var shopDialog = false
    @State private var goalDialog = false
    @State private var themeDialog = false
    @State private var appearanceSheet = false
    @State private var accentSheet = false
    @State private var backgroundSheet = false
    @State private var wallpaperSheet = false
    @State private var voiceDialog = false
    @State private var reminderDialog = false
    @State private var aboutDialog = false
    @State private var privacyDialog = false
    @State private var clearDialog = false
    @State private var showImporter = false
    @State private var shareURL: URL?
    @State private var toast: String?

    private var monthlyGoal: Double {
        demo.isEnabled ? DemoCatalog.monthlyGoal : settings.monthGoal
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: V371.Space.section) {
                profileHero
                settingsSection("个性化") { personalRows }
                settingsSection("经营") { businessRows }
                demoSection
                settingsSection("数据与应用") { dataRows }
                Text("v\(appVersion)")
                    .font(V371.Type.rowSubtitle)
                    .foregroundStyle(V371.Colors.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 4)
            }
            .padding(.horizontal, V371.Space.page)
            .padding(.top, 8)
            .padding(.bottom, 28)
        }
        .scrollIndicators(.hidden)
        .v371Canvas()
        .v371DockInset()
        .navigationTitle("我的")
        .navigationBarTitleDisplayMode(.inline)
        .overlay(alignment: .bottom) {
            if let toast {
                Text(toast)
                    .font(V371.Type.rowTitle)
                    .foregroundStyle(V371.Colors.textPrimary)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 11)
                    .background(
                        Capsule(style: .continuous)
                            .fill(V371.Colors.group)
                            .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
                    )
                    .padding(.bottom, 12)
                    .transition(.opacity.combined(with: reduceMotion ? .identity : .move(edge: .bottom)))
            }
        }
        .sheet(isPresented: $shopDialog) { ShopEditSheet() }
        .sheet(isPresented: $goalDialog) { GoalEditSheet() }
        .sheet(isPresented: $themeDialog) { ThemeChoiceSheet() }
        .sheet(isPresented: $appearanceSheet) { AppearanceSettingsView() }
        .sheet(isPresented: $accentSheet) { AccentThemeSheet() }
        .sheet(isPresented: $backgroundSheet) { BackgroundThemeSheet() }
        .sheet(isPresented: $wallpaperSheet) { WallpaperSheet() }
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
        .sheet(isPresented: Binding(
            get: { shareURL != nil },
            set: { presenting in if !presenting { shareURL = nil } }
        )) {
            // P0-1：以真正的 .json 文件形式分享（系统面板可保存到文件/邮件/IM）
            if let shareURL {
                ShareSheet(activityItems: [shareURL])
                    .ignoresSafeArea(edges: .bottom)
            }
        }
    }

    // MARK: 店铺信息（个人资料入口）

    private var profileHero: some View {
        GroupSurface {
            Button {
                shopDialog = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "storefront.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(V371.Colors.blue)
                        .frame(width: 44, height: 44)
                        .background(V371.Colors.tinted(V371.Colors.blue), in: Circle())
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(DisplayText.visible(settings.shopName, fallback: "我的小店"))
                            .font(V371.Type.rowTitle)
                            .foregroundStyle(V371.Colors.textPrimary)
                            .lineLimit(1)
                        Text("\(DisplayText.visible(settings.ownerName, fallback: "老板")) · 你的小掌柜")
                            .font(V371.Type.rowSubtitle)
                            .foregroundStyle(V371.Colors.textTertiary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 8)
                    V371Chevron()
                }
                .padding(.horizontal, V371.Space.rowPadding)
                .padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("个人资料")
            .accessibilityHint("编辑店铺名称与店主称呼")
        }
    }

    // MARK: 分组

    private func settingsSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title)
            GroupSurface {
                content()
            }
        }
    }

    private func valueTrailing(_ value: String) -> some View {
        HStack(spacing: 4) {
            Text(value)
                .font(V371.Type.rowSubtitle)
                .foregroundStyle(V371.Colors.textTertiary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            V371Chevron()
        }
    }

    @ViewBuilder
    private var personalRows: some View {
        WorkRow(icon: "circle.lefthalf.filled", iconColor: V371.Colors.blue,
                title: "显示模式", action: { themeDialog = true }) {
            valueTrailing(settings.themeModeLabel)
        }
        V371Divider()
        WorkRow(icon: "paintpalette", iconColor: V371.Colors.blue,
                title: "外观", action: { appearanceSheet = true }) {
            valueTrailing(themeStore.accentTheme.displayName)
        }
        V371Divider()
        WorkRow(icon: "square.on.square", iconColor: V371.Colors.gray,
                title: "背景风格", action: { backgroundSheet = true }) {
            valueTrailing(themeStore.backgroundTheme.displayName)
        }
        V371Divider()
        WorkRow(icon: "photo", iconColor: V371.Colors.orange,
                title: "壁纸", action: { wallpaperSheet = true }) {
            valueTrailing(themeStore.wallpaper.isEnabled ? "已设置" : "未设置")
        }
        V371Divider()
        WorkRow(icon: "mic.fill", iconColor: V371.Colors.green,
                title: "语音输入", action: { voiceDialog = true }) {
            valueTrailing(settings.voiceLanguage)
        }
    }

    @ViewBuilder
    private var businessRows: some View {
        WorkRow(icon: "scope", iconColor: V371.Colors.blue,
                title: "月营业目标", action: { goalDialog = true }) {
            valueTrailing(Fmt.groupedInt(monthlyGoal))
        }
        V371Divider()
        WorkRow(icon: "bell", iconColor: V371.Colors.orange,
                title: "提醒设置", action: { reminderDialog = true }) {
            valueTrailing((settings.todoReminderEnabled || settings.expiryReminderEnabled) ? "已开启" : "已关闭")
        }
    }

    @ViewBuilder
    private var demoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader("演示")
            GroupSurface {
                SettingsToggleRow(icon: "wand.and.stars", iconColor: V371.Colors.blue,
                                  title: "Demo Mode", isOn: $demo.isEnabled)
                if demo.isEnabled {
                    Text("当前页面和 AI 使用演示数据，导入不会写入真实数据。")
                        .font(V371.Type.rowSubtitle)
                        .foregroundStyle(V371.Colors.orange)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, V371.Space.rowPadding)
                        .padding(.vertical, 8)
                    V371Divider()
                    WorkRow(icon: "arrow.clockwise", iconColor: V371.Colors.gray,
                            title: "重置演示数据",
                            subtitle: "独立内存",
                            action: {
                                demo.resetDemoData()
                                showToast("演示数据已重置")
                            }) {
                        EmptyView()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var dataRows: some View {
        // P0-1：备份生成真正的 .json 文件（含状态/时间/图片 base64），经系统面板分享
        WorkRow(icon: "square.and.arrow.down", iconColor: V371.Colors.gray,
                title: "数据备份", action: { exportBackupFile() }) {
            valueTrailing("JSON 文件")
        }
        V371Divider()
        WorkRow(icon: "arrow.clockwise", iconColor: V371.Colors.gray,
                title: "数据恢复", action: { showImporter = true }) {
            valueTrailing("JSON")
        }
        V371Divider()
        WorkRow(icon: "paintbrush", iconColor: V371.Colors.gray,
                title: "清理缓存", action: { clearDialog = true }) {
            V371Chevron()
        }
        V371Divider()
        WorkRow(icon: "info.circle", iconColor: V371.Colors.blue,
                title: "关于你的小掌柜", action: { aboutDialog = true }) {
            V371Chevron()
        }
        V371Divider()
        WorkRow(icon: "lock.shield", iconColor: V371.Colors.gray,
                title: "隐私说明", action: { privacyDialog = true }) {
            V371Chevron()
        }
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    private func showToast(_ text: String) {
        withAnimation(reduceMotion ? nil : V32Motion.quick) { toast = text }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation(reduceMotion ? nil : V32Motion.quick) { toast = nil }
        }
    }

    /// P0-1：生成真正的 .json 备份文件并弹出系统分享面板
    private func exportBackupFile() {
        do {
            let url = try BackupService.exportFileURL(context: context)
            Haptic.light()
            shareURL = url
        } catch {
            Haptic.error()
            showToast("备份失败：\(error.localizedDescription)")
        }
    }

    /// P0-1：恢复走 BackupService（字段对称、单次 save、状态/图片不丢失）
    private func restore(from result: Result<URL, Error>) {
        guard case .success(let url) = result else { return }
        let secured = url.startAccessingSecurityScopedResource()
        defer { if secured { url.stopAccessingSecurityScopedResource() } }
        do {
            let raw = try Data(contentsOf: url)
            let count = try BackupService.restore(context: context, from: raw)
            Haptic.success()
            showToast("已恢复 \(count) 条记录")
        } catch {
            Haptic.error()
            showToast("恢复失败：\(error.localizedDescription)")
        }
    }
}

// MARK: - 系统分享面板（分享真正的文件 URL，而非 JSON 纯文本）

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - 设置开关行（V371 行样式）

private struct SettingsToggleRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(iconColor)
                .frame(width: 36, height: 36)
                .background(V371.Colors.tinted(iconColor), in: Circle())
                .accessibilityHidden(true)
            Text(title)
                .font(V371.Type.rowTitle)
                .foregroundStyle(V371.Colors.textPrimary)
                .lineLimit(1)
            Spacer(minLength: 8)
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(V371.Colors.blue)
                .frame(minHeight: 44)
        }
        .padding(.horizontal, V371.Space.rowPadding)
        .padding(.vertical, 12)
        .frame(minHeight: 60)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
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
        NavigationStack {
            Form {
                Section {
                    TextField("店铺名称", text: $shopName)
                        .tint(V371.Colors.blue)
                    TextField("店主称呼", text: $ownerName)
                        .tint(V371.Colors.blue)
                }
            }
            .scrollContentBackground(.hidden)
            .background(V371.Colors.canvas)
            .tint(V371.Colors.blue)
            .navigationTitle("个人资料")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .disabled(!canSave)
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
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
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 8) {
                        Text("¥")
                            .font(V371.Type.rowTitle)
                            .foregroundStyle(V371.Colors.textSecondary)
                        TextField("目标金额", text: $text)
                            .font(V371.Type.rowTitle)
                            .foregroundStyle(V371.Colors.textPrimary)
                            .tint(V371.Colors.blue)
                            .keyboardType(.decimalPad)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(V371.Colors.canvas)
            .tint(V371.Colors.blue)
            .navigationTitle("月营业目标")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        if let value = Double(text), value > 0 {
                            settings.monthGoal = value
                            Haptic.success()
                            dismiss()
                        }
                    }
                    .disabled(!canSave)
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .onAppear { text = String(Int(settings.monthGoal)) }
    }
}

// MARK: - 提醒

private struct ReminderSettingsSheet: View {
    @Bindable var settings: AppSettings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    GroupSurface {
                        SettingsToggleRow(icon: "bell", iconColor: V371.Colors.blue,
                                          title: "待办提醒", isOn: $settings.todoReminderEnabled)
                        V371Divider()
                        SettingsToggleRow(icon: "clock.badge.exclamationmark", iconColor: V371.Colors.orange,
                                          title: "临期退货提醒", isOn: $settings.expiryReminderEnabled)
                    }
                }
                .padding(.horizontal, V371.Space.page)
                .padding(.top, 12)
                .padding(.bottom, 28)
            }
            .scrollIndicators(.hidden)
            .navigationTitle("提醒设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .v371Canvas()
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
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    GroupSurface {
                        ForEach(Array(options.enumerated()), id: \.element.key) { index, option in
                            if index > 0 { V371Divider() }
                            WorkRow(icon: option.icon, iconColor: V371.Colors.blue,
                                    title: option.label,
                                    action: {
                                        settings.themeMode = option.key
                                        Haptic.light()
                                        dismiss()
                                    }) {
                                if settings.themeMode == option.key {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(V371.Colors.blue)
                                        .accessibilityHidden(true)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, V371.Space.page)
                .padding(.top, 12)
                .padding(.bottom, 28)
            }
            .scrollIndicators(.hidden)
            .navigationTitle("显示模式")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("关闭") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .v371Canvas()
    }
}

// MARK: - 主题色选择（b28 T25）

@MainActor
private struct AccentThemeSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ThemeStore.self) private var themeStore

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: V371.Space.section) {
                    GroupSurface {
                        ForEach(Array(AccentTheme.allCases.enumerated()), id: \.element.rawValue) { index, theme in
                            if index > 0 { V371Divider() }
                            Button {
                                themeStore.setAccent(theme)
                                Haptic.light()
                                dismiss()
                            } label: {
                                HStack(spacing: 12) {
                                    Circle()
                                        .fill(theme.palette.accent)
                                        .frame(width: 32, height: 32)
                                        .overlay(Circle().strokeBorder(V371.Colors.divider, lineWidth: 1))
                                        .accessibilityHidden(true)
                                    Text(theme.displayName)
                                        .font(V371.Type.rowTitle)
                                        .foregroundStyle(V371.Colors.textPrimary)
                                        .lineLimit(1)
                                    Spacer(minLength: 8)
                                    if themeStore.accentTheme == theme {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 14, weight: .bold))
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
                            .accessibilityLabel(theme.displayName)
                            .accessibilityAddTraits(themeStore.accentTheme == theme ? .isSelected : [])
                        }
                    }
                    Text("主题色影响点缀色（按钮、图标、选中态）与 Hero 渐变。")
                        .font(V371.Type.rowSubtitle)
                        .foregroundStyle(V371.Colors.textTertiary)
                        .padding(.horizontal, 4)
                }
                .padding(.horizontal, V371.Space.page)
                .padding(.top, 12)
                .padding(.bottom, 28)
            }
            .scrollIndicators(.hidden)
            .navigationTitle("主题色")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("关闭") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .v371Canvas()
    }
}

// MARK: - 背景风格选择（b28 T25）

@MainActor
private struct BackgroundThemeSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ThemeStore.self) private var themeStore

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: V371.Space.section) {
                    GroupSurface {
                        ForEach(Array(BackgroundTheme.allCases.enumerated()), id: \.element.rawValue) { index, theme in
                            if index > 0 { V371Divider() }
                            Button {
                                themeStore.setBackground(theme)
                                Haptic.light()
                                dismiss()
                            } label: {
                                HStack(spacing: 12) {
                                    ZStack {
                                        Circle().fill(theme.palette.pageBG)
                                        Circle().fill(theme.palette.card)
                                            .frame(width: 20, height: 20)
                                        Circle().fill(theme.palette.pageBGSecondary)
                                            .frame(width: 9, height: 9)
                                    }
                                    .frame(width: 32, height: 32)
                                    .overlay(Circle().strokeBorder(V371.Colors.divider, lineWidth: 1))
                                    .accessibilityHidden(true)
                                    Text(theme.displayName)
                                        .font(V371.Type.rowTitle)
                                        .foregroundStyle(V371.Colors.textPrimary)
                                        .lineLimit(1)
                                    Spacer(minLength: 8)
                                    if themeStore.backgroundTheme == theme {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 14, weight: .bold))
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
                            .accessibilityLabel(theme.displayName)
                            .accessibilityAddTraits(themeStore.backgroundTheme == theme ? .isSelected : [])
                        }
                    }
                    Text("背景风格影响页面底色、卡片、分割线与中性文本。主题切换即时全局生效。")
                        .font(V371.Type.rowSubtitle)
                        .foregroundStyle(V371.Colors.textTertiary)
                        .padding(.horizontal, 4)
                }
                .padding(.horizontal, V371.Space.page)
                .padding(.top, 12)
                .padding(.bottom, 28)
            }
            .scrollIndicators(.hidden)
            .navigationTitle("背景风格")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("关闭") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .v371Canvas()
    }
}

// MARK: - 壁纸设置（b28 T27）

@MainActor
private struct WallpaperSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ThemeStore.self) private var themeStore
    @State private var selectedItem: PhotosPickerItem?
    @State private var showFileImporter = false
    @State private var processing = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: V371.Space.section) {
                    previewCard
                    GroupSurface {
                        PhotosPicker(selection: $selectedItem, matching: .images) {
                            sourceRow(icon: "photo.on.rectangle", iconColor: V371.Colors.blue, title: "从相册选择")
                        }
                        .buttonStyle(.plain)
                        .disabled(processing)
                        V371Divider()
                        Button {
                            showFileImporter = true
                        } label: {
                            sourceRow(icon: "folder", iconColor: V371.Colors.blue, title: "从文件选择")
                        }
                        .buttonStyle(.plain)
                        .disabled(processing)
                    }
                    if themeStore.wallpaper.isEnabled {
                        effectSection
                        maskSection
                        deleteButton
                    }
                    if let error {
                        Text(error)
                            .font(V371.Type.rowSubtitle)
                            .foregroundStyle(V371.Colors.red)
                            .padding(.horizontal, 4)
                    }
                    Text("壁纸降采样后落盘到 Application Support，原图不会保留。深色模式自动增强遮罩。")
                        .font(V371.Type.rowSubtitle)
                        .foregroundStyle(V371.Colors.textTertiary)
                        .padding(.horizontal, 4)
                }
                .padding(.horizontal, V371.Space.page)
                .padding(.top, 12)
                .padding(.bottom, 28)
            }
            .scrollIndicators(.hidden)
            .navigationTitle("壁纸")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("关闭") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .v371Canvas()
        .onChange(of: selectedItem) { _, item in
            handlePhotosItem(item)
        }
        .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.image]) { result in
            handleFileResult(result)
        }
    }

    private func sourceRow(icon: String, iconColor: Color, title: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(iconColor)
                .frame(width: 36, height: 36)
                .background(V371.Colors.tinted(iconColor), in: Circle())
                .accessibilityHidden(true)
            Text(title)
                .font(V371.Type.rowTitle)
                .foregroundStyle(V371.Colors.textPrimary)
                .lineLimit(1)
            Spacer(minLength: 8)
            V371Chevron()
        }
        .padding(.horizontal, V371.Space.rowPadding)
        .padding(.vertical, 12)
        .frame(minHeight: 60)
        .contentShape(Rectangle())
    }

    private var previewCard: some View {
        GroupSurface {
            Group {
                if themeStore.wallpaper.isEnabled,
                   let fileName = themeStore.wallpaper.imageFileName,
                   let data = WallpaperStorage.loadData(fileName: fileName),
                   let uiImage = UIImage(data: data) {
                    ZStack {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 150)
                            .clipped()
                        Color.black.opacity(themeStore.wallpaper.maskStrength == .strong ? 0.6 : 0.35)
                        Text("当前壁纸 · \(effectLabel) · \(maskLabel)")
                            .font(V371.Type.rowSubtitle)
                            .foregroundStyle(.white)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: V371.Radius.group, style: .continuous))
                    .padding(8)
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "photo")
                            .font(.system(size: 36))
                            .foregroundStyle(V371.Colors.textTertiary)
                            .accessibilityHidden(true)
                        Text("未设置壁纸")
                            .font(V371.Type.rowTitle)
                            .foregroundStyle(V371.Colors.textTertiary)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 150)
                    .padding(8)
                }
            }
        }
    }

    private var effectSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader("效果")
            GroupSurface {
                ForEach(Array(WallpaperEffect.allCases.enumerated()), id: \.element.rawValue) { index, effect in
                    if index > 0 { V371Divider() }
                    WorkRow(icon: effectIcon(effect), iconColor: V371.Colors.blue,
                            title: effectLabel(effect),
                            action: {
                                themeStore.updateWallpaperOptions(effect: effect, maskStrength: themeStore.wallpaper.maskStrength)
                                Haptic.light()
                            }) {
                        if themeStore.wallpaper.effect == effect {
                            Image(systemName: "checkmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(V371.Colors.blue)
                                .accessibilityHidden(true)
                        }
                    }
                }
            }
        }
    }

    private var maskSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader("遮罩强度")
            GroupSurface {
                ForEach(Array(WallpaperMaskStrength.allCases.enumerated()), id: \.element.rawValue) { index, mask in
                    if index > 0 { V371Divider() }
                    WorkRow(icon: maskIcon(mask), iconColor: V371.Colors.blue,
                            title: maskLabel(mask),
                            action: {
                                themeStore.updateWallpaperOptions(effect: themeStore.wallpaper.effect, maskStrength: mask)
                                Haptic.light()
                            }) {
                        if themeStore.wallpaper.maskStrength == mask {
                            Image(systemName: "checkmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(V371.Colors.blue)
                                .accessibilityHidden(true)
                        }
                    }
                }
            }
        }
    }

    private var deleteButton: some View {
        GroupSurface {
            Button(role: .destructive) {
                themeStore.clearWallpaper()
                Haptic.light()
            } label: {
                HStack(spacing: 8) {
                    Spacer(minLength: 0)
                    Image(systemName: "trash")
                        .font(.system(size: 15, weight: .semibold))
                    Text("删除壁纸")
                        .font(V371.Type.rowTitle)
                    Spacer(minLength: 0)
                }
                .foregroundStyle(V371.Colors.red)
                .padding(.horizontal, V371.Space.rowPadding)
                .padding(.vertical, 14)
                .frame(minHeight: 56)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("删除壁纸")
        }
    }

    private var effectLabel: String { effectLabel(themeStore.wallpaper.effect) }
    private var maskLabel: String { maskLabel(themeStore.wallpaper.maskStrength) }

    private func effectLabel(_ e: WallpaperEffect) -> String {
        switch e {
        case .original: return "原图"
        case .soft: return "柔和"
        case .blurred: return "模糊"
        }
    }
    private func effectIcon(_ e: WallpaperEffect) -> String {
        switch e {
        case .original: return "sun.max"
        case .soft: return "circle.lefthalf.filled"
        case .blurred: return "circle.dashed"
        }
    }
    private func maskLabel(_ m: WallpaperMaskStrength) -> String {
        switch m {
        case .light: return "轻"
        case .medium: return "中"
        case .strong: return "强"
        }
    }
    private func maskIcon(_ m: WallpaperMaskStrength) -> String {
        switch m {
        case .light: return "circle"
        case .medium: return "circle.fill"
        case .strong: return "circle.large.fill"
        }
    }

    // MARK: - 图片处理

    private func handlePhotosItem(_ item: PhotosPickerItem?) {
        guard let item else { return }
        processing = true
        error = nil
        Task {
            do {
                guard let data = try await item.loadTransferable(type: Data.self) else {
                    await MainActor.run {
                        self.error = "无法读取所选图片"
                        self.processing = false
                    }
                    return
                }
                await applyImageData(data)
            } catch {
                await MainActor.run {
                    self.error = "图片加载失败：\(error.localizedDescription)"
                    self.processing = false
                }
            }
        }
    }

    private func handleFileResult(_ result: Result<URL, Error>) {
        processing = true
        error = nil
        switch result {
        case .success(let url):
            let accessed = url.startAccessingSecurityScopedResource()
            defer { if accessed { url.stopAccessingSecurityScopedResource() } }
            guard let data = try? Data(contentsOf: url) else {
                self.error = "无法读取所选文件"
                self.processing = false
                return
            }
            applyImageData(data)
        case .failure(let err):
            self.error = "文件选择失败：\(err.localizedDescription)"
            self.processing = false
        }
    }

    @MainActor
    private func applyImageData(_ data: Data) {
        let failure = themeStore.applyWallpaperImage(
            data: data,
            effect: themeStore.wallpaper.effect,
            maskStrength: themeStore.wallpaper.maskStrength
        )
        if let failure {
            self.error = failure
        } else {
            Haptic.success()
        }
        self.processing = false
    }
}

// MARK: - 语音设置

private struct VoiceSettingsSheet: View {
    @Binding var showVoice: Bool
    let showsVoiceButton: Bool
    @Environment(\.dismiss) private var dismiss
    @Bindable private var settings = AppSettings.shared

    var body: some View {
        NavigationStack {
            Form {
                Section("识别语言") {
                    Picker("识别语言", selection: Binding(
                        get: { settings.voiceLanguage == "粤语" ? 1 : 0 },
                        set: { settings.voiceLanguage = $0 == 1 ? "粤语" : "普通话" }
                    )) {
                        Text("普通话").tag(0)
                        Text("粤语").tag(1)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }
                Section {
                    Text("语音识别由系统提供，录音仅用于实时识别，不会保存音频。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                if showsVoiceButton {
                    Section {
                        Button {
                            dismiss()
                            showVoice = true
                        } label: {
                            Label("测试语音", systemImage: "mic.fill")
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(V371.Colors.canvas)
            .tint(V371.Colors.blue)
            .navigationTitle("语音输入设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - 关于

private struct AboutSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var notesPresented = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    Spacer(minLength: 24)
                    Image(systemName: "storefront")
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(V371.Colors.blue)
                        .frame(width: 72, height: 72)
                        .background(V371.Colors.tinted(V371.Colors.blue), in: Circle())
                        .accessibilityHidden(true)
                    Text("你的小掌柜")
                        .font(V371.Type.sectionTitle)
                        .foregroundStyle(V371.Colors.textPrimary)
                    Text(ReleaseNotes.versionDisplay)
                        .font(V371.Type.rowSubtitle)
                        .foregroundStyle(V371.Colors.textTertiary)
                    GroupSurface {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("本次更新：\(ReleaseNotes.current.headline)")
                                .font(V371.Type.rowSubtitle)
                                .foregroundStyle(V371.Colors.textSecondary)
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Button {
                                notesPresented = true
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "sparkles")
                                        .font(.system(size: 14, weight: .semibold))
                                    Text("V3.5 新变化")
                                        .font(V371.Type.rowTitle)
                                    Spacer()
                                    V371Chevron()
                                }
                                .foregroundStyle(V371.Colors.blue)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("查看 \(ReleaseNotes.versionDisplay) 完整更新说明")
                        }
                        .padding(V371.Space.rowPadding)
                    }
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 30))
                            .foregroundStyle(V371.Colors.textTertiary)
                            .frame(minWidth: 44, minHeight: 44)
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("关闭")
                }
                .padding(.horizontal, V371.Space.page)
                .padding(.bottom, 28)
            }
            .scrollIndicators(.hidden)
            .navigationTitle("关于")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("关闭") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .v371Canvas()
        .sheet(isPresented: $notesPresented) {
            ReleaseNotesSheet()
        }
    }
}

// MARK: - 更新说明

/// App 内完整版本更新说明。内容仅描述用户可感知的功能，
/// 不放工程术语 / 提交信息；未进入本版本的能力（更大尺寸的桌面小组件、
/// 长语音、多意图、长期记忆、主动提醒、AI 建临期、改删操作等）一律不写。
private struct ReleaseNotesSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: V371.Space.section) {
                    GroupSurface {
                        VStack(alignment: .leading, spacing: 14) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("你的小掌柜 \(ReleaseNotes.versionDisplay)")
                                    .font(V371.Type.rowTitle)
                                    .foregroundStyle(V371.Colors.textPrimary)
                                Text(ReleaseNotes.current.headline)
                                    .font(V371.Type.rowSubtitle)
                                    .foregroundStyle(V371.Colors.textTertiary)
                            }
                            ForEach(Array(ReleaseNotes.current.sections.enumerated()), id: \.element.id) { index, section in
                                if index > 0 {
                                    V371Divider(leading: 0)
                                }
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack(spacing: 7) {
                                        Image(systemName: section.icon)
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundStyle(V371.Colors.blue)
                                            .accessibilityHidden(true)
                                        Text(section.title)
                                            .font(V371.Type.rowTitle)
                                            .foregroundStyle(V371.Colors.textPrimary)
                                    }
                                    VStack(alignment: .leading, spacing: 6) {
                                        ForEach(section.items, id: \.self) { item in
                                            HStack(alignment: .top, spacing: 8) {
                                                Image(systemName: "circle.fill")
                                                    .font(.system(size: 4))
                                                    .foregroundStyle(V371.Colors.textTertiary)
                                                    .padding(.top, 7)
                                                    .accessibilityHidden(true)
                                                Text(item)
                                                    .font(V371.Type.rowSubtitle)
                                                    .foregroundStyle(V371.Colors.textSecondary)
                                                    .fixedSize(horizontal: false, vertical: true)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .padding(V371.Space.rowPadding)
                    }
                }
                .padding(.horizontal, V371.Space.page)
                .padding(.top, 12)
                .padding(.bottom, 28)
            }
            .scrollIndicators(.hidden)
            .navigationTitle("更新说明")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("关闭") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .v371Canvas()
    }
}

// MARK: - 信息说明

private struct InfoSheet: View {
    let title: String
    let text: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    GroupSurface {
                        Text(text)
                            .font(V371.Type.rowSubtitle)
                            .foregroundStyle(V371.Colors.textSecondary)
                            .padding(V371.Space.rowPadding)
                    }
                }
                .padding(.horizontal, V371.Space.page)
                .padding(.top, 12)
                .padding(.bottom, 28)
            }
            .scrollIndicators(.hidden)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("关闭") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .v371Canvas()
    }
}
