package com.xiaozhanggui.app.ui.motion

/**
 * 纯函数：系统动画时长缩放 → 是否开启「移除动画」。
 *
 * Android 无障碍「移除动画」开关的本质，就是把
 * `Settings.Global.ANIMATOR_DURATION_SCALE`（及另外两个动画缩放）置 0——
 * 这是全平台通用的 de-facto 信号源（含 ColorOS 17），见
 * `ui.theme.isReduceMotionEnabled` 的 API 核查结论（SDK 35 实测）。
 *
 * 把判定提成纯函数：JVM 可单测；Context 版本（`ui.theme`）只负责取值，
 * 判定逻辑以这里为准，不分叉。
 *
 * @param animatorDurationScale `Settings.Global.ANIMATOR_DURATION_SCALE` 的读值（默认 1f）
 * @return true = 用户开启了「移除动画」（scale == 0）
 */
fun isReduceMotionEnabled(animatorDurationScale: Float): Boolean =
    animatorDurationScale == 0f
