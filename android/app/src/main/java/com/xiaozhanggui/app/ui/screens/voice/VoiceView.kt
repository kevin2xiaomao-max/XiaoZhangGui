package com.xiaozhanggui.app.ui.screens.voice

import android.Manifest
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Inventory
import androidx.compose.material.icons.filled.Layers
import androidx.compose.material.icons.filled.Mic
import androidx.compose.material.icons.filled.NoteAlt
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.ReceiptLong
import androidx.compose.material.icons.filled.Schedule
import androidx.compose.material.icons.filled.Send
import androidx.compose.material.icons.filled.ShoppingCart
import androidx.compose.material.icons.filled.Stop
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.xiaozhanggui.app.data.di.XzgGraph
import com.xiaozhanggui.app.data.voice.VoiceSpeechService
import com.xiaozhanggui.app.domain.Format
import com.xiaozhanggui.app.domain.voice.VoiceDraft
import com.xiaozhanggui.app.domain.voice.VoiceRecordType
import com.xiaozhanggui.app.ui.components.V32PrimaryButton
import com.xiaozhanggui.app.ui.components.V32SecondaryButton
import com.xiaozhanggui.app.ui.components.V32SegmentedPicker
import com.xiaozhanggui.app.ui.theme.LocalXzgPalettes
import com.xiaozhanggui.app.ui.theme.XzgType
import kotlinx.coroutines.delay
import kotlin.math.abs
import kotlin.math.max

/**
 * 语音记一笔 Sheet 内容。1:1 对应 iOS Voice/VoiceView.swift。
 *
 * 供 coordinator 替换 [com.xiaozhanggui.app.ui.navigation.VoiceStubSheet]：
 * 把导航中的 `VoiceStubSheet(onDismiss)` 换成 `VoiceSheetContent(onDismiss)` 即可，
 * 本文件不修改 XzgSheets.kt。
 *
 * - 打开即自动开始识别（对齐 iOS onAppear → beginListening）。
 * - 识别器不可用时麦克风按钮置灰（红线：不许假装可用），走"填入文字"手动输入。
 * - RECORD_AUDIO 由本 Composable 经 ActivityResult 申请（iOS 由 beginListening 内申请，
 *   Android 按任务要求由调用方申请）。
 * - 保存成功后延迟 0.8s 调用 [onDismiss]（对齐 iOS didSave → dismiss）。
 */
@Composable
fun VoiceSheetContent(onDismiss: () -> Unit) {
    val context = LocalContext.current
    val haptic = LocalHapticFeedback.current
    val palettes = LocalXzgPalettes.current

    val speech = remember { VoiceSpeechService(context.applicationContext) }
    val vm: VoiceViewModel = viewModel(
        factory = XzgGraph.vmFactory {
            VoiceViewModel(
                performanceRepository = XzgGraph.performanceRepository,
                expenseRepository = XzgGraph.expenseRepository,
                expiryRepository = XzgGraph.expiryRepository,
                memoRepository = XzgGraph.memoRepository,
                customerRepository = XzgGraph.customerRepository,
                todoRepository = XzgGraph.todoRepository,
                speech = speech,
            )
        },
    )

    val phaseState by vm.phase.collectAsStateWithLifecycle()
    val transcriptState by vm.transcript.collectAsStateWithLifecycle()
    val draftState by vm.draft.collectAsStateWithLifecycle()
    val didSave by vm.didSave.collectAsStateWithLifecycle()
    var manualText by rememberSaveable { mutableStateOf("") }

    fun submitManual() {
        val text = manualText.trim()
        if (text.isEmpty()) return
        manualText = ""
        vm.submitManualText(text)
    }

    val permissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission(),
    ) { granted ->
        if (granted) vm.beginListening() else vm.onPermissionDenied()
    }

    var autoStarted by rememberSaveable { mutableStateOf(false) }
    LaunchedEffect(Unit) {
        if (!autoStarted) {
            autoStarted = true
            when {
                // 识别器不可用：不自动开始，麦克风置灰，用户可走"填入文字"。
                !speech.isAvailable -> Unit
                speech.hasAudioPermission() -> vm.beginListening()
                else -> permissionLauncher.launch(Manifest.permission.RECORD_AUDIO)
            }
        }
    }
    LaunchedEffect(didSave) {
        if (didSave) {
            haptic.performHapticFeedback(HapticFeedbackType.LongPress)
            delay(800)
            onDismiss()
        }
    }

    fun onMicClick() {
        if (!speech.isAvailable) return
        if (!speech.hasAudioPermission()) {
            permissionLauncher.launch(Manifest.permission.RECORD_AUDIO)
            return
        }
        when (phaseState) {
            is VoicePhase.Listening -> vm.stopListening()
            is VoicePhase.Idle, is VoicePhase.Error -> {
                vm.reset()
                vm.beginListening()
            }
            is VoicePhase.TextFallback -> submitManual()
            else -> Unit
        }
    }

    VoiceSheetVisual(
        phase = phaseState,
        transcript = transcriptState,
        draft = draftValue,
        didSave = didSave,
        speechAvailable = speech.isAvailable,
        speechUnavailableHint = vm.speechUnavailableHint,
        manualText = manualText,
        onManualTextChange = { manualText = it },
        onClose = {
            vm.reset()
            onDismiss()
        },
        onMicClick = ::onMicClick,
        onSubmitManual = ::submitManual,
        onEnterTextFallback = { vm.enterTextFallback() },
        onSetRecordType = { vm.setRecordType(it) },
        onSave = { vm.save() },
        performHaptic = { haptic.performHapticFeedback(HapticFeedbackType.LongPress) },
    )
}

