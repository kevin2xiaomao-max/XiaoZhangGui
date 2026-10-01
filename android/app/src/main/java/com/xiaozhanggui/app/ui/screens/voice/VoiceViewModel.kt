package com.xiaozhanggui.app.ui.screens.voice

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.xiaozhanggui.app.data.repository.CustomerRepository
import com.xiaozhanggui.app.data.repository.ExpenseRepository
import com.xiaozhanggui.app.data.repository.ExpiryRepository
import com.xiaozhanggui.app.data.repository.MemoRepository
import com.xiaozhanggui.app.data.repository.PerformanceRepository
import com.xiaozhanggui.app.data.repository.TodoRepository
import com.xiaozhanggui.app.data.voice.VoiceSpeechService
import com.xiaozhanggui.app.domain.voice.QuickCaptureSemantic
import com.xiaozhanggui.app.domain.voice.VoiceDraft
import com.xiaozhanggui.app.domain.voice.VoiceParser
import com.xiaozhanggui.app.domain.voice.VoiceRecordType
import com.xiaozhanggui.app.domain.voice.validateVoiceDraft
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

/**
 * 语音状态机。1:1 对应 iOS Voice/VoiceModel.swift 的 `VoicePhase`。
 */
sealed interface VoicePhase {
    data object Idle : VoicePhase
    data object Listening : VoicePhase
    data object Recognized : VoicePhase
    data object Parsing : VoicePhase
    data object Preview : VoicePhase
    data object Saving : VoicePhase
    data class Error(val message: String) : VoicePhase
    data object TextFallback : VoicePhase

    /** 对应 iOS `VoicePhase.statusText`。 */
    val statusText: String
        get() = when (this) {
            Idle -> "点击麦克风开始"
            Listening -> QuickCaptureSemantic.LISTENING
            Recognized -> QuickCaptureSemantic.PROCESSING
            Parsing -> QuickCaptureSemantic.PROCESSING
            Preview -> QuickCaptureSemantic.READY
            Saving -> QuickCaptureSemantic.SAVING
            is Error -> message
            TextFallback -> "手动输入内容"
        }
}

/**
 * 语音记一笔 ViewModel。1:1 对应 iOS Voice/VoiceViewModel.swift。
 *
 * 流程：beginListening → partial 实时转写 → stopListening/final →
 * handleRecognized → VoiceParser.parse → preview（类型可覆盖）→ save 六分支真实写库。
 *
 * RECORD_AUDIO 由调用方（UI）申请；此处只经 [VoiceSpeechService.hasAudioPermission] 检查状态。
 * 保存成功后置 [didSave]，由 UI 延迟关闭（对齐 iOS `didSave → 0.8s → dismiss`）。
 */
