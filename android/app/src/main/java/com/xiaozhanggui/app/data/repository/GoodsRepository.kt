package com.xiaozhanggui.app.data.repository

import com.xiaozhanggui.app.data.db.GoodsDao
import com.xiaozhanggui.app.data.db.GoodsEntity
import kotlinx.coroutines.flow.Flow

/**
 * 商品 Repository。对应 iOS AppRepository.GoodsRepository（AppRepository.swift:294-317）。
 * add/update/delete + refreshAll，无通知副作用；update 刷新 updatedAt=now。
 */
class GoodsRepository(
    private val dao: GoodsDao,
    private val refresher: SnapshotRefresher = NoopRefresher
) {
    fun observeAll(): Flow<List<GoodsEntity>> = dao.listAll()
    fun observeById(id: String): Flow<GoodsEntity?> = dao.getById(id)

    suspend fun add(goods: GoodsEntity): GoodsEntity {
        dao.insert(goods)
        refresher.refreshAll()
        return goods
    }

    suspend fun update(goods: GoodsEntity): GoodsEntity {
        val updated = goods.copy(updatedAt = System.currentTimeMillis())
        dao.update(updated)
        refresher.refreshAll()
        return updated
    }

    suspend fun delete(goods: GoodsEntity) {
        dao.delete(goods)
        refresher.refreshAll()
    }
}
