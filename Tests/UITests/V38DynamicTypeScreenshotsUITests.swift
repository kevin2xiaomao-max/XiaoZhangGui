import XCTest

/// V3.8 封板 · 动态字体多档位截图与随动验证（仅新增测试，生产代码零改动）。
///
/// 背景：PR-D 把首页 Hero 金额与日期数字改为 @ScaledMetric 随动，但多档位
/// （xL / XXL / AX3）从未逐档截图验证。本测试用启动参数
/// `-UIPreferredContentSizeCategoryName` 注入三档字号，逐档访问四页
/// （首页 / 待办 / 日历 / 经营），留截图附件并做三类检查：
///
/// 1. 机制自检（硬断言，不受记录模式开关影响）：本 harness 有启动参数
///    不传导的前科（深色模式参数曾无效）。以首页日期数字（@ScaledMetric
///    relativeTo .largeTitle，源码可证随动）为参照，三档高度必须单调
///    增长且 AX3 明显大于 xL；否则说明注入未生效，截图无意义，直接红。
/// 2. 层级不倒挂（布局断言）：首页 Hero 高度 > 日期数字与分区标题高度；
///    其余页按各页源码可稳定定位的标题/正文对校验（见各 visit 方法注释）。
/// 3. 无截断/溢出（布局断言）：关键元素必须存在，且 frame 横向落在窗口内。
///
/// 布局断言（2/3）由 `layoutAssertionsStrict` 控制：严格模式下失败即红；
/// 记录模式下只把数值与失败项写进报告附件（发现清单流程用）。
/// 每项实测数值（元素名 / 高度 / frame）都写入 `font-report` 文本附件。
final class V38DynamicTypeScreenshotsUITests: XCTestCase {

    /// 布局断言模式：true = 严格（失败即红）；false = 记录模式（只记不红）。
    /// 机制断言恒为硬断言，不受此开关影响。
    private let layoutAssertionsStrict = true

    private struct Category {
        let name: String     // 截图/报告命名：xL / XXL / AX3
        let argValue: String // -UIPreferredContentSizeCategoryName 的取值
    }

    private let categories: [Category] = [
        Category(name: "xL", argValue: "UICTContentSizeCategoryXL"),
        Category(name: "XXL", argValue: "UICTContentSizeCategoryXXL"),
        Category(name: "AX3", argValue: "UICTContentSizeCategoryAccessibilityXXXL"),
    ]

    private var app: XCUIApplication!
    private var reportLines: [String] = []
    private var findings: [String] = []

    override func setUpWithError() throws {
        continueAfterFailure = true
    }

    override func tearDownWithError() throws {
        if let app, app.state != .notRunning {
            app.terminate()
        }
    }

    // MARK: - 启动（按档位注入字号）

