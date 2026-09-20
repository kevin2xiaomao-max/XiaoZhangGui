import XCTest
@testable import XiaoZhangGui

final class ThemeSelectorTests: XCTestCase {
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
