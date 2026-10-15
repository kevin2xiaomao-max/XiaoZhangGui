package com.xiaozhanggui.app.ui.poc

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Button
import androidx.compose.material3.FilterChip
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.navigation.NavController
import androidx.navigation.NavGraphBuilder
import androidx.navigation.compose.composable
import com.xiaozhanggui.app.ui.poc.droplet.DropletMenuScreen
import com.xiaozhanggui.app.ui.poc.glass.GlassPocScreen
import com.xiaozhanggui.app.ui.poc.morph.MorphDemoScreen
import com.xiaozhanggui.app.ui.poc.transition.TransitionPocScreen

/**
 * PoC 导航隔离图（V3.8 Phase 2）。
 *
 * - 只在 [PocGate.enabled] 时由 `XzgNavGraph` 调用注册；
 *   release 构建（POC_ENABLED=false）不注册任何 PoC route。
 * - PoC 页与生产页物理隔离：生产 route 列表里没有 PoC route，
 *   生产 Screen 里没有指向 PoC 的 navigate 调用。
 */
fun NavGraphBuilder.pocGraph(navController: NavController) {
    if (!PocGate.enabled) return

    composable(PocRoutes.LAUNCHER) {
        PocLauncherScreen(
            onOpenDroplet = { navController.navigate(PocRoutes.DROPLET) },
            onOpenGlass = { navController.navigate(PocRoutes.GLASS) },
            onOpenMorph = { navController.navigate(PocRoutes.MORPH) },
            onOpenTransition = { navController.navigate(PocRoutes.TRANSITION) },
            onBack = { navController.popBackStack() },
        )
    }
    // PoC-1 液滴按钮菜单（真实实现：ui.poc.droplet）。
    composable(PocRoutes.DROPLET) {
        DropletMenuScreen(onBack = { navController.popBackStack() })
    }
    // PoC-2 玻璃材质三档（真实实现：ui.poc.glass）。
    composable(PocRoutes.GLASS) {
        GlassPocScreen(onBack = { navController.popBackStack() })
    }
    // PoC-3 连续形变（真实实现：ui.poc.morph）。
    composable(PocRoutes.MORPH) {
        MorphDemoScreen(onBack = { navController.popBackStack() })
    }
    // PoC-4 OPPO 私有转场探测报告（Worker C 本轮交付）。
    composable(PocRoutes.TRANSITION) {
        TransitionPocScreen(onBack = { navController.popBackStack() })
    }
}

/**
 * PoC 列表入口。仅经 `xzg://poc` 深链进入（debug 构建），
 * 生产页无入口；返回路径：系统返回键回调用方。
 */
@Composable
private fun PocLauncherScreen(
    onOpenDroplet: () -> Unit,
    onOpenGlass: () -> Unit,
    onOpenMorph: () -> Unit,
    onOpenTransition: () -> Unit,
    onBack: () -> Unit,
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(24.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Text("V3.8 PoC 隔离区", style = MaterialTheme.typography.headlineSmall)
        Text(
            "debug 构建专用；release 构建不编译此入口。" +
                "生产页无任何引用（grep 门禁）。",
            style = MaterialTheme.typography.bodySmall,
        )
        Text(
            "截图请分别在浅色 / 深色模式下采集。",
            style = MaterialTheme.typography.bodySmall,
        )
        // ── 全局速度控制（PocSpeed；便于慢放录屏）──
        Text(
            "当前速度：" +
                if (PocSpeed.mode == PocSpeedMode.SLOW) "慢放 ×4" else "正常 1x",
            style = MaterialTheme.typography.bodySmall,
        )
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            PocSpeedMode.entries.forEach { m ->
                FilterChip(
                    selected = PocSpeed.mode == m,
                    onClick = { PocSpeed.mode = m },
                    label = {
                        Text(if (m == PocSpeedMode.SLOW) "慢放 ×4" else "正常")
                    },
                )
            }
        }
        // 每个入口标注完整深链（方便脚本直达；Manifest 已注册 xzg:// + host=poc，
        // path 由 XzgDeepLink 解析，无需改 Manifest）。
        PocEntryButton("PoC-1 液滴按钮菜单\nxzg://poc/droplet", onOpenDroplet)
        PocEntryButton("PoC-2 玻璃材质三档\nxzg://poc/glass", onOpenGlass)
        PocEntryButton("PoC-3 连续形变\nxzg://poc/morph", onOpenMorph)
        PocEntryButton("PoC-4 转场探测报告\nxzg://poc/transition", onOpenTransition)
        PocEntryButton("返回", onBack)
    }
}

@Composable
private fun PocEntryButton(label: String, onClick: () -> Unit) {
    Button(onClick = onClick, modifier = Modifier.fillMaxWidth()) {
        Text(label)
    }
}
