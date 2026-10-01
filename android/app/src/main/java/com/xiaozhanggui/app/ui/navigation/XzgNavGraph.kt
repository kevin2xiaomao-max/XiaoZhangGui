package com.xiaozhanggui.app.ui.navigation

import androidx.compose.foundation.layout.padding
import androidx.compose.material3.DrawerValue
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.rememberDrawerState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.navigation.NavController
import androidx.navigation.NavDestination.Companion.hierarchy
import androidx.navigation.NavGraph.Companion.findStartDestination
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import com.xiaozhanggui.app.ui.screens.ai.AIChatScreen
import com.xiaozhanggui.app.ui.screens.customer.CustomerScreen
import com.xiaozhanggui.app.ui.screens.expiry.ExpiryScreen
import com.xiaozhanggui.app.ui.screens.goods.GoodsScreen
import com.xiaozhanggui.app.ui.screens.home.DailyReportSheet
import com.xiaozhanggui.app.ui.screens.home.HomeDrawer
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
import com.xiaozhanggui.app.ui.theme.XzgType
import kotlinx.coroutines.launch

/**
 * 导航壳。对应 iOS `App/RootView.swift` 的 5 Tab TabView。
 *
 * Phase 3：
 * - 5 Tab 接入真实 Screen：home/todo/profile；schedule/assistant 保留占位
 *   （日程 Phase 3b 实现，小掌柜 AI 对话 Phase 4 实现）。
 * - 抽屉目的地路由：transactions / customer / expiry / goods / memo
 *   （home Tab 由 HomeDrawer 包裹，抽屉的 onNavigate(route)/onOpenSheet(name)
 *   回到此处处理）；另有 performance（经营数据页，由首页营业额 Hero 进入）。
 * - 「工具」路由：paymentcode（由 ProfileScreen 的「收款码」行触发）。
 * - Root 级 Sheet：report（今日经营报告）/ quickrecord / voice / saobei（扫呗导入）。
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

    // 深链接：remember 暂存 pending action，LaunchedEffect 中处理。
    var pendingDeepLink by remember { mutableStateOf<DeepLinkAction?>(null) }
    LaunchedEffect(deepLinkAction) {
        if (deepLinkAction != null && deepLinkAction != DeepLinkAction.Ignore) {
            pendingDeepLink = deepLinkAction
        }
    }
    LaunchedEffect(pendingDeepLink) {
        when (pendingDeepLink) {
            DeepLinkAction.OpenVoice -> activeSheet = RootSheet.VOICE
            DeepLinkAction.OpenQuickRecord -> activeSheet = RootSheet.QUICK_RECORD
            DeepLinkAction.OpenAssistantTab ->
                navController.navigateToTab(XzgTab.ASSISTANT)
            DeepLinkAction.OpenAssistantVoice -> {
                // 切换到小掌柜 Tab 并打开语音 Sheet（AI 语音面板）
                navController.navigateToTab(XzgTab.ASSISTANT)
                activeSheet = RootSheet.VOICE
            }
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
    // 仅在 5 个 Tab 根路由显示底部栏；抽屉二级页/工具页隐藏（对应 iOS 推入页面隐藏 TabBar）
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
        NavHost(
            navController = navController,
            startDestination = XzgTab.HOME.route,
            modifier = Modifier.padding(innerPadding)
        ) {
            // ---- 5 Tab ----
            composable(XzgTab.HOME.route) {
                // 左侧经营快捷抽屉：HomeDrawer 包裹 HomeScreen；
                // 抽屉目的地经 onNavigate/onOpenSheet 回到 shell 处理
                //（对应 HomeDrawer KDoc 约定的 shell 职责）。
                val drawerState = rememberDrawerState(initialValue = DrawerValue.Closed)
                val scope = rememberCoroutineScope()
                HomeDrawer(
                    drawerState = drawerState,
                    onNavigate = { route ->
                        navController.navigate(route) { launchSingleTop = true }
                    },
                    onOpenSheet = { name ->
                        RootSheet.fromKey(name)?.let { activeSheet = it }
                    }
                ) {
                    HomeScreen(
                        onOpenPerformance = {
                            navController.navigate("performance") { launchSingleTop = true }
                        },
                        onOpenTodoTab = { navController.navigateToTab(XzgTab.TODO) },
                        onOpenCustomer = {
                            navController.navigate("customer") { launchSingleTop = true }
                        },
                        onOpenExpiry = {
                            navController.navigate("expiry") { launchSingleTop = true }
                        },
                        onOpenMemo = {
                            navController.navigate("memo") { launchSingleTop = true }
                        },
                        onOpenDrawer = { scope.launch { drawerState.open() } },
                        onOpenQuickRecord = { activeSheet = RootSheet.QUICK_RECORD },
                        // 天气 Sheet 由 HomeScreen 内部自行展示，此处无需额外动作
                        onOpenWeather = {},
                    )
                }
            }
            composable(XzgTab.SCHEDULE.route) {
                ScheduleScreen(
                    onOpenCalendar = { navController.navigate("calendar") },
                    onTodoClick = { navController.navigate(XzgTab.TODO.route) { launchSingleTop = true } },
                    onExpiryClick = { navController.navigate("expiry") { launchSingleTop = true } },
                    onCustomerClick = { navController.navigate("customer") { launchSingleTop = true } },
                )
            }
            composable(XzgTab.ASSISTANT.route) {
                AIChatScreen(onVoice = { activeSheet = RootSheet.VOICE })
            }
            composable(XzgTab.TODO.route) {
                TodoScreen()
            }
            composable(XzgTab.PROFILE.route) {
                ProfileScreen(
                    onOpenPaymentCode = {
                        navController.navigate("paymentcode") { launchSingleTop = true }
                    }
                )
            }
            // ---- 抽屉目的地（二级页）----
            composable("transactions") {
                TransactionHistoryScreen(onBack = { navController.popBackStack() })
            }
            composable("performance") {
                PerformanceScreen(
                    onOpenTransactions = {
                        navController.navigate("transactions") { launchSingleTop = true }
                    },
                    onOpenSaobei = { activeSheet = RootSheet.SAOBEI }
                )
            }
            composable("customer") { CustomerScreen() }
            composable("expiry") { ExpiryScreen() }
            composable("goods") { GoodsScreen() }
            composable("memo") { MemoScreen() }
            composable("calendar") { CalendarScreen() }
            // ---- 工具页 ----
            composable("paymentcode") {
                PaymentCodeScreen(onBack = { navController.popBackStack() })
            }
        }
    }

    // ---- Root 级全局 Sheet ----
    activeSheet?.let { sheet ->
        ModalBottomSheet(onDismissRequest = { activeSheet = null }) {
            when (sheet) {
                RootSheet.REPORT ->
                    DailyReportSheet(onDismiss = { activeSheet = null })
                RootSheet.QUICK_RECORD ->
                    QuickRecordSheetContent(onDismiss = { activeSheet = null })
                RootSheet.VOICE ->
                    VoiceSheetContent(onDismiss = { activeSheet = null })
                RootSheet.SAOBEI ->
                    SaobeiImportSheet(onDismiss = { activeSheet = null })
            }
        }
    }
}

/** Root 级 Sheet：report / quickrecord / voice / saobei */
private enum class RootSheet(val key: String) {
    REPORT("report"),
    QUICK_RECORD("quickrecord"),
    VOICE("voice"),
    SAOBEI("saobei");

    companion object {
        fun fromKey(key: String): RootSheet? = values().find { it.key == key }
    }
}

private fun NavController.navigateToTab(tab: XzgTab) {
    navigate(tab.route) {
        popUpTo(graph.findStartDestination().id) { saveState = true }
        launchSingleTop = true
        restoreState = true
    }
}
