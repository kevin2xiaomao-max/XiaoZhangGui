import Foundation
import SwiftUI

// MARK: - V32 / Theme · 主题唯一入口（b28 T23 / T26）
//
// - ThemeStore 是主题/壁纸配置的唯一读写入口，经 environment 注入
// - 视图不得直接读写 UserDefaults 主题键
// - 首次初始化时对旧 app_theme_name 做一次性迁移（标记 v32_theme_migrated）
// - 默认组合 warmCream + blue（雾蓝）。旧用户按 app_theme_name 迁移，已保存的 v32 键优先

@MainActor
@Observable
final class ThemeStore {
    static let shared = ThemeStore()

    private let defaults: UserDefaults

    private(set) var accentTheme: AccentTheme
    private(set) var backgroundTheme: BackgroundTheme
    private(set) var wallpaper: WallpaperConfig

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

        if !defaults.bool(forKey: Keys.migrated) {
            let hasSavedAccent = defaults.string(forKey: Keys.accent) != nil
            let hasSavedBackground = defaults.string(forKey: Keys.background) != nil
            if !hasSavedAccent || !hasSavedBackground {
                let legacy = defaults.string(forKey: Keys.legacyAppThemeName)
                let mapped = ThemeMigration.map(legacy: legacy)
                if !hasSavedAccent { defaults.set(mapped.accent.rawValue, forKey: Keys.accent) }
                if !hasSavedBackground { defaults.set(mapped.background.rawValue, forKey: Keys.background) }
            }
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

    @discardableResult
    func applyWallpaperImage(data: Data, effect: WallpaperEffect, maskStrength: WallpaperMaskStrength) -> String? {
        let previousFileName = wallpaper.imageFileName

        guard let jpegData = ImageCodec.downscaled(data: data, maxDimension: 2048, quality: 0.84) else {
            return "图片降采样失败"
        }
        let fileName: String
        do {
            fileName = try WallpaperStorage.saveJPEGData(jpegData)
        } catch {
            return "壁纸文件落盘失败：\(error.localizedDescription)"
        }
        let blurredName = WallpaperStorage.blurredFileName(for: fileName)
        if let blurredData = ImageCodec.prerenderBlurred(data: data, blurRadius: 28, maxDimension: 1280, quality: 0.78) {
            do {
                try WallpaperStorage.saveJPEGData(blurredData, fileName: blurredName)
            } catch {
                print("壁纸预渲染模糊版本失败：\(error.localizedDescription)")
            }
        }
        let config = WallpaperConfig(
            isEnabled: true,
            imageFileName: fileName,
            effect: effect,
            maskStrength: maskStrength
        )
        setWallpaper(config)

        if let previousFileName, previousFileName != fileName {
            WallpaperStorage.deleteFile(fileName: previousFileName)
            WallpaperStorage.deleteFile(fileName: WallpaperStorage.blurredFileName(for: previousFileName))
        }
        return nil
    }

    func clearWallpaper() {
        if let fileName = wallpaper.imageFileName {
            WallpaperStorage.deleteFile(fileName: fileName)
            let blurred = WallpaperStorage.blurredFileName(for: fileName)
            WallpaperStorage.deleteFile(fileName: blurred)
        }
        disableWallpaper()
    }

    func updateWallpaperOptions(effect: WallpaperEffect, maskStrength: WallpaperMaskStrength) {
        guard wallpaper.isEnabled else { return }
        var config = wallpaper
        config.effect = effect
        config.maskStrength = maskStrength
        setWallpaper(config)
    }
}

enum ThemeMigration {
    static func map(legacy: String?) -> (accent: AccentTheme, background: BackgroundTheme) {
        guard let legacy, !legacy.isEmpty else { return (.default, .default) }
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
