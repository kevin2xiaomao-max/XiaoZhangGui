import SwiftUI
import UIKit

struct DailyReportSheet: View {
    let report: DailyReport
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("今日营业额") {
                    Text(Fmt.money(report.todayRevenue)).font(.title.weight(.semibold))
                    Text(report.changeText).foregroundStyle(.secondary)
                }
                Section("待办") {
                    LabeledContent("已完成", value: "\(report.completedTodos)")
                    LabeledContent("未完成", value: "\(report.pendingTodos)")
                }
                Section("配送与临时商品") {
                    LabeledContent("配送待处理", value: "\(report.deliveries)")
                    LabeledContent("临时商品待处理", value: "\(report.pendingExpiry)")
                }
            }
            .navigationTitle("今日经营日报")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("关闭") { dismiss() } }
                ToolbarItem(placement: .primaryAction) {
                    ShareLink(item: report.shareText) {
                        Label("分享", systemImage: "square.and.arrow.up")
                    }
                }
                ToolbarItem(placement: .bottomBar) {
                    Button("复制文本") {
                        UIPasteboard.general.string = report.shareText
                        Haptic.success()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
