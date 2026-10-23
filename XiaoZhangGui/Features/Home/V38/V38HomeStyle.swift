import SwiftUI

/// V3.8 重建 · Home 视觉 Tokens（生产）。
///
/// 依据 `02_设计与交互升级说明.md` §正确的视觉 DNA：
/// - Canvas Light 暖白 / Dark 墨绿黑（复用 V371.Colors.canvas）
/// - Accent 低饱和经营绿；Hero 深墨绿卡片（Light/Dark 通用）
/// - Page 16pt，Section 24pt，Group radius 20pt，行高 ≥60pt，触点 ≥44pt
/// - Hero 数字 SF Rounded 等宽，54pt；不引入第三方字体
enum V38HomeStyle {
    /// Revenue Hero 深墨绿卡片底色（Light/Dark 通用，对照视觉稿）。
    static var heroBackground: Color {
        Color(red: 0.11, green: 0.29, blue: 0.24)
    }
    /// Hero 卡片上的次级文字（白色 82% 透明度）。
    static var heroSecondary: Color {
        .white.opacity(0.82)
    }
    /// 低饱和经营绿（Accent）。
    static var businessGreen: Color {
        Color(red: 0.22, green: 0.55, blue: 0.42)
    }

    /// Section 标题（"今天的经营" / "问小掌柜" / "今日事项"）。
    /// V3.8 PR-D C3：20pt == .title3 默认字号，语义样式获得动态字体缩放。
    static let sectionTitle: Font = .title3.weight(.bold)
    /// Hero 金额：54pt SF Rounded 等宽（展示型大数字，基准值）。
    /// V3.8 PR-D C3：调用点（HomeView）用 @ScaledMetric 随动放大，见 scaledHeroAmount(size:)。
    static let heroAmount: Font = .system(size: 54, weight: .semibold, design: .rounded).monospacedDigit()
    /// 日期大数字（展示型基准值，调用点随动见 scaledDateNumber(size:)）。
    static let dateNumber: Font = .system(size: 64, weight: .bold, design: .default)

    /// V3.8 PR-D C3：随动 Hero 金额——Token 层无法用 @ScaledMetric，
    /// 展示型大数字由调用点传入 @ScaledMetric 缩放后的字号。
    static func scaledHeroAmount(size: CGFloat) -> Font {
        .system(size: size, weight: .semibold, design: .rounded).monospacedDigit()
    }

    /// V3.8 PR-D C3：随动日期大数字。
    static func scaledDateNumber(size: CGFloat) -> Font {
        .system(size: size, weight: .bold, design: .default)
    }
}

/// V3.8 Home Section 标题行（标题 + 可选尾部标签）。
struct V38HomeSectionHeader: View {
    let title: String
    var trailing: String? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            // V3.9 PR-F:与全 App SectionHeader 同款金色签名竖条。
            Capsule()
                .fill(V39Palette.headerTick)
                .frame(width: 4, height: 16)
                .accessibilityHidden(true)
            Text(title)
                .font(V38HomeStyle.sectionTitle)
                .foregroundStyle(.primary)
            Spacer()
            if let trailing {
                Text(trailing)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
    }
}
