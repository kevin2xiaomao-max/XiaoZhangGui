package com.xiaozhanggui.app.domain

/**
 * 交易记录搜索（纯函数，可单测）。对应 iOS TransactionHistoryView 的搜索逻辑：
 * 标题 / 来源大小写不敏感匹配；空 query 返回全部（调用方负责按日期倒序）。
 */
interface TransactionSearchable {
    val title: String
    val source: String
}

fun <T : TransactionSearchable> filterTransactions(
    records: List<T>,
    query: String
): List<T> {
    val q = query.trim().lowercase()
    if (q.isEmpty()) return records
    return records.filter {
        it.title.lowercase().contains(q) || it.source.lowercase().contains(q)
    }
}
