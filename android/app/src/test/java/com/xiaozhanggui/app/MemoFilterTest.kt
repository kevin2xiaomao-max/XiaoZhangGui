package com.xiaozhanggui.app

import com.xiaozhanggui.app.data.db.MemoEntity
import com.xiaozhanggui.app.domain.MemoFilterTab
import com.xiaozhanggui.app.domain.filterMemos
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 备忘搜索+筛选回归测试。对应 iOS MemoSearch.filtered：
 * 标题/内容大小写不敏感匹配；语音 tab 恒为空；筛选保持输入顺序（DAO 层已按 updatedAt 倒序）。
 */
class MemoFilterTest {

    private val memos = listOf(
        MemoEntity(title = "供应商送货", content = "周三下午", imagePath = null),
        MemoEntity(title = "冰柜照片", content = "温度偏高", imagePath = "img/1.jpg"),
        MemoEntity(title = "周末备货", content = "饮料与水", imagePath = null)
    )

    @Test
    fun `all tab returns everything`() {
        assertEquals(3, filterMemos(memos, "", MemoFilterTab.ALL).size)
    }

    @Test
    fun `text tab excludes image memos`() {
        val result = filterMemos(memos, "", MemoFilterTab.TEXT)
        assertEquals(2, result.size)
        assertTrue(result.none { !it.imagePath.isNullOrBlank() })
    }

    @Test
    fun `image tab only image memos`() {
        val result = filterMemos(memos, "", MemoFilterTab.IMAGE)
        assertEquals(1, result.size)
        assertEquals("冰柜照片", result.first().title)
    }

    @Test
    fun `voice tab is always empty`() {
        assertTrue(filterMemos(memos, "", MemoFilterTab.VOICE).isEmpty())
    }

    @Test
    fun `query matches title or content case-insensitively`() {
        assertEquals(1, filterMemos(memos, "送货", MemoFilterTab.ALL).size)
        assertEquals(1, filterMemos(memos, "温度", MemoFilterTab.ALL).size)
        assertEquals(0, filterMemos(memos, "不存在", MemoFilterTab.ALL).size)
        // query 与 tab 筛选叠加
        assertEquals(0, filterMemos(memos, "冰柜", MemoFilterTab.TEXT).size)
        assertEquals(1, filterMemos(memos, "冰柜", MemoFilterTab.IMAGE).size)
    }

    @Test
    fun `blank query behaves like empty`() {
        assertEquals(3, filterMemos(memos, "   ", MemoFilterTab.ALL).size)
    }
}
