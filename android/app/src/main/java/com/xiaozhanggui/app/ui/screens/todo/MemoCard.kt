package com.xiaozhanggui.app.ui.screens.todo

import android.graphics.BitmapFactory
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.xiaozhanggui.app.data.db.MemoEntity
import com.xiaozhanggui.app.domain.Format
import com.xiaozhanggui.app.ui.theme.LocalXzgPalettes
import com.xiaozhanggui.app.ui.theme.XzgDimens
import com.xiaozhanggui.app.ui.theme.XzgType
import java.io.File

/**
 * 从 app files dir 下的相对路径解码图片（Room 只存相对路径，对应 iOS 外部存储）。
 * 解码失败返回 null，调用方隐藏图片区。
 */
@Composable
private fun rememberMemoBitmap(relativePath: String?): ImageBitmap? {
    val context = LocalContext.current
    return remember(relativePath) {
        if (relativePath.isNullOrBlank()) {
            null
        } else {
            runCatching {
                val file = File(context.filesDir, relativePath)
                if (file.isFile) BitmapFactory.decodeFile(file.absolutePath)?.asImageBitmap()
                else null
            }.getOrNull()
        }
    }
}

/**
 * 备忘卡片，对应 iOS MemoView.MemoCard（被 TodoView 的"备忘" tab 复用）：
 * 图片（可选，120 高大图）→ 左侧 3px 色条（createdAt 秒 % 3 → brand/amber/info，
 * 创建时间决定的稳定颜色）+ 标题（空则"无标题"）→ 内容（3 行）→ 时间 + trash 删除按钮。
 *
 * 卡片面按 V32Card 视觉规格手写（圆角 18 + cardOutline 描边 + card 底色），
 * 以便图片区顶边贴合卡片（V32Card 自带 padding 16 不适合图片 bleed）。
 */
@Composable
fun MemoCard(
    memo: MemoEntity,
    onClick: () -> Unit,
    onDeleteClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    val palettes = LocalXzgPalettes.current
    // 色条索引 = createdAt 秒 % 3（iOS MemoModel.accentIndex(for:) 同算法）
    val barColor = when (((memo.createdAt / 1000) % 3).toInt()) {
        0 -> palettes.accent.accent
        1 -> palettes.fixed.amber
        else -> palettes.fixed.info
    }
    val bitmap = rememberMemoBitmap(memo.imagePath)

    Surface(
        onClick = onClick,
        modifier = modifier,
        shape = RoundedCornerShape(XzgDimens.card),
        color = palettes.background.card,
        border = BorderStroke(1.dp, palettes.background.cardOutline)
    ) {
        Column(modifier = Modifier.fillMaxWidth()) {
            if (bitmap != null) {
                Image(
                    bitmap = bitmap,
                    contentDescription = "备忘图片",
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(120.dp),
                    contentScale = ContentScale.Crop
                )
            }
            Row(modifier = Modifier.fillMaxWidth()) {
                Box(
                    modifier = Modifier
                        .width(3.dp)
                        .fillMaxHeight()
                        .background(barColor)
                )
                Column(
                    modifier = Modifier
                        .weight(1f)
                        .padding(12.dp)
                ) {
                    Text(
                        text = memo.title.trim().ifEmpty { "无标题" },
                        style = XzgType.headline,
                        color = palettes.background.textPrimary,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis
                    )
                    if (memo.content.trim().isNotEmpty()) {
                        Spacer(Modifier.height(4.dp))
                        Text(
                            text = memo.content.trim(),
                            style = XzgType.body,
                            color = palettes.background.textSecondary,
                            maxLines = 3,
                            overflow = TextOverflow.Ellipsis
                        )
                    }
                    Spacer(Modifier.height(8.dp))
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text(
                            text = Format.memoTime(memo.updatedAt),
                            style = XzgType.caption,
                            color = palettes.background.textTertiary,
                            modifier = Modifier.weight(1f)
                        )
                        IconButton(
                            onClick = onDeleteClick,
                            modifier = Modifier.size(32.dp)
                        ) {
                            Icon(
                                imageVector = Icons.Filled.Delete,
                                contentDescription = "删除备忘",
                                tint = palettes.background.textTertiary,
                                modifier = Modifier.size(18.dp)
                            )
                        }
                    }
                }
            }
        }
    }
}
