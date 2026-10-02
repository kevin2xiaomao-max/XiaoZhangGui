package com.xiaozhanggui.app.domain

import com.xiaozhanggui.app.data.db.MemoEntity

/** 备忘筛选，对应 iOS MemoFilter：全部 / 文字（无图）/ 图片（有图）/ 语音（恒为空）。 */
enum class MemoFilterTab(val label: String) {
    ALL("全部"),
    TEXT("文字"),
    IMAGE("图片"),
    VOICE("语音")
}

/**
 * 搜索 + 筛选（纯函数，可单测）。对应 iOS MemoSearch.filtered：
 * 标题/内容大小写不敏感匹配；语音恒为空；结果按 updatedAt 倒序（DAO 层已排，此处保持输入顺序）。
 */
fun filterMemos(
    memos: List<MemoEntity>,
    query: String,
    filter: MemoFilterTab
): List<MemoEntity> {
    val q = query.trim()
    return memos.filter { memo ->
        val passFilter = when (filter) {
            MemoFilterTab.ALL -> true
            MemoFilterTab.TEXT -> memo.imagePath.isNullOrBlank()
            MemoFilterTab.IMAGE -> !memo.imagePath.isNullOrBlank()
            MemoFilterTab.VOICE -> false
        }
        val passQuery = q.isEmpty() ||
            memo.title.contains(q, ignoreCase = true) ||
            memo.content.contains(q, ignoreCase = true)
        passFilter && passQuery
    }
}
