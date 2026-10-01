package com.xiaozhanggui.app.ui.screens.paymentcode

import android.app.Activity
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.BrokenImage
import androidx.compose.material.icons.filled.Close
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalLifecycleOwner
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import com.xiaozhanggui.app.ui.theme.XzgType

/**
 * 收款码全屏展示（对应 iOS PaymentCodeFullScreenView）。
 *
 * - 黑底全屏 Dialog；多张码左右滑动（HorizontalPager）
 * - 顶部仅关闭键；底部码名称 +「类型 · n/N」页码
 * - 图片缺失显示占位（「图片不可用」「可返回列表后重新替换该收款码图片」）
 * - 亮度保护（对应 iOS PaymentCodeBrightnessGuard）：进入拉高到 0.95，
 *   退出 / 切后台时恢复（try-finally 语义）。
 */
@OptIn(ExperimentalFoundationApi::class)
@Composable
fun PaymentCodeFullScreen(
    codes: List<PaymentCode>,
    startIndex: Int,
    onDismiss: () -> Unit,
) {
    if (codes.isEmpty()) return

    Dialog(
        onDismissRequest = onDismiss,
        properties = DialogProperties(
            usePlatformDefaultWidth = false,
            decorFitsSystemWindows = false
        )
    ) {
        val context = LocalContext.current
        val lifecycle = LocalLifecycleOwner.current.lifecycle
        val window = (context as? Activity)?.window

        // 亮度保护：进入 0.95；退出 / ON_PAUSE 恢复；ON_RESUME 重新拉高
        DisposableEffect(window, lifecycle) {
            val attrs = window?.attributes
            val saved = attrs?.screenBrightness ?: -1f
            fun apply() {
                try {
                    attrs?.let {
                        it.screenBrightness = 0.95f
                        window?.attributes = it
                    }
                } catch (_: Exception) {
                }
            }
            fun restore() {
                try {
                    attrs?.let {
                        it.screenBrightness = saved
                        window?.attributes = it
                    }
                } catch (_: Exception) {
                }
            }
            apply()
            val observer = LifecycleEventObserver { _, event ->
                when (event) {
                    Lifecycle.Event.ON_PAUSE -> restore()
                    Lifecycle.Event.ON_RESUME -> apply()
                    else -> {}
                }
            }
            lifecycle.addObserver(observer)
            onDispose {
                lifecycle.removeObserver(observer)
                restore()
            }
        }

        val pagerState = rememberPagerState(
            initialPage = startIndex.coerceIn(codes.indices)
        ) { codes.size }

        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(Color.Black)
        ) {
            HorizontalPager(
                state = pagerState,
                modifier = Modifier.fillMaxSize()
            ) { page ->
                val code = codes[page]
                val file = remember(code.id, code.fileName) {
                    PaymentCodeStore.imageFile(context, code)
                }
                val bitmap = remember(file?.absolutePath, file?.lastModified()) {
                    try {
                        file?.let {
                            decodeBoundedBitmap(it.absolutePath, 1080)?.asImageBitmap()
                        }
                    } catch (_: Exception) {
                        null
                    }
                }
                Box(
                    modifier = Modifier.fillMaxSize(),
                    contentAlignment = Alignment.Center
                ) {
                    if (bitmap != null) {
                        Image(
                            bitmap = bitmap,
                            contentDescription = code.resolvedName(),
                            modifier = Modifier
                                .fillMaxSize()
                                .padding(32.dp),
                            contentScale = ContentScale.Fit
                        )
                    } else {
                        Column(horizontalAlignment = Alignment.CenterHorizontally) {
                            Icon(
                                imageVector = Icons.Filled.BrokenImage,
                                contentDescription = null,
                                tint = Color.White.copy(alpha = 0.4f),
                                modifier = Modifier.size(48.dp)
                            )
                            Spacer(modifier = Modifier.height(12.dp))
                            Text(
                                text = "图片不可用",
                                style = XzgType.headline,
                                color = Color.White
                            )
                            Spacer(modifier = Modifier.height(6.dp))
                            Text(
                                text = "可返回列表后重新替换该收款码图片",
                                style = XzgType.subhead,
                                color = Color.White.copy(alpha = 0.6f)
                            )
                        }
                    }
                }
            }

            IconButton(
                onClick = onDismiss,
                modifier = Modifier
                    .align(Alignment.TopStart)
                    .padding(16.dp)
                    .size(44.dp)
            ) {
                Icon(
                    imageVector = Icons.Filled.Close,
                    contentDescription = "关闭",
                    tint = Color.White,
                    modifier = Modifier.size(28.dp)
                )
            }

            val page = pagerState.currentPage
            val code = codes.getOrNull(page)
            Column(
                modifier = Modifier
                    .align(Alignment.BottomCenter)
                    .padding(bottom = 48.dp),
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                Text(
                    text = code?.resolvedName().orEmpty(),
                    style = XzgType.headline,
                    color = Color.White
                )
                Spacer(modifier = Modifier.height(4.dp))
                Text(
                    text = "${code?.kind?.displayName.orEmpty()} · ${page + 1}/${codes.size}",
                    style = XzgType.subhead,
                    color = Color.White.copy(alpha = 0.7f)
                )
            }
        }
    }
}