class VoiceViewModel(
    private val performanceRepository: PerformanceRepository,
    private val expenseRepository: ExpenseRepository,
    private val expiryRepository: ExpiryRepository,
    private val memoRepository: MemoRepository,
    private val customerRepository: CustomerRepository,
    private val todoRepository: TodoRepository,
    private val speech: VoiceSpeechService,
) : ViewModel() {

    private val _phase = MutableStateFlow<VoicePhase>(VoicePhase.Idle)
    val phase: StateFlow<VoicePhase> = _phase.asStateFlow()

    /** 实时识别文字（聆听过程的主要视觉内容）。 */
    private val _transcript = MutableStateFlow("")
    val transcript: StateFlow<String> = _transcript.asStateFlow()

    private val _draft = MutableStateFlow<VoiceDraft?>(null)
    val draft: StateFlow<VoiceDraft?> = _draft.asStateFlow()

    /** 保存成功后由 UI 延迟关闭。 */
    private val _didSave = MutableStateFlow(false)
    val didSave: StateFlow<Boolean> = _didSave.asStateFlow()

    /** 识别器不可用时的提示（对齐 iOS `speechAvailableHint`）。 */
    val speechUnavailableHint: String
        get() = if (speech.isAvailable) "" else VoiceSpeechService.ERROR_NOT_AVAILABLE

    val isSpeechAvailable: Boolean
        get() = speech.isAvailable

    /** 预览阶段可切换的记录类型（对齐 iOS `recordType`）。 */
    fun setRecordType(type: VoiceRecordType) {
        _draft.value = _draft.value?.copy(type = type)
    }

    /** 点击麦克风：识别器不可用时静默返回（对齐 iOS；UI 侧按钮置灰）。 */
    fun beginListening() {
        if (!speech.isAvailable) return
        if (!speech.hasAudioPermission()) {
            _phase.value = VoicePhase.Error(VoiceSpeechService.ERROR_PERMISSION_DENIED)
            return
        }
        _transcript.value = ""
        _draft.value = null
        speech.start(
            onPartial = { partial ->
                _transcript.value = partial
                if (_phase.value == VoicePhase.Idle || _phase.value == VoicePhase.Recognized) {
                    _phase.value = VoicePhase.Listening
                }
            },
            onFinal = { handleRecognized(it) },
            onError = { _phase.value = VoicePhase.Error(it) },
        )
        _phase.value = VoicePhase.Listening
    }

    /** 手动停止录音，等待最终识别结果。 */
    fun stopListening() {
        speech.stop()
        _phase.value = VoicePhase.Recognized
    }

    /** 识别完成 → 解析 → 预览。 */
    fun handleRecognized(text: String) {
        val trimmed = text.trim()
        if (trimmed.isEmpty()) {
            _phase.value = VoicePhase.Error(VoiceSpeechService.ERROR_NO_SPEECH_HEARD)
            return
        }
        if (VoiceParser.isUnsupportedQuery(trimmed)) {
            _transcript.value = trimmed
            _phase.value = VoicePhase.Error(VoiceSpeechService.ERROR_NO_SPEECH_HEARD)
            return
        }
        _transcript.value = trimmed
        _phase.value = VoicePhase.Parsing
        _draft.value = VoiceParser.parse(trimmed)
        _phase.value = VoicePhase.Preview
    }

    /** TextFallback：手动输入文本走同一解析链路。 */
    fun submitManualText(text: String) {
        speech.cancel()
        handleRecognized(text)
    }

    /** 进入手动输入。 */
    fun enterTextFallback() {
        speech.cancel()
        _phase.value = VoicePhase.TextFallback
    }

    /** 权限被拒绝（由调用方的权限申请回调转入）。 */
    fun onPermissionDenied() {
        _phase.value = VoicePhase.Error(VoiceSpeechService.ERROR_PERMISSION_DENIED)
    }

    /**
     * 保存草稿（真实写库）。1:1 对应 iOS VoiceViewModel.save() 六分支。
     *
     * 金额缺失等错误直接报给用户：先经 [validateVoiceDraft] 校验（GATE C #6，
     * 金额缺失必须报错，绝不写 0），通过后才写库。
     */
    fun save() {
        val draft = _draft.value ?: return
        validateVoiceDraft(draft)?.let { message ->
            _phase.value = VoicePhase.Error(message)
            return
        }
        _phase.value = VoicePhase.Saving
        viewModelScope.launch {
            runCatching {
                val now = System.currentTimeMillis()
                when (draft.type) {
                    VoiceRecordType.REVENUE -> {
                        val amount = requireNotNull(draft.amount)
                        performanceRepository.add(amount = amount, note = "语音记录", date = now)
                    }
                    VoiceRecordType.EXPENSE -> {
                        val amount = requireNotNull(draft.amount)
                        val category = if (draft.original.contains("进货")) "进货" else "其他"
                        expenseRepository.add(
                            amount = amount,
                            category = category,
                            note = draft.original,
                            date = now,
                        )
                    }
                    VoiceRecordType.EXPIRY -> {
                        val days = draft.expiryDays ?: 7
                        expiryRepository.add(
                            name = draft.title,
                            quantity = 1,
                            expiryDate = now + days * 86_400_000L,
                            remindDaysBefore = 7,
                            note = "语音记录",
                        )
                    }
                    VoiceRecordType.MEMO -> {
                        memoRepository.add(title = draft.title, content = draft.original)
                    }
                    VoiceRecordType.CUSTOMER -> {
                        customerRepository.add(
                            customer = draft.customerName ?: "客户",
                            roomOrAddress = "",
                            phone = "",
                            content = draft.goodsName
                                ?.let { "$it × ${draft.quantity ?: 1}" }
                                ?: draft.original,
                        )
                    }
                    VoiceRecordType.TODO -> {
                        todoRepository.add(
                            title = draft.title,
                            detail = draft.original,
                            dueDate = draft.dueAt,
                            priority = 0,
                        )
                    }
                }
            }.onSuccess {
                _phase.value = VoicePhase.Idle
                _didSave.value = true
            }.onFailure {
                _phase.value = VoicePhase.Error(QuickCaptureSemantic.FAILED)
            }
        }
    }

    /** 回到初始状态。 */
    fun reset() {
        speech.cancel()
        _transcript.value = ""
        _draft.value = null
        _didSave.value = false
        _phase.value = VoicePhase.Idle
    }

    override fun onCleared() {
        speech.release()
        super.onCleared()
    }
}
