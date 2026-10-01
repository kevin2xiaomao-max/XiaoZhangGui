package com.xiaozhanggui.app.ui.screens.ai

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ChatBubbleOutline
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.MoreVert
import androidx.compose.material.icons.filled.AutoAwesome
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.xiaozhanggui.app.XzgApplication
import com.xiaozhanggui.app.data.di.XzgGraph
import com.xiaozhanggui.app.domain.ai.ActionProposal
import com.xiaozhanggui.app.domain.ai.AiRole
import com.xiaozhanggui.app.domain.ai.AiUiMessage
import com.xiaozhanggui.app.ui.components.PillTone
import com.xiaozhanggui.app.ui.components.V32EmptyState
import com.xiaozhanggui.app.ui.components.V32StatusPill
import com.xiaozhanggui.app.ui.theme.LocalXzgPalettes
import com.xiaozhanggui.app.ui.theme.XzgType

/**
 * 小掌柜 AI 聊天页。对应 iOS `AI/UI/AIChatView.swift`。
 *
 * - 空态：4 个范例按钮（1:1 iOS examples）；
 * - TypingIndicator 二元状态（processingLabel 二元显示）；
 * - 右上 Menu：新对话 / 清空当前对话 / AI 设置；
 * - ActionCard 挂在消息列表末尾（最新一轮的待确认卡）；
 * - onVoice 回调透出，由 Phase 4 语音 worker 接管语音面板。
 */
@Composable
fun AIChatScreen(
    onVoice: () -> Unit = {},
    modifier: Modifier = Modifier,
) {
    val context = LocalContext.current
    val viewModel: AIConversationViewModel = viewModel(
        factory = XzgGraph.vmFactory {
            AIConversationViewModel(
                context.applicationContext as XzgApplication
            )
        }
    )
    val palettes = LocalXzgPalettes.current
    val ready by viewModel.ready.collectAsState()
    val messages by viewModel.messages.collectAsState()
    val proposals by viewModel.proposals.collectAsState()
    val isProcessing by viewModel.isProcessing.collectAsState()
    val processingLabel by viewModel.processingLabel.collectAsState()
    val isRemoteConfigured by viewModel.isRemoteConfigured.collectAsState()

    var input by remember { mutableStateOf("") }
    var showSettings by remember { mutableStateOf(false) }
    var showClearConfirm by remember { mutableStateOf(false) }

    AIChatContent(
        messages = messages,
        proposals = proposals,
        isProcessing = isProcessing,
        processingLabel = processingLabel,
        isRemoteConfigured = isRemoteConfigured,
        ready = ready,
        inputText = input,
        onInputTextChange = { input = it },
        onSend = {
            viewModel.send(input)
            input = ""
        },
        onVoice = onVoice,
        onRetry = { viewModel.retryLastFailed() },
        onExample = { viewModel.send(it) },
        onProposalConfirm = { viewModel.confirm(it.id) },
        onProposalRetry = { viewModel.retry(it.id) },
        onProposalModify = { viewModel.modify(it.id) { original -> input = original ?: "" } },
        onProposalCancel = { viewModel.cancel(it.id) },
        onNewConversation = { showClearConfirm = true },
        onOpenSettings = { showSettings = true },
        modifier = modifier
    )

    if (showSettings) {
        AIProviderSettingsSheet(
            onDismiss = { showSettings = false },
            onSaved = { viewModel.refreshAfterSettingsChanged() }
        )
    }

    if (showClearConfirm) {
        AlertDialog(
            onDismissRequest = { showClearConfirm = false },
            title = { Text("清空当前对话？") },
            text = { Text("将清空消息与未确认的卡片；已保存的营业额 / 待办 / 备忘 / 配送不会被删除。") },
            confirmButton = {
                TextButton(onClick = {
                    showClearConfirm = false
                    viewModel.clearConversation()
                }) { Text("清空", color = palettes.fixed.danger) }
            },
            dismissButton = {
                TextButton(onClick = { showClearConfirm = false }) { Text("取消") }
            }
        )
    }
}

/**
 * AI 聊天页纯渲染内容（Paparazzi 截图入口）。
 * 设置 Sheet / 清空确认弹窗保留在 [AIChatScreen]。
 */
