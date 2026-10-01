package com.xiaozhanggui.app

import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.test.assertExists
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.xiaozhanggui.app.data.db.CustomerStatus
import com.xiaozhanggui.app.data.repository.CustomerRepository
import com.xiaozhanggui.app.ui.screens.customer.CustomerContent
import com.xiaozhanggui.app.ui.theme.XzgTheme
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/**
 * 客户需求状态推进测试（Phase 6 Worker A）：待处理 → 配送中 → 已完成。
 *
 * - 真实 [CustomerRepository] + 内存假 DAO + 空通知调度器；
 * - 直接测纯渲染 [CustomerContent]，onAdvance 经 Repository 落库后回流刷新 UI。
 */
@RunWith(AndroidJUnit4::class)
class CustomerStatusTest {

    @get:Rule
    val rule = createComposeRule()

    private lateinit var dao: FakeCustomerRequestDao
    private lateinit var repo: CustomerRepository

    @Before
    fun setup() {
        dao = FakeCustomerRequestDao()
        repo = CustomerRepository(dao, FakeNotifications)
    }

    @Composable
    private fun CustomerTestHarness(repository: CustomerRepository) {
        val requests by repository.observeAll().collectAsStateWithLifecycle(initialValue = emptyList())
        val scope = rememberCoroutineScope()
        CustomerContent(
            requests = requests,
            onAdvance = { request ->
                scope.launch { repository.advanceStatus(request) }
            }
        )
    }

    @Test
    fun customer_advanceStatus_pendingToDeliveringToDone() {
        runBlocking {
            repo.add(customer = "测试客户", content = "两箱可乐")
        }

        rule.setContent {
            XzgTheme { CustomerTestHarness(repo) }
        }

        // 初始：待处理
        rule.waitUntil(timeoutMillis = 5_000) {
            rule.onAllNodesWithText("测试客户").fetchSemanticsNodes().isNotEmpty()
        }
        rule.onNodeWithText(CustomerStatus.PENDING).assertExists()

        // 推进 → 配送中
        rule.onNodeWithContentDescription("推进").performClick()
        rule.waitUntil(timeoutMillis = 5_000) {
            dao.current.firstOrNull()?.status == CustomerStatus.DELIVERING
        }
        rule.onNodeWithText(CustomerStatus.DELIVERING).assertExists()

        // 推进 → 已完成（完成后推进钮消失）
        rule.onNodeWithContentDescription("推进").performClick()
        rule.waitUntil(timeoutMillis = 5_000) {
            dao.current.firstOrNull()?.status == CustomerStatus.DONE
        }
        rule.onNodeWithText(CustomerStatus.DONE).assertExists()
        assertEquals(CustomerStatus.DONE, dao.current.first().status)
    }
}
