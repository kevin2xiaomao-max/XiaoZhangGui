package com.xiaozhanggui.app.ui.components

import android.graphics.BitmapFactory
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AddPhotoAlternate
import androidx.compose.material.icons.filled.BrokenImage
import androidx.compose.material.icons.filled.Cancel
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.xiaozhanggui.app.ui.theme.LocalXzgPalettes
import com.xiaozhanggui.app.ui.theme.XzgDimens
import com.xiaozhanggui.app.ui.theme.XzgType
import java.io.File
import java.util.UUID

/**
 * V32 搜索框。对应 iOS `V32SearchField`：卡片底 + 1dp 描边、搜索图标、
 * 最小高度 46dp、有内容时显示清空钮。
 */
@Composable
fun V32SearchField(value: String, onValueChange: (String) -> Unit, placeholder: String, modifier: Modifier = Modifier) {
    val palettes = LocalXzgPalettes.current
    val shape = RoundedCornerShape(XzgDimens.card)
    Row(
        modifier = modifier
            .fillMaxWidth()
            .clip(shape)
            .background(palettes.background.card)
            .border(1.dp, palettes.background.cardOutline, shape)
            .padding(horizontal = 14.dp)
            .heightIn(min = 46.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Icon(
            imageVector = Icons.Filled.Search,
            contentDescription = null,
            tint = palettes.background.textTertiary,
            modifier = Modifier.size(15.dp)
        )
        Spacer(Modifier.width(10.dp))
        BasicTextField(
            value = value,
            onValueChange = onValueChange,
            modifier = Modifier.weight(1f),
            textStyle = XzgType.body.copy(color = palettes.background.textPrimary),
            singleLine = true,
            cursorBrush = SolidColor(palettes.accent.accent),
            decorationBox = { innerTextField ->
                if (value.isEmpty()) {
                    Text(
                        text = placeholder,
                        style = XzgType.body,
                        color = palettes.background.textQuaternary,
                        maxLines = 1
                    )
                }
                innerTextField()
            }
        )
        if (value.isNotEmpty()) {
            Spacer(Modifier.width(8.dp))
            Box(
                modifier = Modifier
                    .size(20.dp)
                    .v32PressFeedback { onValueChange("") },
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    imageVector = Icons.Filled.Cancel,
                    contentDescription = "清空搜索",
                    tint = palettes.background.textQuaternary,
                    modifier = Modifier.size(15.dp)
                )
            }
        }
    }
}

/**
 * V32 横向分类胶囊条。对应 iOS `V32PillBar`：横向滚动；选中项 caption 加粗 +
 * 品牌色文本 + 品牌浅底，未选中项 textSecondary + pageBGSecondary 底。
 */
@Composable
fun V32PillBar(options: List<String>, selectedIndex: Int, onSelect: (Int) -> Unit, modifier: Modifier = Modifier) {
    val palettes = LocalXzgPalettes.current
    LazyRow(
        modifier = modifier,
        horizontalArrangement = Arrangement.spacedBy(8.dp),
        contentPadding = PaddingValues(vertical = 2.dp)
    ) {
        itemsIndexed(options) { index, option ->
            val selected = index == selectedIndex
            Box(
                modifier = Modifier
                    .clip(CircleShape)
                    .background(if (selected) palettes.accent.accentSoft else palettes.background.pageBGSecondary)
                    .v32PressFeedback { onSelect(index) }
                    .padding(horizontal = 14.dp, vertical = 8.dp),
                contentAlignment = Alignment.Center
            ) {
                Text(
                    text = option,
                    style = XzgType.caption.copy(
                        fontWeight = if (selected) FontWeight.Bold else FontWeight.Normal
                    ),
                    color = if (selected) palettes.accent.accent else palettes.background.textSecondary
                )
            }
        }
    }
}

/**
 * V32 分段选择器：pageBGSecondary 圆角容器，选项等宽平分；选中项为卡片底 +
 * 1dp 描边 + 主文本色半粗，未选中项为次文本色。
 */
@Composable
fun V32SegmentedPicker(options: List<String>, selectedIndex: Int, onSelect: (Int) -> Unit, modifier: Modifier = Modifier) {
    val palettes = LocalXzgPalettes.current
    val containerShape = RoundedCornerShape(XzgDimens.bubble)
    val segmentShape = RoundedCornerShape(8.dp)
    Row(
        modifier = modifier
            .fillMaxWidth()
            .clip(containerShape)
            .background(palettes.background.pageBGSecondary)
            .padding(4.dp),
        horizontalArrangement = Arrangement.spacedBy(4.dp)
    ) {
        options.forEachIndexed { index, option ->
            val selected = index == selectedIndex
            Box(
                modifier = Modifier
                    .weight(1f)
                    .clip(segmentShape)
                    .background(if (selected) palettes.background.card else Color.Transparent)
                    .then(
                        if (selected) Modifier.border(1.dp, palettes.background.cardOutline, segmentShape)
                        else Modifier
                    )
                    .v32PressFeedback { onSelect(index) }
                    .padding(vertical = 8.dp),
                contentAlignment = Alignment.Center
            ) {
                Text(
                    text = option,
                    style = XzgType.subhead.copy(
                        fontWeight = if (selected) FontWeight.SemiBold else FontWeight.Normal
                    ),
                    color = if (selected) palettes.background.textPrimary else palettes.background.textSecondary,
                    maxLines = 1
                )
            }
        }
    }
}

