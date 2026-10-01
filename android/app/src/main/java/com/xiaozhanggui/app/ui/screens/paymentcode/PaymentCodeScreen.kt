package com.xiaozhanggui.app.ui.screens.paymentcode

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.BrokenImage
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.MoreVert
import androidx.compose.material.icons.filled.QrCode
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Scaffold
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
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.xiaozhanggui.app.ui.components.ConfirmDeleteDialog
import com.xiaozhanggui.app.ui.components.V32EmptyState
import com.xiaozhanggui.app.ui.components.V32PrimaryButton
import com.xiaozhanggui.app.ui.screens.profile.XzgToastHost
import com.xiaozhanggui.app.ui.screens.profile.rememberToastState
import com.xiaozhanggui.app.ui.theme.LocalXzgPalettes
import com.xiaozhanggui.app.ui.theme.XzgDimens
import com.xiaozhanggui.app.ui.theme.XzgType
import java.io.File
import kotlinx.coroutines.launch

/**
 * 收款码列表页。对应 iOS `Features/PaymentCode/PaymentCodeView.swift`。
 *
 * - 按 order 升序；每行 52dp 缩略图（圆角 12）+ 名称 + 类型副标题 + 右上菜单
 *   （重命名 / 替换图片 / 删除 → ConfirmDeleteDialog「删除这张收款码？」）
 * - 空态 + 「添加收款码」按钮；底部隐私脚注
 * - 点击行 → 全屏展示（[PaymentCodeFullScreen]）
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun PaymentCodeScreen(
    onBack: () -> Unit = {},
    modifier: Modifier = Modifier,
) {
    val context = LocalContext.current
    val palettes = LocalXzgPalettes.current
    val scope = rememberCoroutineScope()
    val toast = rememberToastState()

    val codes by PaymentCodeStore.codesFlow()
        .collectAsStateWithLifecycle(initialValue = emptyList())

    var editorTarget by remember { mutableStateOf<PaymentCode?>(null) }
    var showEditor by remember { mutableStateOf(false) }
    var deleteTarget by remember { mutableStateOf<PaymentCode?>(null) }
    var fullScreenIndex by remember { mutableStateOf<Int?>(null) }

    fun openEditor(code: PaymentCode?) {
        editorTarget = code
        showEditor = true
    }

    Box(modifier = modifier.fillMaxSize()) {
        Scaffold(
            containerColor = palettes.background.pageBG,
            topBar = {
                TopAppBar(
                    title = {
                        Text(
                            text = "收款码",
                            style = XzgType.pageTitle,
                            color = palettes.background.textPrimary
                        )
                    },
                    navigationIcon = {
                        IconButton(onClick = onBack) {
                            Icon(
                                imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                                contentDescription = "返回",
                                tint = palettes.background.textPrimary
                            )
                        }
                    },
                    colors = TopAppBarDefaults.topAppBarColors(
                        containerColor = palettes.background.pageBG
                    )
                )
            }
        ) { padding ->
            if (codes.isEmpty()) {
                Column(
                    modifier = Modifier
                        .padding(padding)
                        .fillMaxSize()
                        .padding(horizontal = XzgDimens.pageMargin),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.Center
                ) {
                    V32EmptyState(
                        icon = Icons.Filled.QrCode,
                        title = "还没有收款码",
                        message = "添加微信或支付宝收款码，结账时快速出示",
                        actionText = "添加收款码",
                        onAction = { openEditor(null) }
                    )
                    Spacer(modifier = Modifier.height(24.dp))
                    PrivacyFootnote()
                }
            } else {
                LazyColumn(
                    modifier = Modifier
                        .padding(padding)
                        .fillMaxSize(),
                    contentPadding = PaddingValues(vertical = 8.dp)
                ) {
                    items(codes, key = { it.id }) { code ->
                        PaymentCodeRow(
                            code = code,
                            onOpen = { fullScreenIndex = codes.indexOf(code) },
                            onRename = { openEditor(code) },
                            onReplaceImage = { openEditor(code) },
                            onDelete = { deleteTarget = code }
                        )
                    }
                    item {
                        V32PrimaryButton(
                            text = "添加收款码",
                            onClick = { openEditor(null) },
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(horizontal = XzgDimens.pageMargin, vertical = 12.dp)
                        )
                    }
                    item {
                        PrivacyFootnote(
                            modifier = Modifier.padding(
                                horizontal = XzgDimens.pageMargin,
                                vertical = 12.dp
                            )
                        )
                    }
                }
            }
        }
        XzgToastHost(state = toast)
    }

    if (showEditor) {
        ModalBottomSheet(onDismissRequest = { showEditor = false }) {
            PaymentCodeEditorSheet(
                code = editorTarget,
                onDismiss = { showEditor = false },
                onSaved = {
                    showEditor = false
                    toast.show(if (editorTarget == null) "收款码已添加" else "已保存")
                }
            )
        }
    }

    deleteTarget?.let { target ->
        ConfirmDeleteDialog(
            title = "删除这张收款码？",
            message = "将同时删除本机保存的收款码图片，此操作不可撤销。",
            onConfirm = {
                scope.launch {
                    PaymentCodeStore.delete(context, target.id)
                    deleteTarget = null
                    toast.show("已删除")
                }
            },
            onDismiss = { deleteTarget = null }
        )
    }

    fullScreenIndex?.let { index ->
        val safeIndex = index.coerceIn(codes.indices)
        if (codes.isNotEmpty()) {
            PaymentCodeFullScreen(
                codes = codes,
                startIndex = safeIndex,
                onDismiss = { fullScreenIndex = null }
            )
        }
    }
}

/** 底部隐私脚注（常驻）。 */
@Composable
private fun PrivacyFootnote(modifier: Modifier = Modifier) {
    val palettes = LocalXzgPalettes.current
    Text(
        text = "图片仅保存在本设备，不会上传服务器或发送给任何服务",
        style = XzgType.caption,
        color = palettes.background.textQuaternary,
        textAlign = TextAlign.Center,
        modifier = modifier.fillMaxWidth()
    )
}

