package com.xiaozhanggui.app.domain.ai

import java.time.Instant
import java.time.LocalDateTime
import java.time.OffsetDateTime
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.Locale
import kotlinx.serialization.KSerializer
import kotlinx.serialization.Serializable
import kotlinx.serialization.SerializationException
import kotlinx.serialization.descriptors.PrimitiveKind
import kotlinx.serialization.descriptors.PrimitiveSerialDescriptor
import kotlinx.serialization.descriptors.SerialDescriptor
import kotlinx.serialization.encoding.Decoder
import kotlinx.serialization.encoding.Encoder
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import kotlinx.serialization.json.putJsonArray
import kotlinx.serialization.json.putJsonObject

/**
 * AI 工具定义与参数。对应 iOS `AI/Core/AIDTO.swift`（ToolName/ToolArguments/ToolCall）
 * 与 `AI/Tools/ToolCatalog.swift`。
 *
 * - 只注册 5 个工具：1 READ（searchRecords，自动执行）+ 4 CREATE（必须 ActionCard 确认）。
 * - addExpiry / update / delete 明确不注册（iOS ToolCatalog.swift:5-8 注释）。
 * - 纯 Kotlin，无 Android 依赖，可单测。
 */

/** 工具权限分级：read 自动执行；create 必须用户确认。对应 iOS ToolPermission。 */
enum class ToolPermission { READ, CREATE }

/** 工具名。wireName 必须与 iOS ToolName rawValue 1:1（Provider payload / journal 落盘共用）。 */
@Serializable(with = ToolNameSerializer::class)
enum class ToolName(val wireName: String) {
    SEARCH_RECORDS("searchRecords"),
    RECORD_REVENUE("recordRevenue"),
    CREATE_TODO("createTodo"),
    CREATE_MEMO("createMemo"),
    CREATE_DELIVERY("createDelivery");

    val permission: ToolPermission
        get() = if (this == SEARCH_RECORDS) ToolPermission.READ else ToolPermission.CREATE

    /** ActionCard / 日志里的中文名，对应 iOS ToolName.displayName */
    val displayName: String
        get() = when (this) {
            SEARCH_RECORDS -> "查询经营记录"
            RECORD_REVENUE -> "记录营业额"
            CREATE_TODO -> "新建待办"
            CREATE_MEMO -> "新建备忘"
            CREATE_DELIVERY -> "新建配送"
        }

    companion object {
        val liteTools: List<ToolName> = listOf(
            SEARCH_RECORDS, RECORD_REVENUE, CREATE_TODO, CREATE_MEMO, CREATE_DELIVERY
        )
        fun fromWireName(value: String): ToolName? = entries.firstOrNull { it.wireName == value }
    }
}

object ToolNameSerializer : KSerializer<ToolName> {
    override val descriptor: SerialDescriptor =
        PrimitiveSerialDescriptor("ToolName", PrimitiveKind.STRING)
    override fun deserialize(decoder: Decoder): ToolName =
        ToolName.fromWireName(decoder.decodeString())
            ?: throw SerializationException("未注册的工具名")
    override fun serialize(encoder: Encoder, value: ToolName) =
        encoder.encodeString(value.wireName)
}

/** 经营记录种类。对应 iOS BusinessRecordKind。 */
@Serializable(with = BusinessRecordKindSerializer::class)
enum class BusinessRecordKind(val wireName: String) {
    REVENUE_TODAY("revenueToday"),
    TODO_TODAY("todoToday"),
    RECENT_MEMO("recentMemo"),
    EXPIRING_GOODS("expiringGoods"),
    DELIVERY("delivery");

    companion object {
        fun fromWireName(value: String): BusinessRecordKind? =
            entries.firstOrNull { it.wireName == value }
    }
}

object BusinessRecordKindSerializer : KSerializer<BusinessRecordKind> {
    override val descriptor: SerialDescriptor =
        PrimitiveSerialDescriptor("BusinessRecordKind", PrimitiveKind.STRING)
    override fun deserialize(decoder: Decoder): BusinessRecordKind =
        BusinessRecordKind.fromWireName(decoder.decodeString())
            ?: throw SerializationException("未知的记录种类")
    override fun serialize(encoder: Encoder, value: BusinessRecordKind) =
        encoder.encodeString(value.wireName)
}

