package com.xiaozhanggui.app.ui.screens.ai

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.unit.dp
import com.xiaozhanggui.app.data.ai.AiDefaults
import com.xiaozhanggui.app.data.ai.AiSettings
import com.xiaozhanggui.app.data.ai.AiSettingsDraft
import com.xiaozhanggui.app.data.ai.ConnectionTestState
import com.xiaozhanggui.app.data.ai.DeepSeekModel
import com.xiaozhanggui.app.data.ai.ModelTier
import com.xiaozhanggui.app.data.ai.OpenAiCompatProvider
import com.xiaozhanggui.app.data.ai.ProviderConnectionTester
import com.xiaozhanggui.app.data.ai.SearchProviderSelection
import com.xiaozhanggui.app.ui.components.PillTone
import com.xiaozhanggui.app.ui.components.V32Card
import com.xiaozhanggui.app.ui.components.V32PrimaryButton
import com.xiaozhanggui.app.ui.components.V32StatusPill
import com.xiaozhanggui.app.ui.theme.LocalXzgPalettes
import com.xiaozhanggui.app.ui.theme.XzgType
import kotlinx.coroutines.launch

/**
 * AI 设置页。对应 iOS `AI/UI/AIProviderSettingsSheet.swift`。
 *
 * - 模型策略三档：免费优先 / 自动 / 高质量；
 * - 主 Provider（DeepSeek）：服务地址 / 模型 / API Key（不回显）/ 测试连接；
 * - 连接测试胶囊：只有真实 success 才绿色，testing/unverified 中性灰，失败琥珀；
 * - 高级 / 自定义 Provider（备用）：三项都填才启用；
 * - Key 只存本机加密存储，不回显、不进备份。
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AIProviderSettingsSheet(
    onDismiss: () -> Unit,
    onSaved: () -> Unit,
    modifier: Modifier = Modifier
) {
    val context = LocalContext.current
    val palettes = LocalXzgPalettes.current
    val scope = rememberCoroutineScope()
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)

    val settings = remember { AiSettings(context.applicationContext) }
    var draft by remember { mutableStateOf<AiSettingsDraft?>(null) }
    val tester = remember { ProviderConnectionTester() }
    var testStatus by remember { mutableStateOf<ConnectionTestState>(ConnectionTestState.Unverified) }
    var isTesting by remember { mutableStateOf(false) }

    LaunchedEffect(Unit) {
        val d = AiSettingsDraft()
        d.loadFrom(settings)
        draft = d
        testStatus = if (d.primaryKeySaved) ConnectionTestState.Unverified
        else ConnectionTestState.NotConfigured
    }

    fun effectivePrimaryKey(d: AiSettingsDraft): String {
        val staged = d.stagedPrimaryKey.trim()
        if (staged.isNotEmpty()) return staged
        if (d.clearPrimaryKeyRequested) return ""
        return settings.primaryAPIKey
    }

    fun testConnection(d: AiSettingsDraft) {
        val key = effectivePrimaryKey(d)
        val baseUrl = d.primaryBaseURL.trim().ifEmpty { AiDefaults.PRIMARY_BASE_URL }
        val model = d.primaryModel.id
        if (key.isEmpty() || (!baseUrl.startsWith("https://") && !baseUrl.startsWith("http://"))) {
            testStatus = ConnectionTestState.NotConfigured
            return
        }
        isTesting = true
        testStatus = ConnectionTestState.Testing
        scope.launch {
            val provider = OpenAiCompatProvider(baseURL = baseUrl, apiKey = key, model = model)
            testStatus = tester.test(provider)
            isTesting = false
        }
    }

    ModalBottomSheet(onDismissRequest = onDismiss, sheetState = sheetState, modifier = modifier) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 16.dp, vertical = 8.dp)
        ) {
            // 标题行：取消 / AI 设置 / 保存
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically
            ) {
                TextButton(onClick = onDismiss) { Text("取消") }
                Spacer(modifier = Modifier.weight(1f))
                Text(text = "AI 设置", style = XzgType.headline, color = palettes.background.textPrimary)
                Spacer(modifier = Modifier.weight(1f))
                TextButton(onClick = {
                    val d = draft ?: return@TextButton
                    scope.launch {
                        d.commit(settings)
                        onSaved()
                        onDismiss()
                    }
                }) { Text("保存") }
            }

            val d = draft
            if (d == null) {
                Spacer(modifier = Modifier.height(48.dp))
                CircularProgressIndicator()
            } else {
                SettingsContent(
                    draft = d,
                    onDraftChange = { draft = d.copy() },
                    testStatus = testStatus,
                    isTesting = isTesting,
                    onTest = { testConnection(d) }
                )
            }
            Spacer(modifier = Modifier.height(24.dp))
        }
    }
}

@Composable
private fun SettingsContent(
    draft: AiSettingsDraft,
    onDraftChange: () -> Unit,
    testStatus: ConnectionTestState,
    isTesting: Boolean,
    onTest: () -> Unit
) {
    val palettes = LocalXzgPalettes.current

    // 模型策略
    V32Card {
        Column(
            verticalArrangement = Arrangement.spacedBy(10.dp),
            modifier = Modifier.padding(4.dp)
        ) {
            SectionTitle("模型策略")
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                ModelTier.entries.forEach { tier ->
                    val selected = draft.tier == tier
                    TextButton(
                        onClick = { draft.tier = tier; onDraftChange() },
                        modifier = Modifier.weight(1f)
                    ) {
                        Text(
                            text = tier.label,
                            style = XzgType.body,
                            color = if (selected) palettes.accent.accent
                            else palettes.background.textSecondary
                        )
                    }
                }
            }
            Caption("本地能听懂的记账 / 查询不消耗 Token；只有本地没把握时才联网。")
        }
    }
    Spacer(modifier = Modifier.height(12.dp))

    // 主 Provider（DeepSeek）
    V32Card {
        Column(
            verticalArrangement = Arrangement.spacedBy(10.dp),
            modifier = Modifier.padding(4.dp)
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                SectionTitle("DeepSeek", modifier = Modifier.weight(1f))
                V32StatusPill(text = testStatusText(testStatus), tone = connectionPillTone(testStatus))
            }
            FieldLabel("服务地址（默认 DeepSeek 官方，一般无需修改）")
            SettingsTextField(
                value = draft.primaryBaseURL,
                onValueChange = { draft.primaryBaseURL = it; onDraftChange() },
                placeholder = AiDefaults.PRIMARY_BASE_URL,
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Uri)
            )
            FieldLabel("模型")
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                DeepSeekModel.entries.forEach { model ->
                    val selected = draft.primaryModel == model
                    TextButton(
                        onClick = { draft.primaryModel = model; onDraftChange() },
                        modifier = Modifier.weight(1f)
                    ) {
                        Text(
                            text = model.displayName,
                            style = XzgType.body,
                            color = if (selected) palettes.accent.accent
                            else palettes.background.textSecondary
                        )
                    }
                }
            }
            FieldLabel("API Key（仅存本机，不回显）")
            SettingsTextField(
                value = draft.stagedPrimaryKey,
                onValueChange = {
                    draft.stagedPrimaryKey = it
                    if (it.isNotEmpty()) draft.clearPrimaryKeyRequested = false
                    onDraftChange()
                },
                placeholder = if (draft.primaryKeySaved && !draft.clearPrimaryKeyRequested)
                    "已保存，如需更换请粘贴新 Key" else "粘贴 API Key",
                visualTransformation = PasswordVisualTransformation(),
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Password)
            )
            if (draft.primaryKeySaved) {
                TextButton(onClick = {
                    draft.clearPrimaryKeyRequested = !draft.clearPrimaryKeyRequested
                    if (draft.clearPrimaryKeyRequested) draft.stagedPrimaryKey = ""
                    onDraftChange()
                }) {
                    Text(
                        text = if (draft.clearPrimaryKeyRequested) "保留已保存的 Key" else "清除已保存的 Key",
                        style = XzgType.caption,
                        color = palettes.fixed.danger
                    )
                }
            }
            V32PrimaryButton(
                text = "测试连接",
                onClick = onTest,
                enabled = !isTesting
            )
            Caption("只有测试通过显示「连接成功」后，才代表 API 可以正常使用。")
        }
    }
    Spacer(modifier = Modifier.height(12.dp))

    // 高级 / 自定义 Provider
    V32Card {
        Column(
            verticalArrangement = Arrangement.spacedBy(10.dp),
            modifier = Modifier.padding(4.dp)
        ) {
            SectionTitle("高级 / 自定义 Provider（可选）")
            Caption("任意 OpenAI 兼容端点；主 Provider 网络失败 / 超时 / 限流时自动切换一次，三项都填才启用。")
            FieldLabel("服务地址")
            SettingsTextField(
                value = draft.fallbackBaseURL,
                onValueChange = { draft.fallbackBaseURL = it; onDraftChange() },
                placeholder = "https://api.example.com/v1",
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Uri)
            )
            FieldLabel("模型")
            SettingsTextField(
                value = draft.fallbackModel,
                onValueChange = { draft.fallbackModel = it; onDraftChange() },
                placeholder = "模型名"
            )
            FieldLabel("API Key（仅存本机）")
            SettingsTextField(
                value = draft.stagedFallbackKey,
                onValueChange = { draft.stagedFallbackKey = it; onDraftChange() },
                placeholder = "粘贴自定义 Provider API Key",
                visualTransformation = PasswordVisualTransformation(),
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Password)
            )
            if (draft.fallbackKeySaved) {
                TextButton(onClick = {
                    draft.clearFallbackKeyRequested = !draft.clearFallbackKeyRequested
                    if (draft.clearFallbackKeyRequested) draft.stagedFallbackKey = ""
                    onDraftChange()
                }) {
                    Text(
                        text = if (draft.clearFallbackKeyRequested) "保留已保存的备用 Key" else "清除备用 Key",
                        style = XzgType.caption,
                        color = palettes.fixed.danger
                    )
                }
            }
        }
    }
    Spacer(modifier = Modifier.height(12.dp))

    // 搜索 Provider
    V32Card {
        Column(
            verticalArrangement = Arrangement.spacedBy(10.dp),
            modifier = Modifier.padding(4.dp)
        ) {
            SectionTitle("搜索 Provider")
            Caption("搜索只读，不会写入经营数据。每个 Provider 独立配置，Key 仅存本机。")
            Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                SearchProviderSelection.entries.forEach { sel ->
                    val selected = draft.searchProviderSelection == sel
                    TextButton(
                        onClick = { draft.searchProviderSelection = sel; onDraftChange() },
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Text(
                            text = sel.displayName,
                            style = XzgType.body,
                            color = if (selected) palettes.accent.accent
                            else palettes.background.textSecondary
                        )
                    }
                }
            }
        }
    }
    Spacer(modifier = Modifier.height(12.dp))

    // 隐私说明
    Column(
        verticalArrangement = Arrangement.spacedBy(6.dp),
        modifier = Modifier.padding(horizontal = 4.dp)
    ) {
        Caption("Key 只存在本机加密存储，不会进入聊天记录、日志或备份。")
        Caption("普通聊天与记账默认不上传经营数据；查询结果在本机汇总。")
    }
}

/** 设置页文本框（V32 roundedBorder 风格）。 */
@Composable
private fun SettingsTextField(
    value: String,
    onValueChange: (String) -> Unit,
    placeholder: String,
    modifier: Modifier = Modifier,
    visualTransformation: VisualTransformation = VisualTransformation.None,
    keyboardOptions: KeyboardOptions = KeyboardOptions.Default
) {
    val palettes = LocalXzgPalettes.current
    val shape = RoundedCornerShape(10.dp)
    BasicTextField(
        value = value,
        onValueChange = onValueChange,
        modifier = modifier
            .fillMaxWidth()
            .clip(shape)
            .background(palettes.background.card)
            .border(1.dp, palettes.background.cardOutline, shape)
            .padding(horizontal = 12.dp, vertical = 10.dp)
            .heightIn(min = 24.dp),
        textStyle = XzgType.body.copy(color = palettes.background.textPrimary),
        singleLine = true,
        cursorBrush = SolidColor(palettes.accent.accent),
        visualTransformation = visualTransformation,
        keyboardOptions = keyboardOptions,
        decorationBox = { innerTextField ->
            if (value.isEmpty()) {
                Text(
                    text = placeholder,
                    style = XzgType.body,
                    color = palettes.background.textTertiary,
                    maxLines = 1
                )
            }
            innerTextField()
        }
    )
}

