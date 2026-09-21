import SwiftUI

// MARK: - V3.3 AI REAL · AI Provider 设置页
//
// - 所有编辑先写入内存 AISettingsDraft：保存才 commit（trim 后落盘），取消整体丢弃；
// - DeepSeek 主 Provider 模型只能通过 Picker 选择（Flash / V4 Pro），不接受手填模型 ID；
// - 「测试连接」对真实端点发一次最小请求，只有真实成功才显示绿色「连接成功」；
// - API Key 只写 Keychain，输入框不回显已存 Key；
// - 自定义 OpenAI-Compatible Provider 放在「高级 / 自定义 Provider」，不混入 DeepSeek 默认流程。

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
                .padding(.horizontal, V32Layout.pageMargin)
                .padding(.vertical, 12)
            }
            .background(V32.pageBG.ignoresSafeArea())
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
        V32FieldGroup {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("联网搜索").v32Text(.section).foregroundStyle(V32.textPrimary)
                    Spacer()
                    Text(draft.searchKeySaved && !draft.clearSearchKeyRequested ? "已配置" : "未配置")
                        .v32Text(.caption)
                        .foregroundStyle(draft.searchKeySaved && !draft.clearSearchKeyRequested ? V32.brand : V32.textTertiary)
                }
                Text("使用 Tavily 获取实时网页结果；搜索只读，不会写入经营数据。Key 仅存本机 Keychain。")
                    .v32Text(.caption)
                    .foregroundStyle(V32.textSecondary)
                SecureField(draft.searchKeySaved && !draft.clearSearchKeyRequested
                            ? "已保存，如需更换请粘贴新 Key" : "粘贴 Tavily API Key",
                            text: $draft.stagedSearchKey)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onChange(of: draft.stagedSearchKey) { _, value in
                        if !value.isEmpty { draft.clearSearchKeyRequested = false }
                    }
                if draft.searchKeySaved {
                    Button(role: draft.clearSearchKeyRequested ? nil : .destructive) {
                        draft.clearSearchKeyRequested.toggle()
                        if draft.clearSearchKeyRequested { draft.stagedSearchKey = "" }
                    } label: {
                        Text(draft.clearSearchKeyRequested ? "保留已保存的搜索 Key" : "清除已保存的搜索 Key")
                            .v32Text(.caption)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: 档位

    private var tierCard: some View {
        V32FieldGroup {
            VStack(alignment: .leading, spacing: 10) {
                Text("模型策略").v32Text(.section).foregroundStyle(V32.textPrimary)
                Picker("模型策略", selection: $draft.tier) {
                    Text("免费优先").tag(ModelTier.freeFirst)
                    Text("自动").tag(ModelTier.auto)
                    Text("高质量").tag(ModelTier.highQuality)
                }
                .pickerStyle(.segmented)
                Text("本地能听懂的记账 / 查询不消耗 Token；只有本地没把握时才联网。")
                    .v32Text(.caption)
                    .foregroundStyle(V32.textSecondary)
            }
        }
    }

    // MARK: 主 Provider（DeepSeek）

    private var primaryCard: some View {
        V32FieldGroup {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("DeepSeek").v32Text(.section).foregroundStyle(V32.textPrimary)
                    Spacer()
                    V32StatusPill(text: tester.status.text, status: connectionPillStatus)
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
                            .v32Text(.body)
                            .foregroundStyle(V32.textPrimary)
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(V32.textTertiary)
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
                            .v32Text(.caption)
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
                        Text("测试连接").v32Text(.subhead)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isTesting || effectivePrimaryKey.isEmpty)
                .accessibilityHint("真实调用 DeepSeek 验证 Key、模型与服务地址")

                Text("只有测试通过显示「连接成功」后，才代表 API 可以正常使用。")
                    .v32Text(.caption)
                    .foregroundStyle(V32.textTertiary)
            }
        }
    }

    // MARK: 高级 / 自定义 Provider（备用 fallback）

    private var advancedCard: some View {
        V32FieldGroup {
            VStack(alignment: .leading, spacing: 10) {
                Text("高级 / 自定义 Provider（可选）").v32Text(.section).foregroundStyle(V32.textPrimary)
                Text("任意 OpenAI 兼容端点；主 Provider 网络失败 / 超时 / 限流时自动切换一次，三项都填才启用。")
                    .v32Text(.caption).foregroundStyle(V32.textSecondary)
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
                            .v32Text(.caption)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var privacyNote: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Key 只存在本机 Keychain，不会进入聊天记录、日志或备份。", systemImage: "lock.shield")
            Label("普通聊天与记账默认不上传经营数据；查询结果在本机汇总。", systemImage: "hand.raised")
        }
        .v32Text(.caption)
        .foregroundStyle(V32.textSecondary)
        .padding(.horizontal, 4)
    }

    @ViewBuilder
    private func label(_ text: String) -> some View {
        Text(text)
            .v32Text(.caption)
            .foregroundStyle(V32.textSecondary)
    }

    // MARK: 连接状态 / 测试

    private var isTesting: Bool {
        if case .testing = tester.status { return true }
        return false
    }

    private var connectionPillStatus: V32Status {
        switch tester.status {
        case .success: return .delivering
        // 只有真实测试成功才允许绿色：测试中 / 未验证都是中性灰，失败是琥珀
        case .testing, .unverified: return .pending
        case .notConfigured, .failure: return .expiry
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
