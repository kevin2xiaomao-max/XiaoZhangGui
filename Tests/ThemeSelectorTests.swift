import XCTest
@testable import XiaoZhangGui

final class ThemeSelectorTests: XCTestCase {
    func testV371RootConsumesThemeAccentAndPageBackground() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let rootView = try String(
            contentsOf: root.appendingPathComponent("XiaoZhangGui/App/RootView.swift"),
            encoding: .utf8
        )
        let designSystem = try String(
            contentsOf: root.appendingPathComponent("XiaoZhangGui/DesignSystem/V371/V371DesignSystem.swift"),
            encoding: .utf8
        )

        XCTAssertTrue(rootView.contains("themeStore.accentPalette.accent"))
        XCTAssertTrue(designSystem.contains("themeStore.backgroundPalette.pageBG"))
        XCTAssertTrue(designSystem.contains("V32WallpaperBackground()"))
    }

    func testSelectorExposesAllSixThemes() {
        XCTAssertEqual(AccentTheme.allCases.count, 6)
        XCTAssertTrue(AccentTheme.allCases.contains(.blue))
        XCTAssertTrue(AccentTheme.allCases.contains(.purple))
        XCTAssertTrue(AccentTheme.allCases.contains(.emerald))
        XCTAssertTrue(AccentTheme.allCases.contains(.coral))
        XCTAssertTrue(AccentTheme.allCases.contains(.rose))
        XCTAssertTrue(AccentTheme.allCases.contains(.graphite))
    }

    @MainActor
    func testRosePersistsAcrossThemeStoreReload() {
        let suite = "theme.selector.test.rose"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let store = ThemeStore(defaults: defaults)
        store.setAccent(.rose)
        XCTAssertEqual(ThemeStore(defaults: defaults).accentTheme, .rose)
    }

    func testEveryThemeProvidesDistinctRolePalette() {
        for theme in AccentTheme.allCases {
            XCTAssertFalse(theme.palette.accent == theme.palette.heroStart)
            XCTAssertFalse(theme.displayName.isEmpty)
        }
    }
}