/** 连接胶囊文案。 */
private fun testStatusText(status: ConnectionTestState): String = when (status) {
    is ConnectionTestState.Success -> "连接成功"
    is ConnectionTestState.Testing -> "测试中"
    is ConnectionTestState.Failure -> status.message
    is ConnectionTestState.NotConfigured -> "未配置"
    is ConnectionTestState.Unverified -> "未验证"
}

/** 连接胶囊：只有真实 success 才绿色；testing/unverified 中性灰；失败琥珀。1:1 iOS。 */
private fun connectionPillTone(status: ConnectionTestState): PillTone = when (status) {
    is ConnectionTestState.Success -> PillTone.DELIVERING
    is ConnectionTestState.Testing, is ConnectionTestState.Unverified -> PillTone.PENDING
    is ConnectionTestState.NotConfigured, is ConnectionTestState.Failure -> PillTone.EXPIRY
}

@Composable
private fun SectionTitle(text: String, modifier: Modifier = Modifier) {
    Text(
        text = text,
        style = XzgType.section,
        color = LocalXzgPalettes.current.background.textPrimary,
        modifier = modifier
    )
}

@Composable
private fun FieldLabel(text: String) {
    Text(
        text = text,
        style = XzgType.caption,
        color = LocalXzgPalettes.current.background.textSecondary
    )
}

@Composable
private fun Caption(text: String) {
    Text(
        text = text,
        style = XzgType.caption,
        color = LocalXzgPalettes.current.background.textSecondary
    )
}
