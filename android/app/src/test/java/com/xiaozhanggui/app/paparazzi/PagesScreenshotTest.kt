package com.xiaozhanggui.app.paparazzi

import com.xiaozhanggui.app.ui.screens.home.HomeContent
import com.xiaozhanggui.app.ui.screens.todo.MemoContent
import com.xiaozhanggui.app.ui.screens.todo.TodoContent
import org.junit.Test

/**
 * 页面截图：首页 / 待办 / 备忘（WorkerA）。
 * 入场动画关闭（Paparazzi 不推进动画时钟，动画初态透明会导致截图空白）。
 */
class PagesScreenshotTest : XzgScreenshotTest() {

    @Test
    fun homeLight() = pageLight("Home") {
        HomeContent(
            state = ScreenshotFixtures.homeState(),
            onOpenPerformance = {},
            onOpenTodoTab = {},
            onOpenCustomer = {},
            onOpenExpiry = {},
            onOpenMemo = {},
            onOpenDrawer = {},
            onOpenQuickRecord = {},
            onToggleTodo = {},
            onWeatherClick = {},
            animateEntrance = false
        )
    }

    @Test
    fun homeDark() = pageDark("Home") {
        HomeContent(
            state = ScreenshotFixtures.homeState(),
            onOpenPerformance = {},
            onOpenTodoTab = {},
            onOpenCustomer = {},
            onOpenExpiry = {},
            onOpenMemo = {},
            onOpenDrawer = {},
            onOpenQuickRecord = {},
            onToggleTodo = {},
            onWeatherClick = {},
            animateEntrance = false
        )
    }

    @Test
    fun todoLight() = pageLight("Todo") {
        TodoContent(
            todos = ScreenshotFixtures.todos(),
            memos = ScreenshotFixtures.memos()
        )
    }

    @Test
    fun todoDark() = pageDark("Todo") {
        TodoContent(
            todos = ScreenshotFixtures.todos(),
            memos = ScreenshotFixtures.memos()
        )
    }

    @Test
    fun memoLight() = pageLight("Memo") {
        MemoContent(memos = ScreenshotFixtures.memos())
    }

    @Test
    fun memoDark() = pageDark("Memo") {
        MemoContent(memos = ScreenshotFixtures.memos())
    }
}