/**
 * ISO8601 日期编解码（epoch millis ↔ 字符串）。
 * 兼容带/不带毫秒、Z / 时区偏移形式，对应 iOS AIISO8601。
 */
object Iso8601MillisSerializer : KSerializer<Long> {
    override val descriptor: SerialDescriptor =
        PrimitiveSerialDescriptor("Iso8601Millis", PrimitiveKind.STRING)

    override fun deserialize(decoder: Decoder): Long {
        val raw = decoder.decodeString()
        return parse(raw) ?: throw SerializationException("无法解析的日期：$raw")
    }

    override fun serialize(encoder: Encoder, value: Long) {
        encoder.encodeString(Instant.ofEpochMilli(value).toString())
    }

    fun parse(raw: String): Long? {
        val t = raw.trim()
        runCatching { return Instant.parse(t).toEpochMilli() }
        runCatching { return OffsetDateTime.parse(t).toInstant().toEpochMilli() }
        runCatching {
            return LocalDateTime.parse(t).atZone(ZoneId.systemDefault()).toInstant().toEpochMilli()
        }
        return null
    }
}

/** 四类 CREATE + 一类 READ 的参数。日期一律 epoch millis，JSON 层为 ISO8601。 */
@Serializable
data class RevenueArguments(
    val amount: Double? = null,
    /** 来源：美团 / 饿了么 / 现金 / 微信 / 支付宝 … */
    val source: String? = null,
    @Serializable(with = Iso8601MillisSerializer::class) val date: Long? = null,
    val note: String? = null
)

@Serializable
data class TodoArguments(
    val title: String? = null,
    val detail: String? = null,
    @Serializable(with = Iso8601MillisSerializer::class) val dueDate: Long? = null,
    /** 对齐 Todo.priority：0 普通 / 1 重要 / 2 紧急 */
    val priority: Int? = null
)

@Serializable
data class MemoArguments(
    val title: String? = null,
    val content: String? = null
)

@Serializable
data class DeliveryArguments(
    /** 客户 / 房号，如 "302" */
    val customer: String? = null,
    val roomOrAddress: String? = null,
    val phone: String? = null,
    /** 商品完整描述，如 "怡宝 两箱" */
    val content: String? = null,
    /** 商品名，如 "怡宝" */
    val goodsName: String? = null,
    /** 数量原文，如 "两箱" */
    val quantity: String? = null,
    @Serializable(with = Iso8601MillisSerializer::class) val deliveryTime: Long? = null,
    /** 时间原文，如 "今晚8点" */
    val deliveryTimeText: String? = null,
    val note: String? = null,
    /** 配送 / 商品总金额。缺省 null，旧 JSON 无此字段可正常解码。 */
    val amount: Double? = null
)

@Serializable
data class SearchRecordsArguments(
    val query: String? = null,
    val kinds: List<BusinessRecordKind> = emptyList()
)

/** 工具参数（sealed 替代 Swift enum 关联值）。 */
sealed class ToolArguments {
    abstract val toolName: ToolName

    data class Revenue(val args: RevenueArguments) : ToolArguments() {
        override val toolName = ToolName.RECORD_REVENUE
    }
    data class Todo(val args: TodoArguments) : ToolArguments() {
        override val toolName = ToolName.CREATE_TODO
    }
    data class Memo(val args: MemoArguments) : ToolArguments() {
        override val toolName = ToolName.CREATE_MEMO
    }
    data class Delivery(val args: DeliveryArguments) : ToolArguments() {
        override val toolName = ToolName.CREATE_DELIVERY
    }
    data class SearchRecords(val args: SearchRecordsArguments) : ToolArguments() {
        override val toolName = ToolName.SEARCH_RECORDS
    }

