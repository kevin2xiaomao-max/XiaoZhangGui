package com.xiaozhanggui.app.paparazzi

import androidx.activity.result.ActivityResultRegistry
import androidx.activity.result.ActivityResultRegistryOwner
import androidx.activity.result.contract.ActivityResultContract
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalActivityResultRegistryOwner
import androidx.compose.ui.unit.dp
import androidx.core.app.ActivityOptionsCompat
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.LifecycleRegistry
import com.xiaozhanggui.app.data.db.CustomerRequestEntity
import com.xiaozhanggui.app.data.db.ExpiryItemEntity
import com.xiaozhanggui.app.data.db.GoodsCategory
import com.xiaozhanggui.app.data.db.GoodsEntity
import com.xiaozhanggui.app.data.db.MemoEntity
import com.xiaozhanggui.app.data.db.PerformanceEntity
import com.xiaozhanggui.app.data.db.TodoEntity
import com.xiaozhanggui.app.domain.CustomerDeliveryInfo
import com.xiaozhanggui.app.domain.CustomerDeliveryStorage
import com.xiaozhanggui.app.domain.ai.ActionProposal
import com.xiaozhanggui.app.domain.ai.ProposalStatus
import com.xiaozhanggui.app.domain.ai.RevenueArguments
import com.xiaozhanggui.app.domain.ai.ToolArguments
import com.xiaozhanggui.app.domain.ai.ToolName
import com.xiaozhanggui.app.domain.quickrecord.LocalQuickRecordParser
import com.xiaozhanggui.app.domain.voice.VoiceDraft
import com.xiaozhanggui.app.domain.voice.VoiceRecordType
import com.xiaozhanggui.app.ui.screens.ai.ActionCardView
import com.xiaozhanggui.app.ui.screens.customer.CustomerEditorContent
import com.xiaozhanggui.app.ui.screens.expiry.ExpiryEditorContent
import com.xiaozhanggui.app.ui.screens.goods.GoodsEditorContent
import com.xiaozhanggui.app.ui.screens.goods.GoodsEditorMode
import com.xiaozhanggui.app.ui.screens.performance.MoneyEditorContent
import com.xiaozhanggui.app.ui.screens.performance.MoneyEditorMode
import com.xiaozhanggui.app.ui.screens.quickrecord.QuickRecordSheetVisual
import com.xiaozhanggui.app.ui.screens.quickrecord.QuickRecordVisualState
import com.xiaozhanggui.app.ui.screens.todo.MemoEditorContent
import com.xiaozhanggui.app.ui.screens.todo.TodoEditorContent
import com.xiaozhanggui.app.ui.screens.voice.VoicePhase
import com.xiaozhanggui.app.ui.screens.voice.VoiceSheetVisual
import com.xiaozhanggui.app.ui.theme.LocalXzgPalettes
import com.xiaozhanggui.app.ui.theme.XzgDimens
import org.junit.Test
import java.time.ZoneOffset
import java.time.ZonedDateTime

/**
 * Phase 5 Worker B：6 个编辑 Sheet + 3 个专项的 Paparazzi 截图。
 *
 * - Sheet 统一用底部对齐的仿真容器渲染（遮罩 + 顶部圆角 + 小把手），
 *   不依赖 ModalBottomSheet 的手势状态。
 * - PhotoPickerField 内部用 rememberLauncherForActivityResult，
 *   此处提供一个 no-op 的 ActivityResultRegistryOwner 使其在单测中可组合。
 * - 数据全部手写假数据；时间用 UTC 固定毫秒，保证 CI 渲染确定性。
 */
class SheetScreenshotTest : XzgScreenshotTest() {

    // ---------- 仿真 Sheet 容器 ----------

    private fun sheetLight(name: String, content: @Composable () -> Unit) =
        pageLight(name) { SheetFrame(content) }

    private fun sheetDark(name: String, content: @Composable () -> Unit) =
        pageDark(name) { SheetFrame(content) }

    // ---------- 固定假数据 ----------

