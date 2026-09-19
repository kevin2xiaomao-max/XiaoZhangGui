import Foundation

// MARK: - V3.3 Lite · 工具目录（provider 中立 schema）
//
// Lite 注册且仅注册 5 个：
// - searchRecords（READ，可自动执行，但结果必须经隐私裁剪才能进 Provider）
// - recordRevenue / createTodo / createMemo / createDelivery（CREATE，必须 ActionCard 确认）
// 不注册 addExpiry / update / delete（V3.4+，且需更高级确认）。

struct ToolCatalog {
    /// Lite 允许注册的全部工具（顺序固定，便于快照测试）
    static let liteTools: [ToolName] = [
        .searchRecords,
        .recordRevenue,
        .createTodo,
        .createMemo,
        .createDelivery
    ]

    static func definitions() -> [ProviderToolDefinition] {
        liteTools.map { ProviderToolDefinition(name: $0, jsonSchema: schemaData(for: $0)) }
    }

    static func isRegistered(_ name: ToolName) -> Bool {
        liteTools.contains(name)
    }

    // MARK: schema（最小 JSON Schema，FINAL 由 Adapter 映射给 Provider）

    static func schemaData(for name: ToolName) -> Data {
        let object: [String: Any] = [
            "type": "object",
            "properties": properties(for: name),
            "required": required(for: name)
        ]
        if let data = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]) {
            return data
        }
        return Data("{}".utf8)
    }

    private static func required(for name: ToolName) -> [String] {
        switch name {
        case .recordRevenue: return ["amount"]
        case .createTodo: return ["title"]
        case .createMemo: return ["title", "content"]
        case .createDelivery: return []
        case .searchRecords: return ["kinds"]
        }
    }

    private static func properties(for name: ToolName) -> [String: Any] {
        switch name {
        case .recordRevenue:
            return [
                "amount": ["type": "number", "description": "营业额金额，如 680"],
                "source": ["type": "string", "description": "来源，如 美团 / 现金 / 微信"],
                "date": ["type": "string", "format": "date-time", "description": "ISO8601 日期"],
                "note": ["type": "string", "description": "备注"]
            ]
        case .createTodo:
            return [
                "title": ["type": "string", "description": "待办标题"],
                "detail": ["type": "string", "description": "原始描述"],
                "dueDate": ["type": "string", "format": "date-time"],
                "priority": ["type": "integer", "description": "0 普通 / 1 重要 / 2 紧急"]
            ]
        case .createMemo:
            return [
                "title": ["type": "string", "description": "备忘标题（≤20 字）"],
                "content": ["type": "string", "description": "备忘完整内容"]
            ]
        case .createDelivery:
            return [
                "customer": ["type": "string", "description": "客户名，如 阿东；没有客户名时留空，不要用数字或金额代替"],
                "roomOrAddress": ["type": "string", "description": "房号或地址，如 302 / 幸福路9号"],
                "phone": ["type": "string"],
                "content": ["type": "string", "description": "商品与数量，如 珍珠奶茶 3杯；多件用、隔开"],
                "goodsName": ["type": "string", "description": "商品名，如 珍珠奶茶"],
                "quantity": ["type": "string", "description": "数量原文，如 3杯 / 两箱"],
                "deliveryTime": ["type": "string", "format": "date-time"],
                "deliveryTimeText": ["type": "string"],
                "amount": ["type": "number", "description": "配送商品总金额，如 45；没有提到金额时留空"],
                "note": ["type": "string"]
            ]
        case .searchRecords:
            return [
                "query": ["type": "string"],
                "kinds": [
                    "type": "array",
                    "items": [
                        "type": "string",
                        "enum": ["revenueToday", "todoToday", "recentMemo", "expiringGoods", "delivery"]
                    ]
                ]
            ]
        }
    }
}

// MARK: - ActionCard 字段展示（仅本机 UI；不参与 Provider payload）

extension ToolArguments {
    /// 确认卡上展示的「标签 / 值」行，顺序固定
    var fieldRows: [(label: String, value: String)] {
        switch self {
        case .recordRevenue(let a):
            var rows: [(String, String)] = [
                ("金额", "¥" + Self.money(a.amount ?? 0))
            ]
            if let source = a.source, !source.isEmpty { rows.append(("来源", source)) }
            if let date = a.date { rows.append(("日期", Self.dayText(date))) }
            if let note = a.note, !note.isEmpty { rows.append(("备注", note)) }
            return rows.map { (label: $0.0, value: $0.1) }

        case .createTodo(let a):
            var rows: [(String, String)] = [("待办", a.title ?? "")]
            if let due = a.dueDate { rows.append(("时间", Self.dayTimeText(due))) }
            if let priority = a.priority, priority > 0 {
                rows.append(("优先级", priority == 2 ? "紧急" : "重要"))
            }
            if let detail = a.detail, !detail.isEmpty, detail != a.title {
                rows.append(("原文", detail))
            }
            return rows.map { (label: $0.0, value: $0.1) }

        case .createMemo(let a):
            var rows: [(String, String)] = [("备忘", a.title ?? "")]
            if let content = a.content, !content.isEmpty, content != a.title {
                rows.append(("内容", content))
            }
            return rows.map { (label: $0.0, value: $0.1) }

        case .createDelivery(let a):
            var rows: [(String, String)] = []
            if let customer = a.customer?.trimmingCharacters(in: .whitespacesAndNewlines),
               !customer.isEmpty {
                rows.append(("客户", customer))
            }
            if let address = a.roomOrAddress?.trimmingCharacters(in: .whitespacesAndNewlines),
               !address.isEmpty, address != a.customer {
                rows.append(("地址", address))
            }
            if let timeText = a.deliveryTimeText, !timeText.isEmpty {
                rows.append(("时间", timeText))
            } else if let time = a.deliveryTime {
                rows.append(("时间", Self.dayTimeText(time)))
            }
            let goods = a.content ?? [a.goodsName, a.quantity]
                .compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " ")
            if !goods.isEmpty { rows.append(("商品", goods)) }
            if let amount = a.amount, amount > 0 { rows.append(("金额", "¥" + Self.money(amount))) }
            if let phone = a.phone, !phone.isEmpty { rows.append(("电话", phone)) }
            if let note = a.note, !note.isEmpty { rows.append(("备注", note)) }
            return rows.map { (label: $0.0, value: $0.1) }

        case .searchRecords(let a):
            var rows: [(String, String)] = []
            if let query = a.query, !query.isEmpty { rows.append(("问题", query)) }
            rows.append(("范围", a.kinds.map(\.rawValue).joined(separator: "、")))
            return rows.map { (label: $0.0, value: $0.1) }
        }
    }

    private static func money(_ value: Double) -> String {
        if value == value.rounded() { return String(format: "%.0f", value) }
        return String(format: "%.2f", value)
    }

    private static let displayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "M月d日 HH:mm"
        return f
    }()

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "M月d日"
        return f
    }()

    private static func dayText(_ date: Date) -> String { dayFormatter.string(from: date) }
    private static func dayTimeText(_ date: Date) -> String { displayFormatter.string(from: date) }
}