    /** 编码为 ToolCall.argumentsJson。 */
    fun encode(): String = when (this) {
        is Revenue -> aiJson.encodeToString(RevenueArguments.serializer(), args)
        is Todo -> aiJson.encodeToString(TodoArguments.serializer(), args)
        is Memo -> aiJson.encodeToString(MemoArguments.serializer(), args)
        is Delivery -> aiJson.encodeToString(DeliveryArguments.serializer(), args)
        is SearchRecords -> aiJson.encodeToString(SearchRecordsArguments.serializer(), args)
    }

    fun toToolCall(): ToolCall =
        ToolCall(callId = ToolIdempotency.newCallId(), name = toolName, argumentsJson = encode())
}

/**
 * 一次结构化工具调用。`callId` 即 toolCallID，是幂等第一键。
 * 对应 iOS ToolCall（id/name/arguments）；arguments 以 JSON 字符串承载。
 */
data class ToolCall(
    val callId: String,
    val name: ToolName,
    val argumentsJson: String
) {
    fun decodeArguments(): ToolArguments = when (name) {
        ToolName.RECORD_REVENUE ->
            ToolArguments.Revenue(aiJson.decodeFromString<RevenueArguments>(argumentsJson))
        ToolName.CREATE_TODO ->
            ToolArguments.Todo(aiJson.decodeFromString<TodoArguments>(argumentsJson))
        ToolName.CREATE_MEMO ->
            ToolArguments.Memo(aiJson.decodeFromString<MemoArguments>(argumentsJson))
        ToolName.CREATE_DELIVERY ->
            ToolArguments.Delivery(aiJson.decodeFromString<DeliveryArguments>(argumentsJson))
        ToolName.SEARCH_RECORDS ->
            ToolArguments.SearchRecords(aiJson.decodeFromString<SearchRecordsArguments>(argumentsJson))
    }
}

/** 工具执行结果。对应 iOS ToolExecutionResult（去 preview 门，Android 只有 live）。 */
sealed class ToolExecutionResult {
    /** 真实落库成功 */
    data class Executed(val recordId: String, val summary: String) : ToolExecutionResult()
    /** 幂等折叠：与已有调用 / 业务指纹重复 */
    data class Duplicate(val existingToolCallId: String) : ToolExecutionResult()
    /** 执行失败（可重试，不丢 ActionCard） */
    data class Failed(val reason: String) : ToolExecutionResult()
}

/** AI 侧 JSON 编解码：未知字段容错（旧 JSON 缺字段可解码）。 */
val aiJson: Json = Json {
    ignoreUnknownKeys = true
    explicitNulls = false
    encodeDefaults = false
}

/** Provider tool 定义（给 OpenAiCompatProvider 组 tools payload）。 */
data class ToolDefinition(
    val name: ToolName,
    val description: String,
    val parameters: JsonObject
)

/**
 * 工具目录。对应 iOS ToolCatalog + ToolArgumentValidator。
 * 顺序固定（liteTools），便于快照测试。
 */
object ToolCatalog {

    fun isRegistered(name: ToolName): Boolean = name in ToolName.liteTools

    fun definitions(): List<ToolDefinition> = ToolName.liteTools.map {
        ToolDefinition(name = it, description = toolDescription(it), parameters = schemaFor(it))
    }

    /**
     * 参数校验：返回缺失 / 非法字段的中文说明；空数组表示可出确认卡。
     * 对应 iOS ToolArgumentValidator.validate。
     */
    fun validate(call: ToolCall): List<String> {
        if (!isRegistered(call.name)) {
            return listOf("当前版本不支持该操作：${call.name.wireName}")
        }
        return when (val args = call.decodeArguments()) {
            is ToolArguments.Revenue ->
                if ((args.args.amount ?: 0.0) > 0) emptyList() else listOf("缺少有效金额")
            is ToolArguments.Todo ->
                if (!args.args.title.isNullOrBlank()) emptyList() else listOf("缺少待办标题")
            is ToolArguments.Memo -> buildList {
                if (args.args.title.isNullOrBlank()) add("缺少备忘标题")
                if (args.args.content.isNullOrBlank()) add("缺少备忘内容")
            }
            is ToolArguments.Delivery -> {
                val a = args.args
                val hasCustomer = !a.customer.isNullOrBlank()
                val hasContent = !a.content.isNullOrBlank() || !a.goodsName.isNullOrBlank()
                if (!hasCustomer && !hasContent) listOf("缺少配送客户 / 房号或商品") else emptyList()
            }
            is ToolArguments.SearchRecords -> emptyList()
        }
    }

