package com.xiaozhanggui.app.ui.screens.profile

import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.os.Build
import android.provider.MediaStore
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AutoAwesome
import androidx.compose.material.icons.filled.Brush
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.Download
import androidx.compose.material.icons.filled.History
import androidx.compose.material.icons.filled.Image
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.filled.Layers
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.filled.Notifications
import androidx.compose.material.icons.filled.Palette
import androidx.compose.material.icons.filled.QrCode
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.SettingsBrightness
import androidx.compose.material.icons.filled.Storefront
import androidx.compose.material.icons.filled.TrendingUp
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.core.content.pm.PackageInfoCompat
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.xiaozhanggui.app.data.backup.BackupService
import com.xiaozhanggui.app.data.datastore.AccentTheme
import com.xiaozhanggui.app.data.datastore.BackgroundTheme
import com.xiaozhanggui.app.data.datastore.ThemeMode
import com.xiaozhanggui.app.data.di.XzgGraph
import com.xiaozhanggui.app.domain.Format
import com.xiaozhanggui.app.ui.components.ConfirmDeleteDialog
import com.xiaozhanggui.app.ui.theme.LocalXzgPalettes
import com.xiaozhanggui.app.ui.theme.XzgDimens
import com.xiaozhanggui.app.ui.theme.XzgType
import java.io.File
import kotlinx.coroutines.launch