/**
 * 图片选择字段：用 ActivityResultContracts.PickVisualMedia() 选图，
 * 把图片复制到 `context.filesDir`（文件名 `img_<UUID>.jpg`），
 * 通过 onPick 回调相对路径；右上删除钮回调 onPick(null)。
 *
 * 有图：64dp 圆角预览 + 右上删除钮；无图：虚线框"添加图片"按钮。
 */
@Composable
fun PhotoPickerField(imagePath: String?, onPick: (String?) -> Unit, modifier: Modifier = Modifier) {
    val context = LocalContext.current
    val palettes = LocalXzgPalettes.current
    val launcher = rememberLauncherForActivityResult(
        ActivityResultContracts.PickVisualMedia()
    ) { uri ->
        if (uri == null) return@rememberLauncherForActivityResult
        val fileName = "img_${UUID.randomUUID()}.jpg"
        val copied = runCatching {
            context.contentResolver.openInputStream(uri)?.use { input ->
                File(context.filesDir, fileName).outputStream().use { output ->
                    input.copyTo(output)
                }
            } ?: throw IllegalStateException("openInputStream 返回 null")
        }.isSuccess
        if (copied) onPick(fileName)
        // 复制失败：保持原状态，不回调（不静默清空已有图片）
    }

    if (imagePath != null) {
        val bitmap = remember(imagePath) {
            runCatching {
                BitmapFactory.decodeFile(File(context.filesDir, imagePath).absolutePath)
                    ?.asImageBitmap()
            }.getOrNull()
        }
        Box(modifier = modifier.size(64.dp)) {
            if (bitmap != null) {
                Image(
                    bitmap = bitmap,
                    contentDescription = "已选图片",
                    modifier = Modifier
                        .size(64.dp)
                        .clip(RoundedCornerShape(12.dp)),
                    contentScale = ContentScale.Crop
                )
            } else {
                Box(
                    modifier = Modifier
                        .size(64.dp)
                        .clip(RoundedCornerShape(12.dp))
                        .background(palettes.background.neutralSoft),
                    contentAlignment = Alignment.Center
                ) {
                    Icon(
                        imageVector = Icons.Filled.BrokenImage,
                        contentDescription = "图片加载失败",
                        tint = palettes.background.textTertiary,
                        modifier = Modifier.size(24.dp)
                    )
                }
            }
            Box(
                modifier = Modifier
                    .align(Alignment.TopEnd)
                    .offset(x = 6.dp, y = (-6).dp)
                    .size(22.dp)
                    .clip(CircleShape)
                    .background(palettes.fixed.danger)
                    .v32PressFeedback { onPick(null) },
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    imageVector = Icons.Filled.Close,
                    contentDescription = "删除图片",
                    tint = Color.White,
                    modifier = Modifier.size(14.dp)
                )
            }
        }
    } else {
        val shape = RoundedCornerShape(12.dp)
        Box(
            modifier = modifier
                .size(64.dp)
                .clip(shape)
                .dashedBorder(
                    width = 1.5.dp,
                    color = palettes.background.textQuaternary,
                    cornerRadius = 12.dp
                )
                .v32PressFeedback {
                    launcher.launch(
                        PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly)
                    )
                },
            contentAlignment = Alignment.Center
        ) {
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Icon(
                    imageVector = Icons.Filled.AddPhotoAlternate,
                    contentDescription = null,
                    tint = palettes.background.textTertiary,
                    modifier = Modifier.size(20.dp)
                )
                Text(
                    text = "添加图片",
                    style = XzgType.caption,
                    color = palettes.background.textTertiary
                )
            }
        }
    }
}

/** 内部工具：虚线圆角描边（用于 PhotoPickerField 的无图状态）。 */
internal fun Modifier.dashedBorder(
    width: Dp,
    color: Color,
    cornerRadius: Dp,
    dashLength: Dp = 6.dp,
    gapLength: Dp = 4.dp
): Modifier = this.drawBehind {
    val strokeWidthPx = width.toPx()
    drawRoundRect(
        color = color,
        topLeft = Offset(strokeWidthPx / 2f, strokeWidthPx / 2f),
        size = Size(size.width - strokeWidthPx, size.height - strokeWidthPx),
        cornerRadius = CornerRadius(cornerRadius.toPx()),
        style = Stroke(
            width = strokeWidthPx,
            pathEffect = PathEffect.dashPathEffect(
                floatArrayOf(dashLength.toPx(), gapLength.toPx()),
                0f
            )
        )
    )
}
