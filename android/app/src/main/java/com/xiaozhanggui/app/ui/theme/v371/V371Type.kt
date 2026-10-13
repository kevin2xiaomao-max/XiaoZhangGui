package com.xiaozhanggui.app.ui.theme.v371

import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.sp

/**
 * V371 Typography（对应 iOS `V371.Typography`）。
 *
 * 层级靠 size/weight/spacing；等宽数字用 tnum。
 * 已知视觉差异：iOS heroNumber 用 `.rounded` 圆体设计；Android 无系统圆体，
 * 用默认字体 + Bold + tnum 近似。
 */
object V371Type {
    /** Hero 大数字：44 bold 等宽 */
    val heroNumber = TextStyle(
        fontSize = 44.sp,
        fontWeight = FontWeight.Bold,
        fontFeatureSettings = "tnum"
    )

    /** Hero 标题：15 semibold */
    val heroTitle = TextStyle(fontSize = 15.sp, fontWeight = FontWeight.SemiBold)

    /** Section 标题：17 semibold */
    val sectionTitle = TextStyle(fontSize = 17.sp, fontWeight = FontWeight.SemiBold)

    /** 行标题：16 medium */
    val rowTitle = TextStyle(fontSize = 16.sp, fontWeight = FontWeight.Medium)

    /** 行副标题：13 regular */
    val rowSubtitle = TextStyle(fontSize = 13.sp, fontWeight = FontWeight.Normal)

    /** 时间列：13 semibold 等宽 */
    val time = TextStyle(
        fontSize = 13.sp,
        fontWeight = FontWeight.SemiBold,
        fontFeatureSettings = "tnum"
    )

    /** Badge：12 semibold */
    val badge = TextStyle(fontSize = 12.sp, fontWeight = FontWeight.SemiBold)

    /** 快捷入口 label：12 medium */
    val quickAction = TextStyle(fontSize = 12.sp, fontWeight = FontWeight.Medium)
}
