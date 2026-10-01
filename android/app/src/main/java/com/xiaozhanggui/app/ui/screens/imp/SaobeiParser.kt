package com.xiaozhanggui.app.ui.screens.imp

import com.xiaozhanggui.app.data.repository.SaobeiParsedRow
import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.nio.ByteBuffer
import java.nio.charset.Charset
import java.nio.charset.CodingErrorAction
import java.security.MessageDigest
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.OffsetDateTime
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.Locale
import java.util.zip.Inflater
import javax.xml.parsers.SAXParserFactory
import org.xml.sax.Attributes
import org.xml.sax.helpers.DefaultHandler
import kotlin.math.roundToLong

/**
 * 扫呗导入解析管线。逐行对应 iOS `XiaoZhangGui/Features/Import/`：
 * - SaobeiModels.swift → [SaobeiColumn]、[SaobeiImportError]、[SaobeiParseResult]
 *   （SaobeiParsedRow 已在 data/repository/MoneyRepository.kt 定义）
 * - SaobeiCSVParser.swift → [SaobeiCSVParser]（含 SaobeiDateParser、SaobeiFingerprint）
 * - SaobeiXLSXParser.swift → [SaobeiXLSXParser]（MiniZip + SAX）
 * - SaobeiFileValidator.swift → [SaobeiFileValidator]
 * - SaobeiImportWorker.swift / SaobeiImporter → [SaobeiImportWorker]、[SaobeiImporter]
 *
 * 说明：
 * - 日期序列值：iOS 直通原值（CSV mapper 只处理文本日期，序列值会落到错误行），
 *   本实现与 iOS 一致，不做回退换算。
 * - 截图 OCR 分支：iOS 用 Vision；Android 无对应依赖，sheet 不提供该入口。
 */

/** 对应 iOS SaobeiColumn。 */
object SaobeiColumn {
    val dateKeys = listOf("交易时间", "交易日期", "完成时间", "支付时间", "交易完成时间", "时间")
    val amountKeys = listOf("收款金额", "实收金额", "交易金额", "订单金额", "支付金额", "金额")
    val statusKeys = listOf("交易状态", "订单状态", "状态", "支付状态")
    val orderKeys = listOf("订单号", "商户订单号", "流水号", "交易单号", "平台订单号", "商户单号")
    val payKeys = listOf("支付方式", "支付类型", "付款方式", "渠道")

    val successStatuses = setOf("成功", "支付成功", "已支付", "已完成", "交易成功", "success", "SUCCESS", "完成")
    val failedStatuses = setOf("退款", "已退款", "失败", "关闭", "已取消", "已关闭", "撤销", "fail")
}

/** 对应 iOS SaobeiImportError（LocalizedError 的中文案内）。 */
sealed class SaobeiImportError(val userMessage: String) : Exception(userMessage) {
    data object Empty : SaobeiImportError("文件是空的")
    data object UnreadableEncoding : SaobeiImportError("无法识别文件编码，请另存为 UTF-8 CSV")
    data object NoHeader : SaobeiImportError("找不到表头，请确认是扫呗导出文件")
    data object MissingAmountOrDate : SaobeiImportError("缺少交易时间或收款金额列")
    data class UnsupportedExcel(val detail: String) : SaobeiImportError(detail)
}

/** 对应 iOS SaobeiParseResult。 */
data class SaobeiParseResult(
    val rows: List<SaobeiParsedRow>,
    val skipped: List<String>,
    val errors: List<String>,
    val sourceFileName: String
)

enum class SaobeiKind { CSV, XLSX }

/** 对应 iOS SaobeiFileValidator。 */
object SaobeiFileValidator {
    fun kindFor(fileName: String, bytes: ByteArray): SaobeiKind? {
        val ext = fileName.substringAfterLast('.', "").lowercase(Locale.US)
        if (ext == "csv" || ext == "txt") {
            return if (isLikelyCsv(bytes)) SaobeiKind.CSV else null
        }
        if (ext == "xlsx") {
            return if (startsWithZip(bytes)) SaobeiKind.XLSX else null
        }
        return null
    }

