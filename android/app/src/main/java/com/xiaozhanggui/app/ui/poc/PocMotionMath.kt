package com.xiaozhanggui.app.ui.poc

import kotlin.math.PI
import kotlin.math.sin

/**
 * PoC 共享的纯运动数学（Design System §2.2 / §2.3）。
 *
 * - 全部纯函数、可 JVM 单测；
 * - 数值独立标定（V371 时长档 100/180/280/420 为时间基准；
 *   相位分数与过冲幅度为 PoC 独立推导，**未复制 SleepDown 的 260ms/2.2%/3.5% 等数值**）；
 * - 许可证红线：只借鉴"分层/具名降级"思想，实现与数值均为独立推导。
 */
object PocMotionMath {

    /** 钳制到 [0,1]。 */
    fun clamp01(v: Float): Float = v.coerceIn(0f, 1f)

    /**
     * smoothstep 缓动：3t²−2t³（t 先钳制到 [0,1]）。
     *
     * 端点精确：smoothstep(0)=0、smoothstep(1)=1；单调递增。
     */
    fun smoothstep(t: Float): Float {
        val x = clamp01(t)
        return x * x * (3f - 2f * x)
    }

    /**
     * 相位子进度：master 进度 [p] 在 [start,end] 窗口内做 smoothstep 映射，
     * 窗口之外钳制为 0/1。
     *
     * 慢放逐帧符合性：每个相位的起止边界是**精确**的（p≤start→0，p≥end→1），
     * 相位顺序断言只依赖边界，不依赖中间 easing 形状。
     */
    fun phaseProgress(p: Float, start: Float, end: Float): Float {
        require(end > start) { "phase window must be non-empty: [$start,$end]" }
        if (p <= start) return 0f
        if (p >= end) return 1f
        return smoothstep((p - start) / (end - start))
    }

    /**
     * 单峰过冲：q∈[0,1] → 1 + amplitude·sin(πq)。
     *
     * - 仅一次峰值（q=0.5 处）；
     * - q=0/1 时**精确**为 1（无残留）；
     * - 幅度由调用方传入（PoC-1/PoC-3 均为 0.025，即 2.5% < 3%，独立标定）。
     */
    fun singleOvershoot(q: Float, amplitude: Float): Float {
        require(amplitude in 0f..0.03f) {
            "overshoot amplitude must be in [0, 0.03] (<3%): $amplitude"
        }
        val x = clamp01(q)
        if (x == 0f || x == 1f) return 1f
        return 1f + amplitude * sin(PI * x).toFloat()
    }

    /** 线性插值（Float 域；调用方负责 dp/px 映射）。 */
    fun lerp(a: Float, b: Float, t: Float): Float = a + (b - a) * t
}
