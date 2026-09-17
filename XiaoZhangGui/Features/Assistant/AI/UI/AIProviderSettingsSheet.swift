import SwiftUI

// MARK: - V3.3 Lite · AI Provider 设置页
//
// - 非敏感配置（端点 / 模型 / 档位）存 UserDefaults（经 AISettings）；
// - API Key 只写 Keychain，输入框不回显已存 Key，只显示「已配置 / 未配置」；
// - 保存后通知 Chat 页重新装配 live Agent；
// - 不配置 Key 也能使用本地 0-token 能力（四范例记账 / 四类经营问答）。

struct AIProviderSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable private var settings = AISettings.shared

    @State private var primaryKeyInput = ""
    @State private var fallbackKeyInput = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    tierCard
                    primaryCard
                    fallbackCard
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
        }
    }

    // MARK: 档位

    private var tierCard: some View {
        V32Card {
            VStack(alignment: .leading, spacing: 10) {
                Text("模型策略").v32Text(.section).foregroundStyle(V32.textPrimary)
                Picker("模型策略", selection: $settings.tier) {
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

    // MARK: 主 Provider

    private var primaryCard: some View {
        V32Card {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("主 Provider（DeepSeek 兼容）").v32Text(.section).foregroundStyle(V32.textPrimary)
                    Spacer()
                    V32StatusPill(
                        text: settings.isPrimaryConfigured ? "已配置" : "未配置",
                        status: settings.isPrimaryConfigured ? .delivering : .expiry)
                }
                label("服务地址（留空用 DeepSeek 官方）")
                TextField(AISettings.Defaults.primaryBaseURL, text: $settings.primaryBaseURL)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                label("模型（留空用 \(AISettings.Defaults.primaryModel)）")
                TextField(AISettings.Defaults.primaryModel, text: $settings.primaryModel)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                label("API Key（仅存本机 Keychain，不回显）")
                SecureField("粘贴 API Key", text: $primaryKeyInput)
                    .textFieldStyle(.roundedBorder)
                if settings.isPrimaryConfigured {
                    Button(role: .destructive) {
                        settings.primaryAPIKey = ""
                    } label: {
                        Text("清除已保存的 Key").v32Text(.caption)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: Fallback

    private var fallbackCard: some View {
        V32Card {
            VStack(alignment: .leading, spacing: 10) {
                Text("备用 Provider（可选）").v32Text(.section).foregroundStyle(V32.textPrimary)
                Text("主 Provider 网络失败 / 超时 / 限流时自动切换一次；三项都填才启用。")
                    .v32Text(.caption).foregroundStyle(V32.textSecondary)
                label("服务地址")
                TextField("https://api.example.com/v1", text: $settings.fallbackBaseURL)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                label("模型")
                TextField("模型名", text: $settings.fallbackModel)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                label("API Key（仅存 Keychain）")
                SecureField("粘贴备用 API Key", text: $fallbackKeyInput)
                    .textFieldStyle(.roundedBorder)
                HStack {
                    V32StatusPill(
                        text: settings.isFallbackConfigured ? "已启用" : "未启用",
                        status: settings.isFallbackConfigured ? .delivering : .pending)
                    Spacer()
                    if settings.isFallbackConfigured {
                        Button(role: .destructive) {
                            settings.fallbackAPIKey = ""
                        } label: {
                            Text("清除备用 Key").v32Text(.caption)
                        }
                        .buttonStyle(.plain)
                    }
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

    // MARK: 保存

    private func save() {
        let primary = primaryKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        if !primary.isEmpty { settings.primaryAPIKey = primary }
        let fallback = fallbackKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        if !fallback.isEmpty { settings.fallbackAPIKey = fallback }
        // 非敏感字段经 @Bindable 已实时写入 UserDefaults
        NotificationCenter.default.post(name: .aiProviderConfigChanged, object: nil)
        dismiss()
    }
}
