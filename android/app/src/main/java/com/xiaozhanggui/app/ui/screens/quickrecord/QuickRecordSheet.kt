package com.xiaozhanggui.app.ui.screens.quickrecord

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowDropDown
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Mic
import androidx.compose.material.icons.filled.Stop
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.core.content.ContextCompat
import com.xiaozhanggui.app.data.di.XzgGraph
import com.xiaozhanggui.app.data.voice.VoiceSpeechService
import com.xiaozhanggui.app.domain.Format
import com.xiaozhanggui.app.domain.quickrecord.LocalQuickRecordParser
import com.xiaozhanggui.app.domain.voice.QuickCaptureSemantic
import com.xiaozhanggui.app.domain.quickrecord.QuickRecordDraft
import com.xiaozhanggui.app.domain.quickrecord.QuickRecordKind
import com.xiaozhanggui.app.domain.quickrecord.canSaveQuickRecord
import com.xiaozhanggui.app.ui.components.V32Card
import com.xiaozhanggui.app.ui.components.V32PrimaryButton
import com.xiaozhanggui.app.ui.components.V32SectionHeader
import com.xiaozhanggui.app.ui.screens.todo.XzgSheetTextField
import com.xiaozhanggui.app.ui.theme.LocalXzgPalettes
import com.xiaozhanggui.app.ui.theme.XzgDimens
import com.xiaozhanggui.app.ui.theme.XzgType
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

/**
 * 快速记一笔 Sheet 内容（供 coordinator 替换 `XzgSheets.kt` 的 QuickRecordStubSheet）。
 *
 * 1:1 对应 iOS `QuickRecord/QuickRecordSheet.swift`：
 * - 唯一输入「一句话」（3–6 行）+ 只读识别结果卡（类型/内容/金额/时间，空行不渲染）
 *   + 5 类类型覆盖 Menu（覆盖后重新输入重置为 nil）+ 确认保存按钮
 *   （输入为空时 disabled；保存闸门 [canSaveQuickRecord] = trim 非空）。
 * - 语音：复用 [VoiceSpeechService]（与语音页同一识别器），识别结果走
 *   [LocalQuickRecordParser]（非 VoiceParser）；识别器不可用时隐藏麦克风按钮。
 * - commit：trim 非空即保存；**金额缺失写 0，不报错**（GATE C #6，与 Voice 链路的
 *   校验行为差异是 iOS 原生行为，保留）；5 分支写入各自 Repository（无支出分支）。
 * - 成功显示「已保存到：X」+ 0.6s dismiss；失败显示 [QuickCaptureSemantic.FAILED]。
 *
 * 本文件不含 ModalBottomSheet 包裹，detents/圆角由 coordinator 的 sheet 宿主决定。
 */
