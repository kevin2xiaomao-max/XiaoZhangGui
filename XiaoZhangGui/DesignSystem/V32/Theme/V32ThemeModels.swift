import Foundation
import SwiftUI

// MARK: - V32 / Theme · 主题模型（b28 T23）
//
// 设计依据：spec FR-22.2 / FR-22.3 / FR-22.4 / FR-22.10
// - BackgroundTheme 与 AccentTheme 正交，可任意组合
// - rawValue 即持久化键，迁移与回退均以字符串走
// - WallpaperConfig 落盘文件名 + 效果/遮罩档位

/// Accent 主题（点缀色 5 套，spec FR-22.4）。
/// rawValue 即持久化键。
enum AccentTheme: String, CaseIterable, Sendable {
    case emerald = "emerald"      // 墨绿（默认）
    case blue = "blue"
    case purple = "purple"
    case coral = "coral"          // 珊瑚 / 柔橙
    case graphite = "graphite"    // 石墨

    static let `default`: AccentTheme = .emerald

    var displayName: String {
        switch self {
        case .emerald: return "墨绿"
        case .blue: return "霁蓝"
        case .purple: return "紫罗兰"
        case .coral: return "珊瑚"
        case .graphite: return "石墨"
        }
    }
}

/// 背景主题（6 套，spec FR-22.3）。
/// rawValue 即持久化键。
enum BackgroundTheme: String, CaseIterable, Sendable {
    case warmCream = "warm_cream"          // 暖米（默认，等同 b27）
    case pureWhite = "pure_white"
    case sageGreen = "sage_green"
    case hazeBlue = "haze_blue"
    case neutralGray = "neutral_gray"
    case softLilac = "soft_lilac"

    static let `default`: BackgroundTheme = .warmCream

    var displayName: String {
        switch self {
        case .warmCream: return "暖米"
        case .pureWhite: return "纯净白"
        case .sageGreen: return "鼠尾草"
        case .hazeBlue: return "雾霾蓝"
        case .neutralGray: return "中性灰"
        case .softLilac: return "柔紫"
        }
    }
}

/// 壁纸效果档（spec FR-22.8）
enum WallpaperEffect: String, CaseIterable, Sendable, Codable {
    case original = "original"   // 原图（仅遮罩）
    case soft = "soft"           // 柔和（降饱和 / 提亮）
    case blurred = "blurred"     // 模糊（预渲染缓存）

    static let `default`: WallpaperEffect = .soft
}

/// 壁纸遮罩强度（spec FR-22.8）
enum WallpaperMaskStrength: String, CaseIterable, Sendable, Codable {
    case light = "light"
    case medium = "medium"
    case strong = "strong"

    static let `default`: WallpaperMaskStrength = .medium
}

/// 壁纸配置（落盘文件名 + 效果 + 遮罩 + 启用开关）
struct WallpaperConfig: Codable, Equatable, Sendable {
    var isEnabled: Bool
    var imageFileName: String?      // Application Support/Appearance 下的文件名
    var effect: WallpaperEffect
    var maskStrength: WallpaperMaskStrength

    static let disabled = WallpaperConfig(
        isEnabled: false,
        imageFileName: nil,
        effect: .default,
        maskStrength: .default
    )
}
