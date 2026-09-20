import XCTest
@testable import XiaoZhangGui

final class ThemeMigrationTests: XCTestCase {

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

    func testDefaultAccentIsBlueForNewInstalls() {
        XCTAssertEqual(AccentTheme.default, .blue)
        XCTAssertEqual(BackgroundTheme.default, .warmCream)
    }

    func testMapUnrecognizedStringFallsBackToDefault() {
        let mapped = ThemeMigration.map(legacy: "Some Unknown Theme")
        XCTAssertEqual(mapped.accent, AccentTheme.default)
        XCTAssertEqual(mapped.background, BackgroundTheme.default)
    }

    func testMapNilFallsBackToDefault() {
        let mapped = ThemeMigration.map(legacy: nil)
        XCTAssertEqual(mapped.accent, AccentTheme.default)
        XCTAssertEqual(mapped.background, BackgroundTheme.default)
    }

    func testMapEmptyStringFallsBackToDefault() {
        let mapped = ThemeMigration.map(legacy: "")
        XCTAssertEqual(mapped.accent, AccentTheme.default)
        XCTAssertEqual(mapped.background, BackgroundTheme.default)
    }

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

    @MainActor
    func testThemeStoreMigrationIsIdempotent() {
        let defaults = UserDefaults(suiteName: "theme.migration.test.idem")!
        defaults.removePersistentDomain(forName: "theme.migration.test.idem")
        defaults.set("Coral", forKey: "app_theme_name")

        _ = ThemeStore(defaults: defaults)
        XCTAssertEqual(defaults.string(forKey: "v32.theme.accent"), "coral")

        defaults.set("Graphite", forKey: "app_theme_name")
        let store = ThemeStore(defaults: defaults)
        XCTAssertEqual(store.accentTheme, .coral, "已迁移后不应再次读取旧 app_theme_name")
        XCTAssertTrue(defaults.bool(forKey: "v32_theme_migrated"))
    }

    @MainActor
    func testThemeStoreNoLegacyStillMarksMigrated() {
        let defaults = UserDefaults(suiteName: "theme.migration.test.none")!
        defaults.removePersistentDomain(forName: "theme.migration.test.none")

        let store = ThemeStore(defaults: defaults)
        XCTAssertEqual(store.accentTheme, AccentTheme.default)
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

    @MainActor
    func testThemeStoreDoesNotDeleteLegacyKey() {
        let defaults = UserDefaults(suiteName: "theme.migration.test.keep")!
        defaults.removePersistentDomain(forName: "theme.migration.test.keep")
        defaults.set("Emerald", forKey: "app_theme_name")

        _ = ThemeStore(defaults: defaults)
        XCTAssertEqual(defaults.string(forKey: "app_theme_name"), "Emerald")
    }
}
