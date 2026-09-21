import Foundation

/// Shared user-facing vocabulary; the three underlying state machines remain independent.
enum QuickCaptureSemantic {
    static let listening = "正在听…"
    static let processing = "正在整理…"
    static let ready = "请确认将保存的内容"
    static let saving = "正在保存…"
    static let saved = "已保存"
    static let failed = "保存失败，请重试"

    static func savedMessage(destination: String) -> String { "已保存到：\(destination)" }
}
