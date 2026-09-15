import SwiftUI
import UIKit

struct DailyReportSheet: View {
    let report: DailyReport
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                heroCard
                statsCard
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

    private var heroCard: some View {
        V32HeroCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("今日营业额")
                    .v32Text(.subhead)
                    .foregroundStyle(V32.textOnHeroSecondary)
                Text(Fmt.money(report.todayRevenue))
                    .font(V32Font.heroMoney)
                    .foregroundStyle(V32.textOnHero)
                Text(report.changeText)
                    .v32Text(.caption)
                    .foregroundStyle(V32.textOnHeroSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var statsCard: some View {
        V32Card {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    V32MetricCell(label: "已完成待办", value: "\(report.completedTodos)")
                    V32MetricCell(label: "未完成待办", value: "\(report.pendingTodos)")
                }
                Rectangle().fill(V32.divider).frame(height: 1).padding(.vertical, 12)
                HStack(spacing: 12) {
                    V32MetricCell(label: "配送待处理", value: "\(report.deliveries)")
                    V32MetricCell(label: "临期待处理", value: "\(report.pendingExpiry)")
                }
            }
        }
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
