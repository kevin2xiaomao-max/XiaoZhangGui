package com.xiaozhanggui.app.ui.screens.profile

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.DarkMode
import androidx.compose.material.icons.filled.SettingsBrightness
import androidx.compose.material.icons.filled.Storefront
import androidx.compose.material.icons.filled.WbSunny
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
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
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.xiaozhanggui.app.data.datastore.AccentTheme
import com.xiaozhanggui.app.data.datastore.BackgroundTheme
import com.xiaozhanggui.app.data.datastore.ThemeMode
import com.xiaozhanggui.app.data.di.XzgGraph
import com.xiaozhanggui.app.ui.components.V32Card
import com.xiaozhanggui.app.ui.components.V32PrimaryButton
import com.xiaozhanggui.app.ui.components.V32SecondaryButton
import com.xiaozhanggui.app.ui.theme.LocalXzgPalettes
import com.xiaozhanggui.app.ui.theme.XzgDimens
import com.xiaozhanggui.app.ui.theme.XzgType
import com.xiaozhanggui.app.ui.theme.accentPalette
import com.xiaozhanggui.app.ui.theme.backgroundPalette
import java.io.File
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

/**
 * 我的页全部 Sheet（对应 iOS ProfileView 的 Sheets 清单，V32SheetChrome 容器语义）。
 *
 * - ShopEditSheet：店铺名称 + 店主称呼（trim 后均非空才可保存）
 * - GoalEditSheet：¥ + 金额输入（Double > 0 才可保存）
 * - ThemeChoiceSheet：跟随系统 / 浅色 / 深色
 * - AppearanceSheet：6 Accent 色圆 + 名称（底部说明"仅影响点缀色"）
 * - BackgroundSheet：6 背景风格（三层同心圆预览 + 名称）
 * - WallpaperSheet：相册选图存 filesDir + 效果三档 + 遮罩三档 + 删除（简化版：
 *   效果/遮罩只存选择，不做真实图片处理）
 * - ReminderSheet：待办提醒 / 临期退货提醒两个 Toggle
 * - AboutSheet：图标 + 版本 + 更新说明 + "V3.5 新变化"按钮 → ReleaseNotesSheet
 * - InfoSheet：隐私说明纯文本
 */

/** 我的页 Sheet 种类（ProfileScreen 用其驱动单个 ModalBottomSheet）。 */
sealed interface ProfileSheet {
    data object Shop : ProfileSheet
    data object Goal : ProfileSheet
    data object Theme : ProfileSheet
    data object Appearance : ProfileSheet
    data object Background : ProfileSheet
    data object Wallpaper : ProfileSheet
    data object Reminder : ProfileSheet
    data object About : ProfileSheet
    data object Privacy : ProfileSheet
}

/** Sheet 顶栏：标题居中 + 右上关闭（对应 iOS V32SheetChrome）。 */
@Composable
fun SheetHeader(title: String, onClose: () -> Unit) {
    val palettes = LocalXzgPalettes.current
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 4.dp)
    ) {
        Text(
            text = title,
            style = XzgType.headline,
            color = palettes.background.textPrimary,
            modifier = Modifier.align(Alignment.Center)
        )
        IconButton(
            onClick = onClose,
            modifier = Modifier.align(Alignment.CenterEnd).size(32.dp)
        ) {
            Icon(
                imageVector = Icons.Filled.Close,
                contentDescription = "关闭",
                tint = palettes.background.textTertiary,
                modifier = Modifier.size(18.dp)
            )
        }
    }
}

@Composable
private fun SheetColumn(content: @Composable () -> Unit) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = XzgDimens.pageMargin)
            .padding(bottom = XzgDimens.bottomPad)
            .verticalScroll(rememberScrollState()),
        verticalArrangement = Arrangement.spacedBy(12.dp),
        content = { content() }
    )
}

