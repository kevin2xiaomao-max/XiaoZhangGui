package com.xiaozhanggui.app.ui.navigation

import android.net.Uri

/**
 * 深链接动作。对应 iOS `App/AppDeepLink.swift`。
 *
 * scheme 为 `xzg`；host：ai / voice / quickrecord / quick / todo
 *（Manifest 已注册对应 intent-filter，见 AndroidManifest.xml）。
 *
 * 注意：`todo` 为 Android 侧扩展（Phase 6 E2E 旅程需要直达待办页），
 * iOS AppDeepLink 仅有前 4 个 host。
 */
sealed interface DeepLinkAction {
    /** 打开语音记一笔（Root 级全局 Sheet；打开逻辑 Phase 4 实现，当前为桩 Sheet） */
    data object OpenVoice : DeepLinkAction

    /** 打开快速记一笔（Root 级全局 Sheet；打开逻辑 Phase 4 实现，当前为桩 Sheet） */
    data object OpenQuickRecord : DeepLinkAction

    /** 切换到「小掌柜」Tab */
    data object OpenAssistantTab : DeepLinkAction

    /** 切换到「小掌柜」Tab 并打开语音（语音部分 Phase 4 实现） */
    data object OpenAssistantVoice : DeepLinkAction

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
 * - host=ai（无 query，或 mode≠voice）→ [DeepLinkAction.OpenAssistantTab]
 * - host=ai?mode=voice → [DeepLinkAction.OpenAssistantVoice]
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
            if (mode == "voice") DeepLinkAction.OpenAssistantVoice
            else DeepLinkAction.OpenAssistantTab
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
