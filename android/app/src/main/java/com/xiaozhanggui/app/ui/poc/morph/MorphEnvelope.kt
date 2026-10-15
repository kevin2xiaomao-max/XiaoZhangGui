package com.xiaozhanggui.app.ui.poc.morph

import com.xiaozhanggui.app.ui.poc.PocMotionMath.clamp01
import com.xiaozhanggui.app.ui.poc.PocMotionMath.singleOvershoot
import kotlin.math.PI
import kotlin.math.sin

/**
 * PoC-3 连续形变的包络数学（Design System §1.4 4.4 / §2.2 Phase D·F 思想迁移）。
 *
 * 全部纯函数、无量纲：输入运动进度 p∈[0,1]，输出包络系数；
 * 调用方（Compose 层）映射到 dp/px。
 *
 * 语义（合入标准 Roadmap §3 PoC-3）：
 * - 圆角跟随运动包络：`cornerBulge(p)` = sin(πp)，中段隆起、两端精确为 0；
 * - 前缘轻微锥度：`leadingTaperT(p)` 只加到运动方向前缘的两个角，
 *   静止/稳定态精确为 0；
 * - 末段一次过冲：`overshootScale(q)` 单峰、幅度 2.5%（<3%）、终点精确为 1；
 * - 稳定态释放：动画结束后 200ms（[SETTLE_RELEASE_MS]）→ `releasedValue`
 *   返回 token 精确值；200ms 内返回 null（仍持有临时形变）；
 * - 无快照残留：本包络只做数值插值，不创建 Bitmap/离屏快照；
 *   [MorphRuntimeState] 经反射测试保证无 Bitmap 字段。
 *
 * 数值独立标定（未复制 SleepDown 数值）：包络形状 sin(πp) 为通用数学，
 * 2.5% 幅度 / 200ms 释放 / 6dp 锥度上限均为 PoC 独立取值。
 */
object MorphEnvelope {

    /** 末段过冲幅度 2.5%（<3%；`singleOvershoot` 构造时强制 ≤0.03）。 */
    const val OVERSHOOT_AMPLITUDE = 0.025f

    /**
     * 稳定态释放延迟：动画结束后 200ms，圆角/裁切回到 token 标准值
     * （Roadmap §3 PoC-3 合入标准第 2 条）。
     */
    const val SETTLE_RELEASE_MS = 200L

    /**
     * 圆角包络系数 0..1：sin(π·p)。
     * p=0/1 时精确为 0 → 调用方 `rest + peakDelta * bulge` 精确回到 token。
     */
    fun cornerBulge(p: Float): Float {
        val x = clamp01(p)
        if (x == 0f || x == 1f) return 0f
        return sin(PI * x).toFloat()
    }

    /**
     * 前缘锥度包络系数 0..1：与圆角包络同形，独立函数以便分别断言。
     * 调用方只把它加到**运动方向前缘**的两个角上（非对称圆角）；
     * p=0/1 时精确为 0。
     */
    fun leadingTaperT(p: Float): Float = cornerBulge(p)

    /**
     * 末段一次过冲：q∈[0,1] → 1 + 0.025·sin(πq)。
     * 仅一次峰值（q=0.5）；q=0/1 精确为 1；峰值 1.025 < 1.03。
     */
    fun overshootScale(q: Float): Float = singleOvershoot(clamp01(q), OVERSHOOT_AMPLITUDE)

    /**
     * 稳定态释放门：动画结束后 [elapsedAfterEndMs] ≥ 200ms → 返回 token 精确值；
     * 否则返回 null（仍持有临时形变，调用方继续用包络值绘制）。
     *
     * @param token 标准 token 值（如圆角 px；调用方用 `V371Radius.group` 换算）
     */
    fun releasedValue(elapsedAfterEndMs: Long, token: Float): Float? =
        if (elapsedAfterEndMs >= SETTLE_RELEASE_MS) token else null

    /** `releasedValue` 的布尔版：是否应释放临时形变（回到 token 标准几何）。 */
    fun shouldReleaseTempMorph(elapsedAfterEndMs: Long): Boolean =
        elapsedAfterEndMs >= SETTLE_RELEASE_MS
}