    fun isLikelyCsv(bytes: ByteArray): Boolean {
        if (bytes.isEmpty()) return false
        val text = decodeStrict(bytes, Charsets.UTF_8) ?: decodeStrict(bytes, Charsets.UTF_16) ?: return false
        val firstLine = text.split('\n', '\r').firstOrNull() ?: ""
        return firstLine.contains(",") || firstLine.contains("，") ||
                (firstLine.contains("交易时间") && firstLine.contains("收款金额"))
    }

    internal fun startsWithZip(bytes: ByteArray): Boolean =
        bytes.size >= 4 &&
                bytes[0] == 0x50.toByte() && bytes[1] == 0x4B.toByte() &&
                bytes[2] == 0x03.toByte() && bytes[3] == 0x04.toByte()
}

/** 对应 iOS SaobeiDateParser。返回 epoch millis，解析失败返回 null。 */
object SaobeiDateParser {
    private val FORMATS = listOf(
        "yyyy-MM-dd HH:mm:ss",
        "yyyy/MM/dd HH:mm:ss",
        "yyyy-MM-dd HH:mm",
        "yyyy/MM/dd HH:mm",
        "yyyy-MM-dd",
        "yyyy/MM/dd",
        "yyyyMMddHHmmss",
        "yyyyMMdd"
    )

    fun parse(raw: String): Long? {
        val text = raw.trim()
        if (text.isEmpty()) return null
        val zone = ZoneId.systemDefault()
        for (pattern in FORMATS) {
            try {
                val fmt = DateTimeFormatter.ofPattern(pattern, Locale.US)
                return if (pattern.contains('H')) {
                    LocalDateTime.parse(text, fmt).atZone(zone).toInstant().toEpochMilli()
                } else {
                    LocalDate.parse(text, fmt).atStartOfDay(zone).toInstant().toEpochMilli()
                }
            } catch (_: Exception) {
                // 尝试下一个格式
            }
        }
        // ISO8601 回退（对应 iOS ISO8601DateFormatter）
        try {
            return OffsetDateTime.parse(text).toInstant().toEpochMilli()
        } catch (_: Exception) {
        }
        return null
    }
}

/** 对应 iOS SaobeiFingerprint。 */
object SaobeiFingerprint {
    fun make(
        orderNo: String,
        dateMillis: Long,
        amount: Double,
        paymentMethod: String,
        raw: String
    ): String {
        val stamp = dateMillis / 1000
        val cents = (amount * 100).roundToLong()
        val basis = if (orderNo.isNotEmpty()) {
            "saobei|$orderNo|$cents"
        } else {
            "saobei|$stamp|$cents|$paymentMethod|$raw"
        }
        val digest = MessageDigest.getInstance("SHA-256")
            .digest(basis.toByteArray(Charsets.UTF_8))
        return digest.joinToString("") { "%02x".format(it) }
    }
}

/** 对应 iOS SaobeiCSVParser。 */
object SaobeiCSVParser {
    fun parseBytes(bytes: ByteArray, fileName: String): SaobeiParseResult {
        if (bytes.isEmpty()) throw SaobeiImportError.Empty
        if (SaobeiFileValidator.kindFor(fileName, bytes) != SaobeiKind.CSV) {
            throw SaobeiImportError.NoHeader
        }
        val text = decodeText(bytes) ?: throw SaobeiImportError.UnreadableEncoding
        return parseText(text, fileName)
    }

