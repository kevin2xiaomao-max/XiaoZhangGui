import Foundation
import os

// MARK: - V3.3 AI REAL · 统一用户可见错误映射
//
// 真机问题：ProviderFailure 最终常被压成 Swift 默认 localizedDescription
// （"The operation couldn't be completed. (…ProviderFailure error 2.)"），
// 用户无法判断是 Key 错、余额不足还是断网。
//
// 规则：
// - 所有进入聊天 UI 的错误都经本映射转成明确中文；
// - 不暴露 ProviderFailure / NSError 原始类型名、不暴露端点响应原文中的敏感字段；
// - DEBUG 日志只记录 provider id / HTTP status / endpoint host / model id，
//   严禁记录 API Key、Authorization header、完整经营数据。

enum UserFacingAIError {
    static func message(for error: Error) -> String {
        switch error {
        case let failure as ProviderFailure:
            return message(for: failure)
        case let agentError as AgentError:
            return agentError.errorDescription ?? "AI 服务暂时不可用，请稍后重试"
        case let urlError as URLError:
            return message(for: urlError)
        case is CancellationError:
            return "已取消"
        default:
            return "AI 服务暂时不可用，请稍后重试"
        }
    }

    static func message(for failure: ProviderFailure) -> String {
        switch failure {
        case .http(let status, _):
            return message(forHTTPStatus: status)
        case .offline:
            return "当前没有网络连接，请检查网络后重试"
        case .timeout:
            return "网络请求超时，请检查网络后重试"
        case .network:
            return "网络连接失败，请检查网络后重试"
        case .decoding:
            return "AI 返回的内容无法解析，请重试一次"
        case .cancelled:
            return "已取消"
        case .other:
            return "AI 服务暂时不可用，请稍后重试"
        }
    }

    static func message(forHTTPStatus status: Int) -> String {
        switch status {
        case 401, 403:
            return "API Key 无效，请检查后重新保存"
        case 402:
            return "账户余额不足，请前往 DeepSeek 账户充值后重试"
        case 400, 422:
            // DeepSeek 模型名错误实际常以 400 invalid_request_error 返回，422 为参数错误
            return "API 参数或模型配置错误，请检查模型设置"
        case 404:
            return "服务地址或模型不存在，请检查端点与模型设置"
        case 429:
            return "请求过于频繁，请稍后再试"
        case 500...599:
            return "DeepSeek 服务暂时不可用，请稍后再试"
        default:
            return "AI 服务请求失败（\(status)），请稍后再试"
        }
    }

    static func message(for urlError: URLError) -> String {
        switch urlError.code {
        case .notConnectedToInternet, .networkConnectionLost:
            return "当前没有网络连接，请检查网络后重试"
        case .timedOut:
            return "网络请求超时，请检查网络后重试"
        case .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed:
            return "无法连接到服务地址，请检查网络或端点设置"
        default:
            return "网络连接失败，请检查网络后重试"
        }
    }
}

// MARK: - DEBUG 诊断日志（敏感信息红线）

enum AILog {
    private static let logger = Logger(subsystem: "com.xiaozhanggui.ai", category: "provider")

    /// Provider 请求失败诊断。只允许传非敏感字段。
    /// - Parameters:
    ///   - providerID: 工程内 provider 标识（如 primary-deepseek）
    ///   - host: 端点 host（不含 path / key）
    ///   - model: 模型 ID
    ///   - status: HTTP 状态码（网络错误传 nil）
    ///   - reason: 错误分类短标签（如 timeout/offline/decoding），禁止放响应原文
    static func providerFailed(providerID: String, host: String, model: String,
                               status: Int?, reason: String) {
        #if DEBUG
        if let status {
            logger.error("provider=\(providerID, privacy: .public) host=\(host, privacy: .public) model=\(model, privacy: .public) http=\(status, privacy: .public) reason=\(reason, privacy: .public)")
        } else {
            logger.error("provider=\(providerID, privacy: .public) host=\(host, privacy: .public) model=\(model, privacy: .public) reason=\(reason, privacy: .public)")
        }
        #endif
    }
}
