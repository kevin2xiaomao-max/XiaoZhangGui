package com.xiaozhanggui.app.ui.poc.glass

import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.xiaozhanggui.app.ui.theme.XzgDimens

/**
 * 玻璃表面几何 token（Design System §2.1 / §4 检查表）。
 *
 * 铁律：**三档共用同一几何实例**——T3 降级时用户看到的应是
 * "同样的卡片，只是没那么透"，而不是"布局变了"。
 * [forTier] 对任意档位返回同一单例；几何一致性由
 * `GlassGeometryTest` 做 `assertSame` 断言。
 *
 * @param cornerRadius 圆角（与 V32 卡片 token 一致）
 * @param contentPadding 卡片内边距（与 V32 cardPad 一致）
 * @param interCardSpacing 卡片间距（与 V32 cardGap 一致）
 * @param hairline 描边宽度（1dp hairline；T2 双层即两条 1dp）
 * @param elevation 投影（玻璃无投影：层级靠材质表达，恒为 0）
 */
data class GlassGeometry(
    val cornerRadius: Dp,
    val contentPadding: Dp,
    val interCardSpacing: Dp,
    val hairline: Dp,
    val elevation: Dp,
) {
    companion object {
        /**
         * 三档唯一的几何实例（单例）。
         *
         * 取值全部引用 [XzgDimens] 现有 token，不新增数值：
         * 圆角 = card(18dp)，内边距 = cardPad(16dp)，间距 = cardGap(12dp)。
         */
        val Default = GlassGeometry(
            cornerRadius = XzgDimens.card,
            contentPadding = XzgDimens.cardPad,
            interCardSpacing = XzgDimens.cardGap,
            hairline = 1.dp,
            elevation = 0.dp,
        )

        /** 任意档位返回 [Default]——几何与档位无关。 */
        fun forTier(tier: GlassTier): GlassGeometry = Default
    }
}