@Composable
fun QuickRecordSheetContent(onDismiss: () -> Unit) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()

    var text by remember { mutableStateOf("") }
    var draft by remember { mutableStateOf<QuickRecordDraft?>(null) }
    var overriddenKind by remember { mutableStateOf<QuickRecordKind?>(null) }
    var savedMessage by remember { mutableStateOf<String?>(null) }
    var errorMessage by remember { mutableStateOf<String?>(null) }
    var saving by remember { mutableStateOf(false) }
    var kindMenuOpen by remember { mutableStateOf(false) }

    val voice = remember { QuickRecordVoiceRecorder(context.applicationContext) }
    DisposableEffect(voice) { onDispose { voice.release() } }

    /** iOS `.onChange(of: text)` 等价：重输 → 覆盖类型重置 + 重新解析。 */
    fun applyText(newValue: String) {
        text = newValue
        overriddenKind = null
        errorMessage = null
        val trimmed = newValue.trim()
        draft = if (trimmed.isEmpty()) null else LocalQuickRecordParser.parse(trimmed)
    }

    val permissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { granted ->
        if (granted) voice.startListening(onFinal = ::applyText)
        else voice.onPermissionDenied()
    }

    fun hasRecordAudio(): Boolean =
        ContextCompat.checkSelfPermission(context, Manifest.permission.RECORD_AUDIO) ==
            PackageManager.PERMISSION_GRANTED

    fun ensureListening() {
        if (!voice.canUseSpeech || voice.isListening) return
        if (hasRecordAudio()) voice.startListening(onFinal = ::applyText)
        else permissionLauncher.launch(Manifest.permission.RECORD_AUDIO)
    }

    // iOS `onAppear autoStartListening`：弹出即听（识别器可用时）。
    LaunchedEffect(Unit) { ensureListening() }

    fun commit() {
        val trimmed = text.trim()
        if (!canSaveQuickRecord(trimmed) || saving) return
        val finalDraft = (draft ?: LocalQuickRecordParser.parse(trimmed)).let { d ->
            overriddenKind?.let { d.copy(kind = it) } ?: d
        }
        voice.cancel()
        scope.launch {
            saving = true
            errorMessage = null
            try {
                val now = System.currentTimeMillis()
                when (finalDraft.kind) {
                    QuickRecordKind.PERFORMANCE ->
                        XzgGraph.performanceRepository.add(
                            amount = quickRecordCommitAmount(finalDraft),
                            note = finalDraft.note,
                            date = finalDraft.date ?: now,
                        )
                    QuickRecordKind.TODO ->
                        XzgGraph.todoRepository.add(
                            title = finalDraft.title,
                            detail = "",
                            dueDate = finalDraft.date,
                        )
                    QuickRecordKind.CUSTOMER ->
                        XzgGraph.customerRepository.add(
                            customer = finalDraft.customer ?: "",
                            roomOrAddress = "",
                            phone = "",
                            content = finalDraft.title,
                        )
                    QuickRecordKind.EXPIRY ->
                        XzgGraph.expiryRepository.add(
                            name = finalDraft.title,
                            quantity = finalDraft.quantity ?: 1,
                            expiryDate = finalDraft.date ?: now,
                        )
                    QuickRecordKind.MEMO ->
                        XzgGraph.memoRepository.add(
                            title = finalDraft.title,
                            content = finalDraft.note,
                        )
                }
                savedMessage = QuickCaptureSemantic.savedMessage(kindLabel(finalDraft.kind))
                delay(600)
                onDismiss()
            } catch (e: Exception) {
                errorMessage = QuickCaptureSemantic.FAILED
            } finally {
                saving = false
            }
        }
    }

    val voiceCard: QuickRecordVoiceCardState? =
        if (voice.status != QuickRecordVoiceRecorder.Status.IDLE) {
            QuickRecordVoiceCardState(
                title = voice.statusTitle(),
                subtitle = when {
                    voice.isListening && voice.liveTranscript.isNotEmpty() -> voice.liveTranscript
                    voice.isListening -> "停顿后会自动结束，也可停止或取消"
                    voice.status == QuickRecordVoiceRecorder.Status.FAILED ->
                        voice.failureMessage ?: "语音识别失败，可直接打字"
                    else -> null
                },
                showControls = voice.isListening,
            )
        } else null

    QuickRecordSheetVisual(
        state = QuickRecordVisualState(
            text = text,
            draft = draft,
            overriddenKind = overriddenKind,
            savedMessage = savedMessage,
            errorMessage = errorMessage,
            saving = saving,
            kindMenuOpen = kindMenuOpen,
            voiceCard = voiceCard,
            canUseSpeech = voice.canUseSpeech,
            isListening = voice.isListening,
            canSave = canSaveQuickRecord(text) && !saving,
        ),
        onDismiss = onDismiss,
        onTextChange = ::applyText,
        onKindMenuOpenChange = { kindMenuOpen = it },
        onKindOverride = { overriddenKind = it },
        onMicClick = { ensureListening() },
        onStopVoice = { voice.stop() },
        onCancelVoice = { voice.cancel() },
        onSave = ::commit,
    )
}

/**
 * 快速记录 Sheet 纯渲染内容（不含语音识别器 / Repository，供 Paparazzi 截图用）。
 * 渲染逻辑与 QuickRecordSheetContent 完全一致，仅把状态与回调经参数注入。
 */
internal data class QuickRecordVoiceCardState(
    val title: String,
    val subtitle: String?,
    val showControls: Boolean,
)

internal data class QuickRecordVisualState(
    val text: String,
    val draft: QuickRecordDraft?,
    val overriddenKind: QuickRecordKind?,
    val savedMessage: String?,
    val errorMessage: String?,
    val saving: Boolean,
    val kindMenuOpen: Boolean,
    val voiceCard: QuickRecordVoiceCardState?,
    val canUseSpeech: Boolean,
    val isListening: Boolean,
    val canSave: Boolean,
)

