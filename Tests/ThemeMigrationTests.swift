import XCTest
@testable import XiaoZhangGui

/// T26：旧 app_theme_name → 新 Accent + Background 迁移单测
///
/// 覆盖：
///   - ThemeMigration.map(legacy:) 6 个已知旧值映射
///   - 未识别字符串 → 默认 (.emerald, .warmCream)
///   - nil → 默认 (.emerald, .warmCream)
///   - ThemeStore init 一次性迁移（含幂等：第二次 init 不再读旧键）
///   - 迁移后 v32_theme_migrated 标记为 true，业务代码不再读 app_theme_name
final class ThemeMigrationTests: XCTestCase {

    // MARK: - 纯函数 ThemeMigration.map(legacy:)

    func testMapEmeraldLegacy() {
        let mapped = ThemeMigration.map(legacy: "Emerald")
        XCTAssertEqual(mapped.accent, .emerald)
        XCTAssertEqual(mapped.background, .warmCream)
    }

    func testMapMintLegacy() {
        let mapped = ThemeMigration.map(legacy: "Mint")
        XCTAssertEqual(mapped.accent, .emerald)
        XCTAssertEqual(mapped.background, .warmCream)
    }

    func testMapBluePurpleLegacy() {
        let mapped = ThemeMigration.map(legacy: "Blue Purple")
        XCTAssertEqual(mapped.accent, .purple)
        XCTAssertEqual(mapped.background, .warmCream)
    }

    func testMapGraphiteLegacy() {
        let mapped = ThemeMigration.map(legacy: "Graphite")
        XCTAssertEqual(mapped.accent, .graphite)
        XCTAssertEqual(mapped.background, .warmCream)
    }

    func testMapGlacierBlueLegacy() {
        let mapped = ThemeMigration.map(legacy: "Glacier Blue")
        XCTAssertEqual(mapped.accent, .blue)
        XCTAssertEqual(mapped.background, .warmCream)
    }

    func testMapCoralLegacy() {
        let mapped = ThemeMigration.map(legacy: "Coral")
        XCTAssertEqual(mapped.accent, .coral)
        XCTAssertEqual(mapped.background, .warmCream)
    }

    func testMapUnrecognizedStringFallsBackToDefault() {
        let mapped = ThemeMigration.map(legacy: "Some Unknown Theme")
        XCTAssertEqual(mapped.accent, .blue)
        XCTAssertEqual(mapped.background, BackgroundTheme.default)
    }

    func testMapNilFallsBackToDefault() {
        let mapped = ThemeMigration.map(legacy: nil)
        XCTAssertEqual(mapped.accent, .blue)
        XCTAssertEqual(mapped.background, BackgroundTheme.default)
    }

    func testMapEmptyStringFallsBackToDefault() {
        let mapped = ThemeMigration.map(legacy: "")
        XCTAssertEqual(mapped.accent, .blue)
        XCTAssertEqual(mapped.background, BackgroundTheme.default)
    }

    // MARK: - P5.0 palette compatibility

    func testAccentRawValuesRemainCompatibleAndRoseIsAdditive() {
        XCTAssertEqual(AccentTheme.emerald.rawValue, "emerald")
        XCTAssertEqual(AccentTheme.blue.rawValue, "blue")
        XCTAssertEqual(AccentTheme.purple.rawValue, "purple")
        XCTAssertEqual(AccentTheme.coral.rawValue, "coral")
        XCTAssertEqual(AccentTheme.graphite.rawValue, "graphite")
        XCTAssertEqual(AccentTheme.rose.rawValue, "rose")
    }

    func testEveryAccentPaletteProvidesExtendedRoleTokens() {
        for theme in AccentTheme.allCases {
            let palette = theme.palette
            _ = [palette.accent, palette.secondaryAccent, palette.heroStart, palette.heroEnd,
                 palette.selectedTint, palette.chartAccent, palette.aiAccent, palette.subtleTint]
            XCTAssertFalse(theme.displayName.isEmpty)
        }
    }

