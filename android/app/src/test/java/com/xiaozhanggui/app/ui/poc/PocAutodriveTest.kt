package com.xiaozhanggui.app.ui.poc

import com.xiaozhanggui.app.ui.navigation.DeepLinkAction
import com.xiaozhanggui.app.ui.navigation.XzgDeepLink
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * PoC autodrive 自动交互驱动测试（V3.8 真机验收补强）。
 *
 * 覆盖：
 * - [PocAutodrive.enabledForQuery] 纯函数映射；
 * - [PocAutodrive.setEnabled] 全局开关；
 * - `?autodrive=` 深链参数透传进 [DeepLinkAction.OpenPoc]（route / parse）；
 * - release 构建（pocEnabled=false）下 autodrive 参数亦被忽略。
 *
 * [PocAutodrive] 为进程级单例：每个用例结束强制复位 false，
 * 避免用例间顺序依赖（与 PocSpeedTest 同一模式）。
 */
class PocAutodriveTest {

    @After
    fun resetAutodrive() {
        PocAutodrive.setEnabled(false)
    }

    // ── enabledForQuery 纯函数映射 ──

    @Test
    fun `enabledForQuery maps truthy values`() {
        assertEquals(true, PocAutodrive.enabledForQuery("true"))
        assertEquals(true, PocAutodrive.enabledForQuery("1"))
        assertEquals(true, PocAutodrive.enabledForQuery("yes"))
    }

    @Test
    fun `enabledForQuery maps falsy values`() {
        assertEquals(false, PocAutodrive.enabledForQuery("false"))
        assertEquals(false, PocAutodrive.enabledForQuery("0"))
        assertEquals(false, PocAutodrive.enabledForQuery("no"))
    }

    @Test
    fun `enabledForQuery keeps state on null or illegal value`() {
        // 缺省 / 非法值 → null（保持当前状态，不重置；大小写敏感）
        assertNull(PocAutodrive.enabledForQuery(null))
        assertNull(PocAutodrive.enabledForQuery(""))
        assertNull(PocAutodrive.enabledForQuery("TRUE"))
        assertNull(PocAutodrive.enabledForQuery("False"))
        assertNull(PocAutodrive.enabledForQuery("on"))
        assertNull(PocAutodrive.enabledForQuery("2"))
    }

    // ── 全局开关 ──

    @Test
    fun `setEnabled toggles global flag`() {
        assertFalse(PocAutodrive.enabled)
        PocAutodrive.setEnabled(true)
        assertTrue(PocAutodrive.enabled)
        PocAutodrive.setEnabled(false)
        assertFalse(PocAutodrive.enabled)
    }

    // ── 深链 ?autodrive= 透传 ──

    @Test
    fun `route threads autodrive param into OpenPoc`() {
        assertEquals(
            DeepLinkAction.OpenPoc("poc/droplet", autodrive = "true"),
            XzgDeepLink.route("poc", path = "/droplet", pocEnabled = true, autodrive = "true"),
        )
        assertEquals(
            DeepLinkAction.OpenPoc("poc/glass", speed = "slow", autodrive = "false"),
            XzgDeepLink.route(
                "poc", path = "/glass", pocEnabled = true,
                speed = "slow", autodrive = "false",
            ),
        )
    }

    @Test
    fun `route without autodrive keeps null (no reset)`() {
        // 无 autodrive 参数 → null，导航层保持当前状态（与 ?speed= 口径一致）
        assertEquals(
            DeepLinkAction.OpenPoc("poc/droplet"),
            XzgDeepLink.route("poc", path = "/droplet", pocEnabled = true),
        )
    }

    @Test
    fun `parse extracts autodrive alongside speed`() {
        assertEquals(
            DeepLinkAction.OpenPoc("poc/glass", "slow", "true"),
            XzgDeepLink.parse("xzg://poc/glass?speed=slow&autodrive=true", pocEnabled = true),
        )
        assertEquals(
            DeepLinkAction.OpenPoc("poc/morph", autodrive = "true"),
            XzgDeepLink.parse("xzg://poc/morph?autodrive=true", pocEnabled = true),
        )
    }

    @Test
    fun `release build ignores autodrive param`() {
        // release 构建（pocEnabled=false）：autodrive 参数亦被忽略，一律 Ignore
        assertEquals(
            DeepLinkAction.Ignore,
            XzgDeepLink.parse("xzg://poc/morph?autodrive=true", pocEnabled = false),
        )
        assertEquals(
            DeepLinkAction.Ignore,
            XzgDeepLink.route("poc", path = "/droplet", pocEnabled = false, autodrive = "true"),
        )
    }
}
