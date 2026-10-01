package com.xiaozhanggui.app.paparazzi

import com.xiaozhanggui.app.ui.screens.customer.CustomerContent
import com.xiaozhanggui.app.ui.screens.expiry.ExpiryContent
import com.xiaozhanggui.app.ui.screens.goods.GoodsContent
import com.xiaozhanggui.app.ui.screens.performance.PerformanceContent
import org.junit.Test

/** 页面截图：客户 / 临期 / 货品 / 经营数据（WorkerA）。 */
class BusinessScreenshotTest : XzgScreenshotTest() {

    @Test
    fun customerLight() = pageLight("Customer") {
        CustomerContent(requests = ScreenshotFixtures.customerRequests())
    }

    @Test
    fun customerDark() = pageDark("Customer") {
        CustomerContent(requests = ScreenshotFixtures.customerRequests())
    }

    @Test
    fun expiryLight() = pageLight("Expiry") {
        ExpiryContent(items = ScreenshotFixtures.expiryItems())
    }

    @Test
    fun expiryDark() = pageDark("Expiry") {
        ExpiryContent(items = ScreenshotFixtures.expiryItems())
    }

    @Test
    fun goodsLight() = pageLight("Goods") {
        GoodsContent(goods = ScreenshotFixtures.goods())
    }

    @Test
    fun goodsDark() = pageDark("Goods") {
        GoodsContent(goods = ScreenshotFixtures.goods())
    }

    @Test
    fun performanceLight() = pageLight("Performance") {
        PerformanceContent(
            performances = ScreenshotFixtures.performances(),
            expenses = ScreenshotFixtures.expenses()
        )
    }

    @Test
    fun performanceDark() = pageDark("Performance") {
        PerformanceContent(
            performances = ScreenshotFixtures.performances(),
            expenses = ScreenshotFixtures.expenses()
        )
    }
}