@Composable
private fun LabeledField(
    label: String,
    value: String,
    onValueChange: (String) -> Unit,
    placeholder: String = "",
    keyboardType: KeyboardType = KeyboardType.Text,
    leading: @Composable (() -> Unit)? = null,
) {
    val palettes = LocalXzgPalettes.current
    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
        Text(text = label, style = XzgType.caption, color = palettes.background.textTertiary)
        OutlinedTextField(
            value = value,
            onValueChange = onValueChange,
            placeholder = { Text(placeholder, style = XzgType.body) },
            singleLine = true,
            keyboardOptions = KeyboardOptions(keyboardType = keyboardType),
            leadingIcon = leading,
            textStyle = XzgType.body,
            shape = RoundedCornerShape(14.dp),
            modifier = Modifier.fillMaxWidth()
        )
    }
}

// ---------- 店铺信息 ----------

@Composable
fun ShopEditSheet(
    initialShop: String,
    initialOwner: String,
    onDismiss: () -> Unit,
) {
    val settings = remember { XzgGraph.settings }
    val scope = rememberCoroutineScope()
    var shop by remember(initialShop) { mutableStateOf(initialShop) }
    var owner by remember(initialOwner) { mutableStateOf(initialOwner) }
    val canSave = shop.trim().isNotEmpty() && owner.trim().isNotEmpty()

    SheetColumn {
        SheetHeader(title = "店铺信息", onClose = onDismiss)
        LabeledField(label = "店铺名称", value = shop, onValueChange = { shop = it })
        LabeledField(label = "店主称呼", value = owner, onValueChange = { owner = it })
        Spacer(modifier = Modifier.height(4.dp))
        V32PrimaryButton(
            text = "保存",
            onClick = {
                scope.launch {
                    settings.setShopName(shop.trim())
                    settings.setOwnerName(owner.trim())
                    onDismiss()
                }
            },
            modifier = Modifier.fillMaxWidth(),
            enabled = canSave
        )
    }
}

// ---------- 月营业目标 ----------

@Composable
fun GoalEditSheet(
    initialGoal: Double,
    onDismiss: () -> Unit,
) {
    val settings = remember { XzgGraph.settings }
    val scope = rememberCoroutineScope()
    var text by remember(initialGoal) {
        mutableStateOf(if (initialGoal > 0) initialGoal.toLong().toString() else "")
    }
    val amount = text.trim().toDoubleOrNull()

    SheetColumn {
        SheetHeader(title = "月营业目标", onClose = onDismiss)
        LabeledField(
            label = "目标金额",
            value = text,
            onValueChange = { text = it },
            placeholder = "例如 120000",
            keyboardType = KeyboardType.Decimal,
            leading = {
                val palettes = LocalXzgPalettes.current
                Text("¥", style = XzgType.body, color = palettes.background.textSecondary)
            }
        )
        Spacer(modifier = Modifier.height(4.dp))
        V32PrimaryButton(
            text = "保存",
            onClick = {
                scope.launch {
                    settings.setMonthGoal(amount ?: 0.0)
                    onDismiss()
                }
            },
            modifier = Modifier.fillMaxWidth(),
            enabled = (amount ?: 0.0) > 0
        )
    }
}

// ---------- 显示模式 ----------

private fun themeModeIcon(mode: ThemeMode): ImageVector = when (mode) {
    ThemeMode.SYSTEM -> Icons.Filled.SettingsBrightness
    ThemeMode.LIGHT -> Icons.Filled.WbSunny
    ThemeMode.DARK -> Icons.Filled.DarkMode
}

@Composable
fun ThemeChoiceSheet(onDismiss: () -> Unit) {
    val palettes = LocalXzgPalettes.current
    val settings = remember { XzgGraph.settings }
    val scope = rememberCoroutineScope()
    val current by settings.themeMode.collectAsStateWithLifecycle(initialValue = ThemeMode.SYSTEM)

    SheetColumn {
        SheetHeader(title = "显示模式", onClose = onDismiss)
        ThemeMode.values().forEach { mode ->
            val selected = mode == current
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(56.dp)
                    .clip(RoundedCornerShape(14.dp))
                    .clickable {
                        scope.launch {
                            settings.setThemeMode(mode)
                            onDismiss()
                        }
                    }
                    .padding(horizontal = 16.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Icon(
                    imageVector = themeModeIcon(mode),
                    contentDescription = null,
                    tint = if (selected) palettes.accent.accent else palettes.background.textSecondary,
                    modifier = Modifier.size(20.dp)
                )
                Spacer(modifier = Modifier.size(12.dp))
                Text(
                    text = mode.displayName(),
                    style = XzgType.title,
                    color = if (selected) palettes.accent.accent else palettes.background.textPrimary
                )
                Spacer(modifier = Modifier.weight(1f))
                if (selected) {
                    Icon(
                        imageVector = Icons.Filled.Check,
                        contentDescription = "已选中",
                        tint = palettes.accent.accent,
                        modifier = Modifier.size(20.dp)
                    )
                }
            }
        }
    }
}