@Composable
internal fun QuickRecordSheetVisual(
    state: QuickRecordVisualState,
    onDismiss: () -> Unit,
    onTextChange: (String) -> Unit,
    onKindMenuOpenChange: (Boolean) -> Unit,
    onKindOverride: (QuickRecordKind) -> Unit,
    onMicClick: () -> Unit,
    onStopVoice: () -> Unit,
    onCancelVoice: () -> Unit,
    onSave: () -> Unit,
) {
    val palettes = LocalXzgPalettes.current

    val visualDraft = state.draft?.let { d ->
        state.overriddenKind?.let { d.copy(kind = it) } ?: d
    }

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = XzgDimens.pageMargin)
            .padding(top = 14.dp, bottom = 24.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        // 标题栏：居中「快速记录」+ 左侧「取消」
        Box(modifier = Modifier.fillMaxWidth()) {
            Text(
                text = "快速记录",
                style = XzgType.headline,
                color = palettes.background.textPrimary,
                modifier = Modifier.align(Alignment.Center),
            )
            TextButton(
                onClick = onDismiss,
                contentPadding = PaddingValues(0.dp),
                modifier = Modifier.align(Alignment.CenterStart),
            ) {
                Text(
                    text = "取消",
                    style = XzgType.body,
                    color = palettes.background.textTertiary,
                )
            }
        }

        state.voiceCard?.let { card ->
            VoiceStatusCard(
                title = card.title,
                subtitle = card.subtitle,
                showControls = card.showControls,
                onStop = onStopVoice,
                onCancel = onCancelVoice,
            )
        }

        // 一句话输入卡
        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
            V32SectionHeader(
                title = "一句话",
                trailing = {
                    // 监听期间头部麦克风整体不渲染；识别器不可用时直接隐藏。
                    if (state.canUseSpeech && !state.isListening) {
                        MicButton(onClick = onMicClick)
                    }
                },
            )
            V32Card {
                XzgSheetTextField(
                    value = state.text,
                    onValueChange = onTextChange,
                    placeholder = "例如：今天美团680",
                    minLines = 3,
                    maxLines = 6,
                )
            }
            Text(
                text = "本地规则识别，不经过 AI、不需要 API Key；识别不了的内容也会存为备忘。",
                style = XzgType.caption,
                color = palettes.background.textTertiary,
            )
        }

        // 只读识别结果卡
        visualDraft?.let { d ->
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                V32SectionHeader(title = "识别结果")
                V32Card {
                    Column {
                        // 类型行：自动识别为主，点击弹出 5 类覆盖菜单
                        Box {
                            ResultRow(
                                label = "类型",
                                trailing = {
                                    Row(
                                        verticalAlignment = Alignment.CenterVertically,
                                        modifier = Modifier.clickable { onKindMenuOpenChange(true) },
                                    ) {
                                        Text(
                                            text = kindLabel(d.kind),
                                            style = XzgType.body,
                                            color = palettes.background.textPrimary,
                                        )
                                        Icon(
                                            imageVector = Icons.Filled.ArrowDropDown,
                                            contentDescription = "改类型",
                                            tint = palettes.background.textTertiary,
                                            modifier = Modifier.size(18.dp),
                                        )
                                    }
                                },
                            )
                            DropdownMenu(
                                expanded = state.kindMenuOpen,
                                onDismissRequest = { onKindMenuOpenChange(false) },
                            ) {
                                QuickRecordKind.entries.forEach { kind ->
                                    DropdownMenuItem(
                                        text = {
                                            Text(
                                                text = kindLabel(kind),
                                                style = XzgType.body,
                                                color = palettes.background.textPrimary,
                                            )
                                        },
                                        leadingIcon = if (kind == d.kind) {
                                            {
                                                Icon(
                                                    imageVector = Icons.Filled.Check,
                                                    contentDescription = null,
                                                    tint = palettes.accent.accent,
                                                )
                                            }
                                        } else null,
                                        onClick = {
                                            onKindOverride(kind)
                                            onKindMenuOpenChange(false)
                                        },
                                    )
                                }
                            }
                        }
                        HorizontalDivider(color = palettes.background.divider)
                        ResultRow(label = "内容", value = d.note)
                        d.amount?.let { amount ->
                            HorizontalDivider(color = palettes.background.divider)
                            ResultRow(label = "金额", value = Format.money(amount))
                        }
                        d.date?.let { date ->
                            HorizontalDivider(color = palettes.background.divider)
                            ResultRow(label = "时间", value = Format.dateTime(date))
                        }
                    }
                }
            }
        }

        state.savedMessage?.let { message ->
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(
                    imageVector = Icons.Filled.Check,
                    contentDescription = null,
                    tint = palettes.accent.accent,
                    modifier = Modifier.size(18.dp),
                )
                Spacer(modifier = Modifier.width(8.dp))
                Text(
                    text = message,
                    style = XzgType.body,
                    color = palettes.background.textSecondary,
                )
            }
        }

        state.errorMessage?.let { message ->
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(
                    imageVector = Icons.Filled.Close,
                    contentDescription = null,
                    tint = palettes.fixed.danger,
                    modifier = Modifier.size(16.dp),
                )
                Spacer(modifier = Modifier.width(8.dp))
                Text(
                    text = message,
                    style = XzgType.caption,
                    color = palettes.fixed.danger,
                )
            }
        }

        V32PrimaryButton(
            text = "确认保存",
            onClick = onSave,
            enabled = state.canSave,
            modifier = Modifier.fillMaxWidth(),
        )
    }
}