    private val dueAt: Long =
        ZonedDateTime.of(2026, 10, 3, 15, 0, 0, 0, ZoneOffset.UTC).toInstant().toEpochMilli()
    private val bizAt: Long =
        ZonedDateTime.of(2026, 10, 2, 12, 0, 0, 0, ZoneOffset.UTC).toInstant().toEpochMilli()
    private val prodAt: Long =
        ZonedDateTime.of(2026, 9, 1, 0, 0, 0, 0, ZoneOffset.UTC).toInstant().toEpochMilli()
    private val expiryAt: Long =
        ZonedDateTime.of(2026, 10, 20, 0, 0, 0, 0, ZoneOffset.UTC).toInstant().toEpochMilli()

    // ---------- 待办 ----------

    @Test
    fun todoEditorLight() = sheetLight("TodoEditor") {
        TodoEditorContent(
            todo = TodoEntity(
                title = "联系饮料供应商",
                detail = "明天下午三点前确认可乐进货价",
                dueDate = dueAt,
                priority = 1
            ),
            onDismiss = {},
            onSave = { _, _, _, _, _ -> }
        )
    }

    @Test
    fun todoEditorDark() = sheetDark("TodoEditor") {
        TodoEditorContent(
            todo = TodoEntity(
                title = "联系饮料供应商",
                detail = "明天下午三点前确认可乐进货价",
                dueDate = dueAt,
                priority = 1
            ),
            onDismiss = {},
            onSave = { _, _, _, _, _ -> }
        )
    }

    // ---------- 备忘 ----------

    @Test
    fun memoEditorLight() = sheetLight("MemoEditor") {
        MemoEditorContent(
            memo = MemoEntity(
                title = "供应商电话",
                content = "王经理 13800001111，下周二前回电确认"
            ),
            onDismiss = {},
            onSave = { _, _, _ -> }
        )
    }

    @Test
    fun memoEditorDark() = sheetDark("MemoEditor") {
        MemoEditorContent(
            memo = MemoEntity(
                title = "供应商电话",
                content = "王经理 13800001111，下周二前回电确认"
            ),
            onDismiss = {},
            onSave = { _, _, _ -> }
        )
    }

    // ---------- 配送需求 ----------

    @Test
    fun customerEditorLight() = sheetLight("CustomerEditor") {
        CustomerEditorContent(
            request = CustomerRequestEntity(
                customer = CustomerDeliveryStorage.encode(
                    CustomerDeliveryInfo(
                        deliveryTime = dueAt,
                        note = "到了打电话",
                        legacyCustomer = "清泉八街24号"
                    )
                ),
                roomOrAddress = "清泉八街24号",
                phone = "13800138000",
                content = "矿泉水2箱、啤酒10瓶"
            ),
            onDismiss = {},
            onSave = { _, _, _, _, _, _, _ -> }
        )
    }

    @Test
    fun customerEditorDark() = sheetDark("CustomerEditor") {
        CustomerEditorContent(
            request = CustomerRequestEntity(
                customer = CustomerDeliveryStorage.encode(
                    CustomerDeliveryInfo(
                        deliveryTime = dueAt,
                        note = "到了打电话",
                        legacyCustomer = "清泉八街24号"
                    )
                ),
                roomOrAddress = "清泉八街24号",
                phone = "13800138000",
                content = "矿泉水2箱、啤酒10瓶"
            ),
            onDismiss = {},
            onSave = { _, _, _, _, _, _, _ -> }
        )
    }

    // ---------- 临期商品 ----------

    @Test
    fun expiryEditorLight() = sheetLight("ExpiryEditor") {
        ExpiryEditorContent(
            item = ExpiryItemEntity(
                name = "纯牛奶 250ml",
                quantity = 12,
                expiryDate = expiryAt,
                remindDaysBefore = 7,
                note = "A 供应商批次"
            ),
            onDismiss = {},
            onSave = { _, _, _, _, _, _, _ -> }
        )
    }

    @Test
    fun expiryEditorDark() = sheetDark("ExpiryEditor") {
        ExpiryEditorContent(
            item = ExpiryItemEntity(
                name = "纯牛奶 250ml",
                quantity = 12,
                expiryDate = expiryAt,
                remindDaysBefore = 7,
                note = "A 供应商批次"
            ),
            onDismiss = {},
            onSave = { _, _, _, _, _, _, _ -> }
        )
    }

    // ---------- 商品 ----------

