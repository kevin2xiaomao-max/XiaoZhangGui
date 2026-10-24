import XCTest
@testable import XiaoZhangGui

/// V3.8.1 真机 UI 纠偏（线 A：Home + App 壳）单元回归测试。
///
/// - P0-1 后续（2026-10-23 用户确认减法）：快捷菜单已整行删除，
///   原面板调色板（`V38HomeQuickMenuPanelStyle`）随组件一并移除，
///   其 WCAG 对比度矩阵测试只服务被删菜单，故同批删除；
///   「首页不得再出现被删入口」由源码审计（HomeQuickEntryAuditTests）
///   与 UI 测试（V381HomeShellCorrectionUITests）双重把守。
/// - P0-2：浮动 Tab 栏底部避让的共享常量口径（总额外 inset = 60pt），
///   实际遮挡与否由 UI 测试的 frame 断言校验（见 V381HomeShellCorrectionUITests）。
final class V381HomeShellCorrectionTests: XCTestCase {

    // MARK: - P0-2 共享避让常量

    func testFloatingTabBarClearanceTotalsSixtyPoints() {
        // 栏体高出系统安全区的部分（48）+ 呼吸间距（12）= 60pt 额外底部 inset，
        // 经 v32PageBottomInset 的 safeAreaInset 作用于四页根 ScrollView。
        XCTAssertEqual(V32Layout.floatingTabBarReservation, 48, accuracy: 0.5)
        XCTAssertEqual(
            V32Layout.floatingTabBarReservation + V32Layout.pageBottomBreathing, 60,
            accuracy: 0.5
        )
    }
}
