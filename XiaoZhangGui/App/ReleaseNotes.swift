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
        headline: "V3.5 Liquid Glass Leap",
        sections: [
            ReleaseNoteSection(icon: "paintpalette", title: "V3.5 视觉升级", items: [
                "全新主题化首页经营驾驶舱",
                "雾蓝、紫罗兰、墨绿、珊瑚、玫瑰、石墨六套主题，新装默认雾蓝",
                "经营快捷中心 Drawer，集中高频经营工具",
                "Performance、Todo、Schedule、AI 与 Profile 视觉统一",
                "深色模式、iPhone Air、动态字体与辅助功能体验优化",
                "Widget 与 Live Activity 视觉层级升级"
            ]),
            ReleaseNoteSection(icon: "sparkles", title: "小掌柜 AI", items: [
                "能查询天气和商品信息，并结合店铺数据看今日经营与近 7 天趋势",
                "经营建议只使用脱敏后的本地汇总，保护店铺隐私",
                "支持对待确认的金额、来源和时间继续修改"
            ]),
            ReleaseNoteSection(icon: "wrench.and.screwdriver", title: "修复", items: [
                "修复经营数据周/月/多月查询和部分自然语言误判",
                "改进扫呗文件导入，并新增截图识别预览",
                "修复首页滚动时导航栏跳动、键盘与系统返回手势"
            ])
        ]
    )
}
