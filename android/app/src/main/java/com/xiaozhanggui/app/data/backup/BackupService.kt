package com.xiaozhanggui.app.data.backup

import android.content.Context
import java.util.Base64
import com.xiaozhanggui.app.data.db.XzgDatabase
import com.xiaozhanggui.app.data.notification.NotificationScheduler
import com.xiaozhanggui.app.data.repository.SnapshotRefresher
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.withContext
import java.io.File
import java.util.UUID

/**
 * 备份服务。对应 iOS BackupService（Data/BackupService.swift）。
 *
 * - 文件：`xiao-zhang-gui-backup.json`，formatVersion=2
 * - 顶层：app / version / exportedAt / records
 * - 日期 epoch millis；图片 base64（imageBase64）
 * - 恢复为追加（不清空已有数据）；单次 save；通知重建；一次 refreshAll
 * - 容忍 v1 备份（缺字段 → 安全默认）
 * - 与 iOS 备份文件可互读
 *
 * JSON 编解码逻辑在 [BackupCodec]（纯 JVM 可测）；本类只做 DAO/Context 接线。
 */
class BackupService(
    private val context: Context,
    private val db: XzgDatabase,
    private val notifications: NotificationScheduler,
    private val refresher: SnapshotRefresher
) {
    companion object {
        const val FILE_NAME = "xiao-zhang-gui-backup.json"
        const val FORMAT_VERSION = 2
    }

    sealed class BackupError(message: String) : Exception(message) {
        class InvalidFile : BackupError("无法解析备份 JSON")
        class InvalidRecords : BackupError("备份缺少 records")
        class WriteFailed : BackupError("备份写入失败")
    }

    private fun readImageBase64(imagePath: String?): String? {
        if (imagePath.isNullOrBlank()) return null
        return try {
            val f = File(context.filesDir, imagePath)
            if (!f.exists()) null
            else Base64.getEncoder().encodeToString(f.readBytes())
        } catch (e: Exception) {
            null
        }
    }

    private suspend fun writeImageBase64(base64: String?): String? {
        if (base64.isNullOrBlank()) return null
        return try {
            val bytes = Base64.getDecoder().decode(base64)
            val name = "img_${UUID.randomUUID()}.jpg"
            withContext(Dispatchers.IO) {
                File(context.filesDir, name).writeBytes(bytes)
            }
            name
        } catch (e: Exception) {
            null
        }
    }

    /** 导出全部数据为 v2 JSON 字符串 */
    suspend fun exportToJson(): String = withContext(Dispatchers.IO) {
        val data = BackupCodec.BackupData(
            todos = db.todoDao().listAll().first(),
            memos = db.memoDao().listAll().first(),
            performances = db.performanceDao().listAll().first(),
            expenses = db.expenseDao().listAll().first(),
            expiryItems = db.expiryItemDao().listAll().first(),
            customers = db.customerRequestDao().listAll().first(),
            goods = db.goodsDao().listAll().first()
        )
        BackupCodec.encode(data, System.currentTimeMillis(), ::readImageBase64)
    }

    suspend fun exportToFile(): File = withContext(Dispatchers.IO) {
        try {
            val file = File(context.getExternalFilesDir(null), FILE_NAME)
            file.writeText(exportToJson())
            file
        } catch (e: Exception) {
            throw BackupError.WriteFailed()
        }
    }

    /**
     * 恢复（追加，不清空已有数据）。
     * 返回恢复的记录数。
     */
    suspend fun restore(jsonText: String): Int = withContext(Dispatchers.IO) {
        val data = BackupCodec.decode(jsonText, ::writeImageBase64)
        var count = 0
        // 绕过 Repository，直接构造 Entity 批量 insert（对应 iOS BackupService.restore）
        for (t in data.todos) {
            try { db.todoDao().insert(t); count++ } catch (e: Exception) { /* 单条坏记录跳过 */ }
        }
        for (m in data.memos) {
            try { db.memoDao().insert(m); count++ } catch (e: Exception) { /* 单条坏记录跳过 */ }
        }
        for (p in data.performances) {
            try { db.performanceDao().insert(p); count++ } catch (e: Exception) { /* 单条坏记录跳过 */ }
        }
        for (e in data.expenses) {
            try { db.expenseDao().insert(e); count++ } catch (e: Exception) { /* 单条坏记录跳过 */ }
        }
        for (x in data.expiryItems) {
            try { db.expiryItemDao().insert(x); count++ } catch (e: Exception) { /* 单条坏记录跳过 */ }
        }
        for (c in data.customers) {
            try { db.customerRequestDao().insert(c); count++ } catch (e: Exception) { /* 单条坏记录跳过 */ }
        }
        for (g in data.goods) {
            try { db.goodsDao().insert(g); count++ } catch (e: Exception) { /* 单条坏记录跳过 */ }
        }
        // 统一重建通知 + 一次快照刷新（对应 iOS restore 语义）
        rebuildAllNotifications()
        refresher.refreshAll()
        count
    }

    /** 恢复后统一重建所有通知 */
    private suspend fun rebuildAllNotifications() {
        for (t in db.todoDao().listAll().first()) notifications.scheduleTodo(t)
        for (x in db.expiryItemDao().listAll().first()) notifications.scheduleExpiry(x)
        for (c in db.customerRequestDao().listAll().first()) notifications.rescheduleCustomer(c)
    }
}
