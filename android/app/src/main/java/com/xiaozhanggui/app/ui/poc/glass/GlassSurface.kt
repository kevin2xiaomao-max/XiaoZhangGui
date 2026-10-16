package com.xiaozhanggui.app.ui.poc.glass

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import com.xiaozhanggui.app.ui.theme.LocalXzgPalettes

/**
 * PoC-2 玻璃表面（Design System §2.1）。
 *
 * 三档独立实现语义（基于 Android 平台能力，不抄任何外部管线）：
 * - T1：预构建一次模糊快照——快照经 `remember(domain)` 缓存，重组/显隐
 *   永不重建；显隐只改 alpha。真机接线点（Phase 3）：对 BackdropDomain 的
 *   预渲染位图做一次 `RenderEffect.createBlurEffect(10dp)`（API 31+），
 *   快照位图常驻内存；Paparazzi/JVM 下用等效静态柔和渐变（已模糊态）
 *   表达同一像素语义：静态、预构建、只改 alpha。
 * - T2：静态半透明 + 双层 hairline（外高光 1dp + 内暗线 1dp），无模糊成本。
 * - T3：半透明底色（不透明度按对比度守恒提高）+ 单层 hairline，无模糊。
 *
 * 几何铁律：三档共用 [GlassGeometry.Default] 同一实例（圆角/间距/层级一致），
 * 由 `GlassGeometryTest.assertSame` 锁定。
 */
// Material: Glass/T1
// Backdrop-Domain: poc-demo-feed（具名背景域，禁自采样——由调用方传入）
// Role: floating-sheet
// Fallback: T2 -> T3
@Composable
fun GlassSurface(
    tier: GlassTier,
    declaration: GlassMaterialDeclaration,
    modifier: Modifier = Modifier,
    visible: Boolean = true,
    content: @Composable () -> Unit,
) {
    // 三档同一几何实例：圆角/间距/层级与档位无关。
    val geometry = GlassGeometry.forTier(tier)
    val shape = RoundedCornerShape(geometry.cornerRadius)
    // 显隐只改 alpha：快照层（T1）由 remember 缓存，不按帧重建。
    val visibilityAlpha by animateFloatAsState(
        targetValue = if (visible) 1f else 0f,
        label = "glass-visibility-alpha",
    )
    val scrimAlpha = GlassContrast.overlayAlpha.getValue(tier)

    Box(
        modifier = modifier
            .clip(shape)
            .alpha(visibilityAlpha),
    ) {
        // ── 材质层（按档位）──
        when (tier) {
            GlassTier.T1_FIDELITY -> GlassSnapshotLayer(domain = declaration.backdropDomain)
            GlassTier.T2_BALANCED,
            GlassTier.T3_ESSENTIAL,
            -> Unit // T2/T3 无模糊快照层：零 GPU 模糊成本
        }
        // ── 对比度守恒底色（不透明度 T1 < T2 < T3 单调递增）──
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(glassOverlayColor().copy(alpha = scrimAlpha)),
        )
        // ── hairline 描边（T2 双层，T1/T3 单层）──
        GlassHairline(tier = tier, geometry = geometry, shape = shape)
        // ── 内容（调用方提供；三档同一份内容，保证"同一文字"可比）──
        Box(modifier = Modifier.padding(geometry.contentPadding)) {
            content()
        }
    }
}

/**
 * T1 预构建模糊快照层。
 *
 * 语义（独立实现）："背景静止时预构建一次模糊快照"——
 * - `remember(domain)`：快照描述符只构建一次，重组不重建；
 * - 显隐/动画只改外层 alpha，本层无任何按帧更新；
 * - 真机（Phase 3 接线）：`RenderEffect.createBlurEffect(10dp)` 作用于
 *   BackdropDomain 预渲染位图，快照位图常驻，API < 31 / 低内存走 T2；
 * - Paparazzi/JVM：等效静态柔和渐变（已模糊态），像素语义一致。
 */
@Composable
private fun GlassSnapshotLayer(domain: BackdropDomain) {
    // 预构建：只与 domain 有关，remember 缓存，永不按帧重建。
    val snapshotBrush = remember(domain) {
        Brush.verticalGradient(
            colors = listOf(
                Color(0xFFA9C2B1),
                Color(0xFF7FA08A),
                Color(0xFF5B7A66),
            ),
        )
    }
    val blobShape = remember { RoundedCornerShape(28.dp) }
    Box(modifier = Modifier.fillMaxSize()) {
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(snapshotBrush),
        )
        // 模拟"模糊后的内容色块"：静态柔和形状（已模糊态的一部分，随快照预构建）
        Box(
            modifier = Modifier
                .fillMaxWidth(0.62f)
                .height(64.dp)
                .offset(18.dp, 26.dp)
                .clip(blobShape)
                .background(Color.White.copy(alpha = 0.22f)),
        )
        Box(
            modifier = Modifier
                .fillMaxWidth(0.44f)
                .height(40.dp)
                .align(Alignment.BottomEnd)
                .offset((-14.dp), (-18.dp))
                .clip(blobShape)
                .background(Color(0xFF2E4438).copy(alpha = 0.20f)),
        )
    }
}

