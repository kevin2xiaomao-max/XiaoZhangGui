import Foundation

// MARK: - V3.3 Lite · 收款码模型与轻量 metadata 持久化
//
// 隐私边界（V3.3 Payment QR）：
// - 本文件只持久化轻量 metadata：ID / 显示名称 / 类型 / 本地文件名 / 排序 / 创建时间
// - 原始收款码图片 Data / base64 绝不进入 UserDefaults（图片见 PaymentCodeImageStore）
// - 不上传、不发网络请求、不提供给 AI / Provider

/// 收款码类型
enum PaymentCodeKind: String, Codable, CaseIterable, Identifiable {
    case wechat
    case alipay
    case custom

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .wechat: return "微信收款码"
        case .alipay: return "支付宝收款码"
        case .custom: return "自定义二维码"
        }
    }

    /// 列表/全屏用 SF Symbol（不使用任何品牌商标素材）
    var iconName: String {
        switch self {
        case .wechat: return "message.fill"
        case .alipay: return "creditcard.fill"
        case .custom: return "qrcode"
        }
    }
}

/// 一张收款码的轻量描述（图片本体在文件系统）
struct PaymentCode: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var kind: PaymentCodeKind
    /// Application Support/PaymentCodes/ 下的文件名（仅文件名，不含路径）
    var fileName: String
    let createdAt: Date
    /// 追加顺序，从 0 开始；UI 始终按 order 升序展示
    var order: Int
}

enum PaymentCodeError: Error, Equatable {
    /// 图片数据无法解码为 UIImage（空文件 / 损坏 / 非图片格式）
    case invalidImageData
}

/// 收款码 metadata 存储：UserDefaults 中的一小段 JSON。
/// - 注入 UserDefaults（测试用独立 suite），生产使用 .standard
struct PaymentCodeMetadataStore {
    static let storageKey = "xzg.paymentCodes.metadata.v1"

    let defaults: UserDefaults
    let key: String

    init(defaults: UserDefaults = .standard, key: String = PaymentCodeMetadataStore.storageKey) {
        self.defaults = defaults
        self.key = key
    }

    func load() -> [PaymentCode] {
        guard let data = defaults.data(forKey: key) else { return [] }
        guard let codes = try? JSONDecoder.iso8601.decode([PaymentCode].self, from: data) else {
            // 损坏的 metadata 不允许拖垮功能：按空列表处理（图片文件不做扫描式清理）
            return []
        }
        return codes.sorted { lhs, rhs in
            lhs.order != rhs.order ? lhs.order < rhs.order : lhs.createdAt < rhs.createdAt
        }
    }

    func save(_ codes: [PaymentCode]) {
        guard let data = try? JSONEncoder.iso8601.encode(codes) else { return }
        defaults.set(data, forKey: key)
    }

    func clear() {
        defaults.removeObject(forKey: key)
    }
}

// MARK: - JSON 编解码（createdAt 用 ISO8601）

private extension JSONEncoder {
    static var iso8601: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

private extension JSONDecoder {
    static var iso8601: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
