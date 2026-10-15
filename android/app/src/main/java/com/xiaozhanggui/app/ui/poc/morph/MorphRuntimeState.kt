package com.xiaozhanggui.app.ui.poc.morph

/**
 * PoC-3 连续形变的运行时状态（值语义）。
 *
 * 设计约束（Roadmap §3 PoC-3"无快照残留"）：
 * - 只持有标量（位移/进度/时间戳/开关），**不持有 Bitmap、ImageBitmap、
 *   离屏快照或任何图形资源**；
 * - `MorphEnvelopeTest.noBitmapFieldsInRuntimeState` 用反射强制此约束，
 *   后续任何加字段的修改若引入快照类型都会让测试变红。
 *
 * @param dragOffsetPx 拖拽位移（px，可正负）
 * @param dragMaxPx 拖拽上限（px，归一化分母）
 * @param expandProgress 展开进度 0..1（点击展开 Demo）
 * @param tempMorphActive 是否仍持有临时形变（圆角包络/锥度/临时裁切）；
 *   稳定态 200ms 后调用方置 false → 全部绘制回退到 token 常量
 * @param settleStartMs 动画结束时间戳（ms，调用方时钟域）；null=未开始/静止
 */
data class MorphRuntimeState(
    val dragOffsetPx: Float = 0f,
    val dragMaxPx: Float = 1f,
    val expandProgress: Float = 0f,
    val tempMorphActive: Boolean = false,
    val settleStartMs: Long? = null,
) {
    /** 拖拽归一化进度 0..1（取绝对值）。 */
    val dragProgress: Float
        get() = (kotlin.math.abs(dragOffsetPx) / dragMaxPx).coerceIn(0f, 1f)

    /** 拖拽方向：1=右/下，-1=左/上，0=静止（决定锥度加在哪一侧前缘）。 */
    val dragDirection: Int
        get() = when {
            dragOffsetPx > 0f -> 1
            dragOffsetPx < 0f -> -1
            else -> 0
        }
}
