package com.xiaozhanggui.app.ui.screens.paymentcode

import android.graphics.BitmapFactory
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
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Image as ImageIcon
import androidx.compose.material3.OutlinedTextField
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
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import com.xiaozhanggui.app.ui.components.PhotoPickerField
import com.xiaozhanggui.app.ui.components.V32PrimaryButton
import com.xiaozhanggui.app.ui.screens.profile.SheetHeader
import com.xiaozhanggui.app.ui.theme.LocalXzgPalettes
import com.xiaozhanggui.app.ui.theme.XzgDimens
import com.xiaozhanggui.app.ui.theme.XzgType
import java.io.File
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

/**
 * 收款码新增 / 编辑 Sheet（对应 iOS PaymentCodeEditorSheet）。
 *
 * - 类型三选（微信 / 支付宝 / 自定义）+ 名称输入（空则回退类型名）
 * - [PhotoPickerField] 选图（仅换图；64dp 预览 + 删除钮由组件自带）；
 *   图片不可解码时报错「无法读取该图片，请换一张试试」
 * - 180dp 预览卡：新选图优先，否则显示已有图片（编辑模式）
 * - 新增要求已选图才可保存；编辑可只改名 / 只换图
 */
@Composable
fun PaymentCodeEditorSheet(
    code: PaymentCode?,
    onDismiss: () -> Unit,
    onSaved: () -> Unit,
) {
    val context = LocalContext.current
    val palettes = LocalXzgPalettes.current
    val scope = rememberCoroutineScope()
    val isAdd = code == null

    var kind by remember { mutableStateOf(code?.kind ?: PaymentCodeKind.WECHAT) }
    var name by remember { mutableStateOf(code?.name.orEmpty()) }
    // PhotoPickerField 回调的 filesDir 相对路径（如 img_<UUID>.jpg）；null = 未换图
    var pickedPath by remember { mutableStateOf<String?>(null) }
    var error by remember { mutableStateOf<String?>(null) }
    var saving by remember { mutableStateOf(false) }

    fun tempFile(path: String): File = File(context.filesDir, path)

    fun onPick(path: String?) {
        if (path == null) {
            // 用户点了 PhotoPickerField 的删除钮：清除本次新选，编辑模式回退显示原图
            pickedPath = null
            return
        }
        // 校验图片可解码；不可解码则删除临时文件并报错
        val decodable = try {
            BitmapFactory.decodeFile(tempFile(path).absolutePath) != null
        } catch (_: Exception) {
            false
        }
        if (!decodable) {
            try { tempFile(path).delete() } catch (_: Exception) { }
            pickedPath = null
            error = "无法读取该图片，请换一张试试"
        } else {
            // 丢弃之前选的临时文件，避免 filesDir 堆积孤儿文件
            pickedPath?.let { old ->
                if (old != path) try { tempFile(old).delete() } catch (_: Exception) { }
            }
            pickedPath = path
            error = null
        }
    }

    val canSave = !saving && (pickedPath != null || !isAdd)

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = XzgDimens.pageMargin)
            .padding(bottom = XzgDimens.bottomPad)
            .verticalScroll(rememberScrollState()),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        SheetHeader(title = if (isAdd) "添加收款码" else "编辑收款码", onClose = onDismiss)

        Text(text = "类型", style = XzgType.caption, color = palettes.background.textTertiary)
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            PaymentCodeKind.values().forEach { k ->
                val selected = k == kind
                Box(
                    modifier = Modifier
                        .weight(1f)
                        .height(44.dp)
                        .clip(RoundedCornerShape(12.dp))
                        .background(
                            if (selected) palettes.accent.accentSoft
                            else palettes.background.card
                        )
                        .border(
                            1.dp,
                            if (selected) palettes.accent.accent
                            else palettes.background.cardOutline,
                            RoundedCornerShape(12.dp)
                        )
                        .clickable { kind = k },
                    contentAlignment = Alignment.Center
                ) {
                    Text(
                        text = k.displayName,
                        style = XzgType.title,
                        color = if (selected) palettes.accent.accent
                        else palettes.background.textSecondary
                    )
                }
            }
        }

        Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
            Text(text = "名称", style = XzgType.caption, color = palettes.background.textTertiary)
            OutlinedTextField(
                value = name,
                onValueChange = { name = it },
                placeholder = { Text(kind.displayName, style = XzgType.body) },
                singleLine = true,
                textStyle = XzgType.body,
                shape = RoundedCornerShape(14.dp),
                modifier = Modifier.fillMaxWidth()
            )
        }

        // 选图字段：仅用于换图；已选 64dp 预览 + 删除钮由组件自带
        PhotoPickerField(
            imagePath = pickedPath,
            onPick = ::onPick,
            modifier = Modifier.fillMaxWidth()
        )

        // 180dp 预览卡：新选图优先，否则显示已有图片（编辑模式）
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(180.dp)
                .clip(RoundedCornerShape(12.dp))
                .background(palettes.background.cardInset),
            contentAlignment = Alignment.Center
        ) {
            val bitmap = remember(pickedPath, code?.id) {
                try {
                    val file = pickedPath?.let { tempFile(it) }
                        ?: code?.let { PaymentCodeStore.imageFile(context, it) }
                    file?.takeIf { it.exists() }?.let {
                        BitmapFactory.decodeFile(it.absolutePath)?.asImageBitmap()
                    }
                } catch (_: Exception) {
                    null
                }
            }
            if (bitmap != null) {
                Image(
                    bitmap = bitmap,
                    contentDescription = "收款码预览",
                    modifier = Modifier.fillMaxWidth(),
                    contentScale = ContentScale.Crop
                )
            } else {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Icon(
                        imageVector = Icons.Filled.ImageIcon,
                        contentDescription = null,
                        tint = palettes.background.textQuaternary,
                        modifier = Modifier.size(32.dp)
                    )
                    Spacer(modifier = Modifier.height(6.dp))
                    Text(
                        text = "未选择图片",
                        style = XzgType.caption,
                        color = palettes.background.textTertiary
                    )
                }
            }
        }

        error?.let {
            Text(text = it, style = XzgType.caption, color = palettes.fixed.danger)
        }

        Text(
            text = "仅在本机展示你自己保存的收款码图片，不识别、不解析二维码内容。",
            style = XzgType.caption,
            color = palettes.background.textQuaternary
        )

        V32PrimaryButton(
            text = "保存",
            onClick = {
                saving = true
                scope.launch {
                    try {
                        withContext(Dispatchers.IO) {
                            val newBytes = pickedPath?.let { tempFile(it).readBytes() }
                            if (isAdd) {
                                val bytes = newBytes
                                    ?: throw IllegalStateException("请先选择一张收款码图片")
                                PaymentCodeStore.add(context, name, kind, bytes)
                            } else {
                                val target = code ?: throw IllegalStateException("收款码不存在")
                                if (newBytes != null) {
                                    PaymentCodeStore.replaceImage(context, target.id, newBytes)
                                }
                                PaymentCodeStore.updateMeta(target.id, name, kind)
                            }
                            // 落库成功后删除 PhotoPickerField 产生的临时文件
                            pickedPath?.let { try { tempFile(it).delete() } catch (_: Exception) { } }
                        }
                        onSaved()
                    } catch (e: Exception) {
                        error = e.message ?: "保存失败"
                        saving = false
                    }
                }
            },
            modifier = Modifier.fillMaxWidth(),
            enabled = canSave
        )
    }
}
