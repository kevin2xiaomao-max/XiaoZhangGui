package com.xiaozhanggui.app.paparazzi

import com.xiaozhanggui.app.ui.poc.glass.GlassTier
import com.xiaozhanggui.app.ui.poc.glass.GlassTierShowcase
import org.junit.Test

/**
 * PoC-2 玻璃三档截图：三档 × Light/Dark 共 6 张。
 *
 * 同一具名背景域（poc-demo-feed）、同一几何（[GlassGeometry.Default] 单例）、
 * 同一份文字内容；档位不同只改变材质层 / 底色不透明度 / hairline 层数。
 * 几何像素一致性由 `GlassGeometryTest` 的 `assertSame` 锁定，
 * 此处做视觉回归（新增快照，首轮生成基线）。
 */
class GlassPocScreenshotTest : XzgScreenshotTest() {

    @Test
    fun glassT1Light() = pageLight("GlassPoc_T1") {
        GlassTierShowcase(tier = GlassTier.T1_FIDELITY)
    }

    @Test
    fun glassT1Dark() = pageDark("GlassPoc_T1") {
        GlassTierShowcase(tier = GlassTier.T1_FIDELITY)
    }

    @Test
    fun glassT2Light() = pageLight("GlassPoc_T2") {
        GlassTierShowcase(tier = GlassTier.T2_BALANCED)
    }

    @Test
    fun glassT2Dark() = pageDark("GlassPoc_T2") {
        GlassTierShowcase(tier = GlassTier.T2_BALANCED)
    }

    @Test
    fun glassT3Light() = pageLight("GlassPoc_T3") {
        GlassTierShowcase(tier = GlassTier.T3_ESSENTIAL)
    }

    @Test
    fun glassT3Dark() = pageDark("GlassPoc_T3") {
        GlassTierShowcase(tier = GlassTier.T3_ESSENTIAL)
    }
}
