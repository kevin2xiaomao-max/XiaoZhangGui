package com.xiaozhanggui.app.data.repository

import com.xiaozhanggui.app.data.db.ExpenseDao
import com.xiaozhanggui.app.data.db.ExpenseEntity
import com.xiaozhanggui.app.data.db.IncomeSource
import com.xiaozhanggui.app.data.db.PerformanceDao
import com.xiaozhanggui.app.data.db.PerformanceEntity
import kotlinx.coroutines.flow.Flow

/**
 * 扫呗解析行（内存态导入管线）。对应 iOS SaobeiParsedRow。
 */
data class SaobeiParsedRow(
    val date: Long,
    val amount: Double,
    val status: String,
    val orderNo: String,
    val paymentMethod: String,
    val fingerprint: String,
    val isSuccess: Boolean,
    val rawLine: String
)

data class SaobeiImportCommitResult(
    val inserted: Int,
    val duplicates: Int,
    val skippedFailed: Int
)

/**
 * 营业额/支出 Repository。对应 iOS PerformanceRepository / ExpenseRepository
 *（AppRepository.swift:80-188）。
 *
 * GATE C：统计一律用业务 `date`，不用 createdAt。
 */
class PerformanceRepository(
    private val dao: PerformanceDao,
    private val refresher: SnapshotRefresher = NoopRefresher
) {
    fun observeAll(): Flow<List<PerformanceEntity>> = dao.listAll()
    fun observeById(id: String): Flow<PerformanceEntity?> = dao.getById(id)

    /** 手工记录：fingerprint=""、paymentMethod/orderNo/importSource="" */
    suspend fun add(
        amount: Double,
        note: String = "",
        date: Long = System.currentTimeMillis(),
        incomeSource: String = IncomeSource.STORE
    ): PerformanceEntity {
        val entity = PerformanceEntity(
            amount = amount,
            note = note,
            date = date,
            fingerprint = "",
            paymentMethod = "",
            orderNo = "",
            importSource = "",
            incomeSource = incomeSource
        )
        dao.insert(entity)
        refresher.refreshAll()
        return entity
    }

    /** 扫呗单行导入 */
    suspend fun addImported(row: SaobeiParsedRow): PerformanceEntity {
        val note = if (row.paymentMethod.isBlank()) "扫呗" else "扫呗 · ${row.paymentMethod}"
        val entity = PerformanceEntity(
            amount = row.amount,
            note = note,
            date = row.date,
            fingerprint = row.fingerprint,
            paymentMethod = row.paymentMethod,
            orderNo = row.orderNo,
            importSource = "saobei",
            incomeSource = IncomeSource.fromNote(row.paymentMethod)
        )
        dao.insert(entity)
        refresher.refreshAll()
        return entity
    }

    /**
     * 扫呗批量导入（对应 iOS importSaobei）：
     * ① 用 DB 全量非空 fingerprint 初始化 seen 集；
     * ② 文件内重复（同一 fingerprint）只计 duplicates 不落库；
     * ③ 批量 insert + 单次 save + 单次 refreshAll；
     * ④ 全重复时返回 inserted=0。
     */
    suspend fun importSaobei(rows: List<SaobeiParsedRow>, skippedFailed: Int): SaobeiImportCommitResult {
        val seen = dao.allFingerprints().toMutableSet()
        var inserted = 0
        var duplicates = 0
        val toInsert = mutableListOf<PerformanceEntity>()
        for (row in rows) {
            if (!row.isSuccess) continue // 失败行由调用方计入 skippedFailed
            if (row.fingerprint.isBlank() || !seen.add(row.fingerprint)) {
                duplicates++
                continue
            }
            val note = if (row.paymentMethod.isBlank()) "扫呗" else "扫呗 · ${row.paymentMethod}"
            toInsert.add(
                PerformanceEntity(
                    amount = row.amount,
                    note = note,
                    date = row.date,
                    fingerprint = row.fingerprint,
                    paymentMethod = row.paymentMethod,
                    orderNo = row.orderNo,
                    importSource = "saobei",
                    incomeSource = IncomeSource.fromNote(row.paymentMethod)
                )
            )
            inserted++
        }
        for (e in toInsert) dao.insert(e)
        refresher.refreshAll()
        return SaobeiImportCommitResult(inserted, duplicates, skippedFailed)
    }

    suspend fun update(performance: PerformanceEntity) {
        dao.update(performance)
        refresher.refreshAll()
    }

    suspend fun delete(performance: PerformanceEntity) {
        dao.delete(performance)
        refresher.refreshAll()
    }
}

class ExpenseRepository(
    private val dao: ExpenseDao,
    private val refresher: SnapshotRefresher = NoopRefresher
) {
    fun observeAll(): Flow<List<ExpenseEntity>> = dao.listAll()
    fun observeById(id: String): Flow<ExpenseEntity?> = dao.getById(id)

    suspend fun add(
        amount: Double,
        category: String = "其他",
        note: String = "",
        date: Long = System.currentTimeMillis()
    ): ExpenseEntity {
        val entity = ExpenseEntity(amount = amount, category = category, note = note, date = date)
        dao.insert(entity)
        refresher.refreshAll()
        return entity
    }

    suspend fun update(expense: ExpenseEntity) {
        dao.update(expense)
        refresher.refreshAll()
    }

    suspend fun delete(expense: ExpenseEntity) {
        dao.delete(expense)
        refresher.refreshAll()
    }
}
