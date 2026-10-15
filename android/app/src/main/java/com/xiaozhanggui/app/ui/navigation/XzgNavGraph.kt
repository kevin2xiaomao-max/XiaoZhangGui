package com.xiaozhanggui.app.ui.navigation

import androidx.compose.animation.AnimatedContentTransitionScope
import androidx.compose.animation.EnterTransition
import androidx.compose.animation.ExitTransition
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.navigation.NavController
import androidx.navigation.NavBackStackEntry
import androidx.navigation.NavDestination.Companion.hierarchy
import androidx.navigation.NavGraph.Companion.findStartDestination
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import com.xiaozhanggui.app.BuildConfig
import com.xiaozhanggui.app.ui.components.XzgMotionSpecs
import com.xiaozhanggui.app.ui.motion.MotionContext
import com.xiaozhanggui.app.ui.motion.MotionPolicy
import com.xiaozhanggui.app.ui.poc.PocRoutes
import com.xiaozhanggui.app.ui.poc.PocSpeed
import com.xiaozhanggui.app.ui.poc.pocGraph
import com.xiaozhanggui.app.ui.screens.ai.AISheet
import com.xiaozhanggui.app.ui.screens.customer.CustomerScreen
import com.xiaozhanggui.app.ui.screens.expiry.ExpiryScreen
import com.xiaozhanggui.app.ui.screens.goods.GoodsScreen
import com.xiaozhanggui.app.ui.screens.home.DailyReportSheet
import com.xiaozhanggui.app.ui.screens.home.HomeScreen
import com.xiaozhanggui.app.ui.screens.imp.SaobeiImportSheet
import com.xiaozhanggui.app.ui.screens.paymentcode.PaymentCodeScreen
import com.xiaozhanggui.app.ui.screens.performance.PerformanceScreen
import com.xiaozhanggui.app.ui.screens.performance.TransactionHistoryScreen
import com.xiaozhanggui.app.ui.screens.profile.ProfileScreen
import com.xiaozhanggui.app.ui.screens.quickrecord.QuickRecordSheetContent
import com.xiaozhanggui.app.ui.screens.schedule.CalendarScreen
import com.xiaozhanggui.app.ui.screens.schedule.ScheduleScreen
import com.xiaozhanggui.app.ui.screens.todo.MemoScreen
import com.xiaozhanggui.app.ui.screens.todo.TodoScreen
import com.xiaozhanggui.app.ui.screens.voice.VoiceSheetContent
import com.xiaozhanggui.app.ui.theme.LocalXzgPalettes
import com.xiaozhanggui.app.ui.theme.rememberReduceMotion
import com.xiaozhanggui.app.ui.theme.rememberXzgModalBottomSheetState
import com.xiaozhanggui.app.ui.theme.XzgType

