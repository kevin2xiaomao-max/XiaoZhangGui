import SwiftUI
import UIKit

/// V3.8.1 P0-1 · 快捷菜单展开面板的调色板解析（单一事实来源）。
///
/// 真机根因：展开面板按 QuickMorph 视觉稿恒为深色——iOS 26+ Light 下是
/// 显式深色填充、Dark 下是 `secondarySystemBackground` 深灰；而菜单内容
/// 原先用随 colorScheme 变化的 `.primary`，Light 下为黑色，落在深色面板
/// 上几乎不可读。规则：**前景由面板的实际明暗决定**，不由 scheme 单独
/// 决定；背景种类（实色 / 玻璃 / 材质）与 View 的三档渲染一一对应。
/// View 渲染与单元测试的 WCAG 对比度断言共用本解析，杜绝再次漂移。
enum V38HomeQuickMenuPanelStyle {
    /// 展开面板的背景种类，与 `V38HomeQuickMenuBackground` 的三档一一对应。
    enum PanelKind {
        /// Reduce Transparency：secondarySystemBackground 实色。
        case opaqueSystemBackground
        /// iOS 26+：深色面板（Light 显式深色 / Dark 深灰）+ glassEffect。
        case floatingGlass
        /// iOS 18–25：ultraThinMaterial，随 scheme 明暗。
        case thinMaterial
    }

    /// iOS 26+ Light 下展开面板的显式深色（对照 QuickMorph 视觉稿）。
    static let darkPanelColor = Color(red: 0.13, green: 0.16, blue: 0.14)
    /// 深色面板上的品牌绿提亮版（bolt 图标）：与深色面板对比度 ≈10:1。
    static let darkPanelAccent = Color(red: 0.55, green: 0.90, blue: 0.72)

    /// 当前环境对应的背景种类。
    static func currentKind(reduceTransparency: Bool) -> PanelKind {
        if reduceTransparency { return .opaqueSystemBackground }
        if #available(iOS 26.0, *) { return .floatingGlass }
        return .thinMaterial
    }

    /// 面板在给定 scheme 下实际是否为深色。
    static func isDarkPanel(kind: PanelKind, colorScheme: ColorScheme) -> Bool {
        switch kind {
        case .opaqueSystemBackground, .thinMaterial:
            return colorScheme == .dark
        case .floatingGlass:
            return true
        }
    }

    /// View 用调色板（SwiftUI Color）。
    struct Palette {
        let isDarkPanel: Bool
        /// 主文字 / 行图标。
        var primary: Color { isDarkPanel ? .white : .primary }
        /// 次级文字（关闭按钮等）。
        var secondary: Color { isDarkPanel ? .white.opacity(0.72) : .secondary }
        /// 分隔发丝线。
        var hairline: Color { isDarkPanel ? .white.opacity(0.18) : Color(uiColor: .separator) }
        /// 标题 bolt 图标。
        var accent: Color { isDarkPanel ? darkPanelAccent : V38HomeStyle.businessGreen }
    }

    static func palette(kind: PanelKind, colorScheme: ColorScheme) -> Palette {
        Palette(isDarkPanel: isDarkPanel(kind: kind, colorScheme: colorScheme))
    }

    // MARK: - UIColor 口径（供单元测试做 WCAG 对比度断言，与 View 调色板同源）

    private static func traits(for colorScheme: ColorScheme) -> UITraitCollection {
        UITraitCollection(userInterfaceStyle: colorScheme == .dark ? .dark : .light)
    }

    /// 面板背景的代表性不透明色。材质档半透明，以页面画布色
    /// （systemBackground）作等效背衬近似——对比度结论按此近似成立。
    static func panelBackgroundUIColor(kind: PanelKind, colorScheme: ColorScheme) -> UIColor {
        switch kind {
        case .opaqueSystemBackground:
            return UIColor.secondarySystemBackground.resolvedColor(with: traits(for: colorScheme))
        case .floatingGlass:
            if colorScheme == .dark {
                return UIColor.secondarySystemBackground.resolvedColor(with: traits(for: colorScheme))
            }
            return UIColor(red: 0.13, green: 0.16, blue: 0.14, alpha: 1)
        case .thinMaterial:
            return UIColor.systemBackground.resolvedColor(with: traits(for: colorScheme))
        }
    }

    static func primaryForegroundUIColor(kind: PanelKind, colorScheme: ColorScheme) -> UIColor {
        isDarkPanel(kind: kind, colorScheme: colorScheme)
            ? .white
            : UIColor.label.resolvedColor(with: traits(for: colorScheme))
    }

    static func secondaryForegroundUIColor(kind: PanelKind, colorScheme: ColorScheme) -> UIColor {
        isDarkPanel(kind: kind, colorScheme: colorScheme)
            ? UIColor.white.withAlphaComponent(0.72)
            : UIColor.secondaryLabel.resolvedColor(with: traits(for: colorScheme))
    }

    static func accentForegroundUIColor(kind: PanelKind, colorScheme: ColorScheme) -> UIColor {
        isDarkPanel(kind: kind, colorScheme: colorScheme)
            ? UIColor(red: 0.55, green: 0.90, blue: 0.72, alpha: 1)
            : UIColor(red: 0.22, green: 0.55, blue: 0.42, alpha: 1)
    }
}

