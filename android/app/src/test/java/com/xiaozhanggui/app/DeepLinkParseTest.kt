package com.xiaozhanggui.app

import com.xiaozhanggui.app.ui.navigation.DeepLinkAction
import com.xiaozhanggui.app.ui.navigation.XzgDeepLink
import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * 深链接解析回归测试（Phase 6 Worker C）。
 *
 * XzgDeepLink.handle 依赖 android.net.Uri（JVM 下不可用），此处覆盖
 * 纯 JVM 入口 parse(String)/route(host, mode)——handle 仅做参数转发，
 * 映射逻辑与之一致。
 *
 * 路由表（对应 iOS AppDeepLink.swift + RootView.handleDeepLink）：
 * - xzg://ai（无 query / mode≠voice）→ OpenAISheet（V3.7.1：AI 不再是 Tab）
 * - xzg://ai?mode=voice → OpenAISheetVoice（AI Sheet + 短语音面板）
 * - xzg://voice → OpenVoice
 * - xzg://quickrecord / xzg://quick → OpenQuickRecord
 * - xzg://todo → OpenTodoTab（Android 侧扩展，iOS 无此 host）
 * - 未知 host / 非 xzg scheme / 空 / 非法 → Ignore（不崩溃）
 */
class DeepLinkParseTest {

    @Test
    fun `xzg ai opens ai sheet (no longer a tab)`() {
        assertEquals(DeepLinkAction.OpenAISheet, XzgDeepLink.parse("xzg://ai"))
    }

    @Test
    fun `xzg ai with non-voice mode opens ai sheet`() {
        assertEquals(DeepLinkAction.OpenAISheet, XzgDeepLink.parse("xzg://ai?mode=text"))
    }

    @Test
    fun `xzg ai mode voice opens ai sheet with voice panel`() {
        assertEquals(DeepLinkAction.OpenAISheetVoice, XzgDeepLink.parse("xzg://ai?mode=voice"))
    }

    @Test
    fun `xzg voice opens voice sheet`() {
        assertEquals(DeepLinkAction.OpenVoice, XzgDeepLink.parse("xzg://voice"))
    }

    @Test
    fun `xzg quickrecord opens quick record`() {
        assertEquals(DeepLinkAction.OpenQuickRecord, XzgDeepLink.parse("xzg://quickrecord"))
    }

    @Test
    fun `xzg quick opens quick record`() {
        assertEquals(DeepLinkAction.OpenQuickRecord, XzgDeepLink.parse("xzg://quick"))
    }

    @Test
    fun `xzg todo opens todo tab (android extension)`() {
        assertEquals(DeepLinkAction.OpenTodoTab, XzgDeepLink.parse("xzg://todo"))
    }

    @Test
    fun `unknown host is ignored`() {
        assertEquals(DeepLinkAction.Ignore, XzgDeepLink.parse("xzg://unknown"))
        assertEquals(DeepLinkAction.Ignore, XzgDeepLink.parse("xzg://settings"))
        assertEquals(DeepLinkAction.Ignore, XzgDeepLink.parse("xzg://"))
    }

    @Test
    fun `non-xzg scheme is ignored`() {
        assertEquals(DeepLinkAction.Ignore, XzgDeepLink.parse("https://example.com/ai"))
        assertEquals(DeepLinkAction.Ignore, XzgDeepLink.parse("xzg2://ai"))
    }

    @Test
    fun `null blank and malformed input do not crash`() {
        assertEquals(DeepLinkAction.Ignore, XzgDeepLink.parse(null))
        assertEquals(DeepLinkAction.Ignore, XzgDeepLink.parse(""))
        assertEquals(DeepLinkAction.Ignore, XzgDeepLink.parse("   "))
        assertEquals(DeepLinkAction.Ignore, XzgDeepLink.parse("not a uri at all :::"))
        assertEquals(DeepLinkAction.Ignore, XzgDeepLink.parse("://missing-scheme"))
    }

