package com.xiaozhanggui.app.domain

import kotlinx.serialization.Serializable
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import java.nio.charset.StandardCharsets
import java.util.Base64

/**
 * 客户配送信息编解码。对应 iOS CustomerDeliveryStorage
 *（Features/Customer/CustomerEditorSheet.swift:198-226）。
 *
 * 格式：`xzg-delivery-v1:<base64(JSON)>`，JSON 含 deliveryTime / note / legacyCustomer。
 * UI 层必须隐藏编码串（见 DisplayLogic.isEncoded）。
 */
@Serializable
data class CustomerDeliveryInfo(
    /** 配送时间 epoch millis；null = 无 */
    val deliveryTime: Long? = null,
    val note: String = "",
    /** 纯旧数据的明文客户名 */
    val legacyCustomer: String = ""
)

object CustomerDeliveryStorage {
    const val PREFIX = "xzg-delivery-v1:"

    private val json = Json { ignoreUnknownKeys = true }

    /** 编码为存储串 */
    fun encode(info: CustomerDeliveryInfo): String {
        val payload = Base64.getEncoder().encodeToString(
            json.encodeToString(info).toByteArray(StandardCharsets.UTF_8)
        )
        return PREFIX + payload
    }

    /**
     * 解码存储串。
     * - 非编码串（纯旧数据明文客户名）→ CustomerDeliveryInfo(legacyCustomer=原文)
     * - 编码串但解析失败 → legacyCustomer="" 的空信息（不抛异常，保证 UI 不崩）
     */
    fun decode(stored: String): CustomerDeliveryInfo {
        if (!stored.startsWith(PREFIX)) {
            return CustomerDeliveryInfo(legacyCustomer = stored)
        }
        return try {
            val payload = stored.removePrefix(PREFIX)
            val bytes = Base64.getDecoder().decode(payload)
            json.decodeFromString<CustomerDeliveryInfo>(String(bytes, StandardCharsets.UTF_8))
        } catch (e: Exception) {
            CustomerDeliveryInfo()
        }
    }

    /** 是否为编码串 */
    fun isEncoded(stored: String): Boolean = stored.startsWith(PREFIX)
}
