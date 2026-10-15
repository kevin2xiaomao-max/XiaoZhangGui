package com.xiaozhanggui.app.ui.motion

import android.view.Choreographer

/**
 * [FrameRateMonitor] 的 Android 接线（Choreographer 帧回调 → [FrameRateMonitor.onFrame]）。
 *
 * 与核心采样逻辑分离：核心是纯 Kotlin（可 JVM 单测），这里只做平台接线。
 * 回到前台时调用方（如 Activity.onResume / ProcessLifecycleOwner）应调用
 * [FrameRateMonitor.reset] 重新探测。
 */
object FrameRateSampling {

    /**
     * 开始采样：注册一个持续的 Choreographer 帧回调，每帧喂给 [monitor]。
     *
     * @return 取消函数；调用后停止回调（页面销毁/后台时调用，避免泄漏）
     */
    fun start(monitor: FrameRateMonitor): () -> Unit {
        val choreographer = Choreographer.getInstance()
        var cancelled = false
        val callback = object : Choreographer.FrameCallback {
            override fun doFrame(frameTimeNanos: Long) {
                if (cancelled) return
                monitor.onFrame()
                choreographer.postFrameCallback(this)
            }
        }
        choreographer.postFrameCallback(callback)
        return {
            cancelled = true
            choreographer.removeFrameCallback(callback)
        }
    }
}
