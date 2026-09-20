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

    // MARK: - T27 壁纸 apply / clear / load

    /// 应用壁纸：降采样 → 预渲染模糊版 → 落盘 → 更新配置
    /// - Parameters:
    ///   - data: 原始图 Data（来自 PhotosPicker / fileImporter）
    ///   - effect: 效果档
    ///   - maskStrength: 遮罩强度
    /// - Returns: 失败时返回 error 描述，成功返回 nil
    @discardableResult
    func applyWallpaperImage(data: Data, effect: WallpaperEffect, maskStrength: WallpaperMaskStrength) -> String? {
        // P2-1：先记录旧文件名。新壁纸成功落盘并切换配置前，绝不删除任何旧文件——
        // 处理失败时旧壁纸必须原样保留（配置仍指向旧文件）。
        let previousFileName = wallpaper.imageFileName

        // 1. 降采样
        guard let jpegData = ImageCodec.downscaled(data: data, maxDimension: 2048, quality: 0.84) else {
            return "图片降采样失败"
        }
        // 2. 落盘原文件
        let fileName: String
        do {
            fileName = try WallpaperStorage.saveJPEGData(jpegData)
        } catch {
            return "壁纸文件落盘失败：\(error.localizedDescription)"
        }
        // 3. 预渲染模糊版本（仅当 effect=blurred 或保险起见都生成）
        let blurredName = WallpaperStorage.blurredFileName(for: fileName)
        if let blurredData = ImageCodec.prerenderBlurred(data: data, blurRadius: 28, maxDimension: 1280, quality: 0.78) {
            do {
                try WallpaperStorage.saveJPEGData(blurredData, fileName: blurredName)
            } catch {
                // 预渲染失败不阻塞，V32WallpaperBackground 会回退到 .blur
                print("壁纸预渲染模糊版本失败：\(error.localizedDescription)")
            }
        }
        // 4. 更新配置（此刻起当前壁纸已是新文件）
        let config = WallpaperConfig(
            isEnabled: true,
            imageFileName: fileName,
            effect: effect,
            maskStrength: maskStrength
        )
        setWallpaper(config)

        // 5. P2-1：新壁纸已生效，再清理上一张壁纸的原图 / blurred 文件。
        // 只删除配置中记录的明确文件名（不扫描目录），且绝不删除当前文件。
        if let previousFileName, previousFileName != fileName {
            WallpaperStorage.deleteFile(fileName: previousFileName)
            WallpaperStorage.deleteFile(fileName: WallpaperStorage.blurredFileName(for: previousFileName))
        }
        return nil
    }

    /// 清除当前壁纸（删除磁盘文件 + 配置置空）
    func clearWallpaper() {
        if let fileName = wallpaper.imageFileName {
            WallpaperStorage.deleteFile(fileName: fileName)
            let blurred = WallpaperStorage.blurredFileName(for: fileName)
            WallpaperStorage.deleteFile(fileName: blurred)
        }
        disableWallpaper()
    }

    /// 仅更新效果/遮罩档（保留图片文件名）
    func updateWallpaperOptions(effect: WallpaperEffect, maskStrength: WallpaperMaskStrength) {
        guard wallpaper.isEnabled else { return }
        var config = wallpaper
        config.effect = effect
        config.maskStrength = maskStrength
        setWallpaper(config)
    }
}

/// 旧 app_theme_name → 新 (Accent, Background) 映射（spec Migration 章节）
enum ThemeMigration {
    static func map(legacy: String?) -> (accent: AccentTheme, background: BackgroundTheme) {
        guard let legacy, !legacy.isEmpty else { return (.blue, .default) }
        switch legacy {
        case "Emerald", "Mint": return (.emerald, .warmCream)
        case "Blue Purple": return (.purple, .warmCream)
        case "Graphite": return (.graphite, .warmCream)
        case "Glacier Blue": return (.blue, .warmCream)
        case "Coral": return (.coral, .warmCream)
        default: return (.blue, .default)
        }
    }
}
