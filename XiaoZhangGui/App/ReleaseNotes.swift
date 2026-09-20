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
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "3.4.0"
    }

    static var build: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "34"
    }

    static var versionDisplay: String {
        "V\(marketingVersion)（\(build)）"
    }

    static let current = ReleaseNotes(
        headline: "AI 更懂你的店，经营信息一问就懂",
        sections: [
            ReleaseNoteSection(icon: "sparkles", title: "小掌柜 AI", items: [
                "AI 现在能查询天气和商品信息",
                "能结合店铺真实数据分析今日经营与近 7 天趋势",
                "经营建议只使用必要的本地汇总信息，保护店铺隐私",
                "支持对待确认的金额、来源和时间继续修改",
                "修复经营数据周/月/多月查询和部分自然语言误判",
                "改进扫呗文件导入，并新增截图识别预览",
                "默认使用真实数据，演示数据标识更清晰"
            ]),
            ReleaseNoteSection(icon: "wand.and.sparkles", title: "体验升级", items: [
                "AI 对话、操作反馈和动效全面优化",
                "深色模式、动态字体与减少动态效果体验优化",
                "多处稳定性与设备适配改进"
            ])
        ]
    )
}
