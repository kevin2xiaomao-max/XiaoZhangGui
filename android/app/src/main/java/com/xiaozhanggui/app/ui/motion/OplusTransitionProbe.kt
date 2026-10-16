package com.xiaozhanggui.app.ui.motion

/**
 * PoC-4 OPPO 私有转场能力探测（Design System §1.5 / §5.2，Roadmap §3 PoC-4）。
 *
 * **本阶段只做存在性/只读探测**：
 * - `Class.forName` 只做类存在性检查，**不调用任何方法**；
 * - 只读系统公开字段（`Build.VERSION.SDK_INT` / `Build.MANUFACTURER` /
 *   `Build.DISPLAY` / `Build.VERSION.INCREMENTAL` / Activity 窗口模式）；
 * - **不使用 `java.lang.reflect` 调用任何私有 API**——反射私有转场 API
 *   需用户明确授权，当前无授权；`ro.build.version.oplusrom` 等系统属性
 *   需反射 `android.os.SystemProperties` 才能读，本阶段同样不用。
 *
 * 探测逻辑是纯函数：所有输入经 [OplusProbeEnv] 注入，JVM 可测；
 * Android 侧只读采集见 `ui.poc.transition.OplusProbeCollector`。
 *
 * 每个探测项返回具名 [CapabilityResult]，禁止裸 boolean；
 * 每个探测项同时声明公开 API 降级链（当前一律为 `"FADE"`——
 * App 侧独立实现的 Compose NavHost FADE 转场，不依赖任何 OEM 私有能力）。
 *
 * 许可证：独立实现，未复制 SleepDown 任何源码；
 * `OplusSeamlessBackend`（跨 Activity + 反射私有 API）在单 Activity + NavHost
 * 架构下无着陆点，不搬用（Design System §1.5）。
 */

/** 候选 Oplus 平台扩展类名（**未验证候选**，见报告 NOT VERIFIED 说明）。 */
val OPLUS_CLASS_CANDIDATES_UNVERIFIED: List<String> = listOf(
    // 存在性检查的前置意义：若 Oplus 平台扩展类都不存在，
    // 则任何 Oplus 私有转场 API 路径都不可达。类名本身是未验证候选，
    // 真机探测时以实际存在性为准；CI/模拟器上预期全部 missing。
    "com.oplus.content.OplusFeatureConfigManager",
    "com.oplus.os.OplusBuild",
)

/** 被视为 Oplus 系设备的制造商（大小写不敏感匹配）。 */
private val OPLUS_FAMILY_MANUFACTURERS = setOf("oppo", "oneplus", "realme")

/** 窗口模式（影响跟手返回等系统级转场是否可用）。 */
enum class OplusWindowMode {
    /** 正常全屏 */
    NORMAL,

    /** 分屏/自由窗口：系统手势转场不可用 */
    FREEFORM,

    /** 画中画：系统手势转场不可用 */
    PIP,
}

/**
 * 探测环境（全部注入，纯函数输入）。
 *
 * @param apiLevel `Build.VERSION.SDK_INT`
 * @param manufacturer `Build.MANUFACTURER`
 * @param buildDisplay `Build.DISPLAY`（只读；null = 不可读）
 * @param versionIncremental `Build.VERSION.INCREMENTAL`（只读；null = 不可读；
 *   部分机型此处为构建哈希而非版本串，解析时自动忽略非版本形态）
 * @param classPresent 候选类名 → `Class.forName` 是否成功（只做存在性检查）
 * @param predictiveBackSystemEnabled 系统级预测性返回是否启用；
 *   null = 无法经公开 API 读取到系统状态（诚实标 unknown，不猜测）
 * @param windowMode 当前窗口模式
 * @param hardwareAccelerated 是否硬件加速
 */
data class OplusProbeEnv(
    val apiLevel: Int,
    val manufacturer: String,
    val buildDisplay: String?,
    val versionIncremental: String? = null,
    val classPresent: Map<String, Boolean> = emptyMap(),
    val predictiveBackSystemEnabled: Boolean? = null,
    val windowMode: OplusWindowMode = OplusWindowMode.NORMAL,
    val hardwareAccelerated: Boolean = true,
)

/**
 * 单个探测项。
 *
 * @param id 稳定探测项 ID（进探测报告，如 `"predictive-back"`）
 * @param result 具名探测结果
 * @param fallback 等效公开 API 降级链声明：当前一律 `"FADE"`
 *  （App 侧独立实现的 Compose NavHost FADE 转场）
 */
data class OplusProbeItem(
    val id: String,
    val result: CapabilityResult,
    val fallback: String = "FADE",
)

/**
 * 显式版本标记：`ColorOS V17` / `V15` / `ColorOS17`（大小写不敏感）。
 *
 * 数字限 1–2 位并要求词边界，避免把 `V177` 误读成主版本 17；
 * 读不到时由调用方具名 `coloros-version-unparseable`，不猜测。
 */
private val COLOROS_MARKER_REGEX =
    Regex("""(?:ColorOS|V)[\s_]?(\d{1,2})\b""", RegexOption.IGNORE_CASE)

/**
 * OPPO 构建号形态：型号前缀 + 下划线 + 短分量版本号，
 * 如 `PKJ110_17.0.0.201(CN01)` / `CPH2581_15.0.0.601(EX01)`。
 *
 * 分量限定短数字（`\d{1,2}` / `\d{1,3}`），AOSP 形态的长分量
 * 构建号（如 `AP3A.240905.015.A1`）不会命中。
 */
