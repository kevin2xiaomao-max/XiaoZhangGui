import SwiftUI

// MARK: - 日程（v3.2 一级入口）
// T3 阶段为占位页，仅承载新底栏；完整周条 + 时间轴在 Task 6 实现。

struct ScheduleView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: V32Layout.sectionGap) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("日程")
                        .v32Text(.pageTitle)
                        .foregroundStyle(V32.textPrimary)
                    Text("今日事，今日毕")
                        .v32Text(.subhead)
                        .foregroundStyle(V32.textTertiary)
                }
                .padding(.horizontal, V32Layout.pageMargin)
                .padding(.top, 8)

                V32Card {
                    V32EmptyState(
                        systemName: "calendar",
                        title: "日程即将上线",
                        message: "时间轴视图正在按 v3.2 设计稿实现"
                    )
                    .padding(.vertical, 20)
                }
                .padding(.horizontal, V32Layout.pageMargin)
            }
            .padding(.bottom, V32Layout.bottomPad)
        }
        .v32PageBackground()
    }
}
