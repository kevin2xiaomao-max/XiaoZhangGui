package com.xiaozhanggui.app.paparazzi

import com.xiaozhanggui.app.ui.screens.home.HomeContent
import com.xiaozhanggui.app.ui.screens.todo.MemoContent
import com.xiaozhanggui.app.ui.screens.todo.TodoContent
import org.junit.Test

/**
 * 页面截图：首页 / 待办 / 备忘（WorkerA）。
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
            onOpenProfile = {},
            onOpenAI = {},
            onOpenQuickRecord = {},
            onWeatherClick = {}
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
            onOpenProfile = {},
            onOpenAI = {},
            onOpenQuickRecord = {},
            onWeatherClick = {}
        )
    }

    @Test
    fun todoLight() = pageLight("Todo") {
        TodoContent(
            todos = ScreenshotFixtures.todos()
        )
    }

    @Test
    fun todoDark() = pageDark("Todo") {
        TodoContent(
            todos = ScreenshotFixtures.todos()
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
