package com.xiaozhanggui.app

import com.xiaozhanggui.app.ui.navigation.ColdStartPlan
import com.xiaozhanggui.app.ui.navigation.DeepLinkAction
import com.xiaozhanggui.app.ui.navigation.XzgDeepLink
import com.xiaozhanggui.app.ui.navigation.XzgTab
import com.xiaozhanggui.app.ui.navigation.planColdStart
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 冷启动三路测试（V3.7.1 Phase 2 导航 worker）。
 *
 * 覆盖 [planColdStart]（XzgNavGraph 冷启动决策的纯函数核心）：
 * 1. 正常启动（无深链 / Ignore）→ 首页 Tab，无 Sheet；
 * 2. 深链冷启动（xzg://ai / ai?mode=voice / todo / voice / quickrecord）→ 对应初始 Tab + Sheet；
 * 3. 进程恢复（同一 intent 重建）→ 决策幂等一致。
 *
 * V3.6 防回归：冷启动深链曾因在 NavHost setGraph 之前调 navigate() 崩溃
 *（`You must call setGraph() before calling getGraph()`）。
 * 当前设计以构造保证：plan 只决定 startDestination + sheet 标记，
 * Tab 类深链走 startDestination，Sheet 类走 setGraph 之后的 LaunchedEffect，
 * 不存在 setGraph 前 navigate() 的调用路径（见「sheet 深链不切换 Tab」用例）。
 */
class ColdStartPlanTest {

    // ---------- 1. 正常启动 ----------

    @Test
    fun `normal launch starts at home with no sheets`() {
        assertEquals(
            ColdStartPlan(startTab = XzgTab.HOME),
            planColdStart(null)
        )
    }

    @Test
    fun `ignored deep link starts at home with no sheets`() {
        assertEquals(
            ColdStartPlan(startTab = XzgTab.HOME),
            planColdStart(DeepLinkAction.Ignore)
        )
    }

    // ---------- 2. 深链冷启动 ----------

    @Test
    fun `ai deep link cold start opens ai sheet on home tab`() {
        val plan = planColdStart(DeepLinkAction.OpenAISheet)
        assertEquals(XzgTab.HOME, plan.startTab)
        assertTrue(plan.openAISheet)
        assertFalse(plan.aiVoiceDeepLink)
        assertFalse(plan.openVoiceSheet)
        assertFalse(plan.openQuickRecordSheet)
    }

    @Test
    fun `ai voice deep link cold start opens ai sheet with voice panel`() {
        val plan = planColdStart(DeepLinkAction.OpenAISheetVoice)
        assertEquals(XzgTab.HOME, plan.startTab)
        assertTrue(plan.openAISheet)
        assertTrue(plan.aiVoiceDeepLink)
        assertFalse(plan.openVoiceSheet)
    }

    @Test
    fun `todo deep link cold start starts at todo tab`() {
        val plan = planColdStart(DeepLinkAction.OpenTodoTab)
        assertEquals(XzgTab.TODO, plan.startTab)
        assertFalse(plan.openAISheet)
        assertFalse(plan.openVoiceSheet)
        assertFalse(plan.openQuickRecordSheet)
    }

    @Test
    fun `voice deep link cold start opens voice sheet on home tab`() {
        val plan = planColdStart(DeepLinkAction.OpenVoice)
        assertEquals(XzgTab.HOME, plan.startTab)
        assertTrue(plan.openVoiceSheet)
        assertFalse(plan.openAISheet)
    }

    @Test
    fun `quickrecord deep link cold start opens quick record sheet on home tab`() {
        val plan = planColdStart(DeepLinkAction.OpenQuickRecord)
        assertEquals(XzgTab.HOME, plan.startTab)
        assertTrue(plan.openQuickRecordSheet)
        assertFalse(plan.openAISheet)
    }

    // ---------- V3.6 冷启动崩溃防回归 ----------

    /**
     * 所有深链动作的 startTab 必须是四 Tab 之一。
     *
     * 回归含义：
     * - 若某动作映射到已删除的 assistant/profile Tab 路由，
     *   NavHost startDestination 会抛 IllegalArgumentException（未知路由）；
     * - 若走 LaunchedEffect navigate() 则复现 V3.6 的 setGraph 前崩溃。
     *
     * [planColdStart] 的 when 穷举保证新增动作在编译期即被处理，
     * 不会静默落入默认分支。
     */
    @Test
    fun `every deep link action resolves to one of the four tabs`() {
        val allActions = listOf(
            DeepLinkAction.OpenVoice,
            DeepLinkAction.OpenQuickRecord,
            DeepLinkAction.OpenAISheet,
            DeepLinkAction.OpenAISheetVoice,
            DeepLinkAction.OpenTodoTab,
            DeepLinkAction.Ignore,
        )
        val fourTabs = XzgTab.values().toSet()
        // 已删除的 Tab 路由：小掌柜 AI Tab 与「我的」Tab 不得再出现
        val removedRoutes = setOf("assistant", "profile")
        for (action in allActions) {
            val plan = planColdStart(action)
            assertTrue(
                "$action resolved to ${plan.startTab}, expected one of the four tabs",
                plan.startTab in fourTabs
            )
            assertFalse(
                "$action resolved to removed tab route ${plan.startTab.route}",
                plan.startTab.route in removedRoutes
            )
        }
        assertTrue(planColdStart(null).startTab in fourTabs)
    }

    @Test
    fun `sheet deep links never switch tabs`() {
        // Sheet 类深链恒定位首页 Tab + sheet 标记：不触发 navigate()，
        // 即 V3.6 崩溃（setGraph 前 navigate）的调用路径已不存在。
        listOf(
            DeepLinkAction.OpenAISheet,
            DeepLinkAction.OpenAISheetVoice,
            DeepLinkAction.OpenVoice,
            DeepLinkAction.OpenQuickRecord,
        ).forEach { action ->
            assertEquals(
                "sheet deep link $action must not switch tabs",
                XzgTab.HOME,
                planColdStart(action).startTab
            )
        }
    }

    // ---------- 3. 进程恢复 ----------

    /**
     * 进程恢复：MainActivity 重建时 intent.data 不变，XzgNavGraph 经 remember
     * 重新锁存同一 DeepLinkAction → 决策必须幂等一致，
     * 否则恢复后可能落在错误 Tab 或重复弹 Sheet。
     */
    @Test
    fun `process restore reproduces identical plan from same intent`() {
        val uris = listOf(
            "xzg://ai",
            "xzg://ai?mode=voice",
            "xzg://todo",
            "xzg://voice",
            "xzg://quickrecord",
        )
        for (uri in uris) {
            val freshProcess = planColdStart(XzgDeepLink.parse(uri))
            // 模拟进程被杀后恢复：同一 intent 重新解析、重新决策
            val restoredProcess = planColdStart(XzgDeepLink.parse(uri))
            assertEquals(
                "plan diverged after process restore for $uri",
                freshProcess,
                restoredProcess
            )
        }
    }

    @Test
    fun `parse then plan covers full cold start chain`() {
        assertEquals(
            ColdStartPlan(startTab = XzgTab.HOME, openAISheet = true),
            planColdStart(XzgDeepLink.parse("xzg://ai"))
        )
        assertEquals(
            ColdStartPlan(startTab = XzgTab.HOME, openAISheet = true, aiVoiceDeepLink = true),
            planColdStart(XzgDeepLink.parse("xzg://ai?mode=voice"))
        )
        assertEquals(
            ColdStartPlan(startTab = XzgTab.TODO),
            planColdStart(XzgDeepLink.parse("xzg://todo"))
        )
    }
}
