package com.xiaozhanggui.app.ui.components

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.xiaozhanggui.app.ui.theme.LocalXzgPalettes
import com.xiaozhanggui.app.ui.theme.XzgDimens
import com.xiaozhanggui.app.ui.theme.XzgType

/** 图标泡语气。对应 iOS `V32BubbleTone`：brand/amber/danger/info/neutral。 */
enum class BubbleTone { BRAND, AMBER, DANGER, INFO, NEUTRAL }

/**
 * V32 图标泡。对应 iOS `V32IconBubble`：浅底圆角矩形（bubble 圆角 12dp）+
 * 语气色图标。fill/tint 映射与 iOS 一致（brandSoft/amberSoft/dangerSoft/infoSoft/neutralSoft）。
 */
@Composable
fun V32IconBubble(icon: ImageVector, tone: BubbleTone, modifier: Modifier = Modifier, size: Dp = 42.dp) {
    val palettes = LocalXzgPalettes.current
    val (fill, tint) = when (tone) {
        BubbleTone.BRAND -> palettes.accent.accentSoft to palettes.accent.accent
        BubbleTone.AMBER -> palettes.fixed.amberSoft to palettes.fixed.amber
        BubbleTone.DANGER -> palettes.fixed.dangerSoft to palettes.fixed.danger
        BubbleTone.INFO -> palettes.fixed.infoSoft to palettes.fixed.info
        BubbleTone.NEUTRAL -> palettes.background.neutralSoft to palettes.background.textSecondary
    }
    Box(
        modifier = modifier
            .size(size)
            .clip(RoundedCornerShape(XzgDimens.bubble))
            .background(fill),
        contentAlignment = Alignment.Center
    ) {
        Icon(
            imageVector = icon,
            contentDescription = null,
            tint = tint,
            modifier = Modifier.size(XzgDimens.iconRegular)
        )
    }
}

/**
 * 状态胶囊语气。对应 iOS `V32Status`：pending/delivering/done/expiry/info，
 * 另加 NEUTRAL 兜底（与 pending/done 同色）。
 */
enum class PillTone { PENDING, DELIVERING, DONE, EXPIRY, INFO, NEUTRAL }

/**
 * V32 状态胶囊。对应 iOS `V32StatusPill`：6dp 色点 + pill 字阶文本，
 * 文本/底色/色点按语气映射（pending/done/neutral 中性灰；delivering/info 品牌绿；expiry 琥珀）。
 */
@Composable
fun V32StatusPill(text: String, tone: PillTone, modifier: Modifier = Modifier) {
    val palettes = LocalXzgPalettes.current
    val (fg, bg, dot) = when (tone) {
        PillTone.DELIVERING, PillTone.INFO ->
            Triple(palettes.accent.accent, palettes.accent.accentSoft, palettes.accent.accent)
        PillTone.EXPIRY ->
            Triple(palettes.fixed.amber, palettes.fixed.amberSoft, palettes.fixed.amber)
        PillTone.PENDING, PillTone.DONE, PillTone.NEUTRAL ->
            Triple(
                palettes.background.textSecondary,
                palettes.background.neutralSoft,
                palettes.background.neutral
            )
    }
    Row(
        modifier = modifier
            .clip(CircleShape)
            .background(bg)
            .padding(horizontal = 9.dp, vertical = 5.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Box(
            modifier = Modifier
                .size(6.dp)
                .clip(CircleShape)
                .background(dot)
        )
        Text(
            text = text,
            style = XzgType.pill,
            color = fg,
            modifier = Modifier.padding(start = 5.dp)
        )
    }
}

/**
 * V32 进度条。对应 iOS `V32ProgressBar`：neutralSoft 轨道胶囊 + 品牌色填充胶囊，
 * progress 按 0..1 钳制。
 */
@Composable
fun V32ProgressBar(progress: Float, modifier: Modifier = Modifier, height: Dp = 7.dp) {
    val palettes = LocalXzgPalettes.current
    val clamped = progress.coerceIn(0f, 1f)
    Box(
        modifier = modifier
            .fillMaxWidth()
            .height(height)
            .clip(CircleShape)
            .background(palettes.background.neutralSoft)
    ) {
        Box(
            modifier = Modifier
                .fillMaxHeight()
                .fillMaxWidth(clamped)
                .clip(CircleShape)
                .background(palettes.accent.accent)
        )
    }
}

/**
 * 折线迷你图：Canvas 自绘。values 为空时画空画布（不崩溃、不画线）；
 * 单点时画一个圆点；多点时画圆角折线。
 */
@Composable
fun Sparkline(values: List<Double>, modifier: Modifier = Modifier, color: Color) {
    Canvas(modifier = modifier) {
        if (values.isEmpty()) return@Canvas
        val min = values.minOrNull() ?: 0.0
        val max = values.maxOrNull() ?: 0.0
        val range = (max - min).takeIf { it > 0 } ?: 1.0
        val points = values.mapIndexed { index, v ->
            val x = if (values.size == 1) size.width / 2f
            else index.toFloat() / (values.size - 1) * size.width
            val y = size.height - ((v - min) / range).toFloat() * size.height
            Offset(x, y)
        }
        if (points.size == 1) {
            drawCircle(color = color, radius = 3.dp.toPx(), center = points[0])
        } else {
            val path = Path().apply {
                moveTo(points[0].x, points[0].y)
                points.drop(1).forEach { lineTo(it.x, it.y) }
            }
            drawPath(
                path = path,
                color = color,
                style = Stroke(
                    width = 2.dp.toPx(),
                    cap = StrokeCap.Round,
                    join = StrokeJoin.Round
                )
            )
        }
    }
}
