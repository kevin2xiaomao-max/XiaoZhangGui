import Foundation
import SwiftUI

// MARK: - V32 / Theme · 主题唯一入口（b28 T23 / T26）
//
// 设计依据：spec FR-22.1 / FR-22.10 / NFR-8 / NFR-10
// - ThemeStore 是主题/壁纸配置的唯一读写入口，经 environment 注入
// - 视图不得直接读写 UserDefaults 主题键
// - 首次初始化时对旧 app_theme_name 做一次性迁移（标记 v32_theme_migrated）
// - 默认组合 warmCream + emerald 等同 b27 视觉

/// 主题状态唯一来源。`@Observable` 让所有访问其属性的 View 自动刷新。
@MainActor
@Observable
final class ThemeStore {
    static let shared = ThemeStore()

    private let defaults: UserDefaults

    /// 当前 Accent 主题
    private(set) var accentTheme: AccentTheme
    /// 当前 Background 主题
    private(set) var backgroundTheme: BackgroundTheme
    /// 当前壁纸配置
    private(set) var wallpaper: WallpaperConfig

    /// 解析后的当前调色板（仅 MainActor 读取）
    var backgroundPalette: BackgroundPalette { backgroundTheme.palette }
    var accentPalette: AccentPalette { accentTheme.palette }

    private enum Keys {
        static let accent = "v32.theme.accent"
        static let background = "v32.theme.background"
        static let wallpaper = "v32.theme.wallpaper"
        static let migrated = "v32_theme_migrated"
        static let legacyAppThemeName = "app_theme_name"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        // T26 一次性迁移：旧 app_theme_name → 新 accent + background
        if !defaults.bool(forKey: Keys.migrated) {
            let legacy = defaults.string(forKey: Keys.legacyAppThemeName) ?? ""
            let mapped = ThemeMigration.map(legacy: legacy)
            defaults.set(mapped.accent.rawValue, forKey: Keys.accent)
            defaults.set(mapped.background.rawValue, forKey: Keys.background)
            defaults.set(true, forKey: Keys.migrated)
        }

        let accentRaw = defaults.string(forKey: Keys.accent) ?? AccentTheme.default.rawValue
        let bgRaw = defaults.string(forKey: Keys.background) ?? BackgroundTheme.default.rawValue
        self.accentTheme = AccentTheme(rawValue: accentRaw) ?? .default
        self.backgroundTheme = BackgroundTheme(rawValue: bgRaw) ?? .default

        if let data = defaults.data(forKey: Keys.wallpaper),
           let config = try? JSONDecoder().decode(WallpaperConfig.self, from: data) {
            self.wallpaper = config
        } else {
            self.wallpaper = .disabled
        }
    }

    // MARK: - 主题切换（即时全局生效）

    func setAccent(_ theme: AccentTheme) {
        accentTheme = theme
        defaults.set(theme.rawValue, forKey: Keys.accent)
    }

    func setBackground(_ theme: BackgroundTheme) {
        backgroundTheme = theme
        defaults.set(theme.rawValue, forKey: Keys.background)
    }

    func setWallpaper(_ config: WallpaperConfig) {
        wallpaper = config
        if let data = try? JSONEncoder().encode(config) {
            defaults.set(data, forKey: Keys.wallpaper)
        }
    }

    func disableWallpaper() {
        setWallpaper(.disabled)
    }
}

/// 旧 app_theme_name → 新 (Accent, Background) 映射（spec Migration 章节）
enum ThemeMigration {
    static func map(legacy: String?) -> (accent: AccentTheme, background: BackgroundTheme) {
        guard let legacy else { return (.default, .default) }
        switch legacy {
        case "Emerald", "Mint": return (.emerald, .warmCream)
        case "Blue Purple": return (.purple, .warmCream)
        case "Graphite": return (.graphite, .warmCream)
        case "Glacier Blue": return (.blue, .warmCream)
        case "Coral": return (.coral, .warmCream)
        default: return (.default, .default)
        }
    }
}