/**
 * 语音 Sheet 纯渲染内容（不含 ViewModel / 语音识别器，供 Paparazzi 截图用）。
 * 渲染逻辑与 VoiceSheetContent 完全一致，仅把状态与回调经参数注入。
 */
@Composable
internal fun VoiceSheetVisual(
    phase: VoicePhase,
    transcript: String,
    draft: VoiceDraft?,
    didSave: Boolean,
    speechAvailable: Boolean,
    speechUnavailableHint: String,
    manualText: String,
    onManualTextChange: (String) -> Unit,
    onClose: () -> Unit,
    onMicClick: () -> Unit,
    onSubmitManual: () -> Unit,
    onEnterTextFallback: () -> Unit,
    onSetRecordType: (VoiceRecordType) -> Unit,
    onSave: () -> Unit,
    performHaptic: () -> Unit,
) {
    val palettes = LocalXzgPalettes.current

    val inPreview = (phase is VoicePhase.Preview || phase is VoicePhase.Saving) &&
        draft != null

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp)
            .padding(top = 10.dp, bottom = 16.dp),
    ) {
        // 顶部：状态文字 + 关闭（一行，紧凑）
        Row(verticalAlignment = Alignment.CenterVertically) {
            val (titleText, titleColor) = when {
                didSave -> "已记录" to palettes.accent.accent
                phase is VoicePhase.Error -> "出错了，点击重试" to palettes.fixed.danger
                else -> phase.statusText to palettes.background.textPrimary
            }
            Text(
                text = titleText,
                style = XzgType.headline,
                color = titleColor,
                modifier = Modifier.weight(1f),
            )
            IconButton(
                onClick = onClose,
                modifier = Modifier
                    .size(28.dp)
                    .clip(CircleShape)
                    .background(palettes.background.cardInset),
            ) {
                Icon(
                    imageVector = Icons.Filled.Close,
                    contentDescription = "关闭",
                    tint = palettes.background.textSecondary,
                    modifier = Modifier.size(14.dp),
                )
            }
        }

        Spacer(modifier = Modifier.height(8.dp))

        if (inPreview) {
            VoicePreviewSection(
                phase = phase,
                transcript = transcript,
                draft = draft!!,
                onSetRecordType = onSetRecordType,
                onSave = onSave,
                performHaptic = performHaptic,
            )
        } else {
            // 聆听 / 转写区
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .heightIn(min = 76.dp),
                contentAlignment = Alignment.Center,
            ) {
                when {
                    phase is VoicePhase.TextFallback -> {
                        OutlinedTextField(
                            value = manualText,
                            onValueChange = onManualTextChange,
                            placeholder = { Text("例如：明天下午三点联系饮料供应商") },
                            minLines = 2,
                            maxLines = 3,
                            keyboardOptions = KeyboardOptions(imeAction = ImeAction.Done),
                            keyboardActions = KeyboardActions(onDone = { onSubmitManual() }),
                            shape = RoundedCornerShape(12.dp),
                            modifier = Modifier.fillMaxWidth(),
                        )
                    }
                    transcript.isNotEmpty() -> {
                        Text(
                            text = transcript,
                            style = XzgType.body,
                            color = palettes.background.textPrimary,
                            textAlign = TextAlign.Center,
                            maxLines = 3,
                            overflow = TextOverflow.Ellipsis,
                            modifier = Modifier
                                .fillMaxWidth()
                                .clip(RoundedCornerShape(12.dp))
                                .background(palettes.background.cardInset)
                                .padding(10.dp),
                        )
                    }
                    else -> CompactVoiceWaveform()
                }
            }

            Spacer(modifier = Modifier.height(12.dp))

            // 主语音按钮（60dp；listening 时红色 stop 图标；识别器不可用时置灰）
            val listening = phase is VoicePhase.Listening
            val micEnabled = speechAvailable
            val micTint = if (listening) palettes.fixed.danger else palettes.accent.accent
            Box(
                modifier = Modifier.fillMaxWidth(),
                contentAlignment = Alignment.Center,
            ) {
                Button(
                    onClick = onMicClick,
                    enabled = micEnabled,
                    shape = CircleShape,
                    colors = ButtonDefaults.buttonColors(
                        containerColor = micTint,
                        contentColor = Color.White,
                        disabledContainerColor = palettes.background.neutralSoft,
                        disabledContentColor = palettes.background.textQuaternary,
                    ),
                    contentPadding = PaddingValues(0.dp),
                    modifier = Modifier.size(60.dp),
                ) {
                    Icon(
                        imageVector = when {
                            listening -> Icons.Filled.Stop
                            phase is VoicePhase.TextFallback -> Icons.Filled.Send
                            else -> Icons.Filled.Mic
                        },
                        contentDescription = if (listening) "停止" else "开始语音",
                        modifier = Modifier.size(24.dp),
                    )
                }
            }

            Spacer(modifier = Modifier.height(4.dp))

            val hint = when (phase) {
                is VoicePhase.Listening -> "点击停止"
                is VoicePhase.TextFallback -> "输入后回车解析"
                is VoicePhase.Preview, is VoicePhase.Saving, is VoicePhase.Parsing -> ""
                else -> if (micEnabled) "点击重新说" else speechUnavailableHint
            }
            if (hint.isNotEmpty()) {
                Text(
                    text = hint,
                    style = XzgType.caption,
                    color = palettes.background.textTertiary,
                    textAlign = TextAlign.Center,
                    modifier = Modifier.fillMaxWidth(),
                )
            }

            // 失败保留转写 → "填入文字"（走同一解析链路，不丢话）
            if (phase is VoicePhase.Error) {
                Spacer(modifier = Modifier.height(8.dp))
                V32SecondaryButton(
                    text = "填入文字",
                    onClick = onEnterTextFallback,
                    modifier = Modifier.fillMaxWidth(),
                )
            }
        }
    }
}