@Composable
fun AIChatContent(
    messages: List<AiUiMessage>,
    proposals: List<ActionProposal>,
    isProcessing: Boolean,
    processingLabel: String,
    isRemoteConfigured: Boolean,
    ready: Boolean,
    inputText: String,
    onInputTextChange: (String) -> Unit = {},
    onSend: () -> Unit = {},
    onVoice: () -> Unit = {},
    onRetry: () -> Unit = {},
    onExample: (String) -> Unit = {},
    onProposalConfirm: (ActionProposal) -> Unit = {},
    onProposalRetry: (ActionProposal) -> Unit = {},
    onProposalModify: (ActionProposal) -> Unit = {},
    onProposalCancel: (ActionProposal) -> Unit = {},
    onNewConversation: () -> Unit = {},
    onOpenSettings: () -> Unit = {},
    modifier: Modifier = Modifier
) {
    val palettes = LocalXzgPalettes.current
    var showMenu by remember { mutableStateOf(false) }

    val listState = rememberLazyListState()
    LaunchedEffect(messages.size, proposals.size, isProcessing) {
        val total = messages.size + proposals.size + if (isProcessing) 1 else 0
        if (total > 0) listState.animateScrollToItem(total - 1)
    }

    Column(modifier = modifier.fillMaxSize()) {
        // 顶栏：标题 + 状态胶囊 + 菜单
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp, vertical = 10.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = "说句话，帮你记账、派单、备忘",
                    style = XzgType.subhead,
                    color = palettes.background.textSecondary
                )
                Spacer(modifier = Modifier.height(4.dp))
                V32StatusPill(
                    text = if (isRemoteConfigured) "Key 已保存" else "未配置",
                    tone = if (isRemoteConfigured) PillTone.PENDING else PillTone.EXPIRY
                )
            }
            Box {
                IconButton(onClick = { showMenu = true }) {
                    Icon(
                        imageVector = Icons.Filled.MoreVert,
                        contentDescription = "对话菜单",
                        tint = palettes.background.textPrimary
                    )
                }
                DropdownMenu(expanded = showMenu, onDismissRequest = { showMenu = false }) {
                    DropdownMenuItem(
                        text = { Text("新对话") },
                        onClick = { showMenu = false; onNewConversation() }
                    )
                    DropdownMenuItem(
                        text = { Text("清空当前对话") },
                        onClick = { showMenu = false; onNewConversation() }
                    )
                    DropdownMenuItem(
                        text = { Text("AI 设置") },
                        onClick = { showMenu = false; onOpenSettings() }
                    )
                }
            }
        }

        // 消息列表
        LazyColumn(
            state = listState,
            modifier = Modifier
                .weight(1f)
                .fillMaxWidth()
                .padding(horizontal = 16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            if (messages.isEmpty() && proposals.isEmpty() && !isProcessing) {
                item { EmptyState(onExample = onExample) }
            } else {
                items(messages, key = { it.id }) { message ->
                    MessageRow(
                        message = message,
                        onRetry = onRetry
                    )
                }
                items(proposals, key = { it.id }) { proposal ->
                    ActionCardView(
                        proposal = proposal,
                        onConfirm = { onProposalConfirm(proposal) },
                        onRetry = { onProposalRetry(proposal) },
                        onModify = { onProposalModify(proposal) },
                        onCancel = { onProposalCancel(proposal) }
                    )
                }
                if (isProcessing) {
                    item { TypingIndicator(label = processingLabel) }
                }
            }
        }

        // 输入栏
        ChatInputBar(
            text = inputText,
            onTextChange = onInputTextChange,
            isProcessing = isProcessing || !ready,
            voiceAvailable = true,
            onSend = onSend,
            onVoice = onVoice,
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp, vertical = 10.dp)
        )
    }

}

@Composable
private fun EmptyState(onExample: (String) -> Unit) {
    val palettes = LocalXzgPalettes.current
    Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
        V32EmptyState(
            icon = Icons.Filled.AutoAwesome,
            title = "我是小掌柜",
            message = "说句话或点个例子，我先整理成确认卡，你确认后才记录。"
        )
        Text(
            text = "试试这样说",
            style = XzgType.section,
            color = palettes.background.textPrimary
        )
        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
            AIConversationViewModel.EXAMPLES.forEach { example ->
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(12.dp))
                        .background(palettes.background.card)
                        .clickable { onExample(example) }
                        .padding(horizontal = 14.dp, vertical = 12.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Icon(
                        imageVector = Icons.Filled.ChatBubbleOutline,
                        contentDescription = null,
                        tint = palettes.accent.accent,
                        modifier = Modifier.size(16.dp)
                    )
                    Spacer(modifier = Modifier.width(10.dp))
                    Text(
                        text = example,
                        style = XzgType.body,
                        color = palettes.background.textPrimary,
                        modifier = Modifier.weight(1f)
                    )
                    Icon(
                        imageVector = Icons.Filled.ChevronRight,
                        contentDescription = null,
                        tint = palettes.background.textTertiary,
                        modifier = Modifier.size(14.dp)
                    )
                }
            }
        }
    }
}

@Composable
private fun MessageRow(message: AiUiMessage, onRetry: () -> Unit) {
    val palettes = LocalXzgPalettes.current
    if (message.role == AiRole.USER) {
        Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.End) {
            Box(
                modifier = Modifier
                    .clip(RoundedCornerShape(18.dp))
                    .background(palettes.accent.accent)
                    .padding(horizontal = 14.dp, vertical = 10.dp)
            ) {
                Text(
                    text = message.text,
                    style = XzgType.body,
                    color = palettes.accent.onAccent
                )
            }
        }
    } else {
        Column {
            Text(
                text = message.text,
                style = XzgType.body,
                color = if (message.isError) palettes.fixed.danger
                else palettes.background.textPrimary
            )
            if (message.isError) {
                Spacer(modifier = Modifier.height(6.dp))
                TextButton(onClick = onRetry) { Text("重试") }
            }
        }
    }
}

/**
 * TypingIndicator：二元状态（显示 / 不显示），文案为 processingLabel。
 * 对应 iOS `AI/UI/TypingIndicator.swift` 的简化版。
 */
@Composable
private fun TypingIndicator(label: String) {
    val palettes = LocalXzgPalettes.current
    Row(verticalAlignment = Alignment.CenterVertically) {
        repeat(3) {
            Box(
                modifier = Modifier
                    .padding(end = 4.dp)
                    .size(8.dp)
                    .clip(CircleShape)
                    .background(palettes.background.textTertiary)
            )
        }
        Spacer(modifier = Modifier.width(6.dp))
        Text(
            text = label,
            style = XzgType.caption,
            color = palettes.background.textSecondary
        )
    }
}
