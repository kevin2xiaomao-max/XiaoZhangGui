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
 * 路由表（对应 iOS AppDeepLink.swift）：
 * - xzg://ai（无 query / mode≠voice）→ OpenAssistantTab
 * - xzg://ai?mode=voice → OpenAssistantVoice
 * - xzg://voice → OpenVoice
 * - xzg://quickrecord / xzg://quick → OpenQuickRecord
 * - xzg://todo → OpenTodoTab（Android 侧扩展，iOS 无此 host）
 * - 未知 host / 非 xzg scheme / 空 / 非法 → Ignore（不崩溃）
 */
class DeepLinkParseTest {

    @Test
    fun `xzg ai opens assistant tab`() {
        assertEquals(DeepLinkAction.OpenAssistantTab, XzgDeepLink.parse("xzg://ai"))
    }

    @Test
    fun `xzg ai with non-voice mode opens assistant tab`() {
        assertEquals(DeepLinkAction.OpenAssistantTab, XzgDeepLink.parse("xzg://ai?mode=text"))
    }

    @Test
    fun `xzg ai mode voice opens assistant voice`() {
        assertEquals(DeepLinkAction.OpenAssistantVoice, XzgDeepLink.parse("xzg://ai?mode=voice"))
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
        assertEquals(DeepLinkAction.OpenAssistantTab, XzgDeepLink.route("ai"))
        assertEquals(DeepLinkAction.OpenAssistantVoice, XzgDeepLink.route("ai", "voice"))
        assertEquals(DeepLinkAction.OpenAssistantTab, XzgDeepLink.route("ai", "other"))
        assertEquals(DeepLinkAction.OpenTodoTab, XzgDeepLink.route("todo"))
        assertEquals(DeepLinkAction.Ignore, XzgDeepLink.route(null))
        assertEquals(DeepLinkAction.Ignore, XzgDeepLink.route("unknown"))
    }

    // ---------- Phase 1 语义回归 worker 补齐：解析层边界 ----------

    @Test
    fun `ai mode empty string opens assistant tab`() {
        assertEquals(DeepLinkAction.OpenAssistantTab, XzgDeepLink.parse("xzg://ai?mode="))
    }

    @Test
    fun `ai mode voice with extra query params still opens assistant voice`() {
        assertEquals(
            DeepLinkAction.OpenAssistantVoice,
            XzgDeepLink.parse("xzg://ai?mode=voice&foo=bar")
        )
    }

    @Test
    fun `ai mode matching is case sensitive`() {
        // 当前实现 mode == "voice" 精确匹配；大写 VOICE 走默认分支（锁定行为，非语义变更）
        assertEquals(DeepLinkAction.OpenAssistantTab, XzgDeepLink.parse("xzg://ai?mode=VOICE"))
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
}