/** 预览区：识别原文卡 + 解析字段 + 6 类分段选择 + 确认保存（对齐 iOS previewSection）。 */
@Composable
private fun VoicePreviewSection(
    phase: VoicePhase,
    transcript: String,
    draft: VoiceDraft,
    onSetRecordType: (VoiceRecordType) -> Unit,
    onSave: () -> Unit,
    performHaptic: () -> Unit,
) {
    val palettes = LocalXzgPalettes.current
    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Text(
            text = transcript.ifEmpty { "（未识别到文字）" },
            style = XzgType.body,
            color = palettes.background.textPrimary,
            maxLines = 4,
            overflow = TextOverflow.Ellipsis,
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(12.dp))
                .background(palettes.background.cardInset)
                .padding(10.dp),
        )

        VoiceParsedFields(draft)

        val types = VoiceRecordType.entries
        V32SegmentedPicker(
            options = types.map { it.title },
            selectedIndex = types.indexOf(draft.type).coerceAtLeast(0),
            onSelect = { index ->
                performHaptic()
                onSetRecordType(types[index])
            },
        )

        val saving = phase is VoicePhase.Saving
        Box(modifier = Modifier.fillMaxWidth()) {
            V32PrimaryButton(
                text = "确认保存",
                onClick = {
                    performHaptic()
                    onSave()
                },
                enabled = !saving,
                modifier = Modifier.fillMaxWidth(),
            )
            if (saving) {
                CircularProgressIndicator(
                    color = Color.White,
                    strokeWidth = 2.dp,
                    modifier = Modifier
                        .align(Alignment.Center)
                        .size(20.dp),
                )
            }
        }
    }
}

