package com.xiaozhanggui.app.ui.poc.prep

import com.xiaozhanggui.app.ui.motion.DurationTier
import com.xiaozhanggui.app.ui.motion.MotionContext
import com.xiaozhanggui.app.ui.motion.MotionPolicy
import com.xiaozhanggui.app.ui.motion.MotionSpec
import com.xiaozhanggui.app.ui.motion.Overshoot
import com.xiaozhanggui.app.ui.motion.ResolvedMotion
import com.xiaozhanggui.app.ui.motion.TransitionKind
import com.xiaozhanggui.app.ui.poc.PocMotionMath.smoothstep
import com.xiaozhanggui.app.ui.theme.v371.V371Motion
import com.xiaozhanggui.app.ui.theme.MotionSurface
import com.xiaozhanggui.app.ui.theme.ResolvedMotion as LegacyResolvedMotion

/**
 * 经营数字 Motion 呈现的 MotionSpec 声明草案（Design System §3.4）。
 *
 * - 升级点（`PerformanceScreen` Hero 卡与关键数字）：① 数字变化时滚动递增/递减
 *   （STANDARD 280ms，numeric 语义）；② 涨跌颜色只用状态色（涨/跌各一套，
 *   不混用正文色体系，Design DNA 1.4）；③ 首次进入页面时数字从 0 滚动到实际值
 *   （仅首次进入，非每次可见——「首次进入才滚动」，避免廉价感）。
 * - 当前生产行为：数字瞬切。
 * - 颜色语义：[trendOf] 只输出语义（[Trend]），调用方映射到 V371 状态色 token；
 *   本包不引用颜色 token（纯函数隔离）。
 * - Reduce Motion：直接显示终值（numeric→终值，符合 `V371Motion.resolve`
 *   既有语义：`resolveMotion(NUMERIC, reduceMotion=true) = NONE`）。
 *
 * **不接线生产页面**：本对象只声明，不被 `PerformanceScreen` 引用；
 * Phase 3 接线时才把 `NUMBER_ROLL.enabled` 绑定到 [PrepSwitches.PERFORMANCE_NUMBER]。
 */
object PerformanceNumberPrep {

    val NUMBER_ROLL = MotionSpec(
        id = "v38.prep.performance.number-roll",
        transitionKind = TransitionKind.FADE, // numeric 滚动：转场 kind 取最小公分母 FADE
        durationTier = DurationTier.STANDARD, // 280ms（§3.4 验收 #1：时长落在 STANDARD ±20% 内）
        overshoot = Overshoot.NONE, // 数字滚动无过冲（过冲会读出错误金额）
        interruptible = true, // 数字连续变化时中途打断续播（不排队）
        fallbackKind = TransitionKind.FADE,
        enabled = true, // Phase 3 接线绑定 PrepSwitches.PERFORMANCE_NUMBER
        description = "经营核心数字滚动：STANDARD 280ms 递增/递减；" +
            "涨跌只用状态色；首次进入从 0 滚动；Reduce Motion 直接终值",
    )

    /** 涨跌语义（调用方映射到 V371 状态色 token；本包不引用颜色）。 */
    enum class Trend {
        /** 上涨：状态色「涨」一套。 */
        UP,

        /** 下跌：状态色「跌」一套。 */
        DOWN,

        /** 持平：中性状态色（不混用正文色体系）。 */
        FLAT,
    }

    /**
     * 滚动插值：p∈[0,1] → [from, to] 的 smoothstep 插值。
     * - 端点精确：rolledValue(0,·,·)=from、rolledValue(1,·,·)=to；
     * - 单调：from<to 时递增，from>to 时递减（滚动方向与涨跌一致）。
     */
    fun rolledValue(p: Float, from: Double, to: Double): Double {
        val t = smoothstep(p).toDouble()
        return from + (to - from) * t
    }

    /**
     * 涨跌判定（纯函数；阈值由调用方按业务口径传入，默认 0）：
     * to > from + epsilon → UP；to < from − epsilon → DOWN；否则 FLAT。
     */
    fun trendOf(from: Double, to: Double, epsilon: Double = 0.0): Trend = when {
        to > from + epsilon -> Trend.UP
        to < from - epsilon -> Trend.DOWN
        else -> Trend.FLAT
    }

    /**
     * 时长验收换算（§3.4 验收 #1）：STANDARD 280ms ±20% → [224, 336]ms。
     * 录屏逐帧测量滚动时长落在此区间即通过（JVM 侧只断言区间数学）。
     */
    fun standardDurationAcceptRangeMs(): ClosedRange<Int> {
        val nominal = DurationTier.STANDARD.ms
        return (nominal * 0.8).toInt()..(nominal * 1.2).toInt()
    }

    /** 全降级链解析（纯函数）。 */
    fun resolveNumber(spec: MotionSpec = NUMBER_ROLL, ctx: MotionContext): ResolvedMotion =
        MotionPolicy.resolve(spec, ctx)

    /**
     * Reduce Motion numeric 语义（§3.4 验收 #4）：直接显示终值。
     * 既有语义锚点：`V371Motion.resolve(NUMERIC, reduceMotion=true) == NONE`
     * （见 `MotionResolveTest` 回归测试），调用方读到 NONE 立即应用终值。
     */
    fun reduceMotionShowsEndValue(): Boolean =
        V371Motion.resolve(MotionSurface.NUMERIC, reduceMotion = true) == LegacyResolvedMotion.NONE
}