@Composable
private fun PaymentCodeRow(
    code: PaymentCode,
    onOpen: () -> Unit,
    onRename: () -> Unit,
    onReplaceImage: () -> Unit,
    onDelete: () -> Unit,
) {
    val context = LocalContext.current
    val palettes = LocalXzgPalettes.current
    var menuExpanded by remember { mutableStateOf(false) }

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onOpen)
            .padding(horizontal = XzgDimens.pageMargin, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        val file = remember(code.id, code.fileName) {
            PaymentCodeStore.imageFile(context, code)
        }
        val bitmap = rememberCodeBitmap(file)
        Box(
            modifier = Modifier
                .size(52.dp)
                .clip(RoundedCornerShape(12.dp))
                .background(palettes.background.cardInset),
            contentAlignment = Alignment.Center
        ) {
            if (bitmap != null) {
                Image(
                    bitmap = bitmap,
                    contentDescription = code.resolvedName(),
                    modifier = Modifier.fillMaxSize(),
                    contentScale = ContentScale.Crop
                )
            } else {
                Icon(
                    imageVector = Icons.Filled.QrCode,
                    contentDescription = null,
                    tint = palettes.background.textQuaternary,
                    modifier = Modifier.size(24.dp)
                )
            }
        }
        Spacer(modifier = Modifier.size(12.dp))
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = code.resolvedName(),
                style = XzgType.title,
                color = palettes.background.textPrimary
            )
            Spacer(modifier = Modifier.height(2.dp))
            Text(
                text = code.kind.displayName,
                style = XzgType.caption,
                color = palettes.background.textTertiary
            )
        }
        Box {
            IconButton(onClick = { menuExpanded = true }) {
                Icon(
                    imageVector = Icons.Filled.MoreVert,
                    contentDescription = "更多操作",
                    tint = palettes.background.textSecondary
                )
            }
            DropdownMenu(
                expanded = menuExpanded,
                onDismissRequest = { menuExpanded = false }
            ) {
                DropdownMenuItem(
                    text = { Text("重命名", style = XzgType.body) },
                    leadingIcon = {
                        Icon(Icons.Filled.Edit, contentDescription = null)
                    },
                    onClick = { menuExpanded = false; onRename() }
                )
                DropdownMenuItem(
                    text = { Text("替换图片", style = XzgType.body) },
                    leadingIcon = {
                        Icon(Icons.Filled.BrokenImage, contentDescription = null)
                    },
                    onClick = { menuExpanded = false; onReplaceImage() }
                )
                DropdownMenuItem(
                    text = {
                        Text(
                            "删除",
                            style = XzgType.body,
                            color = palettes.fixed.danger
                        )
                    },
                    leadingIcon = {
                        Icon(
                            Icons.Filled.Delete,
                            contentDescription = null,
                            tint = palettes.fixed.danger
                        )
                    },
                    onClick = { menuExpanded = false; onDelete() }
                )
            }
        }
    }
}

/** 按需解码的缩略图（上限 256px，避免大图卡顿）。 */
@Composable
internal fun rememberCodeBitmap(file: File?): ImageBitmap? {
    return remember(file?.absolutePath, file?.lastModified()) {
        try {
            if (file == null || !file.exists()) null
            else decodeBoundedBitmap(file.absolutePath, 256)?.asImageBitmap()
        } catch (_: Exception) {
            null
        }
    }
}

/** 按 maxPx 上限采样解码，避免大图 OOM / 卡顿。 */
internal fun decodeBoundedBitmap(path: String, maxPx: Int): Bitmap? {
    return try {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(path, bounds)
        var sample = 1
        while ((bounds.outWidth / sample) > maxPx || (bounds.outHeight / sample) > maxPx) {
            sample *= 2
        }
        BitmapFactory.decodeFile(path, BitmapFactory.Options().apply { inSampleSize = sample })
    } catch (_: Exception) {
        null
    }
}
