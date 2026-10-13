package com.xiaozhanggui.app.ui.screens.ai

import android.Manifest
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.lifecycle.viewmodel.compose.viewModel
import com.xiaozhanggui.app.XzgApplication
import com.xiaozhanggui.app.data.di.XzgGraph
import com.xiaozhanggui.app.data.voice.ShortVoiceSession
import com.xiaozhanggui.app.data.voice.VoicePermissionFlow
import com.xiaozhanggui.app.data.voice.VoicePermissionOutcome
import com.xiaozhanggui.app.data.voice.VoiceSpeechService
import com.xiaozhanggui.app.data.voice.openAppSettings

/**
 * AI Sheet 容器（V3.7.1：AI 不再是 Tab）。
 * 对应 iOS `RootView` 的 `.sheet(isPresented: $showAI) { NavigationStack { AIChatView(voiceDeepLink:) } }`
 *（presentationDetents .large；此处 sheetState skipPartiallyExpanded = true，即直接全高展开）。
 *
 * - 内容复用 [AIChatScreen]（5 tools / Provider / PendingAction / ExecutionJournal 语义不变）；
 * - [voiceDeepLink] = true（深链 `xzg://ai?mode=voice`）时同步拉起短语音面板，
 *   对应 iOS `AIChatView(voiceDeepLink:)` 自动呈现 ShortVoicePanel；
 * - AI 页内语音按钮经 `AIChatScreen(onVoice)` 同样拉起短语音面板；
 * - 短语音面板按 [ShortVoicePanel] 的宿主约定放在底部覆盖层 + 0.28 黑色遮罩
 *   （点击遮罩 = 取消），对应 iOS `AIChatView.voiceOverlay`；
 * - ASR 不可用（`SpeechRecognizer.isRecognitionAvailable()` = false，无 GMS 的 OPPO 等）
 *   时不拉起面板，降级为文字输入（OPPO 专项红线）。
 *
 * final 原文送入 Agent：与 [AIChatScreen] 共享同一 [AIConversationViewModel]
 *（同 ViewModelStoreOwner + 默认 key，`viewModel()` 只创建一次），
 * 经 `send()` 进入与文字相同的 Agent 流程。
 * 注意：若 [AIChatScreen] 更改 ViewModel 的创建方式（factory/key），此处必须同步，
 * 否则短语音原文会送入一个无界面的游离实例而丢失。
 *
 * 已知缺口（AI worker 后续接线）：短语音失败态「填入文字」需把保留原文填入
 * [AIChatScreen] 的输入框（其 `input` state 为内部持有）；当前实现为关闭面板，
 * 失败态面板已展示保留原文，用户可手动重输，不丢信息。
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AISheet(
    voiceDeepLink: Boolean = false,
    onDismiss: () -> Unit,
) {
    val context = LocalContext.current
    val speech = remember { VoiceSpeechService(context.applicationContext) }
    val aiViewModel: AIConversationViewModel = viewModel(
        factory = XzgGraph.vmFactory {
            AIConversationViewModel(context.applicationContext as XzgApplication)
        }
    )
    val session = remember { ShortVoiceSession(speech) }
    val phase by session.phase.collectAsState()
    val liveTranscript by session.liveTranscript.collectAsState()

    // iOS 语义：深链到达时若 AI Sheet 已在展示则先关再重开，保证入口可达。
    // 此处以 voiceDeepLink 为 key：热启动重复深链（false→true）会重建该状态，等价重开。
    var showVoicePanel by remember(voiceDeepLink) {
        mutableStateOf(voiceDeepLink && speech.isAvailable)
    }

    // 永久拒绝（不再询问）时为 true：短语音失败态额外展示"前往系统设置"引导
    var voiceSettingsBlocked by remember { mutableStateOf(false) }

    fun finishVoicePanel() {
        session.cancel()
        showVoicePanel = false
        voiceSettingsBlocked = false
    }

    fun onVoiceFinal(transcript: String) {
        session.finish()
        showVoicePanel = false
        if (transcript.isNotBlank()) aiViewModel.send(transcript)
    }

    val permissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { granted ->
        if (granted) {
            session.start(onFinal = ::onVoiceFinal)
            return@rememberLauncherForActivityResult
        }
        // 拒绝 → 区分临时拒绝 / 永久拒绝（不再询问）两条路径（验收文档 §2 验收项 4）。
        when (
            VoicePermissionFlow.decideFromActivity(
                context as? android.app.Activity,
                granted,
            )
        ) {
            VoicePermissionOutcome.GRANTED -> session.start(onFinal = ::onVoiceFinal)
            // 临时拒绝 → 关闭面板，回文字输入（不抛错、不重试）
            VoicePermissionOutcome.DENIED_TRANSIENT -> finishVoicePanel()
            // 永久拒绝 → 保持面板打开展示失败态 + 去系统设置引导
            VoicePermissionOutcome.DENIED_PERMANENT -> {
                session.onPermissionPermanentlyDenied()
                voiceSettingsBlocked = true
                showVoicePanel = true
            }
        }
    }

    // 面板打开时启动会话：权限已授则直启，否则先申请；ASR 不可用则直接降级
    LaunchedEffect(showVoicePanel) {
        if (showVoicePanel) {
            when {
                !speech.isAvailable -> showVoicePanel = false
                speech.hasAudioPermission() -> session.start(onFinal = ::onVoiceFinal)
                else -> permissionLauncher.launch(Manifest.permission.RECORD_AUDIO)
            }
        }
    }
    DisposableEffect(session) {
        onDispose { session.release() }
    }

    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
    ) {
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .testTag("ai.sheet")
        ) {
            AIChatScreen(
                // ASR 不可用时麦克风按钮置灰（红线：不许假装可用），文字输入始终可用
                voiceAvailable = speech.isAvailable,
                onVoice = {
                    // ASR 不可用 → 降级文字输入，不拉起面板
                    if (speech.isAvailable) showVoicePanel = true
                }
            )
        }
    }

    // 短语音面板：底部覆盖层 + 0.28 黑色遮罩（点击遮罩 = 取消）
    if (showVoicePanel) {
        Box(
            modifier = Modifier
                .fillMaxSize()
                .testTag("ai.voiceSheet")
        ) {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .background(Color.Black.copy(alpha = 0.28f))
                    .clickable(
                        interactionSource = remember { MutableInteractionSource() },
                        indication = null,
                        onClick = ::finishVoicePanel
                    )
            )
            ShortVoicePanel(
                phase = phase,
                liveTranscript = liveTranscript,
                onStop = { session.stop() },
                onCancel = ::finishVoicePanel,
                onEditText = {
                    // 填入输入框需 AIChatScreen 交出输入态（AI worker 后续接线）；
                    // 当前关闭面板，失败态已展示保留原文，用户可手动重输。
                    finishVoicePanel()
                },
                // 永久拒绝时失败态展示"前往系统设置"引导
                onOpenSettings = if (voiceSettingsBlocked) {
                    { context.openAppSettings() }
                } else {
                    null
                },
                // 面板不忽略底部安全区（宿主约定）
                modifier = Modifier
                    .align(Alignment.BottomCenter)
                    .navigationBarsPadding()
            )
        }
    }
}