/** 类型中文名。对应 iOS kindLabel。 */
private fun kindLabel(kind: QuickRecordKind): String = when (kind) {
    QuickRecordKind.PERFORMANCE -> "营业额"
    QuickRecordKind.TODO -> "待办"
    QuickRecordKind.CUSTOMER -> "配送"
    QuickRecordKind.EXPIRY -> "临时商品"
    QuickRecordKind.MEMO -> "备忘"
}

/**
 * GATE C #6：快速记录金额缺失时写入 0，不报错。
 * 与 Voice 链路的校验行为差异是 iOS 原生行为（`draft.amount ?? 0`），保留。
 * commit() 统一走此函数取写入金额，便于单元测试锁定该行为。
 */
fun quickRecordCommitAmount(draft: QuickRecordDraft): Double = draft.amount ?: 0.0

@Composable
private fun ResultRow(
    label: String,
    value: String? = null,
    trailing: @Composable (() -> Unit)? = null,
) {
    val palettes = LocalXzgPalettes.current
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            text = label,
            style = XzgType.subhead,
            color = palettes.background.textTertiary,
        )
        Spacer(modifier = Modifier.weight(1f))
        if (trailing != null) {
            trailing()
        } else {
            Text(
                text = value.orEmpty(),
                style = XzgType.body,
                color = palettes.background.textPrimary,
            )
        }
    }
}

/** 头部麦克风按钮：只在非监听态出现。对应 iOS micButton（静态样式，无脉冲动画）。 */
@Composable
private fun MicButton(onClick: () -> Unit) {
    val palettes = LocalXzgPalettes.current
    Surface(
        onClick = onClick,
        shape = CircleShape,
        color = palettes.accent.accentSoft,
        modifier = Modifier.size(36.dp),
    ) {
        Box(contentAlignment = Alignment.Center) {
            Icon(
                imageVector = Icons.Filled.Mic,
                contentDescription = "语音说一句",
                tint = palettes.accent.accent,
                modifier = Modifier.size(18.dp),
            )
        }
    }
}

/** 监听状态卡。对应 iOS voiceCard。 */
@Composable
private fun VoiceStatusCard(
    title: String,
    subtitle: String?,
    showControls: Boolean,
    onStop: () -> Unit,
    onCancel: () -> Unit,
) {
    val palettes = LocalXzgPalettes.current
    V32Card {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(12.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Surface(
                shape = CircleShape,
                color = palettes.accent.accentSoft,
                modifier = Modifier.size(40.dp),
            ) {
                Box(contentAlignment = Alignment.Center) {
                    Icon(
                        imageVector = Icons.Filled.Mic,
                        contentDescription = null,
                        tint = palettes.accent.accent,
                        modifier = Modifier.size(18.dp),
                    )
                }
            }
            Spacer(modifier = Modifier.width(12.dp))
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = title,
                    style = XzgType.subhead,
                    color = palettes.background.textPrimary,
                )
                Spacer(modifier = Modifier.height(3.dp))
                subtitle?.let {
                    Text(
                        text = it,
                        style = XzgType.caption,
                        color = palettes.background.textSecondary,
                    )
                }
            }
            if (showControls) {
                Surface(
                    onClick = onStop,
                    shape = CircleShape,
                    color = palettes.accent.accent,
                    modifier = Modifier.size(32.dp),
                ) {
                    Box(contentAlignment = Alignment.Center) {
                        Icon(
                            imageVector = Icons.Filled.Stop,
                            contentDescription = "停止语音",
                            tint = palettes.accent.onAccent,
                            modifier = Modifier.size(14.dp),
                        )
                    }
                }
                Spacer(modifier = Modifier.width(8.dp))
                Surface(
                    onClick = onCancel,
                    shape = CircleShape,
                    color = palettes.background.neutralSoft,
                    modifier = Modifier.size(32.dp),
                ) {
                    Box(contentAlignment = Alignment.Center) {
                        Icon(
                            imageVector = Icons.Filled.Close,
                            contentDescription = "取消语音",
                            tint = palettes.background.textSecondary,
                            modifier = Modifier.size(14.dp),
                        )
                    }
                }
            }
        }
    }
}