// ---------- 外观（Accent） ----------

@Composable
fun AppearanceSheet(onDismiss: () -> Unit) {
    val palettes = LocalXzgPalettes.current
    val settings = remember { XzgGraph.settings }
    val scope = rememberCoroutineScope()
    val current by settings.accentTheme.collectAsStateWithLifecycle(initialValue = AccentTheme.EMERALD)
    val isDark = palettes.isDark

    SheetColumn {
        SheetHeader(title = "外观", onClose = onDismiss)
        AccentTheme.values().forEach { theme ->
            val selected = theme == current
            val dot = accentPalette(theme, isDark).accent
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(56.dp)
                    .clip(RoundedCornerShape(14.dp))
                    .clickable {
                        scope.launch {
                            settings.setAccentTheme(theme)
                            onDismiss()
                        }
                    }
                    .padding(horizontal = 16.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Box(
                    modifier = Modifier
                        .size(28.dp)
                        .clip(CircleShape)
                        .background(dot)
                )
                Spacer(modifier = Modifier.size(12.dp))
                Text(
                    text = theme.displayName(),
                    style = XzgType.title,
                    color = palettes.background.textPrimary
                )
                Spacer(modifier = Modifier.weight(1f))
                if (selected) {
                    Icon(
                        imageVector = Icons.Filled.Check,
                        contentDescription = "已选中",
                        tint = palettes.accent.accent,
                        modifier = Modifier.size(20.dp)
                    )
                }
            }
        }
        Text(
            text = "仅影响点缀色",
            style = XzgType.caption,
            color = palettes.background.textTertiary,
            textAlign = TextAlign.Center,
            modifier = Modifier.fillMaxWidth().padding(top = 4.dp)
        )
    }
}

// ---------- 背景风格 ----------

@Composable
fun BackgroundSheet(onDismiss: () -> Unit) {
    val palettes = LocalXzgPalettes.current
    val settings = remember { XzgGraph.settings }
    val scope = rememberCoroutineScope()
    val current by settings.backgroundTheme.collectAsStateWithLifecycle(initialValue = BackgroundTheme.WARM_CREAM)
    val isDark = palettes.isDark

    SheetColumn {
        SheetHeader(title = "背景风格", onClose = onDismiss)
        BackgroundTheme.values().forEach { theme ->
            val selected = theme == current
            val bp = backgroundPalette(theme, isDark)
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(60.dp)
                    .clip(RoundedCornerShape(14.dp))
                    .clickable {
                        scope.launch {
                            settings.setBackgroundTheme(theme)
                            onDismiss()
                        }
                    }
                    .padding(horizontal = 16.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                // 三层同心圆预览
                Box(
                    modifier = Modifier
                        .size(40.dp)
                        .clip(CircleShape)
                        .background(bp.pageBG)
                        .border(1.dp, bp.cardOutline, CircleShape),
                    contentAlignment = Alignment.Center
                ) {
                    Box(
                        modifier = Modifier
                            .size(26.dp)
                            .clip(CircleShape)
                            .background(bp.card),
                        contentAlignment = Alignment.Center
                    ) {
                        Box(
                            modifier = Modifier
                                .size(10.dp)
                                .clip(CircleShape)
                                .background(bp.textSecondary)
                        )
                    }
                }
                Spacer(modifier = Modifier.size(12.dp))
                Text(
                    text = theme.displayName(),
                    style = XzgType.title,
                    color = palettes.background.textPrimary
                )
                Spacer(modifier = Modifier.weight(1f))
                if (selected) {
                    Icon(
                        imageVector = Icons.Filled.Check,
                        contentDescription = "已选中",
                        tint = palettes.accent.accent,
                        modifier = Modifier.size(20.dp)
                    )
                }
            }
        }
        Text(
            text = "6 种背景风格，可与任意点缀色组合",
            style = XzgType.caption,
            color = palettes.background.textTertiary,
            textAlign = TextAlign.Center,
            modifier = Modifier.fillMaxWidth().padding(top = 4.dp)
        )
    }
}

