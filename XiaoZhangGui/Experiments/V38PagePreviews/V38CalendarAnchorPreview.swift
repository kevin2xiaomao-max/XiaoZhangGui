import SwiftUI

/// V3.8 Pages PoC —— 日历「日期锚点稳定」演示（Debug-only 隔离组件）。
///
/// 规格依据：`Docs/V38-Page-Motion-Spec.md` §3 与资料包 Docs/02 场景 3。
/// 演示要点：
///   1. 日/周模式切换时，锚点日期行几何**完全不动**（位置/高度一致），只有下方内容变密/变疏；
///   2. 点选不同日期时，选中 pill 以被点格子为锚连续滑动（matchedGeometryEffect），格子 frame 不变；
///   3. Reduce Motion 开启时：直接终态，无滑动、无密度渐变。
///
/// 纯演示：不读真实日历数据、不触碰 Schedule 生产页面、不写库、不发网络。
/// 仅通过 SwiftUI Preview 打开，不接入 RootView。
struct V38CalendarAnchorPreview: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var anchorNS

    private enum Mode: String, CaseIterable {
        case day = "日"
        case week = "周"
    }

    private enum Density: String, CaseIterable {
        case compact = "紧凑"
        case standard = "标准"
        case roomy = "舒适"
    }

    @State private var mode: Mode = .week
    @State private var density: Density = .standard
    @State private var selected: Int = 2 // 演示周内选中日索引（周一 = 0）

    private let weekdays = ["一", "二", "三", "四", "五", "六", "日"]
    private let demoDayItems = ["补饮料（示例）", "客户回访（示例）", "盘点（示例）", "临期检查（示例）"]
    private let demoWeekCounts = [2, 1, 3, 0, 2, 4, 1]

    /// 内容密度变化动画：Reduce Motion 下直接终态。
    private var changeAnimation: Animation? {
        reduceMotion ? nil : .easeInOut(duration: 0.28)
    }

    private var rowMinHeight: CGFloat {
        switch density {
        case .compact: return 44
        case .standard: return 56
        case .roomy: return 68
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            anchorBar
            modePicker
            densityPicker
            contentArea
            footerNote
            Spacer()
        }
        .padding(20)
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("日历锚点演示")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - 锚点行：两种模式下几何完全一致，位置不动

    private var anchorBar: some View {
        HStack(spacing: 0) {
            ForEach(weekdays.indices, id: \.self) { index in
                Button {
                    withAnimation(changeAnimation) { selected = index }
                } label: {
                    ZStack {
                        if selected == index {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.accentColor.opacity(0.18))
                                .matchedGeometryEffect(id: "v38.pages.calendar.dateAnchor", in: anchorNS)
                        }
                        Text(weekdays[index])
                            .font(.system(size: 16, weight: selected == index ? .semibold : .regular))
                            .foregroundStyle(selected == index ? .primary : .secondary)
                            .frame(maxWidth: .infinity, minHeight: 52)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("v38.pages.calendar.cell.\(index)")
                .accessibilityLabel("周\(weekdays[index])")
                .accessibilityAddTraits(selected == index ? .isSelected : [])
            }
        }
        .padding(4)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
        .accessibilityIdentifier("v38.pages.calendar.anchor")
        .accessibilityLabel("日期锚点行，模式切换时位置不变")
    }

    // MARK: - 模式与密度切换

    private var modePicker: some View {
        Picker("视图模式", selection: $mode) {
            ForEach(Mode.allCases, id: \.self) { m in
                Text(m.rawValue).tag(m)
                    .accessibilityIdentifier("v38.pages.calendar.mode.\(m == .day ? "day" : "week")")
            }
        }
        .pickerStyle(.segmented)
        .onChange(of: mode) { _, _ in
            // 锚点行不参与此动画：几何保持不动，只有内容区变化。
        }
    }

    private var densityPicker: some View {
        HStack {
            Text("列表密度").font(.subheadline).foregroundStyle(.secondary)
            Spacer()
            Picker("密度", selection: $density) {
                ForEach(Density.allCases, id: \.self) { d in
                    Text(d.rawValue).tag(d)
                        .accessibilityIdentifier("v38.pages.calendar.density.\(d == .compact ? "compact" : d == .standard ? "standard" : "roomy")")
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 220)
        }
    }

    // MARK: - 内容区：仅密度变化

    @ViewBuilder
    private var contentArea: some View {
        if mode == .day {
            VStack(spacing: density == .compact ? 4 : 10) {
                ForEach(demoDayItems, id: \.self) { item in
                    HStack {
                        Text(item).font(.body)
                        Spacer()
                        Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 14)
                    .frame(maxWidth: .infinity, minHeight: rowMinHeight, alignment: .leading)
                    .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
                }
            }
            .transition(.opacity)
        } else {
            HStack(alignment: .bottom, spacing: 6) {
                ForEach(weekdays.indices, id: \.self) { index in
                    VStack(spacing: 4) {
                        Text("\(demoWeekCounts[index])")
                            .font(.caption).foregroundStyle(.secondary)
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(index == selected ? Color.accentColor : Color.secondary.opacity(0.35))
                            .frame(height: barHeight(for: demoWeekCounts[index]))
                        Text(weekdays[index]).font(.caption2).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("v38.pages.calendar.weekbar.\(index)")
                }
            }
            .padding(12)
            .frame(minHeight: rowMinHeight + 60)
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
            .transition(.opacity)
        }
    }

    private func barHeight(for count: Int) -> CGFloat {
        let base: CGFloat = density == .compact ? 6 : density == .standard ? 9 : 12
        return 12 + CGFloat(count) * base
    }

    // MARK: - 头尾说明

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("V3.8 · 日历锚点演示")
                .font(.system(size: 26, weight: .semibold, design: .rounded))
            Text("切换日/周或密度：上方日期行不动，只有内容变密/变疏。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }

    private var footerNote: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("纯演示，不读真实数据", systemImage: "eye.slash")
            Text("验收对照（Spec §3 / G4）：锚点日期在日/周切换前后像素位置一致；selectedDate 语义不变；Reduce Motion 下直接终态。生产接入 NOT RUN。")
                .foregroundStyle(.secondary)
        }
        .font(.footnote)
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
        .accessibilityIdentifier("v38.pages.calendar.note")
    }
}

#if DEBUG
#Preview("日历锚点 · Light") {
    NavigationStack { V38CalendarAnchorPreview() }
        .preferredColorScheme(.light)
}

#Preview("日历锚点 · Dark") {
    NavigationStack { V38CalendarAnchorPreview() }
        .preferredColorScheme(.dark)
}
#endif
