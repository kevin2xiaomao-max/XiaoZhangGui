package com.xiaozhanggui.app.ui.theme.v371

/**
 * V371 无障碍 / 自动化标识（对应 iOS `DesignSystem/V371/V371AccessibilityID.swift`）。
 *
 * 独立于本地化文案，保持稳定，供 UI 自动化与无障碍检查使用。
 * `HERO_REVENUE` 为 V3.6 预埋的 testTag，保持兼容（E2E 依赖）。
 */
object V371TestTags {
    const val SCREEN_HOME = "screen.home"
    const val SCREEN_TODO = "screen.todo"
    const val SCREEN_CALENDAR = "screen.calendar"
    const val SCREEN_BUSINESS = "screen.business"
    const val SCREEN_PROFILE = "screen.profile"

    const val TAB_HOME = "tab.home"
    const val TAB_TODO = "tab.todo"
    const val TAB_CALENDAR = "tab.calendar"
    const val TAB_BUSINESS = "tab.business"

    const val HOME_QUICK_RECORD = "home.quickRecord"
    const val HOME_PROFILE = "home.profile"
    const val HOME_AI = "home.ai"
    const val HOME_CUSTOMER = "home.customer"
    const val HOME_EXPIRY = "home.expiry"
    const val HERO_REVENUE = "home.heroRevenue"

    const val SCROLL_END_HOME = "scrollEnd.home"
}