    @Test
    fun `route maps host and mode directly`() {
        assertEquals(DeepLinkAction.OpenVoice, XzgDeepLink.route("voice"))
        assertEquals(DeepLinkAction.OpenQuickRecord, XzgDeepLink.route("quickrecord"))
        assertEquals(DeepLinkAction.OpenQuickRecord, XzgDeepLink.route("quick"))
        assertEquals(DeepLinkAction.OpenAISheet, XzgDeepLink.route("ai"))
        assertEquals(DeepLinkAction.OpenAISheetVoice, XzgDeepLink.route("ai", "voice"))
        assertEquals(DeepLinkAction.OpenAISheet, XzgDeepLink.route("ai", "other"))
        assertEquals(DeepLinkAction.OpenTodoTab, XzgDeepLink.route("todo"))
        assertEquals(DeepLinkAction.Ignore, XzgDeepLink.route(null))
        assertEquals(DeepLinkAction.Ignore, XzgDeepLink.route("unknown"))
    }

    // ---------- Phase 1 语义回归 worker 补齐：解析层边界 ----------

    @Test
    fun `ai mode empty string opens ai sheet`() {
        assertEquals(DeepLinkAction.OpenAISheet, XzgDeepLink.parse("xzg://ai?mode="))
    }

    @Test
    fun `ai mode voice with extra query params still opens ai sheet with voice`() {
        assertEquals(
            DeepLinkAction.OpenAISheetVoice,
            XzgDeepLink.parse("xzg://ai?mode=voice&foo=bar")
        )
    }

    @Test
    fun `ai mode matching is case sensitive`() {
        // 当前实现 mode == "voice" 精确匹配；大写 VOICE 走默认分支（锁定行为，非语义变更）
        assertEquals(DeepLinkAction.OpenAISheet, XzgDeepLink.parse("xzg://ai?mode=VOICE"))
    }

    @Test
    fun `quick hosts ignore query params`() {
        assertEquals(DeepLinkAction.OpenQuickRecord, XzgDeepLink.parse("xzg://quickrecord?x=1"))
        assertEquals(DeepLinkAction.OpenQuickRecord, XzgDeepLink.parse("xzg://quick?x=1"))
        assertEquals(DeepLinkAction.OpenVoice, XzgDeepLink.parse("xzg://voice?x=1"))
    }

    @Test
    fun `unknown host with query is still ignored`() {
        assertEquals(DeepLinkAction.Ignore, XzgDeepLink.parse("xzg://unknown?mode=voice"))
        assertEquals(DeepLinkAction.Ignore, XzgDeepLink.parse("xzg://settings?tab=ai"))
    }

    // ── V3.8 Phase 2：xzg://poc（PoC 隔离区入口，POC_ENABLED 门控）──

    @Test
    fun `poc host opens poc launcher when poc enabled`() {
        assertEquals(
            DeepLinkAction.OpenPocLauncher,
            XzgDeepLink.route("poc", pocEnabled = true),
        )
    }

    @Test
    fun `poc host is ignored when poc disabled (release)`() {
        // release 构建 POC_ENABLED=false：深链不产生动作，route 不注册。
        assertEquals(
            DeepLinkAction.Ignore,
            XzgDeepLink.route("poc", pocEnabled = false),
        )
    }

    // ── V3.8 PoC 测试菜单增强：逐 PoC 深链 xzg://poc/<droplet|glass|morph|transition> ──

    @Test
    fun `poc droplet path opens droplet demo`() {
        assertEquals(
            DeepLinkAction.OpenPoc("poc/droplet"),
            XzgDeepLink.route("poc", path = "/droplet", pocEnabled = true),
        )
        assertEquals(
            DeepLinkAction.OpenPoc("poc/droplet"),
            XzgDeepLink.parse("xzg://poc/droplet"),
        )
    }

