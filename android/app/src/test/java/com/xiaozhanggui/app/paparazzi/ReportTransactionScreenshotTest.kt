package com.xiaozhanggui.app.paparazzi

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import com.xiaozhanggui.app.data.db.CustomerRequestEntity
import com.xiaozhanggui.app.data.db.CustomerStatus
import com.xiaozhanggui.app.data.db.ExpenseCategory
import com.xiaozhanggui.app.data.db.ExpenseEntity
import com.xiaozhanggui.app.data.db.ExpiryItemEntity
import com.xiaozhanggui.app.data.db.PerformanceEntity
import com.xiaozhanggui.app.data.db.ReturnStatus
import com.xiaozhanggui.app.data.db.TodoEntity
import com.xiaozhanggui.app.ui.screens.home.DailyReport
import com.xiaozhanggui.app.ui.screens.home.DailyReportContent
import com.xiaozhanggui.app.ui.screens.performance.TransactionHistoryContent
import com.xiaozhanggui.app.ui.theme.LocalXzgPalettes
import com.xiaozhanggui.app.ui.theme.XzgDimens
import org.junit.After
import org.junit.Before
import org.junit.Test
import java.time.ZoneOffset
import java.time.ZonedDateTime
import java.util.TimeZone

/**
 * Phase 4 验收修复轮 Worker B：
 * - R15 DailyReport：经营日报纯内容 Paparazzi 截图（Light/Dark）
 * - R18 Transaction：全部交易页 Paparazzi 截图（Light/Dark）
 *
 * 时间全部固定 UTC（@Before/@After 锁定默认时区，保证 CI 渲染确定性；
 * 黄金图由 CI `recordPaparazziDebug` 录制后在同 run 内 verify）。
 */
class ReportTransactionScreenshotTest : XzgScreenshotTest() {

    private val now: Long =
        ZonedDateTime.of(2026, 10, 3, 12, 0, 0, 0, ZoneOffset.UTC).toInstant().toEpochMilli()

    private var savedTz: TimeZone? = null

    @Before
    fun lockUtc() {
        savedTz = TimeZone.getDefault()
        TimeZone.setDefault(TimeZone.getTimeZone("UTC"))
    }

    @After
    fun restoreTz() {
        savedTz?.let { TimeZone.setDefault(it) }
    }

    // ---------- R15：今日经营日报 ----------

    private fun fakeReport(): DailyReport = DailyReport.build(
        now,
        performances = listOf(
            PerformanceEntity(
                id = "p-today-1",
                amount = 680.0,
                note = "美团外卖",
                date = now - 2 * 3600 * 1000L,
                incomeSource = "美团"
            ),
            PerformanceEntity(
                id = "p-today-2",
                amount = 320.5,
                note = "门店现金",
                date = now - 4 * 3600 * 1000L,
                incomeSource = "门店"
            ),
            PerformanceEntity(
                id = "p-yesterday-1",
                amount = 800.0,
                note = "昨日营业",
                date = now - 26 * 3600 * 1000L,
                incomeSource = "美团"
            )
        ),
        todos = listOf(
            TodoEntity(
                id = "t-done-1",
                title = "盘点饮料冰柜",
                isCompleted = true,
                completedAt = now - 3 * 3600 * 1000L
            ),
            TodoEntity(
                id = "t-done-2",
                title = "交上月水电费",
                isCompleted = true,
                completedAt = now - 5 * 3600 * 1000L
            ),
            TodoEntity(
                id = "t-todo-1",
                title = "联系饮料供应商",
                isCompleted = false,
                dueDate = now + 2 * 3600 * 1000L
            )
        ),
        customers = listOf(
            CustomerRequestEntity(
                id = "c-1",
                content = "矿泉水2箱",
                status = CustomerStatus.PENDING
            ),
            CustomerRequestEntity(
                id = "c-2",
                content = "啤酒10瓶",
                status = CustomerStatus.DONE
            )
        ),
        expiryItems = listOf(
            ExpiryItemEntity(
                id = "e-1",
                name = "纯牛奶 250ml",
                quantity = 12,
                expiryDate = now + 5 * 24 * 3600 * 1000L,
                returnStatus = ReturnStatus.PENDING
            ),
            ExpiryItemEntity(
                id = "e-2",
                name = "面包",
                quantity = 3,
                expiryDate = now - 24 * 3600 * 1000L,
                returnStatus = ReturnStatus.RETURNED
            )
        )
    )

    @Test
    fun dailyReportLight() = pageLight("DailyReport") {
        BottomSheetFrame {
            DailyReportContent(
                report = fakeReport(),
                onDismiss = {},
                onCopyText = {},
                onShareText = {}
            )
        }
    }

    @Test
    fun dailyReportDark() = pageDark("DailyReport") {
        BottomSheetFrame {
            DailyReportContent(
                report = fakeReport(),
                onDismiss = {},
                onCopyText = {},
                onShareText = {}
            )
        }
    }

    // ---------- R18：全部交易 ----------

    private fun fakePerformances() = listOf(
        PerformanceEntity(
            id = "p-1",
            amount = 680.0,
            note = "美团外卖到账",
            date = now,
            incomeSource = "美团"
        ),
        PerformanceEntity(
            id = "p-2",
            amount = 120.5,
            note = "门店现金",
            date = now - 24 * 3600 * 1000L,
            incomeSource = "门店"
        )
    )

    private fun fakeExpenses() = listOf(
        ExpenseEntity(
            id = "e-1",
            amount = 120.0,
            category = ExpenseCategory.STOCK,
            note = "进货",
            date = now - 3600 * 1000L
        )
    )

    @Test
    fun transactionHistoryLight() = pageLight("TransactionHistory") {
        TransactionHistoryContent(
            performances = fakePerformances(),
            expenses = fakeExpenses(),
            onBack = {}
        )
    }

    @Test
    fun transactionHistoryDark() = pageDark("TransactionHistory") {
        TransactionHistoryContent(
            performances = fakePerformances(),
            expenses = fakeExpenses(),
            onBack = {}
        )
    }
}

/** 仿真底部 Sheet 容器：遮罩 + 底部对齐 + 顶部圆角 + 小把手（同 SheetScreenshotTest 约定）。 */
@Composable
private fun BottomSheetFrame(content: @Composable () -> Unit) {
    val palettes = LocalXzgPalettes.current
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