// ---------- 壁纸 ----------

private const val WALLPAPER_FILE = "wallpaper.jpg"

private fun loadWallpaperBitmap(context: Context, fileName: String?): Bitmap? {
    if (fileName.isNullOrBlank()) return null
    val f = File(context.filesDir, fileName)
    return try {
        if (f.exists()) BitmapFactory.decodeFile(f.absolutePath) else null
    } catch (_: Exception) {
        null
    }
}

@Composable
private fun <T> SegmentedOptions(
    options: List<T>,
    selected: T,
    label: (T) -> String,
    onSelect: (T) -> Unit,
) {
    val palettes = LocalXzgPalettes.current
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        options.forEach { opt ->
            val isSel = opt == selected
            Box(
                modifier = Modifier
                    .weight(1f)
                    .height(44.dp)
                    .clip(RoundedCornerShape(12.dp))
                    .background(if (isSel) palettes.accent.accentSoft else palettes.background.card)
                    .border(
                        1.dp,
                        if (isSel) palettes.accent.accent else palettes.background.cardOutline,
                        RoundedCornerShape(12.dp)
                    )
                    .clickable { onSelect(opt) },
                contentAlignment = Alignment.Center
            ) {
                Text(
                    text = label(opt),
                    style = XzgType.title,
                    color = if (isSel) palettes.accent.accent else palettes.background.textSecondary
                )
            }
        }
    }
}

@Composable
fun WallpaperSheet(
    onDismiss: () -> Unit,
    onToast: (String) -> Unit,
) {
    val context = LocalContext.current
    val palettes = LocalXzgPalettes.current
    val settings = remember { XzgGraph.settings }
    val scope = rememberCoroutineScope()
    val wallpaperRaw by settings.wallpaperJson.collectAsStateWithLifecycle(initialValue = "")
    val config = remember(wallpaperRaw) { WallpaperConfig.decode(wallpaperRaw) }
    var error by remember { mutableStateOf<String?>(null) }

    val pickLauncher = rememberLauncherForActivityResult(ActivityResultContracts.GetContent()) { uri ->
        if (uri == null) return@rememberLauncherForActivityResult
        scope.launch {
            try {
                val bytes = withContext(Dispatchers.IO) {
                    context.contentResolver.openInputStream(uri)?.use { it.readBytes() }
                        ?: throw IllegalStateException("无法读取图片")
                }
                if (BitmapFactory.decodeByteArray(bytes, 0, bytes.size) == null) {
                    throw IllegalStateException("无法读取该图片，请换一张试试")
                }
                withContext(Dispatchers.IO) {
                    File(context.filesDir, WALLPAPER_FILE).writeBytes(bytes)
                }
                settings.setWallpaperJson(
                    config.copy(isEnabled = true, fileName = WALLPAPER_FILE).encode()
                )
                error = null
            } catch (e: Exception) {
                error = e.message ?: "选择图片失败"
            }
        }
    }

    val maskAlpha = when (WallpaperMask.from(config.mask)) {
        WallpaperMask.LIGHT -> 0.35f
        WallpaperMask.MEDIUM -> 0.5f
        WallpaperMask.STRONG -> 0.7f
    }

    SheetColumn {
        SheetHeader(title = "壁纸", onClose = onDismiss)
        // 预览卡（140dp 高）
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(140.dp)
                .clip(RoundedCornerShape(XzgDimens.card))
                .background(palettes.background.cardInset)
        ) {
            val bmp = remember(config.fileName) { loadWallpaperBitmap(context, config.fileName) }
            if (config.isEnabled && bmp != null) {
                Image(
                    bitmap = bmp.asImageBitmap(),
                    contentDescription = "当前壁纸",
                    modifier = Modifier.fillMaxSize()
                )
                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .background(Color.Black.copy(alpha = maskAlpha))
                )
                if (palettes.isDark) {
                    // 深色模式自动增强遮罩
                    Box(
                        modifier = Modifier
                            .fillMaxSize()
                            .background(Color.Black.copy(alpha = 0.15f))
                    )
                }
                Text(
                    text = "当前壁纸 · ${config.effectLabel()} · ${config.maskLabel()}",
                    style = XzgType.caption,
                    color = Color.White,
                    modifier = Modifier.align(Alignment.BottomStart).padding(12.dp)
                )
            } else {
                Text(
                    text = "未设置壁纸",
                    style = XzgType.subhead,
                    color = palettes.background.textTertiary,
                    modifier = Modifier.align(Alignment.Center)
                )
            }
        }
        V32SecondaryButton(
            text = "从相册选择",
            onClick = { pickLauncher.launch("image/*") },
            modifier = Modifier.fillMaxWidth()
        )
        if (config.isEnabled) {
            Text(text = "效果", style = XzgType.caption, color = palettes.background.textTertiary)
            SegmentedOptions(
                options = WallpaperEffect.values().toList(),
                selected = WallpaperEffect.from(config.effect),
                label = { it.label },
                onSelect = { eff ->
                    scope.launch {
                        settings.setWallpaperJson(config.copy(effect = eff.raw).encode())
                    }
                }
            )
            Text(text = "遮罩强度", style = XzgType.caption, color = palettes.background.textTertiary)
            SegmentedOptions(
                options = WallpaperMask.values().toList(),
                selected = WallpaperMask.from(config.mask),
                label = { it.label },
                onSelect = { m ->
                    scope.launch {
                        settings.setWallpaperJson(config.copy(mask = m.raw).encode())
                    }
                }
            )
            V32SecondaryButton(
                text = "删除壁纸",
                onClick = {
                    scope.launch {
                        withContext(Dispatchers.IO) {
                            try {
                                File(context.filesDir, WALLPAPER_FILE).delete()
                            } catch (_: Exception) {
                            }
                        }
                        settings.setWallpaperJson(WallpaperConfig.disabled.encode())
                        onToast("壁纸已删除")
                    }
                },
                modifier = Modifier.fillMaxWidth()
            )
        }
        error?.let {
            Text(text = it, style = XzgType.caption, color = palettes.fixed.danger)
        }
        Text(
            text = "壁纸保存在本机，不会上传。深色模式自动增强遮罩。",
            style = XzgType.caption,
            color = palettes.background.textQuaternary,
            textAlign = TextAlign.Center,
            modifier = Modifier.fillMaxWidth()
        )
    }
}

