package com.xiaozhanggui.app.domain

import com.xiaozhanggui.app.data.db.GoodsEntity

/** 商品状态：已过期 > 即将到期(7天) > 库存不足(stock<=minStock) > 正常。对应 iOS GoodsState。 */
enum class GoodsState(val label: String) {
    EXPIRED("已过期"),
    EXPIRING_SOON("即将到期"),
    LOW_STOCK("库存不足"),
    NORMAL("正常")
}

private const val SEVEN_DAYS_MS = 7L * 24 * 3600 * 1000

/**
 * 商品状态判定（纯函数，可单测）。判定优先级与 iOS GoodsView 一致：
 * 已过期 > 即将到期(7天内) > 库存不足 > 正常。
 */
fun goodsStateOf(g: GoodsEntity, now: Long): GoodsState {
    val expiry = g.expiryDate
    if (expiry != null) {
        if (expiry < now) return GoodsState.EXPIRED
        if (expiry <= now + SEVEN_DAYS_MS) return GoodsState.EXPIRING_SOON
    }
    if (g.stock <= g.minStock) return GoodsState.LOW_STOCK
    return GoodsState.NORMAL
}

/** 商品编辑器校验：名称必填（对应 iOS GoodsEditorSheet 的保存启用条件）。 */
fun isGoodsNameValid(name: String): Boolean = name.trim().isNotEmpty()