    fun parseText(text: String, fileName: String): SaobeiParseResult {
        val lines = text.replace("\r\n", "\n").replace("\r", "\n").split("\n")
        val headerIndex = lines.indexOfFirst { looksLikeHeader(it) }
        if (headerIndex < 0) throw SaobeiImportError.NoHeader
        val header = parseCsvLine(lines[headerIndex])
        val dateIdx = firstIndex(header, SaobeiColumn.dateKeys)
            ?: throw SaobeiImportError.MissingAmountOrDate
        val amountIdx = firstIndex(header, SaobeiColumn.amountKeys)
            ?: throw SaobeiImportError.MissingAmountOrDate
        val statusIdx = firstIndex(header, SaobeiColumn.statusKeys)
        val orderIdx = firstIndex(header, SaobeiColumn.orderKeys)
        val payIdx = firstIndex(header, SaobeiColumn.payKeys)

        val rows = mutableListOf<SaobeiParsedRow>()
        val skipped = mutableListOf<String>()
        val errors = mutableListOf<String>()

        for (offset in 0 until lines.size - headerIndex - 1) {
            val trimmed = lines[headerIndex + 1 + offset].trim()
            if (trimmed.isEmpty()) continue
            val cols = parseCsvLine(trimmed)
            val dateText = value(cols, dateIdx)
            val amountText = value(cols, amountIdx)
            val date = SaobeiDateParser.parse(dateText)
            val amount = parseAmount(amountText)
            // 与 iOS 一致：行号按 offset+2 显示（表头在第 1 行时的 1-based 行号）
            if (date == null || amount == null) {
                errors.add("第 ${offset + 2} 行无法解析：$trimmed")
                continue
            }
            val status = statusIdx?.let { value(cols, it) } ?: ""
            val orderNo = orderIdx?.let { value(cols, it) } ?: ""
            val pay = payIdx?.let { value(cols, it) } ?: ""
            val success = isSuccess(status)
            val fingerprint = SaobeiFingerprint.make(orderNo, date, amount, pay, trimmed)
            val row = SaobeiParsedRow(
                date = date,
                amount = amount,
                status = status,
                orderNo = orderNo,
                paymentMethod = pay,
                fingerprint = fingerprint,
                isSuccess = success,
                rawLine = trimmed
            )
            if (success) {
                rows.add(row)
            } else {
                skipped.add("第 ${offset + 2} 行未计入（${if (status.isEmpty()) "非成功状态" else status}）")
            }
        }
        return SaobeiParseResult(rows, skipped, errors, fileName)
    }

    /** 对应 iOS decodeText：UTF-8（去 BOM）→ UTF-16 → GB18030 → ISO-8859-1。 */
    fun decodeText(bytes: ByteArray): String? {
        decodeStrict(bytes, Charsets.UTF_8)?.let { return stripBom(it) }
        decodeStrict(bytes, Charsets.UTF_16)?.let { return it }
        decodeStrict(bytes, Charset.forName("GB18030"))?.let { return it }
        return decodeStrict(bytes, Charsets.ISO_8859_1)
    }

    private fun stripBom(text: String): String =
        if (text.startsWith("\uFEFF")) text.substring(1) else text

    private fun looksLikeHeader(line: String): Boolean =
        SaobeiColumn.dateKeys.any { line.contains(it) } &&
                SaobeiColumn.amountKeys.any { line.contains(it) }

    private fun firstIndex(header: List<String>, keys: List<String>): Int? =
        header.indexOfFirst { col ->
            keys.any { col.replace(" ", "").contains(it) }
        }.takeIf { it >= 0 }

    private fun value(cols: List<String>, index: Int): String =
        if (index < cols.size) cols[index].trim() else ""

    /**
     * CSV 行解析：支持引号包裹；分隔符为 `,` / Tab / `，`。
     * 对应 iOS parseCSVLine。
     */
    fun parseCsvLine(line: String): List<String> {
        val result = mutableListOf<String>()
        val current = StringBuilder()
        var inQuotes = false
        var i = 0
        while (i < line.length) {
            val ch = line[i]
            if (ch == '"') {
                val next = i + 1
                if (inQuotes && next < line.length && line[next] == '"') {
                    current.append('"')
                    i = next
                } else {
                    inQuotes = !inQuotes
                }
            } else if ((ch == ',' || ch == '\t' || ch == '，') && !inQuotes) {
                result.add(current.toString())
                current.clear()
            } else {
                current.append(ch)
            }
            i++
        }
        result.add(current.toString())
        return result
    }

    /**
     * 金额清洗：去掉 `,` / `，` / `¥` / `￥`，必须 > 0。
     * 对应 iOS parseAmount。
     */
    fun parseAmount(raw: String): Double? {
        val cleaned = raw
            .replace(",", "")
            .replace("，", "")
            .replace("¥", "")
            .replace("￥", "")
            .trim()
        val value = cleaned.toDoubleOrNull() ?: return null
        return if (value > 0) value else null
    }

