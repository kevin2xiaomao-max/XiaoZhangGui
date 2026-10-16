package com.xiaozhanggui.app.ui.navigation

import android.net.Uri
import com.xiaozhanggui.app.BuildConfig
import com.xiaozhanggui.app.ui.poc.PocRoutes

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
 * V3.8 Phase 2 新增（Android 侧扩展，PoC 隔离区）：
 * - `xzg://poc` → 打开 PoC 列表入口（`poc/launcher`）；
 *   仅 POC_ENABLED（debug 构建）时有效，release 构建映射为 Ignore。
 *
 * V3.8 PoC 测试菜单增强（Android 侧扩展，debug only）：
 * - `xzg://poc/droplet|glass|morph|transition|perf` → 直达对应 PoC 演示屏；
 * - `?speed=slow|normal` → 切换 PoC 全局速度档（PocSpeed）；
 *   仅 POC_ENABLED 时有效，release 构建映射为 Ignore。
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

    /**
     * 打开 PoC 列表入口（V3.8 Phase 2，Android 侧扩展）。
     * 仅 POC_ENABLED（debug 构建）时产生；release 构建中 `xzg://poc`
     * 映射为 [Ignore]，PoC route 不注册。
     */
    data object OpenPocLauncher : DeepLinkAction

    /**
     * 直达某个 PoC 演示屏（V3.8 PoC 测试菜单增强，Android 侧扩展）。
     *
     * - [route]：目标 PoC route（见 [PocRoutes]），由
     *   `xzg://poc/<droplet|glass|morph|transition|perf>` 的 path 解析得到；
     * - [speed]：`?speed=` 原始值（`"slow"` / `"normal"` / null），
     *   导航层经 `PocSpeed.modeForQuery` 落盘为全局速度档；
     * - [autodrive]：`?autodrive=` 原始值（`"true"` / `"false"` / null，
     *   V3.8 真机验收补强），导航层经 `PocAutodrive.enabledForQuery`
     *   置位自动交互驱动；null = 保持当前状态；
     * - 仅 POC_ENABLED（debug 构建）时产生；release 构建映射为 [Ignore]。
     */
    data class OpenPoc(
        val route: String,
        val speed: String? = null,
        val autodrive: String? = null,
    ) : DeepLinkAction

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
 * - host=poc（无 path）→ [DeepLinkAction.OpenPocLauncher]（V3.8 Phase 2；
 *   仅 POC_ENABLED 时有效，否则为 Ignore）
 * - host=poc + path=droplet|glass|morph|transition|perf → [DeepLinkAction.OpenPoc]
 *   （V3.8 PoC 测试菜单增强；非法 path → Ignore；release 下一律 Ignore）；
 *   `?speed=slow|normal` 解析进 [DeepLinkAction.OpenPoc.speed]，
 *   `?autodrive=true|false` 解析进 [DeepLinkAction.OpenPoc.autodrive]
 *   （V3.8 真机验收补强：自动交互驱动）
 * - 其他 → [DeepLinkAction.Ignore]
 */
object XzgDeepLink {
    fun handle(uri: Uri): DeepLinkAction? {
        if (uri.scheme != "xzg") return DeepLinkAction.Ignore
        return route(
            uri.host,
            uri.getQueryParameter("mode"),
            path = uri.path,
            speed = uri.getQueryParameter("speed"),
            autodrive = uri.getQueryParameter("autodrive"),
        )
    }

