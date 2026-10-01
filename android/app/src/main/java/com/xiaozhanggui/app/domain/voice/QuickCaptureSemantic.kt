package com.xiaozhanggui.app.domain.voice

/**
 * 共享文案。1:1 移植 iOS QuickRecord/QuickCaptureSemantic.swift。
 *
 * 注释原文：三个底层状态机保持独立，仅共享词汇。
 * Voice / QuickRecord / AI 短语音三条链路的状态机各自独立实现，只复用这里的文案。
 */
object QuickCaptureSemantic {
    const val LISTENING = "正在听…"
    const val PROCESSING = "正在整理…"
    const val READY = "请确认将保存的内容"
    const val SAVING = "正在保存…"
    const val SAVED = "已保存"
    const val FAILED = "保存失败，请重试"

    fun savedMessage(destination: String): String = "已保存到：$destination"
}