    /**
     * 状态判定：空 → true；先判失败关键词 → false；再判成功关键词 → true；未知 → false。
     * 对应 iOS isSuccess。
     */
    fun isSuccess(status: String): Boolean {
        val trimmed = status.trim()
        if (trimmed.isEmpty()) return true
        if (SaobeiColumn.failedStatuses.any { trimmed.contains(it, ignoreCase = true) }) return false
        if (SaobeiColumn.successStatuses.any { trimmed.contains(it, ignoreCase = true) }) return true
        return false
    }
}

/** 严格解码（遇到非法字节返回 null，而非替换字符）。 */
private fun decodeStrict(bytes: ByteArray, charset: Charset): String? = try {
    charset.newDecoder()
        .onMalformedInput(CodingErrorAction.REPORT)
        .onUnmappableCharacter(CodingErrorAction.REPORT)
        .decode(ByteBuffer.wrap(bytes))
        .toString()
} catch (_: Exception) {
    null
}

/** 对应 iOS SaobeiXLSXParser：ZIP 解压 + SAX 解析 + 转 CSV 复用 SaobeiCSVParser。 */
object SaobeiXLSXParser {
    fun parse(bytes: ByteArray, fileName: String): SaobeiParseResult {
        if (SaobeiFileValidator.kindFor(fileName, bytes) != SaobeiKind.XLSX) {
            throw SaobeiImportError.UnsupportedExcel("文件不是有效的 XLSX，请重新导出 XLSX 或 CSV")
        }
        if (!SaobeiFileValidator.startsWithZip(bytes)) {
            throw SaobeiImportError.UnsupportedExcel("无法识别 Excel 格式，请在扫呗里另存为 CSV")
        }
        val files = try {
            MiniZip.extract(bytes)
        } catch (_: Exception) {
            throw SaobeiImportError.UnsupportedExcel("Excel 解压失败，请另存为 CSV 后导入")
        }
        val workbookData = findFile(files, "xl/workbook.xml")
            ?: throw SaobeiImportError.UnsupportedExcel("Excel 工作簿结构异常（缺少 workbook.xml）")
        val relsData = findFile(files, "xl/_rels/workbook.xml.rels")
        val sheetTargets = parseWorkbook(workbookData, relsData)
        var sheetData: ByteArray? = null
        for (target in sheetTargets) {
            findFile(files, target)?.let { sheetData = it; break }
        }
        if (sheetData == null) {
            sheetData = files.entries
                .firstOrNull { it.key.lowercase(Locale.US).contains("worksheets/sheet") }
                ?.value
        }
        val sheet = sheetData
            ?: throw SaobeiImportError.UnsupportedExcel("Excel 中没有工作表，请另存为 CSV")
        val shared = findFile(files, "xl/sharedstrings.xml")
            ?.let { parseSharedStrings(it) } ?: emptyList()
        val table = parseSheet(sheet, shared)
        if (table.isEmpty()) {
            throw SaobeiImportError.UnsupportedExcel("Excel 内容为空，请另存为 CSV")
        }
        val csv = table.joinToString("\n") { row ->
            row.joinToString(",") { escapeCsv(it) }
        }
        return SaobeiCSVParser.parseText(csv, fileName)
    }

    private fun findFile(files: Map<String, ByteArray>, suffix: String): ByteArray? {
        val lower = suffix.lowercase(Locale.US)
        for ((key, value) in files) {
            if (key.lowercase(Locale.US).endsWith(lower)) return value
        }
        return null
    }

