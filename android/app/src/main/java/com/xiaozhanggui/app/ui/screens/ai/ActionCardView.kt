package com.xiaozhanggui.app.ui.screens.ai

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AttachMoney
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.DeliveryDining
import androidx.compose.material.icons.filled.ErrorOutline
import androidx.compose.material.icons.filled.NoteAlt
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.filled.TaskAlt
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.unit.dp
import com.xiaozhanggui.app.domain.ai.ActionProposal
import com.xiaozhanggui.app.domain.ai.ProposalStatus
import com.xiaozhanggui.app.domain.ai.ToolCall
import com.xiaozhanggui.app.domain.ai.ToolCatalog
import com.xiaozhanggui.app.domain.ai.ToolName
import com.xiaozhanggui.app.domain.ai.fieldRows
import com.xiaozhanggui.app.ui.components.BubbleTone
import com.xiaozhanggui.app.ui.components.V32Card
import com.xiaozhanggui.app.ui.components.V32IconBubble
import com.xiaozhanggui.app.ui.components.V32PrimaryButton
import com.xiaozhanggui.app.ui.components.V32SecondaryButton
import com.xiaozhanggui.app.ui.theme.LocalXzgPalettes
import com.xiaozhanggui.app.ui.theme.XzgType

/**
 * 待确认 ActionCard。对应 iOS `AI/UI/ActionCardView.swift`。
 *
 * - 5 状态文案 1:1（待你确认 / 正在保存… / 已保存 / 重复，已跳过 / 失败，可重试 / 已取消）；
 * - 主按钮文案：确认记录 / 已记录 / 已跳过重复项 / 重试保存；
 * - 次按钮：修改 / 不记录；
 * - 已决（pending / failed 之外）按钮禁用置灰。
 */
@Composable
fun ActionCardView(
    proposal: ActionProposal,
    onConfirm: () -> Unit,
    onRetry: () -> Unit,
    onModify: () -> Unit,
    onCancel: () -> Unit,
    modifier: Modifier = Modifier
) {
    val palettes = LocalXzgPalettes.current
    val arguments = remember(proposal.argumentsJson, proposal.toolName) {
        runCatching {
            ToolCall(callId = "card", name = proposal.toolName, argumentsJson = proposal.argumentsJson)
                .decodeArguments()
        }.getOrNull()
    }
    val rows = remember(arguments) {
        if (arguments != null) arguments.fieldRows() else emptyList()
    }

    V32Card(modifier = modifier) {
        Column(modifier = Modifier.padding(4.dp)) {
            // 标题行
            Row(verticalAlignment = Alignment.CenterVertically) {
                V32IconBubble(icon = toolIcon(proposal.toolName), tone = BubbleTone.BRAND)
                Spacer(modifier = Modifier.width(10.dp))
                Column(modifier = Modifier.weight(1f)) {
                    Text(
                        text = toolTitle(proposal.toolName),
                        style = XzgType.headline,
                        color = palettes.background.textPrimary
                    )
                    Text(
                        text = proposal.statusText,
                        style = XzgType.caption,
                        color = palettes.background.textSecondary
                    )
                }
            }

            // 参数行
            if (rows.isNotEmpty()) {
                Spacer(modifier = Modifier.height(10.dp))
                Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    rows.forEach { row ->
                        Row(modifier = Modifier.fillMaxWidth()) {
                            Text(
                                text = row.first,
                                style = XzgType.caption,
                                color = palettes.background.textTertiary,
                                modifier = Modifier.width(64.dp)
                            )
                            Text(
                                text = row.second,
                                style = XzgType.body,
                                color = palettes.background.textPrimary,
                                modifier = Modifier.weight(1f)
                            )
                        }
                    }
                }
            }

            // 结果行（执行后 / 失败原因）
            proposal.resultText?.let { result ->
                Spacer(modifier = Modifier.height(8.dp))
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(
                        imageVector = if (proposal.status == ProposalStatus.FAILED)
                            Icons.Filled.ErrorOutline else Icons.Filled.CheckCircle,
                        contentDescription = null,
                        tint = if (proposal.status == ProposalStatus.FAILED)
                            palettes.fixed.danger else palettes.accent.accent
                    )
                    Spacer(modifier = Modifier.width(6.dp))
                    Text(
                        text = result,
                        style = XzgType.subhead,
                        color = palettes.background.textSecondary
                    )
                }
            }

            // 操作区
            Spacer(modifier = Modifier.height(12.dp))
            val resolved = proposal.isDecided
            V32PrimaryButton(
                text = confirmTitle(proposal),
                onClick = if (proposal.status == ProposalStatus.FAILED) onRetry else onConfirm,
                enabled = !resolved
            )
            Spacer(modifier = Modifier.height(10.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                V32SecondaryButton(
                    text = "修改",
                    onClick = onModify,
                    modifier = Modifier.weight(1f),
                    enabled = !resolved
                )
                V32SecondaryButton(
                    text = "不记录",
                    onClick = onCancel,
                    modifier = Modifier.weight(1f),
                    enabled = !resolved
                )
            }
        }
    }
}

private fun toolIcon(tool: ToolName): ImageVector = when (tool) {
    ToolName.RECORD_REVENUE -> Icons.Filled.AttachMoney
    ToolName.CREATE_TODO -> Icons.Filled.TaskAlt
    ToolName.CREATE_MEMO -> Icons.Filled.NoteAlt
    ToolName.CREATE_DELIVERY -> Icons.Filled.DeliveryDining
    ToolName.SEARCH_RECORDS -> Icons.Filled.Search
}

private fun toolTitle(tool: ToolName): String = when (tool) {
    ToolName.RECORD_REVENUE -> "记录营业额"
    ToolName.CREATE_TODO -> "新建待办"
    ToolName.CREATE_MEMO -> "新建备忘"
    ToolName.CREATE_DELIVERY -> "新建配送"
    ToolName.SEARCH_RECORDS -> "查询经营记录"
}

/** 主按钮文案 1:1 iOS confirmTitle（无预览门，live only）。 */
private fun confirmTitle(proposal: ActionProposal): String = when (proposal.status) {
    ProposalStatus.EXECUTED -> "已记录"
    ProposalStatus.DUPLICATE -> "已跳过重复项"
    ProposalStatus.FAILED -> "重试保存"
    else -> "确认记录"
}
