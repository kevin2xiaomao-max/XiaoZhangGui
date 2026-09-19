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
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "32"
    }

    static var versionDisplay: String {
        "V\(marketingVersion)（\(build)）"
    }

    static let current = ReleaseNotes(
        headline: "细节更顺手，反馈更清晰",
        sections: [
            ReleaseNoteSection(icon: "wand.and.sparkles", title: "体验精修", items: [
                "界面细节和动效更顺滑",
                "AI 对话和操作反馈更清晰",
                "深色模式与主题体验优化",
                "多处交互和稳定性改进"
            ])
        ]
    )
}
