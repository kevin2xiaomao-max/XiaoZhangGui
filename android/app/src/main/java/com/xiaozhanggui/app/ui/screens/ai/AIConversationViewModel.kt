package com.xiaozhanggui.app.ui.screens.ai

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.xiaozhanggui.app.data.ai.AiAssembly
import com.xiaozhanggui.app.data.ai.AiDependencies
import com.xiaozhanggui.app.data.di.XzgGraph
import com.xiaozhanggui.app.domain.ai.ActionProposal
import com.xiaozhanggui.app.domain.ai.AiUiMessage
import com.xiaozhanggui.app.domain.ai.ProposalStatus
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

/**
 * AI 对话 ViewModel。对应 iOS `AI/UI/AIConversationViewModel.swift`。
 *
 * - 持有 AgentCore（经 AiAssembly 构建）；初始化完成前 UI 显示加载态；
 * - send：processingLabel 按意图切换（正在读取店铺数据 / 正在查询商品 / 正在思考），
 *   TypingIndicator 为二元状态（显示 / 不显示）；
 * - ActionCard 操作：confirm / cancel / modify；
 * - clearConversation：清空消息与待确认卡（幂等账本不受影响）。
 */
class AIConversationViewModel(application: Application) : AndroidViewModel(application) {

    private val _ready = MutableStateFlow(false)
    val ready: StateFlow<Boolean> = _ready.asStateFlow()

    private val _messages = MutableStateFlow<List<AiUiMessage>>(emptyList())
    val messages: StateFlow<List<AiUiMessage>> = _messages.asStateFlow()

    private val _proposals = MutableStateFlow<List<ActionProposal>>(emptyList())
    val proposals: StateFlow<List<ActionProposal>> = _proposals.asStateFlow()

    private val _isProcessing = MutableStateFlow(false)
    val isProcessing: StateFlow<Boolean> = _isProcessing.asStateFlow()

    private val _processingLabel = MutableStateFlow("正在思考")
    val processingLabel: StateFlow<String> = _processingLabel.asStateFlow()

    /** 云端是否已配置（Key 已保存）。对应 iOS isRemoteConfigured。 */
    private val _isRemoteConfigured = MutableStateFlow(false)
    val isRemoteConfigured: StateFlow<Boolean> = _isRemoteConfigured.asStateFlow()

    private var deps: AiDependencies? = null

    init {
        viewModelScope.launch {
            val built = AiAssembly.build(
                context = getApplication(),
                moneyRepository = XzgGraph.performanceRepository,
                todoRepository = XzgGraph.todoRepository,
                memoRepository = XzgGraph.memoRepository,
                customerRepository = XzgGraph.customerRepository,
                expiryRepository = XzgGraph.expiryRepository,
                goodsRepository = XzgGraph.goodsRepository
            )
            deps = built
            _isRemoteConfigured.value = built.settings.isPrimaryKeySaved
            refresh()
            _ready.value = true
        }
    }

    /** 设置页保存后调用：重建 Provider 链并刷新配置状态。 */
    fun refreshAfterSettingsChanged() {
        val current = deps ?: return
        viewModelScope.launch {
            _isRemoteConfigured.value = current.settings.isPrimaryKeySaved
        }
    }

    fun send(text: String) {
        val agent = deps?.agentCore ?: return
        val content = text.trim()
        if (content.isEmpty() || _isProcessing.value) return
        _processingLabel.value = processingLabelFor(content)
        _isProcessing.value = true
        viewModelScope.launch {
            try {
                val result = agent.send(content)
                // 纠正替换：旧卡已取消，UI 移除
                if (result.cancelledProposalIds.isNotEmpty()) {
                    _proposals.value = _proposals.value.filterNot {
                        it.id in result.cancelledProposalIds
                    }
                }
                refresh()
            } finally {
                _isProcessing.value = false
            }
        }
    }

    fun confirm(proposalId: String) {
        val agent = deps?.agentCore ?: return
        viewModelScope.launch {
            agent.confirm(proposalId)
            refresh()
        }
    }

    /** 失败卡的「重试保存」。 */
    fun retry(proposalId: String) {
        val agent = deps?.agentCore ?: return
        viewModelScope.launch {
            agent.retry(proposalId)
            refresh()
        }
    }

    fun cancel(proposalId: String) {
        val agent = deps?.agentCore ?: return
        viewModelScope.launch {
            agent.cancel(proposalId)
            refresh()
        }
    }

    /** 修改：取消旧卡，返回上一条用户原文，填回输入框。 */
    fun modify(proposalId: String, onOriginalText: (String?) -> Unit) {
        val agent = deps?.agentCore ?: return
        viewModelScope.launch {
            val original = agent.modify(proposalId)
            refresh()
            onOriginalText(original)
        }
    }

    fun clearConversation() {
        val agent = deps?.agentCore ?: return
        viewModelScope.launch {
            agent.clearConversation()
            refresh()
        }
    }

    /** 找到最后一条错误回复之前的用户原文，重新发送（1:1 iOS retryLastFailed）。 */
    fun retryLastFailed() {
        val msgs = _messages.value
        val errorIndex = msgs.indexOfLast { it.isError }
        if (errorIndex <= 0) return
        for (i in errorIndex - 1 downTo 0) {
            if (msgs[i].role == AiRole.USER) {
                send(msgs[i].text)
                return
            }
        }
    }

    private suspend fun refresh() {
        val agent = deps?.agentCore ?: return
        _messages.value = agent.messages()
        _proposals.value = agent.pendingProposals()
    }

    private fun processingLabelFor(text: String): String {
        return when {
            text.contains("天气") -> "正在查询天气"
            listOf("多少钱", "进价", "售价", "库存").any { text.contains(it) } -> "正在查询商品"
            listOf("营业额", "配送", "待办", "备忘").any { text.contains(it) } -> "正在读取店铺数据"
            else -> "正在思考"
        }
    }

    companion object {
        /** 4 个范例按钮（1:1 iOS AIChatView.examples）。 */
        val EXAMPLES = listOf(
            "今天美团680",
            "明天下两箱可乐",
            "记一下供应商周五来",
            "今晚8点给302送两箱怡宝"
        )
    }
}