    private fun toolDescription(name: ToolName): String = when (name) {
        ToolName.SEARCH_RECORDS ->
            "查询经营记录：今日营业额、今日待办、最近备忘、临期商品、今日配送。只读，可自动执行。"
        ToolName.RECORD_REVENUE ->
            "记录一笔营业额。金额必填数字；来源如美团/饿了么/现金/微信；日期用 ISO8601。"
        ToolName.CREATE_TODO ->
            "新建一条待办。标题必填；到期时间用 ISO8601；优先级 0 普通/1 重要/2 紧急。"
        ToolName.CREATE_MEMO ->
            "新建一条备忘。标题和内容必填。"
        ToolName.CREATE_DELIVERY ->
            "新建一条配送需求。客户与商品不能同时为空；时间为 ISO8601，时间原文保留用户说法。"
    }

    /** 必填规则 1:1 iOS ToolCatalog.required：revenue[amount] / todo[title] / memo[title,content] / delivery[] / search[kinds] */
    private fun requiredFor(name: ToolName): List<String> = when (name) {
        ToolName.RECORD_REVENUE -> listOf("amount")
        ToolName.CREATE_TODO -> listOf("title")
        ToolName.CREATE_MEMO -> listOf("title", "content")
        ToolName.CREATE_DELIVERY -> emptyList()
        ToolName.SEARCH_RECORDS -> listOf("kinds")
    }

    private fun schemaFor(name: ToolName): JsonObject = buildJsonObject {
        put("type", "object")
        putJsonObject("properties") {
            when (name) {
                ToolName.RECORD_REVENUE -> {
                    putJsonObject("amount") {
                        put("type", "number"); put("description", "营业额金额，如 680")
                    }
                    putJsonObject("source") {
                        put("type", "string"); put("description", "来源，如 美团 / 现金 / 微信")
                    }
                    putJsonObject("date") {
                        put("type", "string"); put("format", "date-time")
                        put("description", "ISO8601 日期")
                    }
                    putJsonObject("note") { put("type", "string"); put("description", "备注") }
                }
                ToolName.CREATE_TODO -> {
                    putJsonObject("title") { put("type", "string"); put("description", "待办标题") }
                    putJsonObject("detail") { put("type", "string"); put("description", "原始描述") }
                    putJsonObject("dueDate") { put("type", "string"); put("format", "date-time") }
                    putJsonObject("priority") {
                        put("type", "integer"); put("description", "0 普通 / 1 重要 / 2 紧急")
                    }
                }
                ToolName.CREATE_MEMO -> {
                    putJsonObject("title") {
                        put("type", "string"); put("description", "备忘标题（≤20 字）")
                    }
                    putJsonObject("content") { put("type", "string"); put("description", "备忘完整内容") }
                }
                ToolName.CREATE_DELIVERY -> {
                    putJsonObject("customer") {
                        put("type", "string")
                        put("description", "客户名，如 阿东；没有客户名时留空，不要用数字或金额代替")
                    }
                    putJsonObject("roomOrAddress") {
                        put("type", "string"); put("description", "房号或地址，如 302 / 幸福路9号")
                    }
                    putJsonObject("phone") { put("type", "string") }
                    putJsonObject("content") {
                        put("type", "string"); put("description", "商品与数量，如 珍珠奶茶 3杯；多件用、隔开")
                    }
                    putJsonObject("goodsName") { put("type", "string"); put("description", "商品名，如 珍珠奶茶") }
                    putJsonObject("quantity") { put("type", "string"); put("description", "数量原文，如 3杯 / 两箱") }
                    putJsonObject("deliveryTime") { put("type", "string"); put("format", "date-time") }
                    putJsonObject("deliveryTimeText") { put("type", "string") }
                    putJsonObject("amount") {
                        put("type", "number")
                        put("description", "配送商品总金额，如 45；没有提到金额时留空")
                    }
                    putJsonObject("note") { put("type", "string") }
                }
                ToolName.SEARCH_RECORDS -> {
                    putJsonObject("query") { put("type", "string") }
                    putJsonObject("kinds") {
                        put("type", "array")
                        putJsonObject("items") {
                            put("type", "string")
                            putJsonArray("enum") {
                                BusinessRecordKind.entries.forEach { add(JsonPrimitive(it.wireName)) }
                            }
                        }
                    }
                }
            }
        }
        putJsonArray("required") { requiredFor(name).forEach { add(JsonPrimitive(it)) } }
    }
}

