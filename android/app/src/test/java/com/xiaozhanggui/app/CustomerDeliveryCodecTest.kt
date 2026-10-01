package com.xiaozhanggui.app

import com.xiaozhanggui.app.domain.CustomerDeliveryInfo
import com.xiaozhanggui.app.domain.CustomerDeliveryStorage
import com.xiaozhanggui.app.domain.DisplayLogic
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * GATE C #2：Customer `xzg-delivery-v1` 编解码 round-trip，编码串不得出现在 UI。
 */
class CustomerDeliveryCodecTest {

    @Test
    fun `encode decode round trip preserves deliveryTime and note`() {
        val info = CustomerDeliveryInfo(
            deliveryTime = 1_700_000_000_000L,
            note = "尽快配送",
            legacyCustomer = "王五"
        )
        val encoded = CustomerDeliveryStorage.encode(info)
        assertTrue(encoded.startsWith("xzg-delivery-v1:"))
        val decoded = CustomerDeliveryStorage.decode(encoded)
        assertEquals(1_700_000_000_000L, decoded.deliveryTime)
        assertEquals("尽快配送", decoded.note)
        assertEquals("王五", decoded.legacyCustomer)
    }

    @Test
    fun `legacy plaintext decodes to legacyCustomer`() {
        val decoded = CustomerDeliveryStorage.decode("张三")
        assertEquals("张三", decoded.legacyCustomer)
        assertNull(decoded.deliveryTime)
    }

    @Test
    fun `corrupt encoded string does not crash`() {
        val decoded = CustomerDeliveryStorage.decode("xzg-delivery-v1:!!!not-base64!!!")
        // 不抛异常，返回空信息
        assertNull(decoded.deliveryTime)
    }

    @Test
    fun `displayCustomerName never shows encoded string`() {
        val info = CustomerDeliveryInfo(deliveryTime = 1_700_000_000_000L, legacyCustomer = "李四")
        val encoded = CustomerDeliveryStorage.encode(info)
        // UI 层：解码得 fallback 客户名，visible() 隐藏编码串
        val display = DisplayLogic.visible(encoded, info.legacyCustomer.ifBlank { "客户" })
        assertEquals("李四", display)
        assertFalse(display.contains("xzg-delivery-v1"))
    }

    @Test
    fun `displayCustomerName falls back to legacy plaintext`() {
        assertEquals("赵六", DisplayLogic.visible("赵六", "客户"))
    }

    @Test
    fun `resolveDeliveryInfo preserves encoded round trip`() {
        val encoded = CustomerDeliveryStorage.encode(
            CustomerDeliveryInfo(note = "放门口", legacyCustomer = "钱七")
        )
        // 解码再编码得到相同存储串（Calendar 按 deliveryTime 聚合用 decode）
        val decoded = CustomerDeliveryStorage.decode(encoded)
        assertEquals(encoded, CustomerDeliveryStorage.encode(decoded))
    }
}
