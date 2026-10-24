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
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "3.9.2"
    }

    static var build: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "41"
    }

    static var versionDisplay: String {
        "V\(marketingVersion)（\(build)）"
    }

    static let current = ReleaseNotes(
        headline: "V3.9.2 · 开店前 30 秒，先看一眼晨报",
        sections: [
            ReleaseNoteSection(icon: "sun.horizon", title: "掌柜晨报（新）", items: [
                "首页金条卡一眼看完：昨日营收环比、今日事项、临期预警与一条建议",
                "全部在本机按你的账本现算，不上传、断网也能用",
                "我的页可开每日 8:00 提醒，开店前先有个数"
            ]),
            ReleaseNoteSection(icon: "calendar", title: "日历", items: [
                "今日改为固定香槟金圆配深墨数字，深色模式下同样清晰",
                "选中金环与密度 chips 统一金色语言，翻月选中日不漂移",
                "新增日 / 周密度视图，安排松紧由你决定"
            ]),
            ReleaseNoteSection(icon: "house", title: "首页", items: [
                "聚合口径重写：多张卡片共用一次统计，滚动与切页更跟手",
                "逾期标红、临期标橙，颜色终于和含义对上",
                "点「逾期」直达待办的逾期筛选，不用再翻两层"
            ]),
            ReleaseNoteSection(icon: "checklist", title: "待办", items: [
                "勾选仍是两段式回执：保存成功才显示完成，失败可重试",
                "六个编辑器加了防丢：有未保存改动时下拉会拦一下，并给放弃确认"
            ]),
            ReleaseNoteSection(icon: "chart.bar", title: "经营", items: [
                "月报改为「较上月同期」口径，月中对比不再被天数误导",
                "收入分类之和恒等于总额，对不上时不再默默吞掉差额"
            ]),
            ReleaseNoteSection(icon: "sparkles", title: "AI 与数据", items: [
                "AI 助手可直接查本月营收、待办与临期，回答带真实数字",
                "备份支持 v3 去重：重复导入不再产生重复账目"
            ])
        ]
    )
}
