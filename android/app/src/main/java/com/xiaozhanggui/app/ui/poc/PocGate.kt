package com.xiaozhanggui.app.ui.poc

import com.xiaozhanggui.app.BuildConfig

/**
 * PoC 总开关（V3.8 Phase 2，Roadmap §2 PoC 通用规则）。
 *
 * - `BuildConfig.POC_ENABLED`：debug 构建为 true，release 构建为 false
 *   （见 `android/app/build.gradle.kts`）。
 * - POC_ENABLED=false 时：PoC route 不注册、PoC 深链被忽略、
 *   PoC 代码不从任何生产路径可达。
 *
 * 生产页**禁止**引用 `ui.poc` 下任何符号（grep 门禁，见 PoC 报告）。
 */
object PocGate {
    /** PoC 功能是否启用（编译期开关，release=false）。 */
    val enabled: Boolean
        get() = BuildConfig.POC_ENABLED
}

/**
 * PoC 独立 route 声明（与生产页物理隔离）。
 *
 * - 五个 PoC 各占一个顶层 route：`poc/droplet` / `poc/glass` /
 *   `poc/morph` / `poc/transition` / `poc/perf`（性能测试，V3.8 真机验收补强）；
 * - `poc/launcher` 为 PoC 列表入口，仅经 `xzg://poc` 深链进入，
 *   生产页无任何入口引用；
 * - 生产路由（`home` / `todo` / `calendar` / `business` / 二级页）
 *   与 PoC route 无交集，返回路径均为系统返回键逐级 pop。
 */
object PocRoutes {
    const val LAUNCHER = "poc/launcher"
    const val DROPLET = "poc/droplet"
    const val GLASS = "poc/glass"
    const val MORPH = "poc/morph"
    const val TRANSITION = "poc/transition"

    /** 性能测试（真机帧率）：FrameMetrics 采集 + 报告导出（V3.8 真机验收补强，debug only）。 */
    const val PERF = "poc/perf"
}
