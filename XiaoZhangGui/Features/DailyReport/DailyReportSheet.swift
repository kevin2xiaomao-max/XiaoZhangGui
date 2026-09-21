import SwiftUI
import UIKit

struct DailyReportSheet: View {
    let report: DailyReport
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                summary
                detailRows
                HStack(spacing: 12) {
                    V32SecondaryButton(title: "复制文本", systemName: "doc.on.doc") {
                        UIPasteboard.general.string = report.shareText
                        Haptic.success()
                    }
                    V32PrimaryButton(title: "分享", systemName: "square.and.arrow.up") {
                        share()
                    }
                }
            }
            .padding(.horizontal, V32Layout.pageMargin)
            .padding(.top, 14)
            .padding(.bottom, V32Layout.bottomPad)
        }
        .scrollIndicators(.hidden)
        .v32PageBackground()
        .v32Sheet([.medium, .large])
    }

    private var header: some View {
        ZStack {
            Text("今日经营日报").v32Text(.headline).foregroundStyle(V32.textPrimary)
            HStack {
                Button("关闭") { dismiss() }
                    .v32Text(.body)
                    .foregroundStyle(V32.textTertiary)
                Spacer()
            }
        }
    }

    private var summary: some View {
            VStack(alignment: .leading, spacing: 10) {
                Text("今日营业额")
                    .v32Text(.subhead)
                    .foregroundStyle(V32.textSecondary)
                Text(Fmt.money(report.todayRevenue))
                    .font(V32Font.heroMoney)
                    .foregroundStyle(V32.textPrimary)
                Text(report.changeText)
                    .v32Text(.caption)
                    .foregroundStyle(V32.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 8)
    }

    private var detailRows: some View {
        VStack(spacing: 0) {
            reportRow("已完成待办", value: "\(report.completedTodos)")
            divider
            reportRow("未完成待办", value: "\(report.pendingTodos)")
            divider
            reportRow("配送待处理", value: "\(report.deliveries)")
            divider
            reportRow("临期待处理", value: "\(report.pendingExpiry)")
        }
    }

    private func reportRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label).v32Text(.body).foregroundStyle(V32.textSecondary)
            Spacer()
            Text(value).v32Text(.headline).foregroundStyle(V32.textPrimary).monospacedDigit()
        }
        .frame(minHeight: 48)
    }

    private var divider: some View {
        Rectangle().fill(V32.divider).frame(height: 1).padding(.leading, 12)
    }

    private func share() {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController else { return }
        let vc = UIActivityViewController(activityItems: [report.shareText], applicationActivities: nil)
        if let pop = vc.popoverPresentationController {
            pop.sourceView = root.view
            pop.sourceRect = CGRect(x: root.view.bounds.midX, y: root.view.bounds.midY, width: 0, height: 0)
            pop.permittedArrowDirections = []
        }
        root.present(vc, animated: true)
    }
}