    // MARK: - ThemeStore 一次性迁移（幂等）

    /// 第一次 init 时若有旧 app_theme_name，应映射到新键并标记 v32_theme_migrated
    @MainActor
    func testThemeStoreMigratesLegacyOnFirstInit() {
        let defaults = UserDefaults(suiteName: "theme.migration.test.first")!
        defaults.removePersistentDomain(forName: "theme.migration.test.first")
        defaults.set("Coral", forKey: "app_theme_name")

        let store = ThemeStore(defaults: defaults)
        XCTAssertEqual(store.accentTheme, .coral)
        XCTAssertEqual(store.backgroundTheme, .warmCream)
        XCTAssertTrue(defaults.bool(forKey: "v32_theme_migrated"))
        XCTAssertEqual(defaults.string(forKey: "v32.theme.accent"), "coral")
        XCTAssertEqual(defaults.string(forKey: "v32.theme.background"), "warm_cream")
    }

    /// 迁移后再次 init 应保留新键，不再读 app_theme_name
    /// 即使将旧键改为别的值，也不会再迁移
    @MainActor
    func testThemeStoreMigrationIsIdempotent() {
        let defaults = UserDefaults(suiteName: "theme.migration.test.idem")!
        defaults.removePersistentDomain(forName: "theme.migration.test.idem")
        defaults.set("Coral", forKey: "app_theme_name")

        // 第一次 init 触发迁移 → coral
        _ = ThemeStore(defaults: defaults)
        XCTAssertEqual(defaults.string(forKey: "v32.theme.accent"), "coral")

        // 修改旧键，不应触发再次迁移
        defaults.set("Graphite", forKey: "app_theme_name")
        let store = ThemeStore(defaults: defaults)
        XCTAssertEqual(store.accentTheme, .coral, "已迁移后不应再次读取旧 app_theme_name")
        XCTAssertTrue(defaults.bool(forKey: "v32_theme_migrated"))
    }

    /// 无旧 app_theme_name 时，init 后应使用默认主题但迁移标记仍置 true
    @MainActor
    func testThemeStoreNoLegacyStillMarksMigrated() {
        let defaults = UserDefaults(suiteName: "theme.migration.test.none")!
        defaults.removePersistentDomain(forName: "theme.migration.test.none")

        let store = ThemeStore(defaults: defaults)
        XCTAssertEqual(store.accentTheme, .blue)
        XCTAssertEqual(store.backgroundTheme, BackgroundTheme.default)
        XCTAssertTrue(defaults.bool(forKey: "v32_theme_migrated"))
    }

    @MainActor
    func testExistingSavedThemeWinsBeforeMigrationFlag() {
        let defaults = UserDefaults(suiteName: "theme.migration.test.saved")!
        defaults.removePersistentDomain(forName: "theme.migration.test.saved")
        defaults.set("rose", forKey: "v32.theme.accent")
        defaults.set("warm_cream", forKey: "v32.theme.background")

        let store = ThemeStore(defaults: defaults)
        XCTAssertEqual(store.accentTheme, .rose)
        XCTAssertEqual(store.backgroundTheme, .warmCream)
    }

    // MARK: - 验证迁移后业务代码不依赖旧键

    /// 迁移完成后，业务代码只读 v32.theme.accent / v32.theme.background；
    /// app_theme_name 仍可留在磁盘（不删），但 ThemeStore 不再使用它。
    @MainActor
    func testThemeStoreDoesNotDeleteLegacyKey() {
        let defaults = UserDefaults(suiteName: "theme.migration.test.keep")!
        defaults.removePersistentDomain(forName: "theme.migration.test.keep")
        defaults.set("Emerald", forKey: "app_theme_name")

        _ = ThemeStore(defaults: defaults)
        // 旧键仍存在（不删，仅不再读取）
        XCTAssertEqual(defaults.string(forKey: "app_theme_name"), "Emerald")
    }
}