    private func launch(category: Category) {
        app = XCUIApplication()
        app.launchArguments = [
            "--ui-testing",
            "--ui-testing-id", UUID().uuidString,
            "-UIPreferredContentSizeCategoryName", category.argValue,
        ]
        addUIInterruptionMonitor(withDescription: "Location permission") { alert in
            let allow = ["使用 App 时允许", "Allow While Using App", "允许一次", "Allow Once"]
                .first { alert.buttons[$0].exists }
            if let allow { alert.buttons[allow].tap(); return true }
            return false
        }
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 20),
                      "[\(category.name)] App 未进入前台")
        XCTAssertTrue(element("screen.home").waitForExistence(timeout: 15),
                      "[\(category.name)] 首页未出现")
        Thread.sleep(forTimeInterval: 0.6)
    }

    // MARK: - 元素定位（沿用现有 UI 测试的 descendants(.any) 口径）

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    /// 首页日期数字：accessibilityLabel 为「…月…日星期…」（month().day().weekday(.wide)），
    /// 与同排的「…月星期…」副标题以是否含「日」区分。字体为
    /// @ScaledMetric(relativeTo: .largeTitle) 64pt —— 机制自检的主参照。
    private func homeDateNumber() -> XCUIElement {
        let pred = NSPredicate(format: "label CONTAINS %@ AND label CONTAINS %@", "日", "星期")
        return app.staticTexts.matching(pred).firstMatch
    }

    /// 日历页 masthead 日期：「10月24日」（month(.wide).day()），不含「星期」，
    /// 与同页的「…日 · 星期…」摘要行以此区分。
    private func calendarMastheadDate() -> XCUIElement {
        let pred = NSPredicate(format: "label CONTAINS %@ AND label CONTAINS %@ AND NOT (label CONTAINS %@)",
                               "月", "日", "星期")
        return app.staticTexts.matching(pred).firstMatch
    }

    /// 日历页星期副标题：label 恰为「星期X」（.subheadline，随动字体）。
    private func calendarWeekday() -> XCUIElement {
        let pred = NSPredicate(format: "label MATCHES %@", "星期[一二三四五六日]")
        return app.staticTexts.matching(pred).firstMatch
    }

    private func navTitle(_ label: String) -> XCUIElement {
        app.navigationBars.staticTexts[label]
    }

    // MARK: - 记录与断言

    private func log(_ line: String) {
        reportLines.append(line)
        print("[FontShots] \(line)")
    }

    private func fmt(_ r: CGRect) -> String {
        String(format: "(x:%.1f y:%.1f w:%.1f h:%.1f)", r.minX, r.minY, r.width, r.height)
    }

    /// 记录一个元素的实测值，返回 (存在, 高度)。
    @discardableResult
    private func measure(_ name: String, _ el: XCUIElement, category: String, page: String) -> (exists: Bool, height: CGFloat) {
        guard el.exists else {
            log("[\(category)][\(page)] \(name): NOT FOUND")
            return (false, 0)
        }
        let f = el.frame
        log("[\(category)][\(page)] \(name): height=\(String(format: "%.1f", f.height)) frame=\(fmt(f))")
        return (true, f.height)
    }

    /// 布局断言：严格模式走 XCTAssert；记录模式只记入发现清单。
    private func layoutCheck(_ condition: Bool, _ label: String) {
        if condition {
            log("  CHECK PASS: \(label)")
        } else {
            log("  CHECK FAIL: \(label)")
            findings.append(label)
            if layoutAssertionsStrict {
                XCTFail("布局断言失败: \(label)")
            }
        }
    }

    /// ③ 无截断/溢出：元素存在且横向 frame 落在窗口内（±1pt 容差）。
    private func boundsCheck(_ name: String, _ el: XCUIElement, category: String, page: String) {
        let windowWidth = app.frame.width
        guard el.exists else {
            layoutCheck(false, "[\(category)][\(page)] 关键元素缺失: \(name)")
            return
        }
        let f = el.frame
        layoutCheck(f.minX >= -1 && f.maxX <= windowWidth + 1,
                    "[\(category)][\(page)] \(name) 横向溢出: frame=\(fmt(f)) windowWidth=\(String(format: "%.1f", windowWidth))")
    }

    private func attachReport(named name: String) {
        var lines = reportLines
        if !findings.isEmpty {
            lines.append("== FINDINGS (\(findings.count)) ==")
            lines.append(contentsOf: findings.map { "- \($0)" })
        }
        let att = XCTAttachment(string: lines.joined(separator: "\n"))
        att.name = name
        att.lifetime = .keepAlways
        add(att)
    }

    private func attachScreenshot(category: String, page: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "font-\(category)-\(page)"
        shot.lifetime = .keepAlways
        add(shot)
    }

    private func tapTab(_ label: String, anchor: String, category: String, page: String) -> Bool {
        let tab = app.tabBars.buttons[label]
        if tab.waitForExistence(timeout: 8) {
            tab.tap()
        } else {
            let fallback = app.buttons[label].firstMatch
            guard fallback.waitForExistence(timeout: 5) else {
                layoutCheck(false, "[\(category)][\(page)] Tab「\(label)」未找到")
                return false
            }
            log("[\(category)][\(page)] Tab「\(label)」经 buttons 兜底定位")
            fallback.tap()
        }
        let ok = element(anchor).waitForExistence(timeout: 12)
        if !ok {
            layoutCheck(false, "[\(category)][\(page)] 切换后页面锚点 \(anchor) 未出现")
        }
        Thread.sleep(forTimeInterval: 0.8)
        return ok
    }

    // MARK: - 机制自检（硬断言）

    /// 三档各启动一次，只测首页参照元素高度：
    /// 日期数字（@ScaledMetric）与分区标题「今天的经营」（.title3 语义字体）。
    /// 断言日期数字高度单调增长（AX3 > XXL > xL）且 AX3 ≥ xL × 1.2。
    /// 若三档无差异 = 启动参数未传导，机制未生效 —— 直接红，不许交无效截图。
    func testMechanismCategoryInjectionScalesReferenceText() {
        var dateHeights: [String: CGFloat] = [:]
        var headerHeights: [String: CGFloat] = [:]
        for cat in categories {
            launch(category: cat)
            let date = homeDateNumber()
            XCTAssertTrue(date.waitForExistence(timeout: 10),
                          "[mechanism][\(cat.name)] 首页日期数字未找到，无法验证机制")
            Thread.sleep(forTimeInterval: 0.4)
            let d = measure("homeDateNumber(@ScaledMetric 64pt)", date, category: cat.name, page: "home")
            if d.exists { dateHeights[cat.name] = d.height }
            let header = app.staticTexts["今天的经营"]
            let h = measure("homeSectionHeader(今天的经营/.title3)", header, category: cat.name, page: "home")
            if h.exists { headerHeights[cat.name] = h.height }
            app.terminate()
        }
        attachReport(named: "font-report-mechanism")
        let xl = dateHeights["xL"] ?? -1
        let xxl = dateHeights["XXL"] ?? -1
        let ax3 = dateHeights["AX3"] ?? -1
        XCTAssertTrue(xl > 0 && xxl > 0 && ax3 > 0,
                      "[mechanism] 日期数字三档未测全: \(dateHeights)")
        XCTAssertGreaterThan(xxl, xl,
                             "[mechanism] XXL(\(xxl)) 应大于 xL(\(xl))：字号注入疑似未生效")
        XCTAssertGreaterThan(ax3, xxl,
                             "[mechanism] AX3(\(ax3)) 应大于 XXL(\(xxl))：字号注入疑似未生效")
        XCTAssertGreaterThanOrEqual(ax3, xl * 1.2,
                                    "[mechanism] AX3(\(ax3)) 应明显大于 xL(\(xl))（≥1.2 倍）")
    }

    // MARK: - 四页逐档截图 + 逐页断言

    func testFontScaleScreenshotsAllPages() {
        for cat in categories {
            launch(category: cat)
            visitHome(category: cat.name)
            if tapTab("待办", anchor: "screen.todo", category: cat.name, page: "todo") {
                visitTodo(category: cat.name)
            }
            if tapTab("日历", anchor: "screen.calendar", category: cat.name, page: "calendar") {
                visitCalendar(category: cat.name)
            }
            if tapTab("经营", anchor: "screen.business", category: cat.name, page: "business") {
                visitBusiness(category: cat.name)
            }
            app.terminate()
        }
        attachReport(named: "font-report")
    }

    /// 首页：Hero（营业额卡）高度须大于日期数字与分区标题（层级不倒挂）。
    private func visitHome(category: String) {
        let page = "home"
        let date = measure("homeDateNumber", homeDateNumber(), category: category, page: page)
        let header = measure("homeSectionHeader(今天的经营)", app.staticTexts["今天的经营"], category: category, page: page)
        let heroEl = element("v38.home.hero")
        let hero = measure("homeHero(v38.home.hero)", heroEl, category: category, page: page)
        let aiEl = element("v38.home.ai.expand")
        _ = measure("homeAICapsule(v38.home.ai.expand)", aiEl, category: category, page: page)
        attachScreenshot(category: category, page: page)
        layoutCheck(hero.exists, "[\(category)][\(page)] Hero 缺失")
        layoutCheck(date.exists, "[\(category)][\(page)] 日期数字缺失")
        if hero.exists && date.exists {
            layoutCheck(hero.height > date.height,
                        "[\(category)][\(page)] 层级倒挂: Hero 高 \(hero.height) ≤ 日期数字高 \(date.height)")
        }
        if hero.exists && header.exists {
            layoutCheck(hero.height > header.height,
                        "[\(category)][\(page)] 层级倒挂: Hero 高 \(hero.height) ≤ 分区标题高 \(header.height)")
        }
        boundsCheck("homeHero", heroEl, category: category, page: page)
        boundsCheck("homeAICapsule", aiEl, category: category, page: page)
    }

    /// 待办：页面主信息块为进度统计（progress，含 32pt 固定字号数字，
    /// accessibilityElement 合并），层级口径为「统计块高度 ≥ 导航标题高度」；
    /// 分段选择器「今天」为 44pt 触达区按钮，只做存在与横向边界检查。
    private func visitTodo(category: String) {
        let page = "todo"
        let title = measure("navTitle(待办)", navTitle("待办"), category: category, page: page)
        let progressEl = element("v38.todo.progress")
        let progress = measure("todoProgress(v38.todo.progress)", progressEl, category: category, page: page)
        let pickerEl = app.buttons["今天"]
        _ = measure("todoPicker(今天)", pickerEl, category: category, page: page)
        attachScreenshot(category: category, page: page)
        layoutCheck(progress.exists, "[\(category)][\(page)] 进度统计块缺失")
        if progress.exists && title.exists {
            layoutCheck(progress.height >= title.height,
                        "[\(category)][\(page)] 层级异常: 进度块高 \(progress.height) < 导航标题高 \(title.height)")
        }
        boundsCheck("todoProgress", progressEl, category: category, page: page)
        boundsCheck("todoPicker(今天)", pickerEl, category: category, page: page)
    }

    /// 日历：masthead 日期为固定 30pt 字号（源码 .system(size:30)，不随动），
    /// 星期副标题为 .subheadline 随动字体 —— 层级口径为「日期高 ≥ 星期高」；
    /// AX 档下随动副标题可能反超固定字号日期，若出现即为真实发现。
    private func visitCalendar(category: String) {
        let page = "calendar"
        _ = measure("navTitle(日历)", navTitle("日历"), category: category, page: page)
        let dateEl = calendarMastheadDate()
        let date = measure("calendarMastheadDate(30pt固定)", dateEl, category: category, page: page)
        let weekdayEl = calendarWeekday()
        let weekday = measure("calendarWeekday(.subheadline)", weekdayEl, category: category, page: page)
        let monthEl = element("v38.schedule.density.month")
        _ = measure("densityMonth", monthEl, category: category, page: page)
        let weekEl = element("v38.schedule.density.week")
        _ = measure("densityWeek", weekEl, category: category, page: page)
        attachScreenshot(category: category, page: page)
        layoutCheck(date.exists, "[\(category)][\(page)] masthead 日期缺失")
        if date.exists && weekday.exists {
            layoutCheck(date.height >= weekday.height,
                        "[\(category)][\(page)] 层级倒挂: masthead 日期高 \(date.height) < 星期副标题高 \(weekday.height)（固定 30pt vs 随动 .subheadline）")
        }
        boundsCheck("densityMonth", monthEl, category: category, page: page)
        boundsCheck("densityWeek", weekEl, category: category, page: page)
    }

    /// 经营：Hero（本月营业额块）高度 ≥ 导航标题高度；图表元素做边界检查
    /// （AX3 下可能在折叠线以下，先原位查、未找到则上滑一次再查并注明）。
    private func visitBusiness(category: String) {
        let page = "business"
        let title = measure("navTitle(经营)", navTitle("经营"), category: category, page: page)
        let heroEl = element("v38.performance.hero")
        let hero = measure("businessHero(v38.performance.hero)", heroEl, category: category, page: page)
        var chartEl = element("v38.performance.chart")
        if !chartEl.exists {
            app.swipeUp()
            Thread.sleep(forTimeInterval: 0.6)
            chartEl = element("v38.performance.chart")
            log("[\(category)][\(page)] chart 原位未找到，上滑后重查: exists=\(chartEl.exists)")
            if chartEl.exists {
                _ = measure("businessChart(afterSwipeUp)", chartEl, category: category, page: page)
            }
            app.swipeDown()
            Thread.sleep(forTimeInterval: 0.6)
        } else {
            _ = measure("businessChart(v38.performance.chart)", chartEl, category: category, page: page)
        }
        attachScreenshot(category: category, page: page)
        layoutCheck(hero.exists, "[\(category)][\(page)] 经营 Hero 缺失")
        if hero.exists && title.exists {
            layoutCheck(hero.height >= title.height,
                        "[\(category)][\(page)] 层级异常: 经营 Hero 高 \(hero.height) < 导航标题高 \(title.height)")
        }
        boundsCheck("businessHero", heroEl, category: category, page: page)
        boundsCheck("businessChart", chartEl, category: category, page: page)
    }
}
