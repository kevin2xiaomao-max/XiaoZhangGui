package com.xiaozhanggui.app.ui.screens.paymentcode

import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json

/** 收款码类型（对应 iOS PaymentCodeKind）。 */
enum class PaymentCodeKind(val displayName: String) {
    WECHAT("微信"),
    ALIPAY("支付宝"),
    CUSTOM("自定义");

    companion object {
        fun from(raw: String): PaymentCodeKind =
            values().find { it.name.equals(raw, ignoreCase = true) } ?: CUSTOM
    }
}

/** 收款码 metadata 行（对应 iOS PaymentCodeMetadata，仅存轻量字段）。 */
@Serializable
data class PaymentCodeMeta(
    val id: String,
    val name: String,
    val kind: String,
    val fileName: String,
    val order: Int,
    val createdAt: Long,
)

/** 收款码领域模型。 */
data class PaymentCode(
    val id: String,
    val name: String,
    val kind: PaymentCodeKind,
    val fileName: String,
    val order: Int,
    val createdAt: Long,
) {
    /** 名称为空时回退为类型名（对应 iOS PaymentCodeStore.resolvedName）。 */
    fun resolvedName(): String = name.ifBlank { kind.displayName }

    fun toMeta() = PaymentCodeMeta(
        id = id,
        name = name,
        kind = kind.name,
        fileName = fileName,
        order = order,
        createdAt = createdAt
    )
}

internal fun PaymentCodeMeta.toCode(): PaymentCode? =
    try {
        PaymentCode(
            id = id,
            name = name,
            kind = PaymentCodeKind.from(kind),
            fileName = fileName,
            order = order,
            createdAt = createdAt
        )
    } catch (_: Exception) {
        null
    }

internal val paymentCodeJson = Json { ignoreUnknownKeys = true }