// MARK: - ActionCard 字段展示（仅本机 UI；不参与 Provider payload）

private val dayFormatter: DateTimeFormatter =
    DateTimeFormatter.ofPattern("M月d日", Locale.CHINA)
private val dayTimeFormatter: DateTimeFormatter =
    DateTimeFormatter.ofPattern("M月d日 HH:mm", Locale.CHINA)

private fun dayText(millis: Long): String =
    Instant.ofEpochMilli(millis).atZone(ZoneId.systemDefault()).format(dayFormatter)

private fun dayTimeText(millis: Long): String =
    Instant.ofEpochMilli(millis).atZone(ZoneId.systemDefault()).format(dayTimeFormatter)

internal fun aiMoney(value: Double): String =
    if (value == kotlin.math.round(value).toDouble()) "%.0f".format(Locale.US, value)
    else "%.2f".format(Locale.US, value)

/** 确认卡上展示的「标签 / 值」行，顺序固定。对应 iOS ToolArguments.fieldRows。 */
fun ToolArguments.fieldRows(): List<Pair<String, String>> = when (this) {
    is ToolArguments.Revenue -> buildList {
        add("金额" to "¥" + aiMoney(args.amount ?: 0.0))
        args.source?.takeIf { it.isNotEmpty() }?.let { add("来源" to it) }
        args.date?.let { add("日期" to dayText(it)) }
        args.note?.takeIf { it.isNotEmpty() }?.let { add("备注" to it) }
    }
    is ToolArguments.Todo -> buildList {
        add("待办" to (args.title ?: ""))
        args.dueDate?.let { add("时间" to dayTimeText(it)) }
        val p = args.priority ?: 0
        if (p > 0) add("优先级" to if (p == 2) "紧急" else "重要")
        args.detail?.takeIf { it.isNotEmpty() && it != args.title }?.let { add("原文" to it) }
    }
    is ToolArguments.Memo -> buildList {
        add("备忘" to (args.title ?: ""))
        args.content?.takeIf { it.isNotEmpty() && it != args.title }?.let { add("内容" to it) }
    }
    is ToolArguments.Delivery -> buildList {
        val a = args
        a.customer?.trim()?.takeIf { it.isNotEmpty() }?.let { add("客户" to it) }
        a.roomOrAddress?.trim()?.takeIf { it.isNotEmpty() && it != a.customer }
            ?.let { add("地址" to it) }
        val timeText = a.deliveryTimeText?.takeIf { it.isNotEmpty() }
        if (timeText != null) add("时间" to timeText)
        else a.deliveryTime?.let { add("时间" to dayTimeText(it)) }
        val goods = a.content
            ?: listOfNotNull(a.goodsName, a.quantity).filter { it.isNotEmpty() }
                .joinToString(" ")
        if (goods.isNotEmpty()) add("商品" to goods)
        val amount = a.amount ?: 0.0
        if (amount > 0) add("金额" to "¥" + aiMoney(amount))
        a.phone?.takeIf { it.isNotEmpty() }?.let { add("电话" to it) }
        a.note?.takeIf { it.isNotEmpty() }?.let { add("备注" to it) }
    }
    is ToolArguments.SearchRecords -> buildList {
        args.query?.takeIf { it.isNotEmpty() }?.let { add("问题" to it) }
        add("范围" to args.kinds.joinToString("、") { it.wireName })
    }
}
