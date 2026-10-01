package com.xiaozhanggui.app.ui.screens.home

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AddCircle
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Description
import androidx.compose.material.icons.filled.FileDownload
import androidx.compose.material.icons.filled.HourglassEmpty
import androidx.compose.material.icons.filled.Inventory2
import androidx.compose.material.icons.filled.NoteAlt
import androidx.compose.material.icons.filled.People
import androidx.compose.material.icons.filled.ReceiptLong
import androidx.compose.material3.DrawerState
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.ModalDrawerSheet
import androidx.compose.material3.ModalNavigationDrawer
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.xiaozhanggui.app.ui.theme.LocalXzgPalettes
import com.xiaozhanggui.app.ui.theme.XzgType
import kotlinx.coroutines.launch

/**
 * 左侧经营快捷抽屉（对应 iOS V35SideUtilityDrawer / V35DrawerContainer）。
 *
 * - 宽 = 屏宽 × 0.84，clamp 300..380dp；右侧圆角 32；背景遮罩黑 0.23（点按关闭）
 * - 8 个目的地：5 个 push（[onNavigate]，route 取值
 *   "transactions"/"customer"/"expiry"/"goods"/"memo"），
 *   3 个 sheet（[onOpenSheet]，name 取值 "report"/"quickrecord"/"saobei"）
 * - 分组标题：经营 / 工具 / 快捷操作；右上关闭钮
 *
 * 点击任一目的地先关闭抽屉再触发回调。shell 层负责：
 * - onNavigate(route) → 导航到对应页面
 * - onOpenSheet("report") → 展示 [DailyReportSheet]
 * - onOpenSheet("quickrecord"/"saobei") → 展示快速记录 / 扫呗导入 Sheet
 */
private data class DrawerDestination(
    val title: String,
    val icon: ImageVector,
    /** 5 个 push 目的地之一（"transactions"/"customer"/"expiry"/"goods"/"memo"），sheet 目的地为 null */
    val route: String?,
    /** 3 个 sheet 目的地之一（"report"/"quickrecord"/"saobei"），push 目的地为 null */
    val sheet: String?
)

private data class DrawerGroup(val title: String, val items: List<DrawerDestination>)

private val drawerGroups = listOf(
    DrawerGroup(
        "经营", listOf(
            // 交易记录 list.bullet.rectangle / 报告 doc.text.magnifyingglass /
            // 客户需求 person.2 / 临期退货 clock.badge.exclamationmark
            DrawerDestination("交易记录", Icons.Filled.ReceiptLong, route = "transactions", sheet = null),
            DrawerDestination("今日经营报告", Icons.Filled.Description, route = null, sheet = "report"),
            DrawerDestination("客户需求", Icons.Filled.People, route = "customer", sheet = null),
            DrawerDestination("临期退货", Icons.Filled.HourglassEmpty, route = "expiry", sheet = null)
        )
    ),
    DrawerGroup(
        "工具", listOf(
            // 商品 shippingbox / 备忘 note.text
            DrawerDestination("商品", Icons.Filled.Inventory2, route = "goods", sheet = null),
            DrawerDestination("备忘", Icons.Filled.NoteAlt, route = "memo", sheet = null)
        )
    ),
    DrawerGroup(
        "快捷操作", listOf(
            // 快速记一笔 plus.circle / 扫呗导入 square.and.arrow.down
            DrawerDestination("快速记一笔", Icons.Filled.AddCircle, route = null, sheet = "quickrecord"),
            DrawerDestination("扫呗导入", Icons.Filled.FileDownload, route = null, sheet = "saobei")
        )
    )
)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun HomeDrawer(
    drawerState: DrawerState,
    onNavigate: (route: String) -> Unit,
    onOpenSheet: (name: String) -> Unit,
    modifier: Modifier = Modifier,
    content: @Composable () -> Unit
) {
    val palettes = LocalXzgPalettes.current
    val scope = rememberCoroutineScope()
    val screenWidth = LocalConfiguration.current.screenWidthDp.dp
    val drawerWidth = (screenWidth * 0.84f).coerceIn(300.dp, 380.dp)

    fun handleDestination(dest: DrawerDestination) {
        scope.launch {
            drawerState.close()
            val route = dest.route
            if (route != null) onNavigate(route) else onOpenSheet(dest.sheet ?: return@launch)
        }
    }

    ModalNavigationDrawer(
        drawerState = drawerState,
        gesturesEnabled = true,
        scrimColor = Color.Black.copy(alpha = 0.23f),
        drawerContent = {
            ModalDrawerSheet(
                modifier = Modifier.width(drawerWidth),
                drawerShape = RoundedCornerShape(topEnd = 32.dp, bottomEnd = 32.dp),
                drawerContainerColor = palettes.background.cardElevated,
                drawerContentColor = palettes.background.textPrimary
            ) {
                DrawerContent(
                    onDestination = ::handleDestination,
                    onClose = { scope.launch { drawerState.close() } }
                )
            }
        },
        content = content,
        modifier = modifier
    )
}

@Composable
private fun DrawerContent(
    onDestination: (DrawerDestination) -> Unit,
    onClose: () -> Unit
) {
    val palettes = LocalXzgPalettes.current
    val bg = palettes.background

    Column(
        modifier = Modifier
            .fillMaxHeight()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 16.dp)
            .padding(top = 12.dp, bottom = 24.dp)
    ) {
        // 右上关闭钮（34×34 圆形，subtleTint 底）
        Box(
            modifier = Modifier.fillMaxWidth(),
            contentAlignment = Alignment.CenterEnd
        ) {
            IconButton(
                onClick = onClose,
                modifier = Modifier
                    .size(34.dp)
                    .clip(CircleShape)
                    .background(palettes.accent.subtleTint)
            ) {
                Icon(
                    Icons.Filled.Close,
                    contentDescription = "关闭",
                    tint = bg.textSecondary,
                    modifier = Modifier.size(18.dp)
                )
            }
        }
        drawerGroups.forEach { group ->
            Text(
                group.title,
                fontSize = 12.sp,
                fontWeight = FontWeight.SemiBold,
                letterSpacing = 1.1.sp,
                color = bg.textTertiary,
                modifier = Modifier.padding(top = 16.dp, bottom = 4.dp, start = 4.dp)
            )
            group.items.forEach { dest ->
                DrawerRow(dest = dest, onClick = { onDestination(dest) })
            }
        }
    }
}

@Composable
private fun DrawerRow(
    dest: DrawerDestination,
    onClick: () -> Unit
) {
    val palettes = LocalXzgPalettes.current
    val bg = palettes.background
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .heightIn(min = 44.dp)
            .clip(RoundedCornerShape(12.dp))
            .clickable(onClick = onClick, role = Role.Button)
            .padding(horizontal = 4.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Icon(
            dest.icon,
            contentDescription = null,
            tint = palettes.accent.accent,
            modifier = Modifier.size(20.dp)
        )
        Text(
            dest.title,
            style = XzgType.body,
            color = bg.textPrimary,
            modifier = Modifier.weight(1f)
        )
    }
}