    /** workbook.xml + rels 找活动 sheet（对应 iOS parseWorkbook + normalizeTarget）。 */
    private fun parseWorkbook(data: ByteArray, relsData: ByteArray?): List<String> {
        val sheets = mutableListOf<Pair<String, String>>()
        try {
            sax(data,
                onStart = { local, qName, attrs ->
                    if (local == "sheet" || qName == "sheet") {
                        val rid = attrs.getValue("r:id") ?: attrs.getValue("id") ?: ""
                        if (rid.isNotEmpty()) sheets.add("" to rid)
                    }
                })
        } catch (_: Exception) {
            return emptyList()
        }
        if (sheets.isEmpty()) return emptyList()
        val rels = mutableMapOf<String, String>()
        if (relsData != null) {
            try {
                sax(relsData,
                    onStart = { local, qName, attrs ->
                        if (local == "Relationship" || qName == "Relationship") {
                            val id = attrs.getValue("Id") ?: ""
                            val target = attrs.getValue("Target") ?: ""
                            if (id.isNotEmpty()) rels[id] = target
                        }
                    })
            } catch (_: Exception) {
            }
        }
        return sheets.mapNotNull { (_, rid) ->
            rels[rid]?.let { normalizeTarget(it) }
        }
    }

    private fun normalizeTarget(target: String): String {
        var s = target
        if (s.startsWith("/")) s = s.substring(1)
        if (!s.lowercase(Locale.US).startsWith("xl/")) s = "xl/$s"
        return s.lowercase(Locale.US)
    }

    /** sharedStrings.xml（SAX，支持 rich text 同 si 下多个 t）。 */
    private fun parseSharedStrings(data: ByteArray): List<String> {
        val result = mutableListOf<String>()
        var inSi = false
        var inT = false
        val current = StringBuilder()
        try {
            sax(data,
                onStart = { local, qName, _ ->
                    when (local.ifEmpty { qName }) {
                        "si" -> { inSi = true; current.clear() }
                        "t" -> if (inSi) inT = true
                    }
                },
                onChars = { ch, start, len ->
                    if (inSi && inT) current.append(ch, start, start + len)
                },
                onEnd = { local, qName ->
                    when (local.ifEmpty { qName }) {
                        "t" -> inT = false
                        "si" -> if (inSi) {
                            result.add(current.toString())
                            inSi = false
                        }
                    }
                })
        } catch (_: Exception) {
        }
        return result
    }

    /**
     * sheet 解析（SAX）：支持 shared（t="s"）/ inlineStr / 数字 / 日期 / self-closing 空 cell。
     * 数字与日期 cell 直接返回原值，由 CSV mapper 处理（与 iOS 一致）。
     */
    private fun parseSheet(data: ByteArray, shared: List<String>): List<List<String>> {
        val rows = mutableMapOf<Int, MutableMap<Int, String>>()
        var inCell = false
        var inValue = false
        var inInlineStr = false
        var inT = false
        var cellType = ""
        var cellRef = ""
        val currentValue = StringBuilder()

        fun resolve(type: String, value: String): String {
            if (type == "s") {
                val idx = value.toIntOrNull()
                if (idx != null && idx >= 0 && idx < shared.size) return shared[idx]
            }
            if (type == "inlineStr") return value
            return value
        }

        /** "B2" → (col=1, row=2)。 */
        fun parseRef(ref: String): Pair<Int, Int> {
            var col = 0
            val digits = StringBuilder()
            for (ch in ref) {
                if (ch.isLetter()) col = col * 26 + (ch.uppercaseChar() - 'A' + 1)
                else if (ch.isDigit()) digits.append(ch)
            }
            return (col - 1).coerceAtLeast(0) to (digits.toString().toIntOrNull() ?: 0)
        }

        try {
            sax(data,
                onStart = { local, qName, attrs ->
                    when (local.ifEmpty { qName }) {
                        "c" -> {
                            inCell = true
                            cellRef = attrs.getValue("r") ?: ""
                            cellType = attrs.getValue("t") ?: ""
                            currentValue.clear()
                        }
                        "v" -> if (inCell) inValue = true
                        "is" -> if (inCell) inInlineStr = true
                        "t" -> if (inInlineStr) inT = true
                    }
                },
                onChars = { ch, start, len ->
                    if (inCell && (inValue || (inInlineStr && inT))) {
                        currentValue.append(ch, start, start + len)
                    }
                },
                onEnd = { local, qName ->
                    when (local.ifEmpty { qName }) {
                        "t" -> if (inInlineStr) inT = false
                        "v" -> inValue = false
                        "is" -> inInlineStr = false
                        "c" -> {
                            val (col, row) = parseRef(cellRef)
                            if (row > 0) {
                                val resolved = resolve(cellType, currentValue.toString())
                                if (resolved.isNotEmpty()) {
                                    rows.getOrPut(row) { mutableMapOf() }[col] = resolved
                                }
                            }
                            inCell = false
                            cellType = ""
                            cellRef = ""
                            currentValue.clear()
                        }
                    }
                })
        } catch (_: Exception) {
        }
        if (rows.isEmpty()) return emptyList()
        val maxCol = rows.values.flatMap { it.keys }.maxOrNull() ?: 0
        return rows.keys.sorted().map { key ->
            (0..maxCol).map { rows[key]?.get(it) ?: "" }
        }
    }

