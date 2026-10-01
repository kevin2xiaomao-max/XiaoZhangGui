package com.xiaozhanggui.app.ui.screens.paymentcode

import android.content.Context
import com.xiaozhanggui.app.data.di.XzgGraph
import java.io.File
import java.util.UUID
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.withContext
import kotlinx.serialization.builtins.ListSerializer

/**
 * 收款码数据层（单例，对应 iOS PaymentCodeStore）。
 *
 * 关键不变量（审计 E_misc.md §1.2，Android 必须遵守）：
 * - metadata 轻量持久化：DataStore key `xzg.paymentCodes.metadata.v1`（经 XzgSettings，
 *   与 DataStore 单实例共用，避免同文件多实例损坏），JSON 数组，只存
 *   id/name/kind/fileName/order/createdAt；损坏的 metadata 返回空列表，不崩。
 * - 图片本体：`filesDir/PaymentCodes/payment-code-<UUID>.jpg`，绝不扫描目录批量清理，
 *   只删 metadata 指向的具体文件。
 * - 事务语义：删除先删文件再更新 metadata；替换先落新文件 + 更新 metadata 再删旧文件
 *   （失败时旧图保留、无孤儿）；order 追加递增。
 * - 隐私边界：图片 Data 永不进入 DataStore/网络/AI（仅文件 + metadata JSON）。
 */
object PaymentCodeStore {
    private const val DIR_NAME = "PaymentCodes"

    private fun dir(context: Context): File =
        File(context.filesDir, DIR_NAME).apply { mkdirs() }

    private suspend fun currentList(): List<PaymentCode> =
        decode(XzgGraph.settings.paymentCodeMetadataJson.first())

    /** 损坏的 metadata 返回空列表，不崩。 */
    private fun decode(raw: String): List<PaymentCode> =
        try {
            if (raw.isBlank()) emptyList()
            else paymentCodeJson
                .decodeFromString(ListSerializer(PaymentCodeMeta.serializer()), raw)
                .mapNotNull { it.toCode() }
        } catch (_: Exception) {
            emptyList()
        }

    private suspend fun persist(list: List<PaymentCode>) {
        val raw = paymentCodeJson.encodeToString(
            ListSerializer(PaymentCodeMeta.serializer()),
            list.map { it.toMeta() }
        )
        XzgGraph.settings.setPaymentCodeMetadataJson(raw)
    }

    /** 按 order 升序的收款码流。 */
    fun codesFlow(): Flow<List<PaymentCode>> =
        XzgGraph.settings.paymentCodeMetadataJson
            .map { decode(it).sortedBy { code -> code.order } }

    /** 新增（要求调用方已确认图片非空）。 */
    suspend fun add(
        context: Context,
        name: String,
        kind: PaymentCodeKind,
        imageBytes: ByteArray,
    ): PaymentCode = withContext(Dispatchers.IO) {
        val id = UUID.randomUUID().toString()
        val fileName = "payment-code-$id.jpg"
        File(dir(context), fileName).writeBytes(imageBytes)
        val current = currentList()
        val code = PaymentCode(
            id = id,
            name = name.trim(),
            kind = kind,
            fileName = fileName,
            order = (current.maxOfOrNull { it.order } ?: -1) + 1,
            createdAt = System.currentTimeMillis()
        )
        persist(current + code)
        code
    }

    /** 更新名称 / 类型（不碰图片文件）。 */
    suspend fun updateMeta(id: String, name: String, kind: PaymentCodeKind) {
        val current = currentList()
        persist(current.map {
            if (it.id == id) it.copy(name = name.trim(), kind = kind) else it
        })
    }

    /**
     * 替换图片：先落新文件 + 更新 metadata，再删旧文件。
     * 失败时旧图保留、无孤儿文件。
     */
    suspend fun replaceImage(
        context: Context,
        id: String,
        imageBytes: ByteArray,
    ): Unit = withContext(Dispatchers.IO) {
        val current = currentList()
        val code = current.find { it.id == id } ?: return@withContext
        val newFileName = "payment-code-${UUID.randomUUID()}.jpg"
        File(dir(context), newFileName).writeBytes(imageBytes)
        persist(current.map { if (it.id == id) it.copy(fileName = newFileName) else it })
        try {
            File(dir(context), code.fileName).delete()
        } catch (_: Exception) {
        }
    }

    /** 删除：先删文件，再更新 metadata。 */
    suspend fun delete(context: Context, id: String): Unit = withContext(Dispatchers.IO) {
        val current = currentList()
        val code = current.find { it.id == id } ?: return@withContext
        try {
            File(dir(context), code.fileName).delete()
        } catch (_: Exception) {
        }
        persist(current.filterNot { it.id == id })
    }

    /** metadata 指向的图片文件；缺失返回 null（调用方显示占位）。 */
    fun imageFile(context: Context, code: PaymentCode): File? {
        val f = File(dir(context), code.fileName)
        return if (f.exists()) f else null
    }
}
