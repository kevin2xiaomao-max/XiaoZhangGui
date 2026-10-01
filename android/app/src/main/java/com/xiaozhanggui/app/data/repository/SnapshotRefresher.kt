package com.xiaozhanggui.app.data.repository

/**
 * 快照刷新钩子。对应 iOS SnapshotSyncManager.refreshAll(context:)。
 * 每次增/改/删/完成/状态推进成功后调用（B_data.md §4 统一副作用）。
 * Phase 2 为接口，Phase 3+ 接 AppWidget / 快照。
 */
fun interface SnapshotRefresher {
    fun refreshAll()
}

/** 空实现（测试/未接线时用） */
object NoopRefresher : SnapshotRefresher {
    override fun refreshAll() {}
}
