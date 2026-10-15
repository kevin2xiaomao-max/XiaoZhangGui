package com.xiaozhanggui.app.ui.poc.glass

import androidx.compose.runtime.Composable
import com.xiaozhanggui.app.ui.poc.droplet.PocStubBody

/**
 * PoC-2 玻璃材质三档占位。
 *
 * route 已在 `ui.poc.PocNav` 注册（`poc/glass`）。
 * **Worker A 交付真实实现后替换本文件**；生产页禁止引用。
 */
@Composable
fun GlassPocStub(onBack: () -> Unit) {
    PocStubBody(
        title = "PoC-2 玻璃材质三档",
        note = "占位：Worker A 交付真实实现后替换。合入标准见 ANDROID_V38_ROADMAP §3 PoC-2。",
        onBack = onBack,
    )
}
