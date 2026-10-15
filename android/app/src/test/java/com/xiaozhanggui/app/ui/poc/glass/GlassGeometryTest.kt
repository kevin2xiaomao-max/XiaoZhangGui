package com.xiaozhanggui.app.ui.poc.glass

import androidx.compose.ui.unit.dp
import com.xiaozhanggui.app.ui.theme.XzgDimens
import org.junit.Assert.assertEquals
import org.junit.Assert.assertSame
import org.junit.Test

/**
 * PoC-2：三档几何一致性（Design System §2.1 / §4 检查表）。
 *
 * T3 降级时用户看到的应是"同样的卡片，只是没那么透"——几何 token
 * 全部引用既有 [XzgDimens]，且 [GlassGeometry.forTier] 对任意档位
 * 返回同一单例（`assertSame` 锁定）。
 */
class GlassGeometryTest {

    @Test
    fun `geometry tokens reference existing xzg dimens`() {
        assertEquals(XzgDimens.card, GlassGeometry.Default.cornerRadius)
        assertEquals(XzgDimens.cardPad, GlassGeometry.Default.contentPadding)
        assertEquals(XzgDimens.cardGap, GlassGeometry.Default.interCardSpacing)
        assertEquals(1.dp, GlassGeometry.Default.hairline)
        assertEquals(0.dp, GlassGeometry.Default.elevation)
    }

    @Test
    fun `three tiers share the same geometry instance`() {
        val geometries = GlassTier.values().map { GlassGeometry.forTier(it) }
        assertSame(geometries[0], geometries[1])
        assertSame(geometries[1], geometries[2])
    }

    @Test
    fun `material declaration fallback chain is strictly downgrading`() {
        val declaration = GlassMaterialDeclaration(
            tier = GlassTier.T1_FIDELITY,
            backdropDomain = BackdropDomain.POC_DEMO_FEED,
            role = "floating-sheet",
            fallback = listOf(GlassTier.T2_BALANCED, GlassTier.T3_ESSENTIAL),
        )
        val comment = declaration.toDeclarationComment()
        assertEquals(
            "Material: Glass/T1\n" +
                "Backdrop-Domain: poc-demo-feed\n" +
                "Role: floating-sheet\n" +
                "Fallback: T2 -> T3",
            comment,
        )
    }
}
