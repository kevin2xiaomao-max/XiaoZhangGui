package com.xiaozhanggui.app.ui.poc.prep

import com.xiaozhanggui.app.ui.motion.DurationTier
import com.xiaozhanggui.app.ui.motion.MotionContext
import com.xiaozhanggui.app.ui.motion.MotionPolicy
import com.xiaozhanggui.app.ui.motion.MotionSpec
import com.xiaozhanggui.app.ui.motion.Overshoot
import com.xiaozhanggui.app.ui.motion.ResolvedMotion
import com.xiaozhanggui.app.ui.motion.TransitionKind
import com.xiaozhanggui.app.ui.poc.PocMotionMath

/**
 * 待办勾选触感 + 状态动画的 MotionSpec 声明草案（Design System §3.2）。
 *
 * - 升级点（`TodoScreen` 的 `V32Checkbox` 行）：① 按压瞬间触感反馈（Haptic，
 *   V371 唯一定义点）；② 勾选框 ✓ 绘制动画（FAST 180ms，打钩路径动画）；
 *   ③ 行内文字同步变为「已完成」样式（删除线淡入，非瞬切）；④ 取消勾选反向播放。
 * - 图标语义冻结：完成=实心态（CheckCircle）、未完成=空心态——动画只表达过渡，
 *   不改变图标语义（与 V3.7.1 验收修复轮 ScheduleTimelineRow 口径统一）。
 * - 当前生产行为：瞬切 + 无反馈 + 文字样式瞬切。
 * - 触感不是视觉动效：Reduce Motion 下**仍保留触感**（§3.2 验收 #4），
 *   只降级视觉绘制（直接切换终态）。
 *
 * **不接线生产页面**：本对象只声明，不被 `TodoScreen` 引用；
 * Phase 3 接线时才把 `TOGGLE.enabled` 绑定到 [PrepSwitches.TODO_TOGGLE]。
 */
object TodoTogglePrep {

    val TOGGLE = MotionSpec(
        id = "v38.prep.todo.toggle",
        transitionKind = TransitionKind.FADE,
        durationTier = DurationTier.FAST, // 180ms：打钩路径绘制档（§3.2 验收指定 FAST）
        overshoot = Overshoot.NONE, // 行状态切换无过冲（页面容器铁律的自然延伸）
        interruptible = true, // 绘制中途反向（勾选→取消）反向播放
        fallbackKind = TransitionKind.FADE, // 本身就是 FADE：降级 = 时长压档/清零过冲
        enabled = true, // Phase 3 接线绑定 PrepSwitches.TODO_TOGGLE
        description = "待办勾选/取消：FAST 180ms 打钩路径绘制 + 删除线淡入；" +
            "触感按压瞬间触发（非视觉动效，Reduce Motion 下保留）",
    )

    /**
     * 触感触发语义：按压瞬间（t=0）触发一次，与视觉绘制进度无关。
     * 测试用「模拟器日志断言」验证每次触发（§3.2 验收 #1；真机 NOT RUN）。
     */
    const val HAPTIC_TIMING = "press-instant"

    /**
     * 打钩路径绘制分数：master 进度 p∈[0,1] → 绘制分数（smoothstep）。
     * - 端点精确：checkDrawProgress(0)=0、checkDrawProgress(1)=1；
     * - 单调递增（慢放逐帧：路径只向前绘制，不回退）；
     * - 取消勾选：反向播放，即 draw(1−p)。
     */
    fun checkDrawProgress(p: Float): Float = PocMotionMath.smoothstep(p)

    /**
     * 删除线 alpha：勾选框绘制到 1/4 后开始淡入（与勾选框绘制同窗，STAGGER）。
     * p≤0.25 精确为 0（删除线不抢跑）；p=1 精确为 1。
     */
    fun strikeAlpha(p: Float): Float = PocMotionMath.phaseProgress(p, 0.25f, 1f)

    /**
     * 标题颜色过渡 t：与删除线同窗（完成态=灰色系，由 V371 状态色 token 映射，
     * 本函数只输出无量纲 t，不引用颜色 token）。
     */
    fun titleDimT(p: Float): Float = strikeAlpha(p)

    /** 全降级链解析（纯函数）。 */
    fun resolveToggle(spec: MotionSpec = TOGGLE, ctx: MotionContext): ResolvedMotion =
        MotionPolicy.resolve(spec, ctx)

    /**
     * Reduce Motion 终态语义（§3.2 验收 #4）：
     * - 视觉：直接切换终态（无绘制动画）——调用方读
     *   [ResolvedMotion.downgradeReason]==`reduce-motion` 后立即应用终值；
     * - 触感：保留（[HAPTIC_TIMING] 与视觉无关）。
     */
    data class ReduceMotionSemantics(
        /** 视觉是否直接终态（true = 跳过绘制动画）。 */
        val visualJumpsToEndState: Boolean,
        /** 触感是否保留（恒 true）。 */
        val hapticKept: Boolean,
    )

    fun reduceMotionSemantics(ctx: MotionContext): ReduceMotionSemantics {
        val resolved = resolveToggle(ctx = ctx.copy(reduceMotion = true))
        return ReduceMotionSemantics(
            visualJumpsToEndState = resolved.downgradeReason ==
                com.xiaozhanggui.app.ui.motion.MotionDowngradeReasons.REDUCE_MOTION,
            hapticKept = true,
        )
    }
}