/**
 * 我的页。对应 iOS `Features/Profile/ProfileView.swift`。
 *
 * 结构（ScrollView，navigationTitle "我的"）：
 * ① profileHero（店名/店主名，点击 → ShopEditSheet）
 * ② 「个性化」：显示模式 / 外观 / 背景风格 / 壁纸
 * ③ 「经营」：月营业目标 / 提醒设置
 * ④ 「演示」：Demo Mode Toggle + 琥珀提示 + 重置演示数据
 * ⑤ 「工具」：收款码（→ onOpenPaymentCode，由 NavGraph 跳转 paymentcode 路由）
 * ⑥ 「数据与应用」：数据备份 / 数据恢复 / 清理缓存 / 关于 / 隐私说明
 * ⑦ 底部居中版本号
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ProfileScreen(
    onOpenPaymentCode: () -> Unit = {},
    modifier: Modifier = Modifier,
) {
    val context = LocalContext.current
    val settings = remember { XzgGraph.settings }
    val scope = rememberCoroutineScope()
    val toast = rememberToastState()

    val shopName by settings.shopName.collectAsStateWithLifecycle(initialValue = "天福便利店")
    val ownerName by settings.ownerName.collectAsStateWithLifecycle(initialValue = "掌柜")
    val monthGoal by settings.monthGoal.collectAsStateWithLifecycle(initialValue = 120000.0)
    val themeMode by settings.themeMode.collectAsStateWithLifecycle(initialValue = ThemeMode.SYSTEM)
    val todoReminder by settings.todoReminderEnabled.collectAsStateWithLifecycle(initialValue = true)
    val expiryReminder by settings.expiryReminderEnabled.collectAsStateWithLifecycle(initialValue = true)
    val demoMode by settings.demoModeEnabled.collectAsStateWithLifecycle(initialValue = false)
    val accentTheme by settings.accentTheme.collectAsStateWithLifecycle(initialValue = AccentTheme.EMERALD)
    val backgroundTheme by settings.backgroundTheme.collectAsStateWithLifecycle(initialValue = BackgroundTheme.WARM_CREAM)
    val wallpaperRaw by settings.wallpaperJson.collectAsStateWithLifecycle(initialValue = "")
    val wallpaperEnabled = remember(wallpaperRaw) { WallpaperConfig.decode(wallpaperRaw).isEnabled }

    var sheet by remember { mutableStateOf<ProfileSheet?>(null) }
    var showReleaseNotes by remember { mutableStateOf(false) }
    var showClearCache by remember { mutableStateOf(false) }

    val versionName = remember {
        try {
            val info = context.packageManager.getPackageInfo(context.packageName, 0)
            info.versionName ?: "3.6.0"
        } catch (_: Exception) {
            "3.6.0"
        }
    }
    val buildNumber = remember {
        try {
            val info = context.packageManager.getPackageInfo(context.packageName, 0)
            PackageInfoCompat.getLongVersionCode(info).toString()
        } catch (_: Exception) {
            "36"
        }
    }

    // 数据恢复：选 JSON 文件 → restore → toast"已恢复 N 条记录"
    val restoreLauncher = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()) { uri ->
        if (uri == null) return@rememberLauncherForActivityResult
        scope.launch {
            try {
                val text = context.contentResolver.openInputStream(uri)?.use {
                    it.bufferedReader().readText()
                } ?: throw IllegalStateException("无法读取所选文件")
                val count = XzgGraph.backupService.restore(text)
                toast.show("已恢复 $count 条记录")
            } catch (e: Exception) {
                toast.show("恢复失败：${e.message ?: "未知错误"}")
            }
        }
    }

    fun doBackup() {
        scope.launch {
            try {
                val file = XzgGraph.backupService.exportToFile()
                shareBackupFile(context, file)
            } catch (e: Exception) {
                toast.show("备份失败：${e.message ?: "未知错误"}")
            }
        }
    }

    Box(modifier = modifier.fillMaxSize()) {
        ProfileContent(
            shopName = shopName,
            ownerName = ownerName,
            monthGoal = monthGoal,
            themeModeLabel = themeMode.displayName(),
            accentLabel = accentTheme.displayName(),
            backgroundLabel = backgroundTheme.displayName(),
            wallpaperEnabled = wallpaperEnabled,
            reminderEnabled = todoReminder || expiryReminder,
            demoMode = demoMode,
            versionName = versionName,
            onShopEdit = { sheet = ProfileSheet.Shop },
            onTheme = { sheet = ProfileSheet.Theme },
            onAppearance = { sheet = ProfileSheet.Appearance },
            onBackground = { sheet = ProfileSheet.Background },
            onWallpaper = { sheet = ProfileSheet.Wallpaper },
            onGoal = { sheet = ProfileSheet.Goal },
            onReminder = { sheet = ProfileSheet.Reminder },
            onDemoChange = { scope.launch { settings.setDemoModeEnabled(it) } },
            onResetDemo = { toast.show("演示数据已重置") },
            onPaymentCode = onOpenPaymentCode,
            onBackup = { doBackup() },
            onRestore = { restoreLauncher.launch(arrayOf("application/json")) },
            onClearCache = { showClearCache = true },
            onAbout = { sheet = ProfileSheet.About },
            onPrivacy = { sheet = ProfileSheet.Privacy },
            modifier = modifier
        )
        XzgToastHost(state = toast)
    }

    // ---- Sheets ----
    sheet?.let { current ->
        ModalBottomSheet(onDismissRequest = { sheet = null }) {
            when (current) {
                ProfileSheet.Shop -> ShopEditSheet(
                    initialShop = shopName,
                    initialOwner = ownerName,
                    onDismiss = { sheet = null }
                )
                ProfileSheet.Goal -> GoalEditSheet(
                    initialGoal = monthGoal,
                    onDismiss = { sheet = null }
                )
                ProfileSheet.Theme -> ThemeChoiceSheet(onDismiss = { sheet = null })
                ProfileSheet.Appearance -> AppearanceSheet(onDismiss = { sheet = null })
                ProfileSheet.Background -> BackgroundSheet(onDismiss = { sheet = null })
                ProfileSheet.Wallpaper -> WallpaperSheet(
                    onDismiss = { sheet = null },
                    onToast = { toast.show(it) }
                )
                ProfileSheet.Reminder -> ReminderSheet(onDismiss = { sheet = null })
                ProfileSheet.About -> AboutSheet(
                    version = versionName,
                    build = buildNumber,
                    onOpenReleaseNotes = { showReleaseNotes = true },
                    onDismiss = { sheet = null }
                )
                ProfileSheet.Privacy -> InfoSheet(onDismiss = { sheet = null })
            }
        }
    }
    if (showReleaseNotes) {
        ModalBottomSheet(onDismissRequest = { showReleaseNotes = false }) {
            ReleaseNotesSheet(
                version = versionName,
                build = buildNumber,
                onDismiss = { showReleaseNotes = false }
            )
        }
    }
    if (showClearCache) {
        ConfirmDeleteDialog(
            title = "清理缓存",
            message = "仅清除图片缓存，不会删除任何经营数据。",
            onConfirm = {
                showClearCache = false
                toast.show("缓存已清理")
            },
            onDismiss = { showClearCache = false }
        )
    }
}

/**
 * 我的页纯渲染内容（Paparazzi 截图入口）。
 * Sheet / 文件选择 / 备份分享 / Toast 保留在 [ProfileScreen]。
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ProfileContent(
    shopName: String,
    ownerName: String,
    monthGoal: Double,
    themeModeLabel: String,
    accentLabel: String,
    backgroundLabel: String,
    wallpaperEnabled: Boolean,
    reminderEnabled: Boolean,
    demoMode: Boolean,
    versionName: String,
    onShopEdit: () -> Unit = {},
    onTheme: () -> Unit = {},
    onAppearance: () -> Unit = {},
    onBackground: () -> Unit = {},
    onWallpaper: () -> Unit = {},
    onGoal: () -> Unit = {},
    onReminder: () -> Unit = {},
    onDemoChange: (Boolean) -> Unit = {},
    onResetDemo: () -> Unit = {},
    onPaymentCode: () -> Unit = {},
    onBackup: () -> Unit = {},
    onRestore: () -> Unit = {},
    onClearCache: () -> Unit = {},
    onAbout: () -> Unit = {},
    onPrivacy: () -> Unit = {},
    modifier: Modifier = Modifier
) {
    val palettes = LocalXzgPalettes.current
    Scaffold(
        modifier = modifier,
        containerColor = palettes.background.pageBG,
        topBar = {
            TopAppBar(
                title = {
                    Text(
                        text = "我的",
                        style = XzgType.pageTitle,
                        color = palettes.background.textPrimary
                    )
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = palettes.background.pageBG
                )
            )
        }
    ) { padding ->
        LazyColumn(
            modifier = Modifier
                .padding(padding)
                .fillMaxSize(),
            contentPadding = PaddingValues(
                horizontal = XzgDimens.pageMargin,
                vertical = 8.dp
            ),
            verticalArrangement = Arrangement.spacedBy(XzgDimens.sectionGap)
        ) {
            // ① profileHero
            item {
                ProfileHero(
                    shopName = shopName,
                    ownerName = ownerName,
                    onClick = onShopEdit
                )
            }
            // ② 个性化
            item {
                SettingsGroup(title = "个性化") {
                    ProfileRow(
                        icon = Icons.Filled.SettingsBrightness,
                        tone = palettes.fixed.info,
                        title = "显示模式",
                        value = themeModeLabel,
                        onClick = onTheme
                    )
                    SettingsDivider()
                    ProfileRow(
                        icon = Icons.Filled.Palette,
                        tone = palettes.accent.accent,
                        title = "外观",
                        value = accentLabel,
                        onClick = onAppearance
                    )
                    SettingsDivider()
                    ProfileRow(
                        icon = Icons.Filled.Layers,
                        tone = palettes.background.neutral,
                        title = "背景风格",
                        value = backgroundLabel,
                        onClick = onBackground
                    )
                    SettingsDivider()
                    ProfileRow(
                        icon = Icons.Filled.Image,
                        tone = palettes.fixed.amber,
                        title = "壁纸",
                        value = if (wallpaperEnabled) "已设置" else "未设置",
                        onClick = onWallpaper
                    )
                }
            }
            // ③ 经营
            item {
                SettingsGroup(title = "经营") {
                    ProfileRow(
                        icon = Icons.Filled.TrendingUp,
                        tone = palettes.accent.accent,
                        title = "月营业目标",
                        value = Format.groupedInt(monthGoal),
                        onClick = onGoal
                    )
                    SettingsDivider()
                    ProfileRow(
                        icon = Icons.Filled.Notifications,
                        tone = palettes.fixed.amber,
                        title = "提醒设置",
                        value = if (reminderEnabled) "已开启" else "已关闭",
                        onClick = onReminder
                    )
                }
            }
            // ④ 演示
            item {
                SettingsGroup(title = "演示") {
                    DemoModeRow(
                        checked = demoMode,
                        onCheckedChange = onDemoChange
                    )
                    if (demoMode) {
                        SettingsDivider()
                        Box(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(horizontal = 16.dp, vertical = 10.dp)
                                .clip(RoundedCornerShape(12.dp))
                                .background(palettes.fixed.amberSoft)
                                .padding(12.dp)
                        ) {
                            Text(
                                text = "演示模式使用独立演示数据，不会影响真实经营数据。",
                                style = XzgType.caption,
                                color = palettes.fixed.amber
                            )
                        }
                        ProfileRow(
                            icon = Icons.Filled.Refresh,
                            tone = palettes.background.neutral,
                            title = "重置演示数据",
                            value = "独立内存",
                            showChevron = false,
                            onClick = onResetDemo
                        )
                    }
                }
            }
            // ⑤ 工具
            item {
                SettingsGroup(title = "工具") {
                    ProfileRow(
                        icon = Icons.Filled.QrCode,
                        tone = palettes.accent.accent,
                        title = "收款码",
                        onClick = onPaymentCode
                    )
                }
            }
            // ⑥ 数据与应用
            item {
                SettingsGroup(title = "数据与应用") {
                    ProfileRow(
                        icon = Icons.Filled.Download,
                        tone = palettes.background.neutral,
                        title = "数据备份",
                        value = "JSON 文件",
                        showChevron = false,
                        onClick = onBackup
                    )
                    SettingsDivider()
                    ProfileRow(
                        icon = Icons.Filled.History,
                        tone = palettes.background.neutral,
                        title = "数据恢复",
                        value = "JSON",
                        showChevron = false,
                        onClick = onRestore
                    )
                    SettingsDivider()
                    ProfileRow(
                        icon = Icons.Filled.Brush,
                        tone = palettes.background.neutral,
                        title = "清理缓存",
                        onClick = onClearCache
                    )
                    SettingsDivider()
                    ProfileRow(
                        icon = Icons.Filled.Info,
                        tone = palettes.fixed.info,
                        title = "关于你的小掌柜",
                        onClick = onAbout
                    )
                    SettingsDivider()
                    ProfileRow(
                        icon = Icons.Filled.Lock,
                        tone = palettes.background.neutral,
                        title = "隐私说明",
                        onClick = onPrivacy
                    )
                }
            }
            // ⑦ 底部版本号
            item {
                Text(
                    text = "v$versionName",
                    style = XzgType.caption,
                    color = palettes.background.textQuaternary,
                    textAlign = TextAlign.Center,
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(vertical = 8.dp)
                )
            }
        }
    }
}

/** 店铺 Hero：图标 + 店名 / 店主名 · 你的小掌柜 + chevron，点击打开店铺信息 Sheet。 */
@Composable
private fun ProfileHero(
    shopName: String,
    ownerName: String,
    onClick: () -> Unit,
) {
    val palettes = LocalXzgPalettes.current
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(16.dp))
            .clickable(onClick = onClick)
            .padding(vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Icon(
            imageVector = Icons.Filled.Storefront,
            contentDescription = null,
            tint = palettes.accent.accent,
            modifier = Modifier.size(28.dp)
        )
        Spacer(modifier = Modifier.width(12.dp))
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = shopName.ifBlank { "我的小店" },
                style = XzgType.section,
                color = palettes.background.textPrimary
            )
            Spacer(modifier = Modifier.height(2.dp))
            Text(
                text = "${ownerName.ifBlank { "老板" }} · 你的小掌柜",
                style = XzgType.subhead,
                color = palettes.background.textTertiary
            )
        }
        Icon(
            imageVector = Icons.Filled.ChevronRight,
            contentDescription = null,
            tint = palettes.background.textQuaternary,
            modifier = Modifier.size(16.dp)
        )
    }
}