/** 玻璃底色：Light=白，Dark=深 surface（与对比度标定一致） */
@Composable
private fun glassOverlayColor(): Color {
    val palettes = LocalXzgPalettes.current
    return remember(palettes.isDark) {
        if (palettes.isDark) Color(0xFF232A26) else Color.White
    }
}

/** hairline 描边：T2 双层（外高光 + 内暗线），T1/T3 单层高光 */
@Composable
private fun GlassHairline(
    tier: GlassTier,
    geometry: GlassGeometry,
    shape: RoundedCornerShape,
) {
    val palettes = LocalXzgPalettes.current
    val highlight = remember(palettes.isDark) {
        if (palettes.isDark) Color.White.copy(alpha = 0.22f)
        else Color.White.copy(alpha = 0.55f)
    }
    when (tier) {
        GlassTier.T2_BALANCED -> {
            // 双层 hairline：外 1dp 高光 + 内 1dp 暗线
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .border(geometry.hairline, highlight, shape),
            )
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(geometry.hairline)
                    .border(
                        width = geometry.hairline,
                        color = Color.Black.copy(alpha = 0.10f),
                        shape = RoundedCornerShape(geometry.cornerRadius - geometry.hairline),
                    ),
            )
        }
        GlassTier.T1_FIDELITY,
        GlassTier.T3_ESSENTIAL,
        -> {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .border(geometry.hairline, highlight, shape),
            )
        }
    }
}

/**
 * 三档展示卡（截图 + PoC 屏共用）。
 *
 * 同一具名背景域（[BackdropDomain.POC_DEMO_FEED]）、同一几何、同一份文字内容；
 * 档位不同只改变材质层/底色不透明度/hairline 层数。
 *
 * @param visible autodrive 三档轮切用：false 时只改 alpha 淡出
 *  （[GlassSurface] 的 `animateFloatAsState` 产生真实显隐动画帧），
 *   布局占位不变。默认 true，手动模式与 Paparazzi 行为零变化。
 */
// Material: Glass/T{1,2,3}
// Backdrop-Domain: poc-demo-feed
// Role: floating-sheet
// Fallback: T2 -> T3
@Composable
fun GlassTierShowcase(tier: GlassTier, visible: Boolean = true) {
    val declaration = remember(tier) {
        GlassMaterialDeclaration(
            tier = tier,
            backdropDomain = BackdropDomain.POC_DEMO_FEED,
            role = "floating-sheet",
            fallback = when (tier) {
                GlassTier.T1_FIDELITY -> listOf(GlassTier.T2_BALANCED, GlassTier.T3_ESSENTIAL)
                GlassTier.T2_BALANCED -> listOf(GlassTier.T3_ESSENTIAL)
                GlassTier.T3_ESSENTIAL -> emptyList()
            },
        )
    }
    val palettes = LocalXzgPalettes.current
    Box(modifier = Modifier.fillMaxWidth()) {
        // 具名背景域内容（PoC 假背景：静态 feed 色条，不触碰生产页面）
        PocBackdropFeed()
        GlassSurface(
            tier = tier,
            declaration = declaration,
            visible = visible,
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 20.dp, vertical = 28.dp),
        ) {
            Column {
                Text(
                    text = "玻璃 ${tier.tierId} · ${tierName(tier)}",
                    color = palettes.background.textPrimary,
                )
                Spacer(modifier = Modifier.height(6.dp))
                Text(
                    text = "同一文字 · 同一几何 · 对比度守恒",
                    color = palettes.background.textSecondary,
                )
            }
        }
    }
}

private fun tierName(tier: GlassTier): String = when (tier) {
    GlassTier.T1_FIDELITY -> "质感"
    GlassTier.T2_BALANCED -> "性能"
    GlassTier.T3_ESSENTIAL -> "超级性能"
}

/** PoC 假背景域内容：静态渐变 + feed 色条（仅 PoC 隔离区使用） */
@Composable
private fun PocBackdropFeed() {
    val feedBrush = remember {
        Brush.verticalGradient(
            colors = listOf(Color(0xFFE8E4D8), Color(0xFFD8D2C0), Color(0xFFC4BCA6)),
        )
    }
    val darkFeedBrush = remember {
        Brush.verticalGradient(
            colors = listOf(Color(0xFF23282A), Color(0xFF1A1E20), Color(0xFF121516)),
        )
    }
    val palettes = LocalXzgPalettes.current
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .background(if (palettes.isDark) darkFeedBrush else feedBrush)
            .padding(16.dp),
    ) {
        repeat(4) { index ->
            Box(
                modifier = Modifier
                    .fillMaxWidth(if (index % 2 == 0) 1f else 0.72f)
                    .height(44.dp)
                    .clip(RoundedCornerShape(12.dp))
                    .background(
                        if (palettes.isDark) Color.White.copy(alpha = 0.06f)
                        else Color(0xFF6B7A6E).copy(alpha = 0.16f),
                    ),
            )
            Spacer(modifier = Modifier.height(10.dp))
        }
    }
}
