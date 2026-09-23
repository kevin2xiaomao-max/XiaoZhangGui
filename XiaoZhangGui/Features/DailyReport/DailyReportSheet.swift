import SwiftUI
import UIKit

// MARK: - 今日经营日报 Sheet（V371：原生 NavigationStack + 分组列表；分享/复制逻辑原样）

struct DailyReportSheet: View {
    let report: DailyReport
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: V371.Space.section) {
                    summary
                    detailSection
                    ctaRow
                }
                .padding(.horizontal, V371.Space.page)
                .padding(.top, 14)
                .padding(.bottom, 28)
            }
            .scrollIndicators(.hidden)
            .v371Canvas()
            .navigationTitle("今日经营日报")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    /// 营业额摘要：编辑型排版（非 Hero 蓝面，保持克制）
    private var summary: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("今日营业额")
                .font(V371.Typography.rowSubtitle)
                .foregroundStyle(V371.Colors.textSecondary)
            Text(Fmt.money(report.todayRevenue))
                .font(V371.Typography.heroNumber)
                .foregroundStyle(V371.Colors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(report.changeText)
                .font(V371.Typography.rowSubtitle)
                .foregroundStyle(V371.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("今日营业额\(Fmt.money(report.todayRevenue))，\(report.changeText)")
    }

    private var detailSection: some View {
        GroupSurface {
            reportRow("已完成待办", value: "\(report.completedTodos)")
            V371Divider(leading: 0)
            reportRow("未完成待办", value: "\(report.pendingTodos)")
            V371Divider(leading: 0)
            reportRow("配送待处理", value: "\(report.deliveries)")
            V371Divider(leading: 0)
            reportRow("临期待处理", value: "\(report.pendingExpiry)")
        }
    }

    private func reportRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(V371.Typography.rowTitle)
                .foregroundStyle(V371.Colors.textSecondary)
            Spacer()
            Text(value)
                .font(V371.Typography.rowTitle)
                .foregroundStyle(V371.Colors.textPrimary)
                .monospacedDigit()
        }
        .padding(.horizontal, V371.Space.rowPadding)
        .padding(.vertical, 12)
        .frame(minHeight: 48)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label)\(value)")
    }

    private var ctaRow: some View {
        HStack(spacing: 12) {
            Button {
                UIPasteboard.general.string = report.shareText
                Haptic.success()
            } label: {
                Label("复制文本", systemImage: "doc.on.doc")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(V371.Colors.textPrimary)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(
                        Capsule(style: .continuous)
                            .fill(V371.Colors.group)
                            .overlay(
                                Capsule(style: .continuous)
                                    .strokeBorder(V371.Colors.divider, lineWidth: 1)
                            )
                    )
                    .contentShape(Capsule(style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("复制日报文本")
            Button {
                Haptic.light()
                share()
            } label: {
                Label("分享", systemImage: "square.and.arrow.up")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(V371.Colors.blue, in: Capsule(style: .continuous))
                    .contentShape(Capsule(style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("分享日报")
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
