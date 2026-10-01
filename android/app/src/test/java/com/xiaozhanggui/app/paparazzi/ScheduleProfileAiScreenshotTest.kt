package com.xiaozhanggui.app.paparazzi

import com.xiaozhanggui.app.ui.screens.ai.AIChatContent
import com.xiaozhanggui.app.ui.screens.profile.ProfileContent
import com.xiaozhanggui.app.ui.screens.schedule.CalendarContent
import com.xiaozhanggui.app.ui.screens.schedule.ScheduleContent
import org.junit.Test

/** 页面截图：日程 / 日历 / 我的 / 小掌柜 AI（WorkerA）。 */
class ScheduleProfileAiScreenshotTest : XzgScreenshotTest() {

    @Test
    fun scheduleLight() = pageLight("Schedule") {
        ScheduleContent(
            selectedDayMillis = ScreenshotFixtures.todayStart(),
            day = ScreenshotFixtures.scheduleDay()
        )
    }

    @Test
    fun scheduleDark() = pageDark("Schedule") {
        ScheduleContent(
            selectedDayMillis = ScreenshotFixtures.todayStart(),
            day = ScreenshotFixtures.scheduleDay()
        )
    }

    @Test
    fun calendarLight() = pageLight("Calendar") {
        CalendarContent(
            monthMillis = ScreenshotFixtures.monthStart(),
            selectedDayMillis = ScreenshotFixtures.todayStart(),
            flags = ScreenshotFixtures.calendarFlags(),
            data = ScreenshotFixtures.calendarDayData()
        )
    }

    @Test
    fun calendarDark() = pageDark("Calendar") {
        CalendarContent(
            monthMillis = ScreenshotFixtures.monthStart(),
            selectedDayMillis = ScreenshotFixtures.todayStart(),
            flags = ScreenshotFixtures.calendarFlags(),
            data = ScreenshotFixtures.calendarDayData()
        )
    }

    @Test
    fun profileLight() = pageLight("Profile") {
        ProfileContent(
            shopName = "天福便利店",
            ownerName = "王掌柜",
            monthGoal = 120000.0,
            themeModeLabel = "跟随系统",
            accentLabel = "品牌绿",
            backgroundLabel = "默认",
            wallpaperEnabled = false,
            reminderEnabled = true,
            demoMode = false,
            versionName = "3.6.0"
        )
    }

    @Test
    fun profileDark() = pageDark("Profile") {
        ProfileContent(
            shopName = "天福便利店",
            ownerName = "王掌柜",
            monthGoal = 120000.0,
            themeModeLabel = "跟随系统",
            accentLabel = "品牌绿",
            backgroundLabel = "默认",
            wallpaperEnabled = false,
            reminderEnabled = true,
            demoMode = false,
            versionName = "3.6.0"
        )
    }

    @Test
    fun aiChatLight() = pageLight("AIChat") {
        AIChatContent(
            messages = ScreenshotFixtures.aiMessages(),
            proposals = listOf(ScreenshotFixtures.aiProposal()),
            isProcessing = false,
            processingLabel = "",
            isRemoteConfigured = true,
            ready = true,
            inputText = ""
        )
    }

    @Test
    fun aiChatDark() = pageDark("AIChat") {
        AIChatContent(
            messages = ScreenshotFixtures.aiMessages(),
            proposals = listOf(ScreenshotFixtures.aiProposal()),
            isProcessing = false,
            processingLabel = "",
            isRemoteConfigured = true,
            ready = true,
            inputText = ""
        )
    }
}
