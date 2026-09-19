import Foundation
import LLMProviderKit
import LLMProviderKitOpenAI

// MARK: - V3.3 Lite · OpenAI 兼容 Provider 适配（DeepSeek 主 Provider）
//
// 🔒 本文件是全工程唯一允许 import LLMProviderKit / LLMProviderKitOpenAI 的业务文件。
// 第三方类型（LLMRequest / LLMResponse / OpenAIProvider …）不得出现在本文件之外，
// AgentCore / ToolRouter / UI 只认识工程内的 AIProvider / ProviderTurn / ToolCall。
// DeepSeek、OpenRouter、Groq、本地 vLLM 等任何 OpenAI /chat/completions 兼容端点
// 都通过本适配器接入，业务层不感知厂商。

/// 第三方「单次补全」接缝：真实实现是 OpenAIProvider，测试注入脚本实现。
protocol XZGChatCompleting: Sendable {
    func complete(_ request: LLMRequest) async throws -> LLMResponse
}

extension OpenAIProvider: XZGChatCompleting {}

struct OpenAICompatProvider: AIProvider {
    nonisolated let id: String
    let model: String
    /// 仅用于诊断日志（host，不含 path / Key）
    private let endpointHost: String
    private let chat: any XZGChatCompleting

    /// 正式构造：OpenAI 兼容端点 + Bearer Key。
    init(id: String, baseURL: URL, apiKey: String, model: String) {
        self.id = id
        self.model = model
        self.endpointHost = baseURL.host ?? "unknown"
        self.chat = OpenAIProvider(configuration: LLMProviderConfiguration(
            name: id,
            baseURL: baseURL,
            apiKey: apiKey,
            defaultModel: model
        ))
    }

    /// 测试构造：注入脚本 completion（不发网络请求、不消耗 Token）。
    init(id: String, model: String, chat: any XZGChatCompleting) {
        self.id = id
        self.model = model
        self.endpointHost = "test"
        self.chat = chat
    }

    func complete(_ request: ProviderRequest) async throws -> ProviderTurn {
        let llmRequest = try Self.makeRequest(request, model: model)
        let response: LLMResponse
        do {
            response = try await chat.complete(llmRequest)
        } catch let error as LLMError {
            let failure = Self.mapError(error)
            Self.log(failure, providerID: id, host: endpointHost, model: model)
            throw failure
        } catch let urlError as URLError {
            let failure = Self.mapURLError(urlError)
            Self.log(failure, providerID: id, host: endpointHost, model: model)
            throw failure
        } catch {
            let failure = ProviderFailure.network(error.localizedDescription)
            Self.log(failure, providerID: id, host: endpointHost, model: model)
            throw failure
        }
        return try Self.mapResponse(response)
    }

    private static func log(_ failure: ProviderFailure, providerID: String, host: String, model: String) {
        switch failure {
        case .http(let status, _):
            AILog.providerFailed(providerID: providerID, host: host, model: model,
                                 status: status, reason: "http")
        case .timeout:
            AILog.providerFailed(providerID: providerID, host: host, model: model,
                                 status: nil, reason: "timeout")
        case .offline:
            AILog.providerFailed(providerID: providerID, host: host, model: model,
                                 status: nil, reason: "offline")
        case .network:
            AILog.providerFailed(providerID: providerID, host: host, model: model,
                                 status: nil, reason: "network")
        case .decoding:
            AILog.providerFailed(providerID: providerID, host: host, model: model,
                                 status: nil, reason: "decoding")
        case .cancelled:
            break
        case .other:
            AILog.providerFailed(providerID: providerID, host: host, model: model,
                                 status: nil, reason: "other")
        }
    }

    // MARK: 请求构造（纯函数，可单测）