    private fun escapeCsv(value: String): String =
        if (value.contains(",") || value.contains("\"") || value.contains("\n")) {
            "\"" + value.replace("\"", "\"\"") + "\""
        } else value

    /** 简易 SAX 分发：localName 为空时用 qName 回退（对应 iOS elementName）。 */
    private fun sax(
        data: ByteArray,
        onStart: (local: String, qName: String, attrs: Attributes) -> Unit = { _, _, _ -> },
        onChars: (ch: CharArray, start: Int, len: Int) -> Unit = { _, _, _ -> },
        onEnd: (local: String, qName: String) -> Unit = { _, _ -> }
    ) {
        val factory = SAXParserFactory.newInstance()
        factory.isNamespaceAware = true
        val parser = factory.newSAXParser()
        parser.parse(
            ByteArrayInputStream(data),
            object : DefaultHandler() {
                override fun startElement(
                    uri: String?,
                    localName: String?,
                    qName: String?,
                    attributes: Attributes?
                ) {
                    onStart(localName ?: "", qName ?: "", attributes ?: EmptyAttributes)
                }

                override fun characters(ch: CharArray?, start: Int, length: Int) {
                    if (ch != null) onChars(ch, start, length)
                }

                override fun endElement(uri: String?, localName: String?, qName: String?) {
                    onEnd(localName ?: "", qName ?: "")
                }
            }
        )
    }

    private object EmptyAttributes : Attributes {
        override fun getLength() = 0
        override fun getURI(index: Int) = ""
        override fun getLocalName(index: Int) = ""
        override fun getQName(index: Int) = ""
        override fun getType(index: Int) = ""
        override fun getValue(index: Int): String? = null
        override fun getIndex(uri: String?, localName: String?) = -1
        override fun getIndex(qName: String?) = -1
        override fun getType(uri: String?, localName: String?) = ""
        override fun getType(qName: String?) = ""
        override fun getValue(uri: String?, localName: String?): String? = null
        override fun getValue(qName: String?): String? = null
    }
}

/** 对应 iOS MiniZip：从 Central Directory 读取（先找 EOCD）。 */
private object MiniZip {
    fun extract(data: ByteArray): Map<String, ByteArray> {
        val result = mutableMapOf<String, ByteArray>()
        val eocd = findEocd(data) ?: throw IllegalArgumentException("invalid zip")
        val cdOffset = u32(data, eocd + 16).toInt()
        val cdCount = u16(data, eocd + 10).toInt()
        var off = cdOffset
        var n = 0
        while (n < cdCount) {
            n++
            if (off + 46 > data.size || u32(data, off) != 0x02014b50L) break
            val method = u16(data, off + 10).toInt()
            val compSize = u32(data, off + 20).toInt()
            val uncompSize = u32(data, off + 24).toInt()
            val nameLen = u16(data, off + 28).toInt()
            val extraLen = u16(data, off + 30).toInt()
            val commentLen = u16(data, off + 32).toInt()
            val localHeaderOffset = u32(data, off + 42).toInt()
            val nameStart = off + 46
            if (nameStart + nameLen > data.size) break
            val name = decodeStrict(data.copyOfRange(nameStart, nameStart + nameLen), Charsets.UTF_8)
                ?: "file"
            if (localHeaderOffset + 30 <= data.size &&
                u32(data, localHeaderOffset) == 0x04034b50L
            ) {
                val localNameLen = u16(data, localHeaderOffset + 26).toInt()
                val localExtraLen = u16(data, localHeaderOffset + 28).toInt()
                val dataStart = localHeaderOffset + 30 + localNameLen + localExtraLen
                if (dataStart + compSize <= data.size) {
                    val payload = data.copyOfRange(dataStart, dataStart + compSize)
                    when (method) {
                        0 -> result[name] = payload
                        8 -> inflateRaw(payload, uncompSize)?.let { result[name] = it }
                    }
                }
            }
            off += 46 + nameLen + extraLen + commentLen
        }
        return result
    }