private val OPPO_BUILD_ID_REGEX =
    Regex("""\b[A-Za-z0-9]+_(\d{1,2})\.\d{1,2}\.\d{1,3}\b""")

/**
 * 从多个公开字段解析 ColorOS 主版本号。
 *
 * 来源优先级（即参数顺序）：`Build.DISPLAY` 先于
 * `Build.VERSION.INCREMENTAL`——DISPLAY 是设置里"版本号"显示的
 * 构建号，是最权威的公开来源。每个来源内部规则顺序：
 * 显式标记（[COLOROS_MARKER_REGEX]）先于构建号形态（[OPPO_BUILD_ID_REGEX]）。
 *
 * 背景（P0 真机修复，2026-10-16）：OPPO PKJ110 / ColorOS 17 真机上
 * `Build.DISPLAY` 无 `ColorOS` / `V` 版本标记（旧逻辑直接返回 null，
 * PoC-4 界面显示 `UNAVAILABLE · coloros-version-unparseable`），
 * 增补 `Build.VERSION.INCREMENTAL` 第二来源与构建号形态规则后可解析。
 *
 * 任一来源任一规则命中即返回；全部读不到返回 null
 * （由调用方具名 `coloros-version-unparseable` / `-unreadable`，不猜测）。
 */
fun parseColorOsMajorVersion(
    buildDisplay: String?,
    versionIncremental: String? = null,
): Int? {
    val sources = listOfNotNull(
        buildDisplay?.takeIf { it.isNotBlank() },
        versionIncremental?.takeIf { it.isNotBlank() },
    )
    for (source in sources) {
        parseColorOsMajorFromSource(source)?.let { return it }
    }
    return null
}

private fun parseColorOsMajorFromSource(source: String): Int? {
    COLOROS_MARKER_REGEX.find(source)
        ?.groupValues?.get(1)?.toIntOrNull()?.let { return it }
    return OPPO_BUILD_ID_REGEX.find(source)
        ?.groupValues?.get(1)?.toIntOrNull()
}

/**
 * ColorOS 17 单 Activity 内转场能力探测（纯函数）。
 *
 * 探测项（顺序即报告顺序）：
 * 1. `hardware-acceleration` —— 非硬件加速管线下转场不可用
 * 2. `api-level` —— API 33+ 才有预测性返回手势基础
 * 3. `device-family` —— 非 Oplus 系设备无 ColorOS 私有转场
 * 4. `coloros-version` —— ColorOS 17+ 才进入私有转场验证范围
 * 5. `oplus-class:<SimpleName>` × N —— 候选类存在性（前置条件）
 * 6. `predictive-back` —— 系统级预测性返回状态
 * 7. `window-mode` —— 非全屏窗口模式下系统手势转场不可用
 */
fun probeOplusTransitions(env: OplusProbeEnv): List<OplusProbeItem> {
    val items = mutableListOf<OplusProbeItem>()

    items += OplusProbeItem(
        id = "hardware-acceleration",
        result = if (env.hardwareAccelerated) CapabilityResult.Ok
        else CapabilityResult.Unsupported("transition-requires-hardware-acceleration"),
    )

    items += OplusProbeItem(
        id = "api-level",
        result = if (env.apiLevel >= 33) CapabilityResult.Ok
        else CapabilityResult.Unsupported("oplus-api-level-below-33"),
    )

    items += OplusProbeItem(
        id = "device-family",
        result = if (env.manufacturer.lowercase() in OPLUS_FAMILY_MANUFACTURERS) {
            CapabilityResult.Ok
        } else {
            CapabilityResult.Unsupported("not-oplus-family-device")
        },
    )

    val colorOsMajor = parseColorOsMajorVersion(env.buildDisplay, env.versionIncremental)
    items += OplusProbeItem(
        id = "coloros-version",
        result = when {
            env.buildDisplay.isNullOrBlank() && env.versionIncremental.isNullOrBlank() ->
                CapabilityResult.Unsupported("coloros-version-unreadable")
            colorOsMajor == null ->
                CapabilityResult.Unsupported("coloros-version-unparseable")
            colorOsMajor < 17 ->
                CapabilityResult.Unsupported("coloros-below-17")
            else -> CapabilityResult.Ok
        },
    )

    for (candidate in OPLUS_CLASS_CANDIDATES_UNVERIFIED) {
        val simpleName = candidate.substringAfterLast('.')
        val present = env.classPresent[candidate] == true
        items += OplusProbeItem(
            id = "oplus-class:$simpleName",
            result = if (present) CapabilityResult.Ok
            else CapabilityResult.Unsupported("oplus-class-missing:$simpleName"),
        )
    }

    items += OplusProbeItem(
        id = "predictive-back",
        result = when {
            env.apiLevel < 33 ->
                CapabilityResult.Unsupported("predictive-back-unsupported-below-api-33")
            env.predictiveBackSystemEnabled == false ->
                CapabilityResult.Unsupported("predictive-back-disabled-by-system")
            env.predictiveBackSystemEnabled == null ->
                CapabilityResult.Unsupported("predictive-back-system-state-unknown")
            else -> CapabilityResult.Ok
        },
    )

    items += OplusProbeItem(
        id = "window-mode",
        result = when (env.windowMode) {
            OplusWindowMode.NORMAL -> CapabilityResult.Ok
            OplusWindowMode.FREEFORM ->
                CapabilityResult.Unsupported("window-mode-freeform-no-gesture-transition")
            OplusWindowMode.PIP ->
                CapabilityResult.Unsupported("window-mode-pip-no-gesture-transition")
        },
    )

    return items
}