    @Test
    fun goodsEditorLight() = sheetLight("GoodsEditor") {
        GoodsEditorContent(
            mode = GoodsEditorMode.EDIT,
            goods = GoodsEntity(
                name = "可口可乐 330ml",
                category = GoodsCategory.DRINK,
                barcode = "6901234567890",
                stock = 48,
                minStock = 12,
                purchasePrice = 2.5,
                salePrice = 4.0,
                productionDate = prodAt,
                shelfLifeDays = 365,
                expiryDate = expiryAt,
                note = "畅销款"
            ),
            onDismiss = {},
            onSave = {}
        )
    }

    @Test
    fun goodsEditorDark() = sheetDark("GoodsEditor") {
        GoodsEditorContent(
            mode = GoodsEditorMode.EDIT,
            goods = GoodsEntity(
                name = "可口可乐 330ml",
                category = GoodsCategory.DRINK,
                barcode = "6901234567890",
                stock = 48,
                minStock = 12,
                purchasePrice = 2.5,
                salePrice = 4.0,
                productionDate = prodAt,
                shelfLifeDays = 365,
                expiryDate = expiryAt,
                note = "畅销款"
            ),
            onDismiss = {},
            onSave = {}
        )
    }

    // ---------- 记账 ----------

    @Test
    fun moneyEditorLight() = sheetLight("MoneyEditor") {
        MoneyEditorContent(
            mode = MoneyEditorMode.EDIT_PERFORMANCE,
            performance = PerformanceEntity(
                amount = 1280.5,
                note = "美团外卖",
                date = bizAt,
                incomeSource = "美团"
            ),
            onDismiss = {},
            onSave = { _, _, _, _, _ -> }
        )
    }

    @Test
    fun moneyEditorDark() = sheetDark("MoneyEditor") {
        MoneyEditorContent(
            mode = MoneyEditorMode.EDIT_PERFORMANCE,
            performance = PerformanceEntity(
                amount = 1280.5,
                note = "美团外卖",
                date = bizAt,
                incomeSource = "美团"
            ),
            onDismiss = {},
            onSave = { _, _, _, _, _ -> }
        )
    }

    // ---------- 语音面板 ----------

    @Test
    fun voicePanelLight() = sheetLight("VoicePanel") {
        VoiceSheetVisual(
            phase = VoicePhase.Preview,
            transcript = "今天美团680",
            draft = VoiceDraft(
                type = VoiceRecordType.REVENUE,
                title = "美团外卖",
                detail = "",
                amount = 680.0,
                dueAt = bizAt,
                expiryDays = null,
                customerName = null,
                quantity = null,
                goodsName = null,
                original = "今天美团680"
            ),
            didSave = false,
            speechAvailable = true,
            speechUnavailableHint = "当前设备未提供系统语音识别服务",
            manualText = "",
            onManualTextChange = {},
            onClose = {},
            onMicClick = {},
            onSubmitManual = {},
            onEnterTextFallback = {},
            onSetRecordType = {},
            onSave = {},
            performHaptic = {}
        )
    }

    @Test
    fun voicePanelDark() = sheetDark("VoicePanel") {
        VoiceSheetVisual(
            phase = VoicePhase.Preview,
            transcript = "今天美团680",
            draft = VoiceDraft(
                type = VoiceRecordType.REVENUE,
                title = "美团外卖",
                detail = "",
                amount = 680.0,
                dueAt = bizAt,
                expiryDays = null,
                customerName = null,
                quantity = null,
                goodsName = null,
                original = "今天美团680"
            ),
            didSave = false,
            speechAvailable = true,
            speechUnavailableHint = "当前设备未提供系统语音识别服务",
            manualText = "",
            onManualTextChange = {},
            onClose = {},
            onMicClick = {},
            onSubmitManual = {},
            onEnterTextFallback = {},
            onSetRecordType = {},
            onSave = {},
            performHaptic = {}
        )
    }

    // ---------- 快速记一笔 ----------

    @Test
    fun quickRecordLight() = sheetLight("QuickRecord") {
        val text = "今天美团680"
        QuickRecordSheetVisual(
            state = QuickRecordVisualState(
                text = text,
                draft = LocalQuickRecordParser.parse(text, nowMillis = bizAt),
                overriddenKind = null,
                savedMessage = null,
                errorMessage = null,
                saving = false,
                kindMenuOpen = false,
                voiceCard = null,
                canUseSpeech = true,
                isListening = false,
                canSave = true
            ),
            onDismiss = {},
            onTextChange = {},
            onKindMenuOpenChange = {},
            onKindOverride = {},
            onMicClick = {},
            onStopVoice = {},
            onCancelVoice = {},
            onSave = {}
        )
    }

