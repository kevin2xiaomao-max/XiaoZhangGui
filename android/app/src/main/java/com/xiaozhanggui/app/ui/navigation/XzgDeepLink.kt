package com.xiaozhanggui.app.ui.navigation

import android.net.Uri

/**
 * 深链接动作。对应 iOS `App/AppDeepLink.swift`。
 *
 * scheme 为 `xzg`；host：ai / voice / quickrecord / quick
 *（Manifest 已注册对应 intent-filter，见 AndroidManifest.xml）。
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
 * - 其他 → [DeepLinkAction.Ignore]
 */
object XzgDeepLink {
    fun handle(uri: Uri): DeepLinkAction? {
        if (uri.scheme != "xzg") return DeepLinkAction.Ignore
        return when (uri.host) {
            "voice" -> DeepLinkAction.OpenVoice
            "quickrecord", "quick" -> DeepLinkAction.OpenQuickRecord
            "ai" ->
                if (uri.getQueryParameter("mode") == "voice") DeepLinkAction.OpenAssistantVoice
                else DeepLinkAction.OpenAssistantTab
            else -> DeepLinkAction.Ignore
        }
    }
}
