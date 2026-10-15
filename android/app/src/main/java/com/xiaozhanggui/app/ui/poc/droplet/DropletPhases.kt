package com.xiaozhanggui.app.ui.poc.droplet

import com.xiaozhanggui.app.ui.poc.PocMotionMath.phaseProgress
import com.xiaozhanggui.app.ui.poc.PocMotionMath.singleOvershoot

/**
 * PoC-1 液滴六层动作的相位数学（Design System §2.2）。
 *
 * 全部纯函数：输入 master 进度 p∈[0,1]（展开总时长 STANDARD 280ms），
 * 输出各层的无量纲进度/系数；调用方（Compose 层）负责 dp/px 映射与绘制。
 *
 * 相位边界（master 进度分数，独立标定——**未复制 SleepDown 的 260ms/2.2%/3.5%**）：
 *
 * ```
 * p: 0.00 ───── 0.25 ───── 0.50 ───── 0.75 ───── 1.00
 * B 收缩  [████████]                         [████] 回归(F)
 * B 位移  [██████████████████████████████]  (与收缩同起，0.90 结束)
 * C 纵向     [██████████████████████]        (0.05–0.70，STANDARD 280ms)
 * C 横向              [██████████████████████] (0.30–1.00，滞后 1/4 相位)
 * D 圆角             [███████████████████████] (0.28–0.95，延迟 Phase C 约 1/3)
 * E 内容              [████████████████]      (0.25–0.75，几何 1/4→3/4)
 * F 过冲                                     [████████] (0.85–1.00，单峰 2.5%)
 * ```
 *
 * 慢放逐帧符合性说明：
 * - 每个相位的起止边界是精确的（`phaseProgress` 在窗口外钳制 0/1），
 *   相位顺序断言只依赖边界值，不依赖 easing 中间形状；
 * - 收起时 master 进度反向 1→0，各相位自动反向执行（§2.2 Phase F）；
 * - p=1 时所有临时形变精确回到终值（scale=1、圆角 t=1、alpha=1、过冲=1），
 *   调用方以此做"稳定态释放"（见 `DropletMenuScreen` 的 released 分支）。
 */
object DropletPhases {

    // ── Phase B：收缩（锚点 scale 1→0.96）──
    const val SHRINK_START = 0f
    const val SHRINK_END = 0.25f

    /** Phase B 锚点最小缩放（任务书指定 0.96；PRESS_SCALE 语义=轻微收缩）。 */
    const val ANCHOR_MIN_SCALE = 0.96f

    // ── Phase B：位移（与收缩**同起**，禁止"先收缩完再位移"）──
    const val MOVE_START = 0f
    const val MOVE_END = 0.90f

    // ── Phase C：高度先行（纵向 0.05–0.70；横向滞后约 1/4 相位）──
    const val HEIGHT_START = 0.05f
    const val HEIGHT_END = 0.70f
    const val WIDTH_START = 0.30f
    const val WIDTH_END = 1.00f

    // ── Phase D：圆角延迟插值（延迟 Phase C 约 1/3：
    //    (0.28−0.05)/(0.70−0.05) ≈ 0.35）──
    const val CORNER_START = 0.28f
    const val CORNER_END = 0.95f

    // ── Phase E：内容在几何展开 1/4→3/4 区间淡入 ──
    const val CONTENT_START = 0.25f
    const val CONTENT_END = 0.75f

    // ── Phase F：末段一次过冲 + 锚点回归 ──
    const val OVERSHOOT_START = 0.85f
    const val OVERSHOOT_END = 1.00f

    /**
     * Phase F 过冲幅度 2.5%（<3%，独立标定；`singleOvershoot` 在构造时
     * 强制 amplitude ≤ 0.03，超限抛异常）。
     */
    const val OVERSHOOT_AMPLITUDE = 0.025f

    /**
     * Phase B-1 锚点收缩：[0,0.25] 内 1→0.96，保持，[0.85,1] 回归 1（Phase F）。
     * p=0/1 时精确为 1。
     */
    fun anchorScale(p: Float): Float {
        val pressed = 1f - (1f - ANCHOR_MIN_SCALE) * phaseProgress(p, SHRINK_START, SHRINK_END)
        val released = (1f - ANCHOR_MIN_SCALE) * phaseProgress(p, OVERSHOOT_START, OVERSHOOT_END)
        return pressed + released
    }

    /**
     * Phase B-2 浮层位移进度：与收缩**同起**（t=0 同时启动）。
     * 反例"收缩播完才开始位移" ⇔ moveProgress(p)=0 对一切 p<0.25；
     * 此处 moveProgress(0.125)>0，测试强制断言。
     */
    fun moveProgress(p: Float): Float = phaseProgress(p, MOVE_START, MOVE_END)

    /** Phase C 纵向展开分数：p=0.6 时 ≈0.94（≥90% 先行）。 */
    fun heightFraction(p: Float): Float = phaseProgress(p, HEIGHT_START, HEIGHT_END)

    /** Phase C 横向展开分数：滞后纵向约 1/4 相位（0.30−0.05=0.25）。 */
    fun widthFraction(p: Float): Float = phaseProgress(p, WIDTH_START, WIDTH_END)

    /**
     * Phase D 圆角插值 t：调用方 `lerp(anchorRadiusPx, targetTokenRadiusPx, t)`。
     * p=1 时精确为 1 → 稳定态回到标准圆角 token（§2.2 Phase D / 检查表"稳定态"）。
     */
    fun cornerT(p: Float): Float = phaseProgress(p, CORNER_START, CORNER_END)

    /**
     * Phase E 内容 alpha：p≤0.25 时精确为 0
     * （反例"内容在几何展开前出现"零容忍）。
     */
    fun contentAlpha(p: Float): Float = phaseProgress(p, CONTENT_START, CONTENT_END)

    /**
     * 液滴体自身 surface alpha：p∈[0,0.2] 淡入（液滴体是几何层，不是"内容"，
     * 不受 Phase E 约束；0.2 后恒为 1）。
     */
    fun surfaceAlpha(p: Float): Float = phaseProgress(p, 0f, 0.2f)

    /**
     * Phase F 末段一次过冲：单峰（峰值 1.025，q=0.5 处）、p=1 时精确回 1。
     * 注意此处用**线性** q（非 smoothstep），保证峰值位置与"仅一次"可精确断言。
     */
    fun panelOvershoot(p: Float): Float {
        val q = ((p - OVERSHOOT_START) / (OVERSHOOT_END - OVERSHOOT_START)).coerceIn(0f, 1f)
        return singleOvershoot(q, OVERSHOOT_AMPLITUDE)
    }

    /**
     * Phase D 前缘锥度包络（0..1）：仅调用方把它加到**运动方向前缘**的两个角上；
     * p=0/1 时精确为 0（静止与稳定态无锥度）。
     */
    fun leadingTaperT(p: Float): Float {
        val m = moveProgress(p) // 0→1（MOVE_END=0.9；p=1 时 moveProgress=1）
        if (m <= 0f || m >= 1f) return 0f
        val sine = kotlin.math.sin(kotlin.math.PI * m).toFloat()
        return sine * (1f - cornerT(p))
    }
}
