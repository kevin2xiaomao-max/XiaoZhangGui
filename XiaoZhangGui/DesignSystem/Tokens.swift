import SwiftUI

/// 3.0 轻量 tokens。语义色走系统，品牌色只当 Accent。
enum Tokens {
    enum Space {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 20
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
        static let page: CGFloat = 16
    }

    enum Radius {
        static let sm: CGFloat = 8
        static let md: CGFloat = 10
        static let lg: CGFloat = 12
        static let xl: CGFloat = 16
    }

    enum TypeSize {
        static let hero: Font = .system(.largeTitle, design: .rounded).weight(.semibold)
        static let title: Font = .title2.weight(.semibold)
        static let headline: Font = .headline
        static let body: Font = .body
        static let callout: Font = .callout
        static let subheadline: Font = .subheadline
        static let footnote: Font = .footnote
        static let caption: Font = .caption
    }

    enum Surface {
        static var page: Color { Color(.systemBackground) }
        static var grouped: Color { Color(.systemGroupedBackground) }
        static var groupedSecondary: Color { Color(.secondarySystemGroupedBackground) }
        static var fill: Color { Color(.secondarySystemBackground) }
        static var separator: Color { Color(.separator) }
    }
}
