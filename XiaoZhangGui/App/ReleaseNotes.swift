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
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "3.6.0"
    }

    static var build: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "36"
    }

    static var versionDisplay: String {
        "V\(marketingVersion)（\(build)）"
    }

    static let current = ReleaseNotes(
        headline: "V3.6 全新升级",
        sections: [
            ReleaseNoteSection(icon: "house", title: "首页与经营数据", items: [
                "Home 1.4 Compact 最终收口：营业额、趋势与今日重点更清晰",
                "Performance 2.0 聚焦大数字、趋势和关键经营指标",
                "保留真实数据展示，不使用装饰性假趋势"
            ]),
            ReleaseNoteSection(icon: "sparkles", title: "AI 小掌柜", items: [
                "General Assistant 普通问答能力接入现有 Provider",
                "URL Reading 网页阅读保持可用",
                "AI Provider 设置与外部能力路由进一步完善"
            ]),
            ReleaseNoteSection(icon: "globe", title: "外部能力框架", items: [
                "Web Search 已完成 Provider 通用化，支持 Tavily 与自定义 Search adapter",
                "免费优先仅使用用户明确允许的已配置 Provider，不会静默产生付费调用",
                "Vision 图片能力框架已完成，相册选图链路已接入",
                "PDF / TXT / MD 文件提取与分析链路已完成",
                "Search / Vision / File 代码完成，DEVICE/API SMOKE PENDING"
            ]),
            ReleaseNoteSection(icon: "lock.shield", title: "安全与稳定性", items: [
                "API Key 仅通过本机 Keychain 配置，不写入源码或聊天记录",
                "外部能力保持只读，业务写入继续经过确认与安全执行链",
                "完成 P1 cleanup，并通过 405/405 XCTest、10/10 XCUITest 等门禁"
            ]),
            ReleaseNoteSection(icon: "checkmark.seal", title: "验证状态", items: [
                "V3.6 UI、Performance 与 AI capability foundation 已保存",
                "Search / Vision / File 暂不标记为 LIVE，等待真机 API 验证"
            ])
        ]
    )
}
