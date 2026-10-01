package com.xiaozhanggui.app.ui.theme

import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.sp

/**
 * V32 字阶。对应 iOS `DesignSystem/V32/V32Font.swift`。
 *
 * iOS 侧中文走系统字体、数字用 SF Rounded + 等宽数字（.monospacedDigit()）。
 * Android 等价：系统默认字体 + 数字样式加 `fontFeatureSettings = "tnum"`
 *（tabular figures），保证金额/指标数字等宽对齐。
 */
object XzgType {
    /** 38 bold，Hero 金额数字（等宽） */
    val heroMoney = TextStyle(
        fontSize = 38.sp,
        fontWeight = FontWeight.Bold,
        fontFamily = FontFamily.Default,
        fontFeatureSettings = "tnum"
    )

    /** 22 bold，指标数字（等宽） */
    val metric = TextStyle(
        fontSize = 22.sp,
        fontWeight = FontWeight.Bold,
        fontFamily = FontFamily.Default,
        fontFeatureSettings = "tnum"
    )

    /** 15 semibold，小指标数字（等宽） */
    val metricSmall = TextStyle(
        fontSize = 15.sp,
        fontWeight = FontWeight.SemiBold,
        fontFamily = FontFamily.Default,
        fontFeatureSettings = "tnum"
    )

    /** 32 bold */
    val display = TextStyle(fontSize = 32.sp, fontWeight = FontWeight.Bold)

    /** 26 bold，二级页头 */
    val pageTitle = TextStyle(fontSize = 26.sp, fontWeight = FontWeight.Bold)

    /** 20 bold，区块标题 */
    val section = TextStyle(fontSize = 20.sp, fontWeight = FontWeight.Bold)

    /** 16 semibold */
    val headline = TextStyle(fontSize = 16.sp, fontWeight = FontWeight.SemiBold)

    /** 15 semibold */
    val title = TextStyle(fontSize = 15.sp, fontWeight = FontWeight.SemiBold)

    /** 15 regular，正文 */
    val body = TextStyle(fontSize = 15.sp, fontWeight = FontWeight.Normal)

    /** 13 regular，次要文本 */
    val subhead = TextStyle(fontSize = 13.sp, fontWeight = FontWeight.Normal)

    /** 12 regular，说明文本 */
    val caption = TextStyle(fontSize = 12.sp, fontWeight = FontWeight.Normal)

    /** 11 semibold，胶囊/状态文本 */
    val pill = TextStyle(fontSize = 11.sp, fontWeight = FontWeight.SemiBold)
}
