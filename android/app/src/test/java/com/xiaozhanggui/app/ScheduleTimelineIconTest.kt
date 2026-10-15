package com.xiaozhanggui.app

import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.outlined.Circle
import com.xiaozhanggui.app.ui.components.BubbleTone
import com.xiaozhanggui.app.ui.screens.schedule.timelineTodoIconTone
import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * P0-1 回归：日程时间轴 Todo 行的图标/语气必须跟随完成态。
 *
 * iOS 证据（`ScheduleView.swift:281-282`）：
 * 完成=`checkmark.circle.fill`+`V371.Colors.green`，未完成=`circle`+`V371.Colors.blue`。
 * Android 映射：完成=填充 CheckCircle + BRAND（V371 绿），未完成=空心 Circle + INFO（V371 蓝）。
 *
 * 红绿验证：把 [timelineTodoIconTone] 改回修复前硬编码
 * （`Icons.Filled.CheckCircle to BubbleTone.BRAND` 不看参数），
 * `uncompleted todo uses hollow circle with info blue tone` 必失败（红）；
 * 恢复后两用例通过（绿）。
 */
class ScheduleTimelineIconTest {

    @Test
    fun `completed todo uses filled check circle with brand green tone`() {
        val (icon, tone) = timelineTodoIconTone(isCompleted = true)
        assertEquals(Icons.Filled.CheckCircle, icon)
        assertEquals(BubbleTone.BRAND, tone)
    }

    @Test
    fun `uncompleted todo uses hollow circle with info blue tone`() {
        val (icon, tone) = timelineTodoIconTone(isCompleted = false)
        assertEquals(Icons.Outlined.Circle, icon)
        assertEquals(BubbleTone.INFO, tone)
    }
}
