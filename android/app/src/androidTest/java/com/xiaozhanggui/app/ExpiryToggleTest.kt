package com.xiaozhanggui.app

import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.assertCountEquals
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.xiaozhanggui.app.data.db.ReturnStatus
import com.xiaozhanggui.app.data.repository.ExpiryRepository
import com.xiaozhanggui.app.ui.screens.expiry.ExpiryContent
import com.xiaozhanggui.app.ui.theme.XzgTheme
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/**
 * 临期退货切换测试（Phase 6 Worker A）：退货 ⇄ 恢复。
 *
 * - 真实 [ExpiryRepository] + 内存假 DAO + 空通知调度器；
 * - 直接测纯渲染 [ExpiryContent]，onToggleReturn 经 Repository 落库后回流刷新 UI。
 */
@RunWith(AndroidJUnit4::class)
class ExpiryToggleTest {

    @get:Rule
    val rule = createComposeRule()

    private lateinit var dao: FakeExpiryItemDao
    private lateinit var repo: ExpiryRepository

    @Before
    fun setup() {
        dao = FakeExpiryItemDao()
        repo = ExpiryRepository(dao, FakeNotifications)
    }

    @Composable
    private fun ExpiryTestHarness(repository: ExpiryRepository) {
        val items by repository.observeAll().collectAsStateWithLifecycle(initialValue = emptyList())
        val scope = rememberCoroutineScope()
        ExpiryContent(
            items = items,
            onToggleReturn = { item ->
                scope.launch { repository.toggleReturn(item) }
            }
        )
    }

    @Test
    fun expiry_toggleReturn_returnAndRestore() {
        // 2 天后到期 → 落在「紧急·3天内」分组
        runBlocking {
            repo.add(
                name = "可乐",
                quantity = 2,
                expiryDate = System.currentTimeMillis() + 2 * 24 * 3600 * 1000L
            )
        }

        rule.setContent {
            XzgTheme { ExpiryTestHarness(repo) }
        }

        rule.waitUntil(timeoutMillis = 5_000) {
            rule.onAllNodesWithText("可乐 ×2").fetchSemanticsNodes().isNotEmpty()
        }
        // 初始待处理：退货按钮可见
        rule.onNodeWithText("退货").assertExists()

        // 退货 → 已退货徽标。"已退货"有 2 处（分组标题 + 卡片徽标），
        // 用计数断言同时覆盖两者，避免 onNodeWithText 的歧义失败。
        rule.onNodeWithText("退货").performClick()
        rule.waitUntil(timeoutMillis = 5_000) {
            dao.current.firstOrNull()?.returnStatus == ReturnStatus.RETURNED
        }
        rule.onAllNodesWithText("已退货").assertCountEquals(2)
        rule.onNodeWithText("恢复").assertExists()

        // 恢复 → 回到待处理
        rule.onNodeWithText("恢复").performClick()
        rule.waitUntil(timeoutMillis = 5_000) {
            val item = dao.current.firstOrNull()
            item?.returnStatus == ReturnStatus.PENDING && item.returnedAt == null
        }
        // 徽标与分组标题一并消失
        rule.onAllNodesWithText("已退货").assertCountEquals(0)
        rule.onNodeWithText("退货").assertExists()
        assertEquals(ReturnStatus.PENDING, dao.current.first().returnStatus)
        assertNull(dao.current.first().returnedAt)
    }
}