/** 设置分组：caption 标题 + 卡片容器（对应 iOS settingsGroup）。 */
@Composable
private fun SettingsGroup(
    title: String,
    content: @Composable ColumnScope.() -> Unit,
) {
    val palettes = LocalXzgPalettes.current
    Column {
        Text(
            text = title,
            style = XzgType.caption,
            color = palettes.background.textTertiary,
            modifier = Modifier.padding(start = 4.dp, bottom = 8.dp)
        )
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(XzgDimens.card))
                .background(palettes.background.card)
                .border(1.dp, palettes.background.cardOutline, RoundedCornerShape(XzgDimens.card)),
            content = content
        )
    }
}

/** 行间 divider（leading 48，对应 iOS settingsGroup 行间 divider）。 */
@Composable
private fun SettingsDivider() {
    val palettes = LocalXzgPalettes.current
    HorizontalDivider(
        color = palettes.background.divider,
        modifier = Modifier.padding(start = 48.dp)
    )
}

/**
 * 设置行：图标（16pt，tone 色，宽 24）+ 标题（15 semibold）+ 右侧值（12，textTertiary）
 * + chevron；minHeight 54（对应 iOS ProfileRow）。
 */
@Composable
fun ProfileRow(
    icon: ImageVector,
    tone: Color,
    title: String,
    value: String? = null,
    showChevron: Boolean = true,
    onClick: (() -> Unit)? = null,
) {
    val palettes = LocalXzgPalettes.current
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .height(54.dp)
            .let { if (onClick != null) it.clickable(onClick = onClick) else it }
            .padding(horizontal = 16.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Box(
            modifier = Modifier.width(24.dp),
            contentAlignment = Alignment.CenterStart
        ) {
            Icon(
                imageVector = icon,
                contentDescription = null,
                tint = tone,
                modifier = Modifier.size(16.dp)
            )
        }
        Spacer(modifier = Modifier.width(8.dp))
        Text(
            text = title,
            style = XzgType.title,
            color = palettes.background.textPrimary
        )
        Spacer(modifier = Modifier.weight(1f))
        if (value != null) {
            Text(
                text = value,
                style = XzgType.caption,
                color = palettes.background.textTertiary
            )
            Spacer(modifier = Modifier.width(6.dp))
        }
        if (showChevron) {
            Icon(
                imageVector = Icons.Filled.ChevronRight,
                contentDescription = null,
                tint = palettes.background.textQuaternary,
                modifier = Modifier.size(14.dp)
            )
        }
    }
}

