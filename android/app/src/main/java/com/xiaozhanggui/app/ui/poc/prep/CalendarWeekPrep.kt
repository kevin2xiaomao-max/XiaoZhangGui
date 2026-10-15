package com.xiaozhanggui.app.ui.poc.prep

import com.xiaozhanggui.app.ui.motion.DurationTier
import com.xiaozhanggui.app.ui.motion.MotionContext
import com.xiaozhanggui.app.ui.motion.MotionPolicy
import com.xiaozhanggui.app.ui.motion.MotionSpec
import com.xiaozhanggui.app.ui.motion.Overshoot
import com.xiaozhanggui.app.ui.motion.ResolvedMotion
import com.xiaozhanggui.app.ui.motion.TransitionKind
import com.xiaozhanggui.app.ui.poc.PocMotionMath.phaseProgress
import com.xiaozhanggui.app.ui.poc.PocMotionMath.smoothstep

/**
 * 日历周切换双轨运动的 MotionSpec 声明草案（Design System §3.3）。
 *
 * - 升级点（`CalendarScreen` 周视图左右切换）：页面容器周做单调滑动
 *   （无过冲，「页面必单调」），日期格内容做分组错峰淡入；
 *   连续快速滑动时中途反转保持速度续播（解决动画排队卡顿）。
 * - 双轨（§1.4 借鉴 4.1，但数值独立标定）：
 *   - 容器轨 [CONTAINER_SLIDE]：单调 tween，无过冲，FAST 180ms；
 *   - 内容轨 [CONTENT_STAGGER]：分组错峰淡入（每列一组，共 7 组，
 *     组间步长独立标定，见 [STAGGER_STEP_MS]）。
 * - 当前生产行为：周切换瞬切（无动画）。
 * - 密集列表规则（§1.4 借鉴 4.2）：当周事件卡片 > 10 时，
 *   内容错峰退化为整面单调（[MotionPolicy] dense-list 分支，具名 `dense-list`）。
 *
 * **不接线生产页面**：本对象只声明，不被 `CalendarScreen` 引用；
 * Phase 3 接线时才把两个 spec 的 `enabled` 绑定到 [PrepSwitches.CALENDAR_WEEK]。
 */
object CalendarWeekPrep {

    /** 页面容器周：单调滑动，无过冲（铁律「页面必单调」）。 */
    val CONTAINER_SLIDE = MotionSpec(
        id = "v38.prep.calendar.week-container-slide",
        transitionKind = TransitionKind.FADE, // 「淡入淡出+轻微位移」：滑动走位移分量
        durationTier = DurationTier.FAST, // 180ms：周切换高频手势，用快速档
        overshoot = Overshoot.NONE, // 容器无过冲（铁律）
        interruptible = true, // 中途反转保持速度续播（§3.3 验收 #3）
        fallbackKind = TransitionKind.FADE,
        enabled = true, // Phase 3 接线绑定 PrepSwitches.CALENDAR_WEEK
        description = "日历周切换容器轨：单调滑动无过冲；中途反转速度连续",
    )

    /** 日期格内容：分组错峰淡入（容器轨的伴随轨）。 */
    val CONTENT_STAGGER = MotionSpec(
        id = "v38.prep.calendar.week-content-stagger",
        transitionKind = TransitionKind.FADE,
        durationTier = DurationTier.FAST, // 与容器同窗 180ms；错峰只吃窗口内的延迟
        overshoot = Overshoot.NONE, // 淡入不需要过冲
        interruptible = true,
        fallbackKind = TransitionKind.FADE,
        enabled = true, // Phase 3 接线绑定 PrepSwitches.CALENDAR_WEEK
        description = "日历周切换内容轨：7 列分组错峰淡入；密集列表时退化为整面单调",
    )

    /** 内容分组数：周视图 7 个日期列，每列一组（设计稿标定；真机帧率验证后可调）。 */
    const val GROUP_COUNT = 7

    /**
     * 组间错峰步长（ms，独立标定——**未复制 SleepDown 的 6组×18ms**）。
     * 7 组 × 12ms = 最后一组在 72ms 处启动，留 108ms 做淡入；
     * 真机 ≥55fps 验证前为暂定值（NOT RUN，见准备文档）。
     */
    const val STAGGER_STEP_MS = 12f

    /**
     * 第 [groupIndex] 组的启动延迟（ms）：`groupIndex × STAGGER_STEP_MS`。
     * 单调递增（后组不抢跑前组）。
     */
    fun groupDelayMs(groupIndex: Int): Float {
        require(groupIndex in 0 until GROUP_COUNT) { "groupIndex out of range: $groupIndex" }
        return groupIndex * STAGGER_STEP_MS
    }

    /**
     * 第 [groupIndex] 组的 alpha：master 进度 p∈[0,1]（FAST 180ms 窗），
     * 在 [delayMs, 180ms] 窗口内 smoothstep 淡入；窗口外钳制 0/1。
     * - 端点精确：groupAlpha(0,·)=0、groupAlpha(1,·)=1（全组）；
     * - 后组在 p 很小时恒为 0（错峰可见，§3.3 验收 #1）。
     */
    fun groupAlpha(p: Float, groupIndex: Int, windowMs: Float = DurationTier.FAST.ms.toFloat()): Float {
        val delayFrac = groupDelayMs(groupIndex) / windowMs
        return phaseProgress(p, delayFrac, 1f)
    }

    /**
     * 容器滑动位移分数：单调 smoothstep（无过冲断言：∀p∈[0,1] 单调递增）。
     * 反转时用 [tweenVelocity] 取当前速度播种，保证速度连续（§3.3 验收 #3）。
     */
    fun slideProgress(p: Float): Float = smoothstep(p)

    /**
     * smoothstep 速度包络（一阶导数）：v(p) = 6p(1−p)。
     * - v(0)=v(1)=0（起止静止）；v(0.5)=1.5（峰值）；
     * - 处处 ≥0（单调保证）；
     * - 中途反转时：新动画的初速度 = v(p_interrupt) × (剩余位移/总位移)，
     *   无「急停再起」。
     */
    fun tweenVelocity(p: Float): Float {
        val x = p.coerceIn(0f, 1f)
        return 6f * x * (1f - x)
    }

    /** 容器轨解析（纯函数）。 */
    fun resolveContainer(spec: MotionSpec = CONTAINER_SLIDE, ctx: MotionContext): ResolvedMotion =
        MotionPolicy.resolve(spec, ctx)

    /** 内容轨解析（纯函数；denseList=true → 具名 `dense-list` 退化为整面单调）。 */
    fun resolveContent(spec: MotionSpec = CONTENT_STAGGER, ctx: MotionContext): ResolvedMotion =
        MotionPolicy.resolve(spec, ctx)
}