    @Test
    fun `poc glass path opens glass demo`() {
        assertEquals(
            DeepLinkAction.OpenPoc("poc/glass"),
            XzgDeepLink.route("poc", path = "/glass", pocEnabled = true),
        )
        assertEquals(
            DeepLinkAction.OpenPoc("poc/glass"),
            XzgDeepLink.parse("xzg://poc/glass"),
        )
    }

    @Test
    fun `poc morph path opens morph demo`() {
        assertEquals(
            DeepLinkAction.OpenPoc("poc/morph"),
            XzgDeepLink.route("poc", path = "/morph", pocEnabled = true),
        )
        assertEquals(
            DeepLinkAction.OpenPoc("poc/morph"),
            XzgDeepLink.parse("xzg://poc/morph"),
        )
    }

    @Test
    fun `poc transition path opens transition report`() {
        assertEquals(
            DeepLinkAction.OpenPoc("poc/transition"),
            XzgDeepLink.route("poc", path = "/transition", pocEnabled = true),
        )
        assertEquals(
            DeepLinkAction.OpenPoc("poc/transition"),
            XzgDeepLink.parse("xzg://poc/transition"),
        )
    }

    @Test
    fun `poc bare host still opens launcher (phase 2 behavior kept)`() {
        // xzg://poc（无 path）仍进 launcher；显式 /launcher 亦可。
        assertEquals(DeepLinkAction.OpenPocLauncher, XzgDeepLink.parse("xzg://poc"))
        assertEquals(DeepLinkAction.OpenPocLauncher, XzgDeepLink.parse("xzg://poc/"))
        assertEquals(DeepLinkAction.OpenPocLauncher, XzgDeepLink.parse("xzg://poc/launcher"))
        assertEquals(
            DeepLinkAction.OpenPocLauncher,
            XzgDeepLink.route("poc", pocEnabled = true),
        )
        assertEquals(
            DeepLinkAction.OpenPocLauncher,
            XzgDeepLink.route("poc", path = null, pocEnabled = true),
        )
    }

    @Test
    fun `poc illegal path is ignored`() {
        assertEquals(DeepLinkAction.Ignore, XzgDeepLink.parse("xzg://poc/bogus"))
        assertEquals(DeepLinkAction.Ignore, XzgDeepLink.parse("xzg://poc/Droplet"))
        assertEquals(
            DeepLinkAction.Ignore,
            XzgDeepLink.route("poc", path = "/nope", pocEnabled = true),
        )
    }

    @Test
    fun `poc per-screen deep links are ignored when poc disabled (release)`() {
        // release 构建：四个逐 PoC 深链同样映射为 Ignore（route 不注册）。
        listOf("/droplet", "/glass", "/morph", "/transition", null, "/").forEach { path ->
            assertEquals(
                "path=$path must be ignored in release",
                DeepLinkAction.Ignore,
                XzgDeepLink.route("poc", path = path, pocEnabled = false),
            )
        }
    }

    @Test
    fun `poc speed query param is parsed into action`() {
        assertEquals(
            DeepLinkAction.OpenPoc("poc/droplet", "slow"),
            XzgDeepLink.parse("xzg://poc/droplet?speed=slow"),
        )
        assertEquals(
            DeepLinkAction.OpenPoc("poc/glass", "normal"),
            XzgDeepLink.parse("xzg://poc/glass?speed=normal"),
        )
        // 无 speed 参数 → null（导航层保持当前档，不重置）
        assertEquals(
            DeepLinkAction.OpenPoc("poc/morph"),
            XzgDeepLink.parse("xzg://poc/morph"),
        )
        // 非法 speed 值原样透传（导航层 modeForQuery → null → 保持当前档）
        assertEquals(
            DeepLinkAction.OpenPoc("poc/transition", "fast"),
            XzgDeepLink.parse("xzg://poc/transition?speed=fast"),
        )
    }
}