    static func makeRequest(_ request: ProviderRequest, model: String) throws -> LLMRequest {
        var messages: [LLMMessage] = [.system(systemPrompt)]

        // Lite 正常链路 context 恒空（READ 已本地回答）；若未来云端总结需要，
        // 也只能携带 ContextRedactor 产出的最小脱敏 JSON。
        if let json = request.context.json,
           let object = try? JSONSerialization.jsonObject(with: json) as? [String: Any],
           !object.isEmpty,
           let pretty = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]),
           let contextText = String(data: pretty, encoding: .utf8) {
            messages.append(.system("与当前问题相关的最小经营数据（已脱敏，勿外发）：\n\(contextText)"))
        }

        messages.append(contentsOf: request.messages.map(convert))

        let tools: [LLMToolDefinition] = ToolCatalog.definitions().map { def in
            let parameters = (try? JSONSerialization.jsonObject(with: def.jsonSchema) as? [String: Any])
                ?? ["type": "object", "properties": [:]]
            return LLMToolDefinition(
                name: def.name.rawValue,
                description: toolDescription(def.name),
                parameters: parameters
            )
        }

        return LLMRequest(
            model: model,
            messages: messages,
            temperature: 0.2,
            maxTokens: nil,
            topP: nil,
            tools: tools
        )
    }

    private static func convert(_ message: AIMessage) -> LLMMessage {
        switch message.role {
        case .system: return .system(message.content)
        case .user: return .user(message.content)
        case .assistant: return .assistant(message.content)
        // Lite 没有多轮 tool 消息；防御性映射，不让第三方角色泄漏
        case .tool: return .assistant(message.content)
        }
    }

    // MARK: 响应解析（纯函数，可单测；异常一律 fail-closed）

    static func mapResponse(_ response: LLMResponse) throws -> ProviderTurn {
        if let toolCall = response.toolCalls.first {
            return .toolCall(try decodeToolCall(toolCall))
        }
        let text = response.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            throw ProviderFailure.decoding("模型返回了空响应")
        }
        return .text(text)
    }

    static func decodeToolCall(_ tc: LLMToolCall) throws -> ToolCall {
        guard let tool = ToolName(rawValue: tc.name), ToolCatalog.isRegistered(tool) else {
            throw ProviderFailure.decoding("模型返回了当前版本不支持的工具：\(tc.name)")
        }
        let data = Data(tc.arguments.utf8)
        let decoder = JSONDecoder.aiTools

        let arguments: ToolArguments
        do {
            switch tool {
            case .recordRevenue:
                arguments = .recordRevenue(try decoder.decode(RevenueArguments.self, from: data))
            case .createTodo:
                arguments = .createTodo(try decoder.decode(TodoArguments.self, from: data))
            case .createMemo:
                arguments = .createMemo(try decoder.decode(MemoArguments.self, from: data))
            case .createDelivery:
                arguments = .createDelivery(try decoder.decode(DeliveryArguments.self, from: data))
            case .searchRecords:
                // kinds 可能被模型省略，做容错解码
                let payload = try decoder.decode(SearchRecordsPayload.self, from: data)
                arguments = .searchRecords(SearchRecordsArguments(
                    query: payload.query,
                    kinds: payload.kinds ?? []
                ))
            }
        } catch let failure as ProviderFailure {
            throw failure
        } catch {
            throw ProviderFailure.decoding("工具参数无法解析（\(tool.rawValue)）：\(error.localizedDescription)")
        }

        // 模型侧 toolCall id 作为幂等第一键（同一响应重试得到同一 id）
        return ToolCall(id: "call_\(tc.id)", name: tool, arguments: arguments)
    }

    /// searchRecords 的容错解码体（kinds 可缺省）
    private struct SearchRecordsPayload: Decodable {
        let query: String?
        let kinds: [BusinessRecordKind]?
    }

    // MARK: 错误映射（第三方错误 → 工程内 ProviderFailure）

    static func mapError(_ error: LLMError) -> ProviderFailure {
        switch error {
        case .httpError(let code, let data):
            let body = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
            return .http(status: code, body: body)
        case .networkError(let message):
            let lower = message.lowercased()
            if lower.contains("timed out") || lower.contains("timeout") || message.contains("超时") {
                return .timeout
            }
            if lower.contains("offline") || lower.contains("not connected")
                || lower.contains("no internet") || message.contains("没有网络") {
                return .offline
            }
            return .network(message)
        case .invalidResponse(let reason), .streamingError(let reason):
            return .decoding(reason)
        case .invalidRequest(let reason), .providerError(let reason),
             .unsupportedOperation(let reason), .unknownProvider(let reason):
            return .other(reason)
        }
    }

    /// URLError 细分：无网络 / 超时 / 连不上主机，给出可自救的中文分类。
    static func mapURLError(_ error: URLError) -> ProviderFailure {
        switch error.code {
        case .timedOut:
            return .timeout
        case .notConnectedToInternet, .networkConnectionLost:
            return .offline
        case .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed,
             .dataNotAllowed, .internationalRoamingOff:
            return .offline
        default:
            return .network(error.localizedDescription)
        }
    }

    // MARK: 系统提示词 / 工具说明

    static let systemPrompt = """
    你是「小掌柜」，面向个体小店老板的经营助手，用简短口语化中文回答。
    规则：
    1. 需要记录经营数据时，只能调用下方提供的工具，一次最多调用一个工具；所有记录都要用户在确认卡片上确认后才会保存；
    2. 工具参数严格符合 schema：金额用数字、日期用 ISO8601（含时区），缺失信息不要编造，改用一句话追问用户；
    3. 禁止调用未提供的工具，禁止执行删除、修改类操作；
    4. searchRecords 仅用于查询：今日营业额、今日待办、最近备忘、临期商品、今日配送；
    5. 普通聊天、知识问答、经营建议（如选品、定价、促销话术）都直接正常回答，不要调用任何工具；用户的话里出现时间词不代表要建待办，必须先分清是在「问」还是在「记」；
    6. 天气查询由本地天气能力优先处理；新闻、股价等没有对应工具的实时外部信息，直接说明暂时无法查询，绝不能为此新建待办或备忘。
    """

    static func toolDescription(_ name: ToolName) -> String {
        switch name {
        case .recordRevenue:
            return "记录一笔营业额。amount：数字金额（必填，正数）；source：来源，如 美团/微信/支付宝/现金；date：ISO8601，缺省为今天；note：备注。"
        case .createTodo:
            return "新建一条待办。title：标题（必填）；detail：详情；dueDate：ISO8601；priority：0普通/1重要/2紧急。单纯提问不要建待办；时间有歧义（如「3点」没说上午下午）时不要猜，直接追问。"
        case .createMemo:
            return "新建一条备忘。title：标题（必填）；content：正文（必填）。"
        case .createDelivery:
            return "新建一条客户配送。customer：客户名（没有就留空，禁止用数字或金额冒充）；roomOrAddress：房号或地址，如 302 / 幸福路9号；phone：电话；content：商品与数量，如 珍珠奶茶 3杯；goodsName：商品名；quantity：数量原文；amount：总金额数字；deliveryTime：ISO8601；deliveryTimeText：时间原文，如 今晚8点；note：备注。customer 与商品至少要有一个。"
        case .searchRecords:
            return "查询经营记录。kinds：数组，取值 revenueToday / todoToday / recentMemo / expiringGoods / delivery；query：可选的自然语言问题。"
        }
    }
}

// MARK: - 工具参数 JSON 解码（支持带 / 不带毫秒的 ISO8601）

extension JSONDecoder {
    /// AI 工具参数解码：日期兼容 2026-09-18T20:00:00Z 与带毫秒形式。
    static var aiTools: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let raw = try container.decode(String.self)
            if let date = AIISO8601.parse(raw) { return date }
            throw DecodingError.dataCorruptedError(
                in: container, debugDescription: "无法解析的日期：\(raw)")
        }
        return decoder
    }
}

enum AIISO8601 {
    private static let fractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let plain = ISO8601DateFormatter()

    static func parse(_ raw: String) -> Date? {
        fractional.date(from: raw) ?? plain.date(from: raw)
    }
}
