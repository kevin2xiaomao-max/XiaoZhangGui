package com.xiaozhanggui.app.ui.navigation

/**
 * 冷启动初始导航决策（纯函数，JVM 可测）。
 *
 * V3.6 防回归（冷启动深链崩溃 `You must call setGraph() before calling getGraph()`）：
 * - 需要切 Tab 的深链 → 只决定 NavHost 的 startDestination（setGraph 时即生效，
 *   不在 LaunchedEffect 里调 navigate()）；
 * - 需要开 Sheet 的深链（AI / 语音 / 速记）→ 只产生 sheet 标记，由 XzgNavGraph
 *   在 NavHost setGraph 之后的 LaunchedEffect 里打开。
 *
 * 进程恢复：MainActivity 重建时 intent.data 不变 → XzgNavGraph 经 remember
 * 重新锁存同一 [DeepLinkAction] → 决策幂等一致（见 ColdStartPlanTest「进程恢复」用例）。
 */
data class ColdStartPlan(
    /** NavHost startDestination：恒为四 Tab 之一（V3.7.1 已无 assistant/profile Tab 路由） */
    val startTab: XzgTab,
    /** 打开 AI Sheet（`xzg://ai`） */
    val openAISheet: Boolean = false,
    /** AI Sheet 内同步拉起短语音面板（`xzg://ai?mode=voice`） */
    val aiVoiceDeepLink: Boolean = false,
    /** 打开独立语音 Sheet（`xzg://voice`，语音记一笔） */
    val openVoiceSheet: Boolean = false,
    /** 打开快速记一笔 Sheet（`xzg://quickrecord`） */
    val openQuickRecordSheet: Boolean = false,
    /**
     * 打开 PoC 列表入口（`xzg://poc`，V3.8 Phase 2）。
     * 仅 POC_ENABLED（debug 构建）时 XzgNavGraph 才实际导航；
     * release 构建中该深链在路由层即被映射为 Ignore。
     */
    val openPocLauncher: Boolean = false,
)

/**
 * 冷启动决策：深链动作 → 初始 Tab + 待开 Sheet。
 * when 穷举 [DeepLinkAction]：新增动作未在此处理会在编译期报错，
 * 不会静默落入某个默认分支导致冷启动行为未定义。
 */
fun planColdStart(action: DeepLinkAction?): ColdStartPlan = when (action) {
    DeepLinkAction.OpenTodoTab ->
        ColdStartPlan(startTab = XzgTab.TODO)
    DeepLinkAction.OpenAISheet ->
        ColdStartPlan(startTab = XzgTab.HOME, openAISheet = true)
    DeepLinkAction.OpenAISheetVoice ->
        ColdStartPlan(startTab = XzgTab.HOME, openAISheet = true, aiVoiceDeepLink = true)
    DeepLinkAction.OpenVoice ->
        ColdStartPlan(startTab = XzgTab.HOME, openVoiceSheet = true)
    DeepLinkAction.OpenQuickRecord ->
        ColdStartPlan(startTab = XzgTab.HOME, openQuickRecordSheet = true)
    DeepLinkAction.OpenPocLauncher ->
        ColdStartPlan(startTab = XzgTab.HOME, openPocLauncher = true)
    null, DeepLinkAction.Ignore ->
        ColdStartPlan(startTab = XzgTab.HOME)
}