    @Test
    fun quickRecordDark() = sheetDark("QuickRecord") {
        val text = "今天美团680"
        QuickRecordSheetVisual(
            state = QuickRecordVisualState(
                text = text,
                draft = LocalQuickRecordParser.parse(text, nowMillis = bizAt),
                overriddenKind = null,
                savedMessage = null,
                errorMessage = null,
                saving = false,
                kindMenuOpen = false,
                voiceCard = null,
                canUseSpeech = true,
                isListening = false,
                canSave = true
            ),
            onDismiss = {},
            onTextChange = {},
            onKindMenuOpenChange = {},
            onKindOverride = {},
            onMicClick = {},
            onStopVoice = {},
            onCancelVoice = {},
            onSave = {}
        )
    }

    // ---------- AI ActionCard ----------

    @Test
    fun aiActionCardLight() = pageLight("AIActionCard") {
        ActionCardColumn()
    }

    @Test
    fun aiActionCardDark() = pageDark("AIActionCard") {
        ActionCardColumn()
    }

    @Composable
    private fun ActionCardColumn() {
        val palettes = LocalXzgPalettes.current
        Column(
            modifier = Modifier
                .fillMaxSize()
                .background(palettes.background.pageBG)
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            ActionCardView(
                proposal = ActionProposal(
                    toolName = ToolName.RECORD_REVENUE,
                    argumentsJson = ToolArguments.Revenue(
                        RevenueArguments(amount = 680.0, source = "美团", note = "外卖到账")
                    ).encode(),
                    status = ProposalStatus.PENDING
                ),
                onConfirm = {},
                onRetry = {},
                onModify = {},
                onCancel = {}
            )
            ActionCardView(
                proposal = ActionProposal(
                    toolName = ToolName.RECORD_REVENUE,
                    argumentsJson = ToolArguments.Revenue(
                        RevenueArguments(amount = 680.0, source = "美团", note = "外卖到账")
                    ).encode(),
                    status = ProposalStatus.EXECUTED,
                    resultText = "已记录 ¥680.00（美团）"
                ),
                onConfirm = {},
                onRetry = {},
                onModify = {},
                onCancel = {}
            )
        }
    }
}

/** 仿真底部 Sheet 容器：遮罩 + 底部对齐 + 顶部圆角 + 小把手。 */
@Composable
private fun SheetFrame(content: @Composable () -> Unit) {
    val palettes = LocalXzgPalettes.current
    CompositionLocalProvider(LocalActivityResultRegistryOwner provides FakeRegistryOwner) {
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(Color.Black.copy(alpha = 0.45f))
        ) {
            Column(
                modifier = Modifier
                    .align(Alignment.BottomCenter)
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(topStart = XzgDimens.sheet, topEnd = XzgDimens.sheet))
                    .background(palettes.background.pageBG)
            ) {
                Box(
                    modifier = Modifier
                        .align(Alignment.CenterHorizontally)
                        .padding(top = 8.dp)
                        .size(width = 36.dp, height = 4.dp)
                        .clip(CircleShape)
                        .background(palettes.background.textQuaternary.copy(alpha = 0.55f))
                )
                content()
            }
        }
    }
}

/** Paparazzi 单测用的 no-op ActivityResultRegistryOwner（截图不触发真实选择）。 */
private object FakeRegistryOwner : ActivityResultRegistryOwner {
    private val owner = FakeLifecycleOwner()
    override val lifecycle: Lifecycle get() = owner.lifecycle
    override val activityResultRegistry: ActivityResultRegistry =
        object : ActivityResultRegistry() {
            override fun <I, O> onLaunch(
                requestCode: Int,
                contract: ActivityResultContract<I, O>,
                input: I,
                options: ActivityOptionsCompat?
            ) = Unit
        }
}

private class FakeLifecycleOwner : LifecycleOwner {
    private val registry = LifecycleRegistry(this)

    init {
        registry.handleLifecycleEvent(Lifecycle.Event.ON_RESUME)
    }

    override val lifecycle: Lifecycle get() = registry
}