// ---------- 提醒设置 ----------

@Composable
private fun ToggleRow(
    title: String,
    description: String,
    checked: Boolean,
    onCheckedChange: (Boolean) -> Unit,
) {
    val palettes = LocalXzgPalettes.current
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .height(64.dp)
            .padding(horizontal = 16.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Column(modifier = Modifier.weight(1f)) {
            Text(text = title, style = XzgType.title, color = palettes.background.textPrimary)
            Text(text = description, style = XzgType.caption, color = palettes.background.textTertiary)
        }
        Switch(checked = checked, onCheckedChange = onCheckedChange)
    }
}

@Composable
fun ReminderSheet(onDismiss: () -> Unit) {
    val settings = remember { XzgGraph.settings }
    val scope = rememberCoroutineScope()
    val todoReminder by settings.todoReminderEnabled.collectAsStateWithLifecycle(initialValue = true)
    val expiryReminder by settings.expiryReminderEnabled.collectAsStateWithLifecycle(initialValue = true)

    SheetColumn {
        SheetHeader(title = "提醒设置", onClose = onDismiss)
        ToggleRow(
            title = "待办提醒",
            description = "到期前提醒你处理待办事项",
            checked = todoReminder,
            onCheckedChange = { scope.launch { settings.setTodoReminderEnabled(it) } }
        )
        ToggleRow(
            title = "临期退货提醒",
            description = "商品临近过期或可退货时提醒",
            checked = expiryReminder,
            onCheckedChange = { scope.launch { settings.setExpiryReminderEnabled(it) } }
        )
    }
}

// ---------- 关于 ----------