private fun QuickRecordVoiceRecorder.statusTitle(): String = when (status) {
    QuickRecordVoiceRecorder.Status.LISTENING ->
        if (liveTranscript.isEmpty()) "正在听…说一件事" else "正在识别"
    QuickRecordVoiceRecorder.Status.DENIED -> "麦克风 / 语音识别权限未开启，可直接打字"
    QuickRecordVoiceRecorder.Status.EMPTY -> "没有听清，可再说一次或直接打字"
    QuickRecordVoiceRecorder.Status.FAILED -> failureMessage ?: "语音识别失败，可直接打字"
    QuickRecordVoiceRecorder.Status.IDLE -> ""
}

/**
 * 快速记录语音录制。对应 iOS `QuickRecordSheet.swift` 的 QuickRecordVoiceRecorder。
 *
 * 复用 [VoiceSpeechService]（与语音页同一识别器，3 秒静音自动结束内置），
 * 识别结果走 [LocalQuickRecordParser]（非 VoiceParser）。
 * 识别器不可用时 [canUseSpeech] 为 false，上层隐藏麦克风按钮、安静退化为键盘输入。
 */
class QuickRecordVoiceRecorder(appContext: Context) {

    /** 对应 iOS QuickRecordVoiceRecorder.Status。 */
    enum class Status {
        IDLE,
        LISTENING,
        DENIED,
        EMPTY,
        FAILED,
    }

    private val speech = VoiceSpeechService(appContext)

    var status by mutableStateOf(Status.IDLE)
        private set
    var liveTranscript by mutableStateOf("")
        private set
    var failureMessage by mutableStateOf<String?>(null)
        private set

    /** 识别器无法初始化时只保留键盘输入。对应 iOS canUseSpeech。 */
    val canUseSpeech: Boolean get() = speech.isAvailable
    val isListening: Boolean get() = status == Status.LISTENING
    fun hasAudioPermission(): Boolean = speech.hasAudioPermission()

    fun startListening(onFinal: (String) -> Unit) {
        if (status == Status.LISTENING) return
        liveTranscript = ""
        failureMessage = null
        speech.start(
            onPartial = { liveTranscript = it },
            onFinal = { final ->
                val trimmed = final.trim()
                if (trimmed.isEmpty()) {
                    // VoiceSpeechService 已把空结果映射为错误，此处为防御性兜底。
                    status = Status.EMPTY
                } else {
                    status = Status.IDLE
                    onFinal(trimmed)
                }
            },
            onError = { message ->
                // VoiceSpeechService 的错误映射：权限拒绝 / 不可用 / 其余（无语音/识别错误）。
                status = when (message) {
                    VoiceSpeechService.ERROR_PERMISSION_DENIED -> Status.DENIED
                    VoiceSpeechService.ERROR_NOT_AVAILABLE -> Status.FAILED
                    else -> Status.EMPTY
                }
                failureMessage = if (status == Status.FAILED) message else null
            },
        )
        if (status == Status.IDLE) status = Status.LISTENING
    }

    /** 权限被拒时由调用方通知，进入 denied 态（可直接打字）。 */
    fun onPermissionDenied() {
        status = Status.DENIED
    }

    /** 手动停止，等待最终结果。 */
    fun stop() {
        speech.stop()
    }

    /** 取消 / 关闭时立即释放麦克风。 */
    fun cancel() {
        speech.cancel()
        liveTranscript = ""
        if (status == Status.LISTENING) status = Status.IDLE
    }

    fun release() {
        speech.release()
    }
}
