import SwiftUI

// MARK: - V3.3 AI REAL · AI Provider 设置页（V3.7.1 Presentation 重构）
//
// 行为原样保留（只换 UI）：
// - 所有编辑先写入内存 AISettingsDraft：保存才 commit（trim 后落盘），取消整体丢弃；
// - DeepSeek 主 Provider 模型只能通过 Picker 选择（Flash / V4 Pro），不接受手填模型 ID；
// - 「测试连接」对真实端点发一次最小请求，只有真实成功才显示绿色「连接成功」；
// - API Key 只写 Keychain，输入框不回显已存 Key；
// - 自定义 OpenAI-Compatible Provider 放在「高级 / 自定义 Provider」，不混入 DeepSeek 默认流程。
//
// V371：GroupSurface 分组 + SectionHeader + StatusBadge，S0 canvas 底。

struct AIProviderSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss

    /// 打开即复制当前设置；不 commit 就绝不落盘
    @State private var draft = AISettingsDraft(settings: .shared)
    @State private var tester = ProviderConnectionTester(initial: .unverified)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    tierCard
                    primaryCard
                    searchCard
                    advancedCard
                    privacyNote
                }
                .padding(.horizontal, V371.Space.page)
                .padding(.vertical, 12)
            }
            .v371Canvas()
            .navigationTitle("小掌柜 AI 设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .fontWeight(.semibold)
                }
            }
            .onAppear {
                tester.synchronize(hasEffectiveKey: !effectivePrimaryKey.isEmpty)
            }
        }
    }

    // MARK: 联网搜索

    private var searchCard: some View {
        GroupSurface {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader("搜索 Provider") {
                    Text(searchConfigurationStatus)
                        .font(.caption)
                        .foregroundStyle(searchConfigurationStatus == "已配置" ? V371.Colors.blue : V371.Colors.textTertiary)
                }
                Picker("搜索 Provider", selection: $draft.searchProviderSelection) {
                    ForEach(SearchProviderSelection.allCases, id: \.self) { provider in
                        Text(provider.displayName).tag(provider)
                    }
                }
                .pickerStyle(.menu)

                Text("搜索只读，不会写入经营数据。每个 Provider 独立配置，Key 仅存本机 Keychain。")
                    .font(.caption)
                    .foregroundStyle(V371.Colors.textSecondary)

                if draft.searchProviderSelection == .automaticFreeFirst {
                    Text("自动模式只会调用你明确标记为“允许免费优先自动使用”的已配置 Provider；没有可用项时直接停止，不会偷偷产生付费调用。")
                        .font(.caption)
                        .foregroundStyle(V371.Colors.textSecondary)
                }

                if draft.searchProviderSelection == .tavily ||
                    draft.searchProviderSelection == .automaticFreeFirst {
                    searchDivider
                    tavilySearchConfiguration
                }

                if draft.searchProviderSelection == .customJSON ||
                    draft.searchProviderSelection == .automaticFreeFirst {
                    searchDivider
                    customSearchConfiguration
                }
            }
            .padding(V371.Space.rowPadding)
        }
    }

    private var searchDivider: some View {
        Divider().overlay(V371.Colors.divider)
    }

    private var tavilySearchConfiguration: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tavily adapter").font(.subheadline).foregroundStyle(V371.Colors.textPrimary)
            label("Base URL")
            TextField("https://api.tavily.com/search", text: $draft.tavilySearchBaseURL)
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            label("API Key（仅存 Keychain）")
            SecureField(
                draft.tavilySearchKeySaved && !draft.clearTavilySearchKeyRequested
                    ? "已保存，如需更换请粘贴新 Key" : "粘贴 Tavily API Key",
                text: $draft.stagedTavilySearchKey
            )
            .textFieldStyle(.roundedBorder)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .onChange(of: draft.stagedTavilySearchKey) { _, value in
                if !value.isEmpty { draft.clearTavilySearchKeyRequested = false }
            }
            searchKeyClearButton(
                saved: draft.tavilySearchKeySaved,
                clearRequested: $draft.clearTavilySearchKeyRequested,
                stagedKey: $draft.stagedTavilySearchKey
            )
            Toggle("允许免费优先自动使用", isOn: $draft.tavilySearchFreeFirstEnabled)
                .font(.caption)
        }
    }

    private var customSearchConfiguration: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("自定义 JSON Search adapter").font(.subheadline).foregroundStyle(V371.Colors.textPrimary)
            Text("适用于百炼、国内 Search API、自建 Proxy 等适配层。请求为 query，响应统一为 answer 与 title/content/sourceURL。")
                .font(.caption)
                .foregroundStyle(V371.Colors.textSecondary)
            label("Base URL")
            TextField("https://search.example.com/v1/query", text: $draft.customSearchBaseURL)
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            label("API Key（仅存 Keychain）")
            SecureField(
                draft.customSearchKeySaved && !draft.clearCustomSearchKeyRequested
                    ? "已保存，如需更换请粘贴新 Key" : "粘贴 Search API Key",
                text: $draft.stagedCustomSearchKey
            )
            .textFieldStyle(.roundedBorder)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .onChange(of: draft.stagedCustomSearchKey) { _, value in
                if !value.isEmpty { draft.clearCustomSearchKeyRequested = false }
            }
            searchKeyClearButton(
                saved: draft.customSearchKeySaved,
                clearRequested: $draft.clearCustomSearchKeyRequested,
                stagedKey: $draft.stagedCustomSearchKey
            )
            Toggle("允许免费优先自动使用", isOn: $draft.customSearchFreeFirstEnabled)
                .font(.caption)
        }
    }

    @ViewBuilder
    private func searchKeyClearButton(
        saved: Bool,
        clearRequested: Binding<Bool>,
        stagedKey: Binding<String>
    ) -> some View {
        if saved {
            Button(role: clearRequested.wrappedValue ? nil : .destructive) {
                clearRequested.wrappedValue.toggle()
                if clearRequested.wrappedValue { stagedKey.wrappedValue = "" }
            } label: {
                Text(clearRequested.wrappedValue ? "保留已保存的 Key" : "清除已保存的 Key")
                    .font(.caption)
            }
            .buttonStyle(.plain)
        }
    }

    private var searchConfigurationStatus: String {
        switch draft.searchProviderSelection {
        case .disabled:
            return "未配置"
        case .automaticFreeFirst:
            let tavilyReady = effectiveTavilySearchKey.isEmpty == false &&
                draft.tavilySearchFreeFirstEnabled && validHTTPURL(draft.tavilySearchBaseURL)
            let customReady = effectiveCustomSearchKey.isEmpty == false &&
                draft.customSearchFreeFirstEnabled && validHTTPURL(draft.customSearchBaseURL)
            return tavilyReady || customReady ? "已配置" : "未配置"
        case .tavily:
            return !effectiveTavilySearchKey.isEmpty && validHTTPURL(draft.tavilySearchBaseURL)
                ? "已配置" : "未配置"
        case .customJSON:
            return !effectiveCustomSearchKey.isEmpty && validHTTPURL(draft.customSearchBaseURL)
                ? "已配置" : "未配置"
        }
    }

    private var effectiveTavilySearchKey: String {
        let staged = draft.stagedTavilySearchKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if !staged.isEmpty { return staged }
        if draft.clearTavilySearchKeyRequested { return "" }
        return AISettings.shared.tavilySearchAPIKey
    }

    private var effectiveCustomSearchKey: String {
        let staged = draft.stagedCustomSearchKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if !staged.isEmpty { return staged }
        if draft.clearCustomSearchKeyRequested { return "" }
        return AISettings.shared.customSearchAPIKey
    }

    private func validHTTPURL(_ text: String) -> Bool {
        guard let url = URL(string: text.trimmingCharacters(in: .whitespacesAndNewlines)),
              let scheme = url.scheme else { return false }
        return scheme == "https" || scheme == "http"
    }

    // MARK: 档位

    private var tierCard: some View {
        GroupSurface {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader("模型策略")
                Picker("模型策略", selection: $draft.tier) {
                    Text("免费优先").tag(ModelTier.freeFirst)
                    Text("自动").tag(ModelTier.auto)
                    Text("高质量").tag(ModelTier.highQuality)
                }
                .pickerStyle(.segmented)
                Text("本地能听懂的记账 / 查询不消耗 Token；只有本地没把握时才联网。")
                    .font(.caption)
                    .foregroundStyle(V371.Colors.textSecondary)
            }
            .padding(V371.Space.rowPadding)
        }
    }

    // MARK: 主 Provider（DeepSeek）

    private var primaryCard: some View {
        GroupSurface {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader("DeepSeek") {
                    StatusBadge(tester.status.text, color: connectionBadgeColor)
                }
                label("服务地址（默认 DeepSeek 官方，一般无需修改）")
                TextField(AISettings.Defaults.primaryBaseURL, text: $draft.primaryBaseURL)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onChange(of: draft.primaryBaseURL) { _, _ in tester.reset(to: hasSavedKeyState) }

                label("模型")
                Picker(selection: $draft.primaryModel) {
                    ForEach(DeepSeekModel.allCases, id: \.self) { model in
                        Text(model.displayName).tag(model)
                    }
                } label: {
                    HStack {
                        Text(draft.primaryModel.displayName)
                            .font(.body)
                            .foregroundStyle(V371.Colors.textPrimary)
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(V371.Colors.textTertiary)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: draft.primaryModel) { _, _ in tester.reset(to: hasSavedKeyState) }

                label("API Key（仅存本机 Keychain，不回显）")
                SecureField(draft.primaryKeySaved && !draft.clearPrimaryKeyRequested
                            ? "已保存，如需更换请粘贴新 Key" : "粘贴 API Key",
                            text: $draft.stagedPrimaryKey)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: draft.stagedPrimaryKey) { _, _ in
                        if !draft.stagedPrimaryKey.isEmpty { draft.clearPrimaryKeyRequested = false }
                        tester.synchronize(hasEffectiveKey: !effectivePrimaryKey.isEmpty)
                    }
                if draft.primaryKeySaved {
                    Button(role: draft.clearPrimaryKeyRequested ? nil : .destructive) {
                        draft.clearPrimaryKeyRequested.toggle()
                        if draft.clearPrimaryKeyRequested { draft.stagedPrimaryKey = "" }
                        tester.synchronize(hasEffectiveKey: !effectivePrimaryKey.isEmpty)
                    } label: {
                        Text(draft.clearPrimaryKeyRequested ? "保留已保存的 Key" : "清除已保存的 Key")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    testConnection()
                } label: {
                    HStack(spacing: 6) {
                        if case .testing = tester.status {
                            ProgressView().controlSize(.small)
                        } else {
                            Image(systemName: "antenna.radiowaves.left.and.right")
                        }
                        Text("测试连接").font(.subheadline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isTesting || effectivePrimaryKey.isEmpty)
                .accessibilityHint("真实调用 DeepSeek 验证 Key、模型与服务地址")

                Text("只有测试通过显示「连接成功」后，才代表 API 可以正常使用。")
                    .font(.caption)
                    .foregroundStyle(V371.Colors.textTertiary)
            }
            .padding(V371.Space.rowPadding)
        }
    }

    // MARK: 高级 / 自定义 Provider（备用 fallback）

    private var advancedCard: some View {
        GroupSurface {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader("高级 / 自定义 Provider（可选）")
                Text("任意 OpenAI 兼容端点；主 Provider 网络失败 / 超时 / 限流时自动切换一次，三项都填才启用。")
                    .font(.caption).foregroundStyle(V371.Colors.textSecondary)
                label("服务地址")
                TextField("https://api.example.com/v1", text: $draft.fallbackBaseURL)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                label("模型")
                TextField("模型名", text: $draft.fallbackModel)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                label("API Key（仅存 Keychain）")
                SecureField("粘贴自定义 Provider API Key", text: $draft.stagedFallbackKey)
                    .textFieldStyle(.roundedBorder)
                if draft.fallbackKeySaved {
                    Button(role: draft.clearFallbackKeyRequested ? nil : .destructive) {
                        draft.clearFallbackKeyRequested.toggle()
                        if draft.clearFallbackKeyRequested { draft.stagedFallbackKey = "" }
                    } label: {
                        Text(draft.clearFallbackKeyRequested ? "保留已保存的备用 Key" : "清除备用 Key")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(V371.Space.rowPadding)
        }
    }

    private var privacyNote: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Key 只存在本机 Keychain，不会进入聊天记录、日志或备份。", systemImage: "lock.shield")
            Label("普通聊天与记账默认不上传经营数据；查询结果在本机汇总。", systemImage: "hand.raised")
        }
        .font(.caption)
        .foregroundStyle(V371.Colors.textSecondary)
        .padding(.horizontal, 4)
    }

    @ViewBuilder
    private func label(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(V371.Colors.textSecondary)
    }

    // MARK: 连接状态 / 测试

    private var isTesting: Bool {
        if case .testing = tester.status { return true }
        return false
    }

    /// 只有真实测试成功才允许绿色：测试中 / 未验证是中性灰，失败 / 未配置是琥珀。
    private var connectionBadgeColor: Color {
        switch tester.status {
        case .success: return V371.Colors.green
        case .testing, .unverified: return V371.Colors.gray
        case .notConfigured, .failure: return V371.Colors.orange
        }
    }

    /// 配置变更后回到「Key 已保存 / 未配置」基础态（不抹掉正在进行的测试）
    private var hasSavedKeyState: ProviderConnectionStatus {
        effectivePrimaryKey.isEmpty ? .notConfigured : .unverified
    }

    private var effectivePrimaryKey: String {
        let staged = draft.stagedPrimaryKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if !staged.isEmpty { return staged }
        if draft.clearPrimaryKeyRequested { return "" }
        return AISettings.shared.primaryAPIKey
    }

    private func testConnection() {
        let key = effectivePrimaryKey
        let urlText = draft.primaryBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let baseURLText = urlText.isEmpty ? AISettings.Defaults.primaryBaseURL : urlText
        let model = draft.primaryModel.rawValue
        guard !key.isEmpty, let url = URL(string: baseURLText),
              url.scheme == "https" || url.scheme == "http" else {
            tester.reset(to: .notConfigured)
            return
        }
        do {
            let provider = try XZGAIProviderAdapter.makePrimary(
                baseURL: url, apiKey: key, model: model)
            Task { await tester.test(provider, model: model) }
        } catch {
            tester.reset(to: .notConfigured)
        }
    }

    // MARK: 保存（唯一落盘点；取消不触发本方法）

    private func save() {
        draft.commit(to: .shared)
        NotificationCenter.default.post(name: .aiProviderConfigChanged, object: nil)
        dismiss()
    }
}