@Composable
fun AboutSheet(
    version: String,
    build: String,
    onOpenReleaseNotes: () -> Unit,
    onDismiss: () -> Unit,
) {
    val palettes = LocalXzgPalettes.current
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = XzgDimens.pageMargin)
            .padding(top = 12.dp, bottom = XzgDimens.bottomPad),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Box(
            modifier = Modifier
                .size(64.dp)
                .clip(CircleShape)
                .background(palettes.accent.accentSoft),
            contentAlignment = Alignment.Center
        ) {
            Icon(
                imageVector = Icons.Filled.Storefront,
                contentDescription = null,
                tint = palettes.accent.accent,
                modifier = Modifier.size(28.dp)
            )
        }
        Spacer(modifier = Modifier.height(12.dp))
        Text(text = "你的小掌柜", style = XzgType.section, color = palettes.background.textPrimary)
        Spacer(modifier = Modifier.height(4.dp))
        Text(
            text = "V$version（$build）",
            style = XzgType.caption,
            color = palettes.background.textTertiary
        )
        Spacer(modifier = Modifier.height(16.dp))
        V32Card(modifier = Modifier.fillMaxWidth()) {
            Text(
                text = "本次更新：V3.6 全新升级",
                style = XzgType.subhead,
                color = palettes.background.textSecondary,
                modifier = Modifier.fillMaxWidth()
            )
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .clickable { onOpenReleaseNotes() }
                    .padding(vertical = 8.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = "V3.5 新变化",
                    style = XzgType.title,
                    color = palettes.accent.accent
                )
                Spacer(modifier = Modifier.weight(1f))
                Icon(
                    imageVector = Icons.Filled.ChevronRight,
                    contentDescription = null,
                    tint = palettes.background.textTertiary,
                    modifier = Modifier.size(16.dp)
                )
            }
        }
        Spacer(modifier = Modifier.height(16.dp))
        IconButton(onClick = onDismiss, modifier = Modifier.size(40.dp)) {
            Icon(
                imageVector = Icons.Filled.Close,
                contentDescription = "关闭",
                tint = palettes.background.textQuaternary,
                modifier = Modifier.size(30.dp)
            )
        }
    }
}

// ---------- 更新说明 ----------

@Composable
private fun ReleaseNoteSection(title: String, items: List<String>) {
    val palettes = LocalXzgPalettes.current
    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
        Text(text = title, style = XzgType.title, color = palettes.background.textPrimary)
        items.forEach { item ->
            Text(
                text = "· $item",
                style = XzgType.subhead,
                color = palettes.background.textSecondary
            )
        }
    }
}

@Composable
fun ReleaseNotesSheet(
    version: String,
    build: String,
    onDismiss: () -> Unit,
) {
    SheetColumn {
        SheetHeader(title = "更新说明", onClose = onDismiss)
        Text(
            text = "你的小掌柜 V$version（$build）",
            style = XzgType.headline,
            color = LocalXzgPalettes.current.background.textPrimary
        )
        Text(
            text = "V3.6 全新升级",
            style = XzgType.subhead,
            color = LocalXzgPalettes.current.background.textSecondary
        )
        ReleaseNoteSection(
            title = "首页",
            items = listOf("Home 1.4 Compact 最终收口：营业额、趋势与今日重点更清晰")
        )
        ReleaseNoteSection(
            title = "导航",
            items = listOf("5 Tab 底部导航：首页 / 日程 / 小掌柜 / 待办 / 我的，随手可达")
        )
        ReleaseNoteSection(
            title = "小掌柜 AI",
            items = listOf("小掌柜 AI 对话：语音记一笔、快速记一笔，经营问题随问随答")
        )
    }
}

// ---------- 隐私说明 ----------

@Composable
fun InfoSheet(onDismiss: () -> Unit) {
    val palettes = LocalXzgPalettes.current
    SheetColumn {
        SheetHeader(title = "隐私说明", onClose = onDismiss)
        V32Card(modifier = Modifier.fillMaxWidth()) {
            Text(
                text = "店铺、客户、商品和营业数据默认仅保存在本机数据库。" +
                    "麦克风仅在你主动开始语音识别时使用；图片仅在你拍照或选择相册时读取。" +
                    "导出数据必须由你在系统分享面板中确认。",
                style = XzgType.body,
                color = palettes.background.textSecondary
            )
        }
    }
}
