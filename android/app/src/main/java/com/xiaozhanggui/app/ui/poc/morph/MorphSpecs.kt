package com.xiaozhanggui.app.ui.poc.morph

import com.xiaozhanggui.app.ui.motion.DurationTier
import com.xiaozhanggui.app.ui.motion.MotionSpec
import com.xiaozhanggui.app.ui.motion.Overshoot
import com.xiaozhanggui.app.ui.motion.TransitionKind

/**
 * PoC-3 连续形变的 MotionSpec 声明（Design System §2.3）。
 *
 * - transitionKind = FADE：连续形变是卡片**自身**几何的连续变化
 *   （圆角包络/锥度/过冲），不是锚点转场，不用 SHARED_ANCHOR；
 * - durationTier = STANDARD（280ms，V371 档）；
 * - overshoot = CONTENT_ONLY（卡片是内容层；"内容可过冲、页面必单调"）；
 * - fallbackKind = FADE；Reduce Motion → FAST 短淡入（MotionPolicy 统一处理）。
 *
 * 与 PoC-1 一样：本声明独立存放，不进 Phase 1 `XzgMotionSpecs.all`
 * 注册表，随 PoC 代码受 [com.xiaozhanggui.app.ui.poc.PocGate] 编译门约束。
 */
object MorphSpecs {
    val CARD_MORPH = MotionSpec(
        id = "v38.poc.morph.card",
        transitionKind = TransitionKind.FADE,
        durationTier = DurationTier.STANDARD,
        overshoot = Overshoot.CONTENT_ONLY,
        interruptible = true,
        fallbackKind = TransitionKind.FADE,
        description = "PoC-3 连续形变：卡片拖拽/展开的圆角包络+前缘锥度+末段一次过冲；" +
            "稳定态 200ms 后释放临时形变",
    )
}
