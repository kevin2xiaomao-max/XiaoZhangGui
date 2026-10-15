package com.xiaozhanggui.app.paparazzi

import com.xiaozhanggui.app.ui.poc.droplet.DropletMenuStatic
import com.xiaozhanggui.app.ui.poc.morph.MorphCardStatic
import org.junit.Test

/**
 * PoC-1 / PoC-3 Paparazzi 截图（Roadmap §3 PoC 验证方法）。
 *
 * - 展开中途 + 稳定态 × Light/Dark = 8 张；
 * - 渲染器与交互屏同构（`DropletMenuStatic` / `MorphCardStatic`
 *   与真机跑的是同一套纯渲染路径），截图即相位证据；
 * - 稳定态截图的几何一致性另有代码级断言
 *   （`DropletSteadyStateTest` / `MorphEnvelopeTest`）。
 */
class PocScreenshotTest : XzgScreenshotTest() {

    // ── PoC-1 液滴按钮菜单 ──

    @Test
    fun dropletMidLight() {
        // progress=0.45：纵向已 ≈90%、横向滞后、内容半显
        pageLight("Poc_droplet_mid") { DropletMenuStatic(progress = 0.45f) }
    }

    @Test
    fun dropletMidDark() {
        pageDark("Poc_droplet_mid") { DropletMenuStatic(progress = 0.45f) }
    }

    @Test
    fun dropletSteadyLight() {
        // progress=1.0：稳定态，几何 == 标准 token（V371Radius.group）
        pageLight("Poc_droplet_steady") { DropletMenuStatic(progress = 1f) }
    }

    @Test
    fun dropletSteadyDark() {
        pageDark("Poc_droplet_steady") { DropletMenuStatic(progress = 1f) }
    }

    // ── PoC-3 连续形变 ──

    @Test
    fun morphMidLight() {
        // progress=0.5：圆角隆起 + 前缘锥度可见
        pageLight("Poc_morph_mid") { MorphCardStatic(progress = 0.5f, settled = false) }
    }

    @Test
    fun morphMidDark() {
        pageDark("Poc_morph_mid") { MorphCardStatic(progress = 0.5f, settled = false) }
    }

    @Test
    fun morphSteadyLight() {
        // 稳定态：几何 == V371Radius.group token
        pageLight("Poc_morph_steady") { MorphCardStatic(progress = 0f, settled = true) }
    }

    @Test
    fun morphSteadyDark() {
        pageDark("Poc_morph_steady") { MorphCardStatic(progress = 0f, settled = true) }
    }
}