    /**
     * 纯 JVM 可测的路由核心（不依赖 android.net.Uri）。
     * [handle] 的行为与此前完全一致：仅把已解析的 scheme/host/mode/path/speed
     * 映射为动作。
     *
     * @param pocEnabled PoC 开关（默认取 [BuildConfig.POC_ENABLED]；
     *   测试可显式传入以覆盖两种构建形态）
     * @param path 深链 path（如 `xzg://poc/droplet` 的 `/droplet`；
     *   追加在末尾的默认参数，保持既有调用签名兼容）
     * @param speed `?speed=` 原始值（原样透传进 [DeepLinkAction.OpenPoc]）
     * @param autodrive `?autodrive=` 原始值（原样透传进
     *   [DeepLinkAction.OpenPoc]；V3.8 真机验收补强）
     */
    fun route(
        host: String?,
        mode: String? = null,
        pocEnabled: Boolean = BuildConfig.POC_ENABLED,
        path: String? = null,
        speed: String? = null,
        autodrive: String? = null,
    ): DeepLinkAction = when (host) {
        "voice" -> DeepLinkAction.OpenVoice
        "quickrecord", "quick" -> DeepLinkAction.OpenQuickRecord
        "ai" ->
            if (mode == "voice") DeepLinkAction.OpenAISheetVoice
            else DeepLinkAction.OpenAISheet
        "todo" -> DeepLinkAction.OpenTodoTab
        "poc" -> routePoc(path, speed, pocEnabled, autodrive)
        else -> DeepLinkAction.Ignore
    }

    /**
     * `xzg://poc[/<path>][?speed=][&autodrive=]` 路由（V3.8 PoC 测试菜单增强）。
     *
     * - path 为空 / `"launcher"` → [DeepLinkAction.OpenPocLauncher]
     *  （`xzg://poc` 仍进 launcher，保持 Phase 2 行为）；
     * - `droplet` / `glass` / `morph` / `transition` / `perf` →
     *   [DeepLinkAction.OpenPoc]（route 取 [PocRoutes] 对应值）；
     * - 非法 path → [DeepLinkAction.Ignore]；
     * - pocEnabled=false（release 构建）→ 一律 [DeepLinkAction.Ignore]。
     */
    private fun routePoc(
        path: String?,
        speed: String?,
        pocEnabled: Boolean,
        autodrive: String?,
    ): DeepLinkAction {
        if (!pocEnabled) return DeepLinkAction.Ignore
        return when (path?.trim('/')) {
            null, "", "launcher" -> DeepLinkAction.OpenPocLauncher
            "droplet" -> DeepLinkAction.OpenPoc(PocRoutes.DROPLET, speed, autodrive)
            "glass" -> DeepLinkAction.OpenPoc(PocRoutes.GLASS, speed, autodrive)
            "morph" -> DeepLinkAction.OpenPoc(PocRoutes.MORPH, speed, autodrive)
            "transition" -> DeepLinkAction.OpenPoc(PocRoutes.TRANSITION, speed, autodrive)
            "perf" -> DeepLinkAction.OpenPoc(PocRoutes.PERF, speed, autodrive)
            else -> DeepLinkAction.Ignore
        }
    }

    /**
     * 纯 JVM 可测的完整 URI 解析（java.net.URI）。
     * 空/非法输入一律返回 [DeepLinkAction.Ignore]，不抛异常。
     *
     * @param pocEnabled PoC 开关（默认取 [BuildConfig.POC_ENABLED]；
     *   测试可显式传入以覆盖两种构建形态；注意 release 单元测试的
     *   BuildConfig.POC_ENABLED=false，PoC 相关断言必须显式传 true）
     */
    fun parse(raw: String?, pocEnabled: Boolean = BuildConfig.POC_ENABLED): DeepLinkAction {
        if (raw.isNullOrBlank()) return DeepLinkAction.Ignore
        val parsed = try {
            java.net.URI(raw.trim())
        } catch (e: Exception) {
            return DeepLinkAction.Ignore
        }
        if (parsed.scheme != "xzg") return DeepLinkAction.Ignore
        return route(
            parsed.host,
            queryParam(parsed.rawQuery, "mode"),
            pocEnabled = pocEnabled,
            path = parsed.path,
            speed = queryParam(parsed.rawQuery, "speed"),
            autodrive = queryParam(parsed.rawQuery, "autodrive"),
        )
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