/// V3.8 重建 · Home 生产级快捷菜单。
///
/// 由 Worker B 的 `V38QuickMenuView`（Experiments，`#if DEBUG`）生产化：
/// - 移除 DEBUG 限制；选项点击经 `onSelect` 回调接入真实 QuickRecordSheet 路由
/// - 展开态对照 `XZG_iOS_V38_UI_QuickMorph.png`：深色"快速操作"菜单
/// - 不写库、不建保存链；保存由现有 QuickRecordSheet 完成
/// - 动效时序使用生产模块 `V38MotionTokens`
/// - 无障碍：行按钮 identifier 直接挂按钮（容器不挂 identifier，避免遮蔽）
struct V38HomeQuickMenu: View {
    enum Action: String, CaseIterable {
        case income, expense, memo

        var title: String {
            switch self {
            case .income: return "记收入"
            case .expense: return "记支出"
            case .memo: return "写备忘"
            }
        }

        var icon: String {
            switch self {
            case .income: return "plus.circle"
            case .expense: return "minus.circle"
            case .memo: return "note.text"
            }
        }
    }

    @Binding var isExpanded: Bool
    /// 选项被点击：宿主打开 QuickRecordSheet（现有生产路由）。
    var onSelect: (Action) -> Void = { _ in }
    /// 展开/收起变化时通知宿主（互斥收起 AI 胶囊）。
    var onExpandChange: (Bool) -> Void = { _ in }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme
    @Namespace private var morph

    /// V3.8.1 P0-1：展开面板调色板——前景按面板实际明暗解析（见 PanelStyle）。
    private var panelPalette: V38HomeQuickMenuPanelStyle.Palette {
        V38HomeQuickMenuPanelStyle.palette(
            kind: V38HomeQuickMenuPanelStyle.currentKind(reduceTransparency: reduceTransparency),
            colorScheme: colorScheme
        )
    }

    var body: some View {
        if isExpanded {
            // 注意：不给 ZStack 容器挂 accessibilityIdentifier——实测（Worker B）：
            // identifier 挂在容器上会覆盖其内部按钮的 identifier。展开态改由
            // 收起按钮（v38.home.quick.collapse）的存在性判定。
            ZStack {
                V38HomeQuickMenuBackground()
                    .matchedGeometryEffect(id: "v38-home-quick", in: morph)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                VStack(spacing: 0) {
                    HStack(spacing: 10) {
                        Image(systemName: "bolt.fill")
                            .foregroundStyle(panelPalette.accent)
                        Text("快速操作")
                            .font(.headline)
                            .foregroundStyle(panelPalette.primary)
                            .lineLimit(1)
                        Spacer()
                    }
                    .padding(16)
                    panelHairline
                    ForEach(Action.allCases, id: \.self) { action in
                        quickRow(action)
                        if action != Action.allCases.last {
                            panelHairline
                        }
                    }
                }
            }
            .overlay(alignment: .topTrailing) {
                Button { setExpanded(false) } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(panelPalette.secondary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("v38.home.quick.collapse")
                .accessibilityLabel("收起快速操作")
                .padding(12)
            }
        } else {
            Button { setExpanded(true) } label: {
                V38HomeGlassSurface(radius: 25) {
                    HStack(spacing: 10) {
                        Image(systemName: "plus")
                            .font(.headline)
                        // V3.8.1 P0-4：半宽胶囊 + 大字号下保持单行，禁止换行/截断关键文字。
                        Text("快速记一笔")
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                        Spacer()
                        Image(systemName: "chevron.up")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 18)
                    .frame(minHeight: 52)
                }
                .matchedGeometryEffect(id: "v38-home-quick", in: morph)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("v38.home.quick.expand")
            .accessibilityLabel("展开快速操作")
        }
    }

    /// 面板内分隔发丝线：颜色随面板明暗（Divider 的 separator 色在
    /// Light scheme 下是深色半透明，落在深色面板上不可见，故显式给色）。
    private var panelHairline: some View {
        Rectangle()
            .fill(panelPalette.hairline)
            .frame(height: 0.5)
            .padding(.horizontal, 16)
    }

    private func quickRow(_ action: Action) -> some View {
        Button {
            onSelect(action)
            setExpanded(false)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: action.icon)
                Text(action.title)
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)
                Spacer()
            }
            // V3.8.1 P0-1：行前景用面板调色板（深色面板上为白色），不再随 scheme 变黑。
            .foregroundStyle(panelPalette.primary)
            .frame(maxWidth: .infinity, minHeight: 50, alignment: .leading)
            .contentShape(Rectangle())
            .padding(.horizontal, 18)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("v38.home.quick.\(action.rawValue)")
        .accessibilityLabel(action.title)
    }

    private func setExpanded(_ value: Bool) {
        withAnimation(V38MotionTokens.animation(for: .expand, reduceMotion: reduceMotion)) {
            onExpandChange(value)
            isExpanded = value
        }
    }
}

/// 快捷菜单展开态背景：深色面板（三档：Reduce Transparency / iOS 26 glass / 旧系统材质）。
private struct V38HomeQuickMenuBackground: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 26, style: .continuous)
        if reduceTransparency {
            shape
                .fill(Color(uiColor: .secondarySystemBackground))
                .overlay(shape.strokeBorder(Color.secondary.opacity(0.16), lineWidth: 1))
        } else if #available(iOS 26.0, *) {
            // 深色"快速操作"面板：对照 QuickMorph 视觉稿。
            // 深色填充与 V38HomeQuickMenuPanelStyle.darkPanelColor 同源；
            // 内容前景由 PanelStyle 按面板明暗解析（P0-1），不随 scheme 变黑。
            shape
                .fill(colorScheme == .dark ? Color(uiColor: .secondarySystemBackground) : V38HomeQuickMenuPanelStyle.darkPanelColor)
                .glassEffect(.regular, in: shape)
        } else {
            shape
                .fill(.ultraThinMaterial)
                .overlay(shape.strokeBorder(Color.secondary.opacity(0.12), lineWidth: 1))
        }
    }
}
