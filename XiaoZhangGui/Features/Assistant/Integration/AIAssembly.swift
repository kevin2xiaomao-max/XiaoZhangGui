import Foundation
import SwiftData
import SwiftUI

// MARK: - V3.3 Lite · AI 正式装配（AI 目录之外）
//
// 这是 live Agent 的唯一装配点：
// - ModelContext 只在这里出现，经 Repository 执行器 / 读取器注入；
// - 主 Provider 未配置 Key 时使用 UnconfiguredRemoteProvider（明确报错，绝不回退 Mock）；
// - fallback 未完整配置即禁用；
// - 会话 / 待确认 / 执行日志使用文件版 Store，崩溃后可恢复、防重复落库。

enum AIAssembly {
    @MainActor
    static func makeLiveAgent(
        context: ModelContext,
        settings: AISettings = .shared
    ) throws -> AgentCore {
        let directory = UITestMode.isEnabled ? UITestMode.storageDirectory : nil
        let journal = FileExecutionJournal(directory: directory)
        let pending = FilePendingActionStore(directory: directory)
        let conversation = FileConversationStore(directory: directory)

        let primary: any AIProvider
        if settings.isPrimaryConfigured,
           let configured = try? XZGAIProviderAdapter.makePrimary(settings: settings) {
            primary = configured
        } else {
            // 本地 0-token 能力仍可用；需要上云时明确提示未配置
            primary = UnconfiguredRemoteProvider()
        }

        let fallback: (any AIProvider)? = settings.isFallbackConfigured
            ? try? XZGAIProviderAdapter.makeFallback(settings: settings)
            : nil

        let searchCapability = WebSearchProviderFactory.makeCapability(settings: settings)

        let multimodalVision: VisionCapability
        let multimodalDocument: DocumentCapability
        if settings.isPrimaryConfigured,
           let baseURL = URL(string: settings.resolvedPrimaryBaseURL) {
            let key = KeychainAIProviderCredentials().primaryAPIKey()
            multimodalVision = VisionCapability(provider: OpenAICompatibleVisionProvider(
                id: "openai-compatible-vision",
                endpoint: baseURL,
                apiKey: key,
                model: settings.resolvedPrimaryModel
            ))
            multimodalDocument = DocumentCapability(provider: OpenAICompatibleDocumentProvider(
                id: "openai-compatible-document",
                endpoint: baseURL,
                apiKey: key,
                model: settings.resolvedPrimaryModel
            ))
        } else {
            multimodalVision = VisionCapability()
            multimodalDocument = DocumentCapability()
        }

        let env = try AgentEnvironment.makeLive(
            provider: primary,
            fallback: fallback,
            contextProvider: RepositoryBusinessContextReader(context: context),
            toolExecutor: RepositoryToolExecutor(context: context, journal: journal),
            conversation: conversation,
            pending: pending,
            journal: journal,
            tier: settings.tier,
            webSearchCapability: searchCapability,
            visionCapability: multimodalVision,
            documentCapability: multimodalDocument
        )
        return AgentCore(env)
    }
}

extension Notification.Name {
    /// 设置页保存 Provider 配置后发出，触发 Chat 页重新装配 live Agent
    static let aiProviderConfigChanged = Notification.Name("aiProviderConfigChanged")
}

// MARK: - SwiftData ↔ AI 桥接修饰符（AI 目录内的 View 不 import SwiftData）

struct AILiveEnvironmentModifier: ViewModifier {
    /// 每次（重新）装配出 live Agent 时回调，View 侧替换 ViewModel 内的 Agent
    let onReady: @MainActor (AgentCore) -> Void

    @Environment(\.modelContext) private var modelContext

    func body(content: Content) -> some View {
        content
            .onAppear { attach() }
            .onReceive(NotificationCenter.default.publisher(for: .aiProviderConfigChanged)) { _ in
                attach(force: true)
            }
    }

    @MainActor
    private func attach(force: Bool = false) {
        guard force || !attached else { return }
        attached = true
        if let agent = try? AIAssembly.makeLiveAgent(context: modelContext) {
            onReady(agent)
        }
    }

    @State private var attached = false
}

extension View {
    /// 把 live AI Agent（含真实 Repository 执行器）挂到 Chat 页面。
    /// AI 目录内的 View 可调用本方法，但看不到 ModelContext。
    func aiAttachLive(onReady: @escaping @MainActor (AgentCore) -> Void) -> some View {
        modifier(AILiveEnvironmentModifier(onReady: onReady))
    }
}
