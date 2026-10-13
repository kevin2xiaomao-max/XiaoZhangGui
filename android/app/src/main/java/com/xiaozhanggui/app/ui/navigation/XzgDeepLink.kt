package com.xiaozhanggui.app.ui.navigation

import android.net.Uri

/**
 * 深链接动作。对应 iOS `App/AppDeepLink.swift` + `App/RootView.swift handleDeepLink`。
 *
 * scheme 为 `xzg`；host：ai / voice / quickrecord / quick / todo
 *（Manifest 已注册对应 intent-filter，见 AndroidManifest.xml）。
 *
 * V3.7.1 语义（对应 iOS「AI 不再是 Tab」）：
 * - `xzg://ai` → 打开 AI Sheet（原 `OpenAssistantTab` 已删除）；
 * - `xzg://ai?mode=voice` → 打开 AI Sheet 并同步拉起短语音面板（原 `OpenAssistantVoice` 已删除）。
 *
 * 注意：`todo` 为 Android 侧扩展（Phase 6 E2E 旅程需要直达待办页），
 * iOS AppDeepLink 仅有前 4 个 host。
 */
sealed interface DeepLinkAction {
    /** 打开语音记一笔（Root 级全局 Sheet） */
    data object OpenVoice : DeepLinkAction

    /** 打开快速记一笔（Root 级全局 Sheet） */
    data object OpenQuickRecord : DeepLinkAction

    /**
     * 打开 AI Sheet（V3.7.1：AI 不再是 Tab）。
     * 对应 iOS `RootView.handleDeepLink` 的 `.ai(voiceMode: false)` → showAI sheet。
     */
    data object OpenAISheet : DeepLinkAction

    /**
     * 打开 AI Sheet 并同步拉起短语音面板（V3.7.1）。
     * 对应 iOS `.ai(voiceMode: true)` → showAI sheet + `AIChatView(voiceDeepLink:)`
     * 自动拉起 ShortVoicePanel；ASR 不可用时降级为文字输入（不拉起面板）。
     */
    data object OpenAISheetVoice : DeepLinkAction

    /** 切换到「待办」Tab（Android 侧扩展，iOS 无此 host） */
    data object OpenTodoTab : DeepLinkAction

    /** 未知链接：忽略 */
    data object Ignore : DeepLinkAction
}

/**
 * 深链接解析。
 *
 * - host=voice → [DeepLinkAction.OpenVoice]
 * - host=quickrecord / quick → [DeepLinkAction.OpenQuickRecord]
 * - host=ai（无 query，或 mode≠voice）→ [DeepLinkAction.OpenAISheet]（V3.7.1：AI Sheet，非 Tab）
 * - host=ai?mode=voice → [DeepLinkAction.OpenAISheetVoice]（AI Sheet + 短语音面板）
 * - host=todo → [DeepLinkAction.OpenTodoTab]（Android 侧扩展）
 * - 其他 → [DeepLinkAction.Ignore]
 */
object XzgDeepLink {
    fun handle(uri: Uri): DeepLinkAction? {
        if (uri.scheme != "xzg") return DeepLinkAction.Ignore
        return route(uri.host, uri.getQueryParameter("mode"))
    }

    /**
     * 纯 JVM 可测的路由核心（不依赖 android.net.Uri）。
     * [handle] 的行为与此前完全一致：仅把已解析的 scheme/host/mode 映射为动作。
     */
    fun route(host: String?, mode: String? = null): DeepLinkAction = when (host) {
        "voice" -> DeepLinkAction.OpenVoice
        "quickrecord", "quick" -> DeepLinkAction.OpenQuickRecord
        "ai" ->
            if (mode == "voice") DeepLinkAction.OpenAISheetVoice
            else DeepLinkAction.OpenAISheet
        "todo" -> DeepLinkAction.OpenTodoTab
        else -> DeepLinkAction.Ignore
    }

    /**
     * 纯 JVM 可测的完整 URI 解析（java.net.URI）。
     * 空/非法输入一律返回 [DeepLinkAction.Ignore]，不抛异常。
     */
    fun parse(raw: String?): DeepLinkAction {
        if (raw.isNullOrBlank()) return DeepLinkAction.Ignore
        val parsed = try {
            java.net.URI(raw.trim())
        } catch (e: Exception) {
            return DeepLinkAction.Ignore
        }
        if (parsed.scheme != "xzg") return DeepLinkAction.Ignore
        return route(parsed.host, queryParam(parsed.rawQuery, "mode"))
    }

    private fun queryParam(rawQuery: String?, name: String): String? {
        if (rawQuery.isNullOrEmpty()) return null
        for (pair in rawQuery.split('&')) {
            val idx = pair.indexOf('=')
            if (idx > 0 && pair.substring(0, idx) == name) {
                return pair.substring(idx + 1)
            }
        }
        return null
    }
}
