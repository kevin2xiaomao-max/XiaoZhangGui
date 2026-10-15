package com.xiaozhanggui.app.ui.poc.droplet

import com.xiaozhanggui.app.ui.motion.DurationTier
import com.xiaozhanggui.app.ui.motion.MotionSpec
import com.xiaozhanggui.app.ui.motion.Overshoot
import com.xiaozhanggui.app.ui.motion.TransitionKind

/**
 * PoC-1 液滴按钮菜单的 MotionSpec 声明（Design System §2.3）。
 *
 * - transitionKind = SHARED_ANCHOR（仅 §2.2 批准的锚点展开场景）；
 * - durationTier = STANDARD（280ms：纵向展开用 STANDARD 档，§2.2 Phase C）；
 * - overshoot = CONTENT_ONLY（浮层是内容层非页面容器；"内容可过冲、页面必单调"）；
 * - fallbackKind = FADE（任何降级路径的显式声明：无锚点/Reduce Motion/
 *   低端档/帧率不足/能力探测失败 → FADE；具名原因见 [DropletDowngradeReasons]
 *   与 `MotionDowngradeReasons`）。
 *
 * 注意：本声明**不**进入 Phase 1 的 `XzgMotionSpecs.all` 注册表
 * （该注册表硬约束 transitionKind 一律 FADE；PoC 声明独立存放，
 * 随 PoC 代码一起受 [com.xiaozhanggui.app.ui.poc.PocGate] 编译门约束）。
 */
object DropletSpecs {
    val MENU_EXPAND = MotionSpec(
        id = "v38.poc.droplet.menu-expand",
        transitionKind = TransitionKind.SHARED_ANCHOR,
        durationTier = DurationTier.STANDARD,
        overshoot = Overshoot.CONTENT_ONLY,
        interruptible = true,
        fallbackKind = TransitionKind.FADE,
        description = "PoC-1 液滴按钮菜单：锚点→菜单六层动作（Phase A–F）；" +
            "降级 no-anchor/reduce-motion/perf-tier-essential/frame-rate → FADE",
    )
}
