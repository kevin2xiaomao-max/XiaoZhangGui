import WidgetKit
import SwiftUI

// MARK: - Widget Bundle 入口
// 包含：今日经营小组件（主屏/锁屏）+ Live Activity（锁屏/灵动岛）
// 需 Mac/Xcode：以 XiaoZhangGuiWidget extension target 编译（见 README 验证清单）

@main
struct XiaoZhangGuiWidgetBundle: WidgetBundle {
    var body: some Widget {
        TodayStatsWidget()
        BusinessLiveActivityWidget()
    }
}
