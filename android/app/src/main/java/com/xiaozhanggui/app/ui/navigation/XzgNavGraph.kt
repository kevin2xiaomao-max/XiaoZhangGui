package com.xiaozhanggui.app.ui.navigation

import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Icon
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.navigation.NavDestination.Companion.hierarchy
import androidx.navigation.NavGraph.Companion.findStartDestination
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import com.xiaozhanggui.app.ui.screens.AssistantPlaceholderScreen
import com.xiaozhanggui.app.ui.screens.HomePlaceholderScreen
import com.xiaozhanggui.app.ui.screens.ProfilePlaceholderScreen
import com.xiaozhanggui.app.ui.screens.SchedulePlaceholderScreen
import com.xiaozhanggui.app.ui.screens.TodoPlaceholderScreen
import com.xiaozhanggui.app.ui.theme.LocalXzgPalettes
import com.xiaozhanggui.app.ui.theme.XzgType

/**
 * 导航骨架。对应 iOS `App/RootView.swift` 的 5 Tab TabView。
 *
 * Phase 1 仅骨架：底部导航栏 + NavHost + 5 个占位页面。
 * Phase 3 实现各 NavigationStack 内页；届时底部栏样式按 V32 视觉重做
 *（当前 Material3 NavigationBar 为占位，视觉以 iOS V3.6 为准）。
 *
 * iOS 行为备忘（Phase 3/5 实现）：
 * - iOS 26 下滑隐藏 tab bar → nestedScroll 等价
 * - 全局 Sheet（语音/速记，圆角 28，固定高度 260/340）
 * - 深链接 xzg:// → onNewIntent 分发
 */
@Composable
fun XzgNavGraph() {
    val navController = rememberNavController()
    val palettes = LocalXzgPalettes.current

    Scaffold(
        containerColor = palettes.background.pageBG,
        bottomBar = {
            NavigationBar(containerColor = palettes.background.card) {
                val navBackStackEntry by navController.currentBackStackEntryAsState()
                val currentDestination = navBackStackEntry?.destination
                XzgTab.values().forEach { tab ->
                    val selected =
                        currentDestination?.hierarchy?.any { it.route == tab.route } == true
                    NavigationBarItem(
                        selected = selected,
                        onClick = {
                            navController.navigate(tab.route) {
                                popUpTo(navController.graph.findStartDestination().id) {
                                    saveState = true
                                }
                                launchSingleTop = true
                                restoreState = true
                            }
                        },
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
    ) { innerPadding ->
        NavHost(
            navController = navController,
            startDestination = XzgTab.HOME.route,
            modifier = Modifier.padding(innerPadding)
        ) {
            composable(XzgTab.HOME.route) { HomePlaceholderScreen() }
            composable(XzgTab.SCHEDULE.route) { SchedulePlaceholderScreen() }
            composable(XzgTab.ASSISTANT.route) { AssistantPlaceholderScreen() }
            composable(XzgTab.TODO.route) { TodoPlaceholderScreen() }
            composable(XzgTab.PROFILE.route) { ProfilePlaceholderScreen() }
        }
    }
}