/** 解析结果字段展示（对齐 iOS parsedFields：按类型展示金额/商品/临期/客户/数量/备忘/事项/时间）。 */
@Composable
private fun VoiceParsedFields(draft: VoiceDraft) {
    val palettes = LocalXzgPalettes.current
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(10.dp))
            .background(palettes.background.cardInset)
            .padding(10.dp),
        verticalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        when (draft.type) {
            VoiceRecordType.REVENUE, VoiceRecordType.EXPENSE -> {
                draft.amount?.let {
                    VoiceFieldRow("金额", "¥${Format.money(it)}", Icons.Filled.ReceiptLong)
                }
            }
            VoiceRecordType.EXPIRY -> {
                VoiceFieldRow("商品", draft.title, Icons.Filled.Inventory)
                draft.expiryDays?.let {
                    VoiceFieldRow("临期", "还有 $it 天", Icons.Filled.Warning)
                }
            }
            VoiceRecordType.CUSTOMER -> {
                draft.customerName?.let {
                    VoiceFieldRow("客户", it, Icons.Filled.Person)
                }
                draft.goodsName?.let {
                    VoiceFieldRow("商品", it, Icons.Filled.ShoppingCart)
                }
                draft.quantity?.let {
                    VoiceFieldRow("数量", "$it", Icons.Filled.Layers)
                }
            }
            VoiceRecordType.MEMO -> {
                VoiceFieldRow("备忘", draft.detail, Icons.Filled.NoteAlt)
            }
            VoiceRecordType.TODO -> {
                VoiceFieldRow("事项", draft.title, Icons.Filled.CheckCircle)
            }
        }
        draft.dueAt?.let {
            VoiceFieldRow("时间", Format.monthDayTime(it), Icons.Filled.Schedule)
        }
    }
}

@Composable
private fun VoiceFieldRow(label: String, value: String, icon: ImageVector) {
    val palettes = LocalXzgPalettes.current
    Row(verticalAlignment = Alignment.CenterVertically) {
        Icon(
            imageVector = icon,
            contentDescription = null,
            tint = palettes.accent.accent,
            modifier = Modifier.size(18.dp),
        )
        Spacer(modifier = Modifier.width(8.dp))
        Text(
            text = label,
            style = XzgType.subhead,
            color = palettes.background.textSecondary,
            modifier = Modifier.width(36.dp),
        )
        Text(
            text = value,
            style = XzgType.subhead,
            color = palettes.background.textPrimary,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            modifier = Modifier.weight(1f),
        )
    }
}

/**
 * 紧凑波形（对齐 iOS CompactVoiceWaveform）：
 * 15 个 Capsule 的装饰性动画，accessibilityHidden，非麦克风音量驱动。
 */
@Composable
private fun CompactVoiceWaveform(modifier: Modifier = Modifier) {
    val palettes = LocalXzgPalettes.current
    val transition = rememberInfiniteTransition(label = "voiceWave")
    Row(
        modifier = modifier,
        horizontalArrangement = Arrangement.spacedBy(3.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        for (index in 0 until 15) {
            val animated by transition.animateFloat(
                initialValue = 4f,
                targetValue = 18f,
                animationSpec = infiniteRepeatable(
                    animation = tween(
                        durationMillis = 600,
                        delayMillis = (index % 5) * 70,
                        easing = FastOutSlowInEasing,
                    ),
                    repeatMode = RepeatMode.Reverse,
                ),
                label = "bar$index",
            )
            val centerDist = abs(index - 7)
            val factor = max(0.4f, 1f - centerDist * 0.08f)
            val height = max(4f, animated * factor)
            Box(
                modifier = Modifier
                    .width(2.5.dp)
                    .height(height.dp)
                    .clip(CircleShape)
                    .background(palettes.accent.accent.copy(alpha = 0.7f)),
            )
        }
    }
}
