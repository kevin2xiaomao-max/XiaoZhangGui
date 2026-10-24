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
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "3.9.1"
    }

    static var build: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "40"
    }

    static var versionDisplay: String {
        "V\(marketingVersion)（\(build)）"
    }

    static let current = ReleaseNotes(
        headline: "V3.8 全新升级",
        sections: [
            ReleaseNoteSection(icon: "house", title: "首页", items: [
                "全新 Editorial 版式：大日期头与营业额 Hero，今日经营一眼看清",
                "AI 胶囊入口常驻首页，点开即可语音或文字记一笔",
                "快捷操作与今日事项改为平面列表，常用功能一步直达"
            ]),
            ReleaseNoteSection(icon: "checklist", title: "待办", items: [
                "勾选采用两段式回执：保存成功后才显示完成",
                "保存失败会明确提示并可以重试，不再出现假完成"
            ]),
            ReleaseNoteSection(icon: "calendar", title: "日历", items: [
                "日期选中以锚点方式切换，翻看月份时选中日不漂移",
                "新增日 / 周密度视图，安排松紧由你决定"
            ]),
            ReleaseNoteSection(icon: "chart.bar", title: "经营", items: [
                "收入按分类口径汇总，分类之和始终等于总额",
                "趋势图与金额数字过渡，变化过程看得更清楚"
            ]),
            ReleaseNoteSection(icon: "accessibility", title: "外观与无障碍", items: [
                "深色模式全面适配，夜间看店不刺眼",
                "支持动态字体与 VoiceOver，字号与语音播报都照顾到"
            ])
        ]
    )
}