/**
 * 导航壳。对应 iOS `App/RootView.swift` 的 4 Tab TabView
 *（首页/待办/日历/经营；AI 不再是 Tab，「我的」走首页头像）。
 *
 * V3.7.1（Phase 2 导航重构）：
 * - 4 Tab 接入真实 Screen：home/todo/calendar/business；
 *   calendar Tab 内容为 ScheduleScreen（即 iOS 日历 Tab 下的 ScheduleView 对应屏），
 *   完整月历为二级页（路由 "calendar_month"）；
 *   business Tab 内容为 PerformanceScreen（经营 menu：商品/记录/日报/扫呗，由经营页内部接线）。
 * - AI = Root 级 Sheet（[AISheet]，内容复用 AIChatScreen）：
 *   首页 AICommandEntry（onOpenAI）与深链 `xzg://ai[?mode=voice]` 都走此处打开；
 *   `mode=voice` 时同步拉起短语音面板（ASR 不可用则降级文字输入）。
 * - Profile 为导航目的地（路由 "profile"）：首页 header 右上角头像（onOpenProfile）
 *   → navigationDestination；返回键回首页（R05）。
 * - 首页已无经营快捷抽屉入口（V3.6 HomeDrawer 退役）：抽屉原目的地全部迁至新入口——
 *   交易记录→经营页「查看全部」；客户/临期→首页「今日重点」行；商品→经营 toolbar；
 *   备忘→经营 menu「记录」（R13）；日报/速记/扫呗→经营 menu / 首页胶囊 Sheet。
 * - 深链接：MainActivity 把解析出的 [DeepLinkAction] 经 [deepLinkAction] 传入，
 *   此处 remember 暂存为 pending，经 LaunchedEffect 处理后通过 [onDeepLink]
 *   回调通知 MainActivity 已消费。
 *
 * iOS 行为备忘（Phase 5 实现）：
 * - iOS 26 下滑隐藏 tab bar → nestedScroll 等价
 * - 底部栏按 V32 视觉重做（当前 Material3 NavigationBar 为占位）
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun XzgNavGraph(
    deepLinkAction: DeepLinkAction? = null,
    onDeepLink: (DeepLinkAction) -> Unit = {},
) {
    val navController = rememberNavController()
    val palettes = LocalXzgPalettes.current

    var activeSheet by remember { mutableStateOf<RootSheet?>(null) }

    // 深链接冷启动：planColdStart 只决定 NavHost 的 startDestination + 待开 Sheet 标记，
    // 不在 NavHost setGraph 之前调用 navigate()（V3.6 冷启动深链崩溃防回归：
    // `You must call setGraph() before calling getGraph()`）。
    // remember 锁存初始值：热启动（onNewIntent）的新 deepLinkAction
    // 走下面的 LaunchedEffect 导航，不重置 NavHost。
    val initialDeepLink = remember { deepLinkAction }
    val coldStart = remember(initialDeepLink) { planColdStart(initialDeepLink) }
    val startTab = coldStart.startTab
    // 冷启动的 Sheet 类深链接在 NavHost setGraph 之后经 LaunchedEffect 打开。
    LaunchedEffect(coldStart) {
        activeSheet = when {
            coldStart.openAISheet -> RootSheet.AI(coldStart.aiVoiceDeepLink)
            coldStart.openVoiceSheet -> RootSheet.VOICE
            coldStart.openQuickRecordSheet -> RootSheet.QUICK_RECORD
            else -> activeSheet
        }
        // V3.8 Phase 2：PoC 深链冷启动 → NavHost setGraph 后导航到 PoC 入口。
        // POC_ENABLED=false（release）时 route 未注册，此处不导航。
        if (coldStart.openPocLauncher && BuildConfig.POC_ENABLED) {
            navController.navigate(PocRoutes.LAUNCHER) { launchSingleTop = true }
        }
        // V3.8 PoC 测试菜单增强：逐 PoC 深链冷启动（`xzg://poc/<屏>`）→
        // NavHost setGraph 后直达对应演示屏。POC_ENABLED=false 时不导航。
        (initialDeepLink as? DeepLinkAction.OpenPoc)?.let { handleOpenPoc(it, navController) }
        if (initialDeepLink != null && initialDeepLink != DeepLinkAction.Ignore) {
            onDeepLink(initialDeepLink)
        }
    }

    // 深链接热启动（onNewIntent）：deepLinkAction 在首帧之后变化，
    // 此时 NavHost 已 setGraph，可安全 navigate。
    var pendingDeepLink by remember { mutableStateOf<DeepLinkAction?>(null) }
    LaunchedEffect(deepLinkAction) {
        if (deepLinkAction != null &&
            deepLinkAction != DeepLinkAction.Ignore &&
            deepLinkAction != initialDeepLink
        ) {
            pendingDeepLink = deepLinkAction
        }
    }
    LaunchedEffect(pendingDeepLink) {
        when (pendingDeepLink) {
            DeepLinkAction.OpenVoice -> activeSheet = RootSheet.VOICE
            DeepLinkAction.OpenQuickRecord -> activeSheet = RootSheet.QUICK_RECORD
            // iOS 语义：深链到达时若 AI Sheet 已在展示则先关再重开，保证入口可达。
            // RootSheet.AI 为 data class：voice 标记变化即产生新实例，
            // AISheet 以 voiceDeepLink 为 key 重建语音面板态，等价重开。
            DeepLinkAction.OpenAISheet -> activeSheet = RootSheet.AI(voiceDeepLink = false)
            DeepLinkAction.OpenAISheetVoice -> activeSheet = RootSheet.AI(voiceDeepLink = true)
            DeepLinkAction.OpenTodoTab ->
                navController.navigateToTab(XzgTab.TODO)
            // V3.8 Phase 2：PoC 深链热启动。release 构建 route 未注册，不导航。
            DeepLinkAction.OpenPocLauncher ->
                if (BuildConfig.POC_ENABLED) {
                    navController.navigate(PocRoutes.LAUNCHER) { launchSingleTop = true }
                }
            // V3.8 PoC 测试菜单增强：逐 PoC 深链热启动（`xzg://poc/<屏>`）。
            // pendingDeepLink 为委托属性（不可 smart cast），此处显式转换是安全的：
            // when 分支的 is 检查已保证类型。
            is DeepLinkAction.OpenPoc ->
                handleOpenPoc(pendingDeepLink as DeepLinkAction.OpenPoc, navController)
            null, DeepLinkAction.Ignore -> {}
        }
        val consumed = pendingDeepLink
        pendingDeepLink = null
        if (consumed != null && consumed != DeepLinkAction.Ignore) {
            onDeepLink(consumed)
        }
    }

    val navBackStackEntry by navController.currentBackStackEntryAsState()
    val currentRoute = navBackStackEntry?.destination?.route
    // 仅在 4 个 Tab 根路由显示底部栏；二级页/工具页/Profile 目的地隐藏
    //（对应 iOS 推入页面隐藏 TabBar）。
    val showBottomBar = XzgTab.values().any { it.route == currentRoute }

    Scaffold(
        containerColor = palettes.background.pageBG,
        bottomBar = {
            if (showBottomBar) {
                NavigationBar(containerColor = palettes.background.card) {
                    val currentDestination = navBackStackEntry?.destination
                    XzgTab.values().forEach { tab ->
                        val selected =
                            currentDestination?.hierarchy?.any { it.route == tab.route } == true
                        NavigationBarItem(
                            selected = selected,
                            onClick = { navController.navigateToTab(tab) },
                            modifier = Modifier.testTag(tab.tag),
                            icon = {
                                Icon(
                                    imageVector = if (selected) tab.selectedIcon else tab.icon,
                                    contentDescription = tab.label
                                )
                            },
                            label = { Text(tab.label, style = XzgType.caption) }
                        )
                    }
                }
            }
        }
    ) { innerPadding ->
        // MotionSpec（V3.8 Phase 1）：XzgMotionSpecs.NAV_PAGE_FADE
        //（Tab 切换 / NavHost 页面导航：FADE，页面容器单调 tween 180ms 无过冲；
        // 禁 NATIVE（OEM 转场不一致）/ SHARED_ANCHOR（Phase 2 PoC）；
        // 解析走 MotionPolicy：reduce-motion / 总开关关闭等任何降级 → 直接显示；
        // 内容分组错峰淡入由各 Screen 后续接入。）
        val reduceMotion = rememberReduceMotion()
        val navResolved = remember(reduceMotion) {
            MotionPolicy.resolve(
                XzgMotionSpecs.NAV_PAGE_FADE,
                MotionContext(reduceMotion = reduceMotion),
            )
        }
        val pageEnter: AnimatedContentTransitionScope<NavBackStackEntry>.() -> EnterTransition =
            {
                if (navResolved.downgradeReason == null)
                    fadeIn(animationSpec = tween(durationMillis = navResolved.durationTier.ms))
                else EnterTransition.None
            }
        val pageExit: AnimatedContentTransitionScope<NavBackStackEntry>.() -> ExitTransition =
            {
                if (navResolved.downgradeReason == null)
                    fadeOut(animationSpec = tween(durationMillis = navResolved.durationTier.ms))
                else ExitTransition.None
            }
        NavHost(
            navController = navController,
            startDestination = startTab.route,
            modifier = Modifier.padding(innerPadding),
            enterTransition = pageEnter,
            exitTransition = pageExit,
            popEnterTransition = pageEnter,
            popExitTransition = pageExit,
        ) {
            // ---- 4 Tab ----
            composable(XzgTab.HOME.route) {
                HomeScreen(
                    onOpenPerformance = {
                        // 首页 Hero「今日营业额」可点进经营：切到经营 Tab（对应 iOS heroFlat → 经营）
                        navController.navigateToTab(XzgTab.BUSINESS)
                    },
                    onOpenTodoTab = { navController.navigateToTab(XzgTab.TODO) },
                    onOpenCustomer = {
                        navController.navigate("customer") { launchSingleTop = true }
                    },
                    onOpenExpiry = {
                        navController.navigate("expiry") { launchSingleTop = true }
                    },
                    // 首页 header 右上角头像 → navigationDestination 进 Profile（R05）
                    onOpenProfile = {
                        navController.navigate("profile") { launchSingleTop = true }
                    },
                    // 首页 AICommandEntry → AI Sheet（R09；AI 不再是 Tab）
                    onOpenAI = { activeSheet = RootSheet.AI() },
                    onOpenQuickRecord = { activeSheet = RootSheet.QUICK_RECORD },
                    // 天气 Sheet 由 HomeScreen 内部自行展示，此处无需额外动作
                    onWeatherClick = {},
                )
            }
            composable(XzgTab.CALENDAR.route) {
                ScheduleScreen(
                    onOpenCalendar = { navController.navigate("calendar_month") },
                    onTodoClick = { navController.navigate(XzgTab.TODO.route) { launchSingleTop = true } },
                    onExpiryClick = { navController.navigate("expiry") { launchSingleTop = true } },
                    onCustomerClick = { navController.navigate("customer") { launchSingleTop = true } },
                )
            }
            composable(XzgTab.TODO.route) {
                TodoScreen()
            }
            composable(XzgTab.BUSINESS.route) {
                PerformanceScreen(
                    onOpenTransactions = {
                        navController.navigate("transactions") { launchSingleTop = true }
                    },
                    onOpenSaobei = { activeSheet = RootSheet.SAOBEI },
                    onOpenGoods = {
                        navController.navigate("goods") { launchSingleTop = true }
                    },
                    onOpenMemo = {
                        navController.navigate("memo") { launchSingleTop = true }
                    },
                    onOpenDailyReport = { activeSheet = RootSheet.REPORT },
                )
            }
            // ---- 首页头像 → Profile（导航目的地，非 Tab；对应 iOS HomeRoute.profile）----
            // 返回路径：系统返回键回首页（R05）。
            composable("profile") {
                ProfileScreen(
                    onOpenPaymentCode = {
                        navController.navigate("paymentcode") { launchSingleTop = true }
                    }
                )
            }
            // ---- 二级页 ----
            composable("transactions") {
                TransactionHistoryScreen(onBack = { navController.popBackStack() })
            }
            composable("customer") { CustomerScreen() }
            composable("expiry") { ExpiryScreen() }
            composable("goods") { GoodsScreen() }
            composable("memo") { MemoScreen() }
            composable("calendar_month") { CalendarScreen() }
            // ---- 工具页 ----
            composable("paymentcode") {
                PaymentCodeScreen(onBack = { navController.popBackStack() })
            }
            // ---- PoC 隔离区（V3.8 Phase 2）----
            // 独立 route（poc/*），与生产页物理隔离；
            // release 构建（POC_ENABLED=false）不注册。
            if (BuildConfig.POC_ENABLED) {
                pocGraph(navController)
            }
        }
    }

    // ---- Root 级全局 Sheet ----
    activeSheet?.let { sheet ->
        if (sheet is RootSheet.AI) {
            AISheet(
                voiceDeepLink = sheet.voiceDeepLink,
                onDismiss = { activeSheet = null }
            )
        } else {
            RootModalSheet(sheet = sheet, onDismiss = { activeSheet = null })
        }
    }
}

/**
 * Root 级通用 Sheet 宿主（report / quickrecord / voice / saobei）。
 * Reduce Motion 时 Sheet 直接呈现（见 [rememberXzgModalBottomSheetState]）。
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun RootModalSheet(sheet: RootSheet, onDismiss: () -> Unit) {
    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = rememberXzgModalBottomSheetState()
    ) {
        when (sheet) {
            RootSheet.REPORT ->
                DailyReportSheet(onDismiss = onDismiss)
            RootSheet.QUICK_RECORD ->
                QuickRecordSheetContent(onDismiss = onDismiss)
            RootSheet.VOICE ->
                VoiceSheetContent(onDismiss = onDismiss)
            RootSheet.SAOBEI ->
                SaobeiImportSheet(onDismiss = onDismiss)
            is RootSheet.AI -> Unit // 不可达：外层已处理
        }
    }
}

/** Root 级 Sheet：report / quickrecord / voice / saobei / ai（V3.7.1 新增） */
private sealed interface RootSheet {
    data object REPORT : RootSheet
    data object QUICK_RECORD : RootSheet
    data object VOICE : RootSheet
    data object SAOBEI : RootSheet

    /** AI Sheet；voiceDeepLink = true 时同步拉起短语音面板（`xzg://ai?mode=voice`） */
    data class AI(val voiceDeepLink: Boolean = false) : RootSheet
}

/**
 * V3.8 PoC 测试菜单增强：`DeepLinkAction.OpenPoc` 深链导航（冷/热启动共用）。
 *
 * - POC_ENABLED=false（release 构建）时 PoC route 未注册，直接返回不导航；
 * - `?speed=` 参数经 [PocSpeed.modeForQuery] 落盘为全局速度档
 *   （无参数/非法值 → 保持当前档，不重置）。
 */
private fun handleOpenPoc(action: DeepLinkAction.OpenPoc, navController: NavController) {
    if (!BuildConfig.POC_ENABLED) return
    PocSpeed.modeForQuery(action.speed)?.let { PocSpeed.mode = it }
    navController.navigate(action.route) { launchSingleTop = true }
}

private fun NavController.navigateToTab(tab: XzgTab) {
    navigate(tab.route) {
        popUpTo(graph.findStartDestination().id) { saveState = true }
        launchSingleTop = true
        restoreState = true
    }
}