/** Demo Mode 行：图标 + 标题 + Switch（tint brand，对应 iOS Toggle）。 */
@Composable
private fun DemoModeRow(
    checked: Boolean,
    onCheckedChange: (Boolean) -> Unit,
) {
    val palettes = LocalXzgPalettes.current
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .height(54.dp)
            .padding(horizontal = 16.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Box(
            modifier = Modifier.width(24.dp),
            contentAlignment = Alignment.CenterStart
        ) {
            Icon(
                imageVector = Icons.Filled.AutoAwesome,
                contentDescription = null,
                tint = palettes.fixed.info,
                modifier = Modifier.size(16.dp)
            )
        }
        Spacer(modifier = Modifier.width(8.dp))
        Text(
            text = "Demo Mode",
            style = XzgType.title,
            color = palettes.background.textPrimary,
            modifier = Modifier.weight(1f)
        )
        Switch(checked = checked, onCheckedChange = onCheckedChange)
    }
}

/**
 * 备份分享（ACTION_SEND）。
 *
 * Manifest 未声明 FileProvider：API 29+ 走 MediaStore.Downloads 生成 content:// URI
 * 分享真实文件（避免 file:// URI 在 API 24+ 触发 FileUriExposedException）；
 * API 26–28 降级为分享 JSON 文本内容。
 */
private fun shareBackupFile(context: Context, file: File) {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
        val values = ContentValues().apply {
            put(MediaStore.Downloads.DISPLAY_NAME, BackupService.FILE_NAME)
            put(MediaStore.Downloads.MIME_TYPE, "application/json")
        }
        val resolver = context.contentResolver
        val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
            ?: throw IllegalStateException("无法创建分享文件")
        resolver.openOutputStream(uri)?.use { out ->
            file.inputStream().use { it.copyTo(out) }
        } ?: throw IllegalStateException("无法写入分享文件")
        val send = Intent(Intent.ACTION_SEND).apply {
            type = "application/json"
            putExtra(Intent.EXTRA_STREAM, uri)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        context.startActivity(Intent.createChooser(send, "分享备份文件"))
    } else {
        val send = Intent(Intent.ACTION_SEND).apply {
            type = "text/plain"
            putExtra(Intent.EXTRA_TEXT, file.readText())
        }
        context.startActivity(Intent.createChooser(send, "分享备份文件"))
    }
}