    /** 从文件末尾往前找 EOCD（0x06054b50）。ZIP comment 最长 65535。 */
    private fun findEocd(bytes: ByteArray): Int? {
        val n = bytes.size
        if (n < 22) return null
        val minPos = maxOf(0, n - 65557)
        var i = n - 22
        while (i >= minPos) {
            if (bytes[i] == 0x50.toByte() && bytes[i + 1] == 0x4B.toByte() &&
                bytes[i + 2] == 0x05.toByte() && bytes[i + 3] == 0x06.toByte()
            ) {
                return i
            }
            i--
        }
        return null
    }

    private fun u16(b: ByteArray, i: Int): Long =
        (b[i].toLong() and 0xFF) or ((b[i + 1].toLong() and 0xFF) shl 8)

    private fun u32(b: ByteArray, i: Int): Long =
        (b[i].toLong() and 0xFF) or ((b[i + 1].toLong() and 0xFF) shl 8) or
                ((b[i + 2].toLong() and 0xFF) shl 16) or ((b[i + 3].toLong() and 0xFF) shl 24)

    /**
     * 解 raw DEFLATE（RFC 1951，对应 ZIP method 8）。
     * Java Inflater(true) = raw DEFLATE；失败时回退 RFC 1950 zlib 包装。
     */
    private fun inflateRaw(payload: ByteArray, expected: Int): ByteArray? {
        for (nowrap in listOf(true, false)) {
            try {
                val inflater = Inflater(nowrap)
                inflater.setInput(payload)
                val out = ByteArrayOutputStream()
                val buf = ByteArray(16384)
                while (!inflater.finished()) {
                    val count = inflater.inflate(buf)
                    if (count == 0) break
                    out.write(buf, 0, count)
                }
                inflater.end()
                val bytes = out.toByteArray()
                if (bytes.isNotEmpty() || expected == 0) return bytes
            } catch (_: Exception) {
                // 尝试下一个包装
            }
        }
        return null
    }
}

/** 对应 iOS SaobeiImporter（路由：.xls 拒绝 / .xlsx+ZIP 魔数走 XLSX / 其余走 CSV）。 */
object SaobeiImporter {
    fun parse(bytes: ByteArray, fileName: String): SaobeiParseResult {
        val lower = fileName.lowercase(Locale.US)
        // .xls 是旧二进制格式（≠ .xlsx ZIP/XML），不伪装支持
        if (lower.endsWith(".xls") && !lower.endsWith(".xlsx")) {
            throw SaobeiImportError.UnsupportedExcel("暂不支持旧版 XLS，请另存为 XLSX 或 CSV")
        }
        if (lower.endsWith(".xlsx") || SaobeiFileValidator.startsWithZip(bytes)) {
            return SaobeiXLSXParser.parse(bytes, fileName)
        }
        return SaobeiCSVParser.parseBytes(bytes, fileName)
    }
}

/** 对应 iOS SaobeiImportWorker：先轻量校验，再路由解析。 */
object SaobeiImportWorker {
    fun parse(bytes: ByteArray, fileName: String): SaobeiParseResult {
        if (SaobeiFileValidator.kindFor(fileName, bytes) == null) {
            throw SaobeiImportError.NoHeader
        }
        return SaobeiImporter.parse(bytes, fileName)
    }
}
