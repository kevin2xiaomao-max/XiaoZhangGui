import Foundation

struct ReleaseNoteSection: Identifiable, Equatable {
    var id: String { title }
    let icon: String
    let title: String
    let items: [String]
}

struct ReleaseNotes: Equatable {
    let headline: String
    let sections: [ReleaseNoteSection]

    static var marketingVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "3.5.0"
    }

    static var build: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "35"
    }

    static var versionDisplay: String {
        "V\(marketingVersion)（\(build)）"
    }

    static let current = ReleaseNotes(
        headline: "V3.5 全新升级",
        sections: [
            ReleaseNoteSection(icon: "paintpalette", title: "全新设计", items: [
                "全面升级界面设计，更简洁、更清晰",
                "重做经营数据、日程、待办、客户需求和临期管理",
                "优化深色模式与大字体显示"
            ]),
            ReleaseNoteSection(icon: "square.and.pencil", title: "记录更顺手", items: [
                "待办与备忘重新整理",
                "优化备忘的文字、图片和语音浏览",
                "快速记录流程更清楚，保存结果一目了然"
            ]),
            ReleaseNoteSection(icon: "sparkles", title: "AI 小掌柜升级", items: [
                "优化 AI 对话与操作卡片",
                "统一语音、快速记录与 AI 的状态反馈",
                "保存前确认，成功与失败状态更加明确"
            ]),
            ReleaseNoteSection(icon: "chart.bar.xaxis", title: "经营体验升级", items: [
                "优化营业额、交易记录和经营报告",
                "客户配送与临期商品处理更加直观",
                "优化扫呗导入、收款码、天气和日历"
            ]),
            ReleaseNoteSection(icon: "checkmark.seal", title: "细节优化", items: [
                "优化操作反馈、动效和辅助功能",
                "Widget 与实时活动视觉升级",
                "修复多项稳定性和交互问题"
            ])
        ]
    )
}
