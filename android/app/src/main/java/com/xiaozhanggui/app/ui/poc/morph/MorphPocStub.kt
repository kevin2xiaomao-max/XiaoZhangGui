package com.xiaozhanggui.app.ui.poc.morph

import androidx.compose.runtime.Composable
import com.xiaozhanggui.app.ui.poc.droplet.PocStubBody

/**
 * PoC-3 连续形变占位。
 *
 * route 已在 `ui.poc.PocNav` 注册（`poc/morph`）。
 * **Worker B 交付真实实现后替换本文件**；生产页禁止引用。
 */
@Composable
fun MorphPocStub(onBack: () -> Unit) {
    PocStubBody(
        title = "PoC-3 连续形变",
        note = "占位：Worker B 交付真实实现后替换。合入标准见 ANDROID_V38_ROADMAP §3 PoC-3。",
        onBack = onBack,
    )
}
