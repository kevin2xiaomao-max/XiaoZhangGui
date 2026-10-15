import SwiftUI

/// 日历日期锚点稳定演示（Debug-only 隔离组件）。
///
/// 对应 `Docs/V38-Page-Motion-Spec.md` §3：
/// 日期格子是几何锚点 —— 日/周密度切换与重选时，选中环以被选日期格为锚
/// 做 matched-geometry 滑移，`selectedDate` 本身绝不漂移。
///
/// 纯演示数据，不读 Repository、不写 SwiftData、不接生产日历页。
struct ScheduleAnchorDemoView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var anchor

    @State private var selectedDate: Date = Calendar.current.startOfDay(for: Date())
    @State private var density: Density = .month

    private enum Density: String, CaseIterable {
        case month = "月"
        case week = "周"
    }

    private var calendar: Calendar { Calendar.current }

    /// 演示事项（静态占位，非真实业务数据）。
    private let demoEvents: [Int: [String]] = [
        3: ["演示：进货"],
        8: ["演示：盘点"],
        15: ["演示：对账", "演示：回访"],
        21: ["演示：上架"],
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                densityPicker
                calendarGrid
                selectionCaption
                eventList
                disclaimer
            }
            .padding(20)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("日期锚点演示")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("v38.page.schedule.demo")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("V3.8 · 日期锚点稳定")
                .font(.system(size: 28, weight: .semibold, design: .rounded))
            Text("切换 月/周 密度，选中日期保持不动")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }

    private var densityPicker: some View {
        Picker("密度", selection: $density) {
            ForEach(Density.allCases, id: \.self) { d in
                Text(d.rawValue).tag(d)
            }
        }
        .pickerStyle(.segmented)
        .accessibilityIdentifier("v38.page.schedule.density")
    }

    private var visibleDays: [Date] {
        switch density {
        case .month:
            return monthDays()
        case .week:
            return weekDays(containing: selectedDate)
        }
    }

    private var calendarGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
            ForEach(visibleDays, id: \.self) { day in
                dayCell(day)
            }
        }
        .padding(12)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20))
        .accessibilityIdentifier("v38.page.schedule.grid")
    }

    @ViewBuilder
    private func dayCell(_ day: Date) -> some View {
        let dayNum = calendar.component(.day, from: day)
        let isSelected = calendar.isDate(day, inSameDayAs: selectedDate)
        let isToday = calendar.isDateInToday(day)
        Button {
            withAnimation(V38MotionLabTokens.animation(for: .expand, reduceMotion: reduceMotion)) {
                selectedDate = day
            }
        } label: {
            ZStack {
                if isSelected {
                    // 选中环：以日期格为几何锚点的 matched-geometry 滑移体。
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.accentColor.opacity(0.18))
                        .matchedGeometryEffect(id: "v38-schedule-selection", in: anchor)
                }
                VStack(spacing: 2) {
                    Text("\(dayNum)")
                        .font(.system(size: 16, weight: isSelected ? .semibold : .regular))
                        .foregroundStyle(isSelected ? .accentColor : .primary)
                    if isToday {
                        Circle().fill(Color.accentColor).frame(width: 4, height: 4)
                    } else if demoEvents[dayNum] != nil {
                        Circle().fill(Color.secondary).frame(width: 4, height: 4)
                    } else {
                        Circle().fill(Color.clear).frame(width: 4, height: 4)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 44)
                .contentShape(Rectangle())
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("v38.page.schedule.day.\(dayNum)")
        .accessibilityLabel("\(monthName(of: day))\(dayNum)日\(isSelected ? "，已选中" : "")")
    }

    private var selectionCaption: some View {
        Text("选中：\(monthName(of: selectedDate))\(calendar.component(.day, from: selectedDate))日 · 密度切换后保持不变")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .accessibilityIdentifier("v38.page.schedule.selection.caption")
    }

    private var eventList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("当日事项（演示数据）")
                .font(.headline)
            let dayNum = calendar.component(.day, from: selectedDate)
            if let events = demoEvents[dayNum] {
                ForEach(events, id: \.self) { e in
                    Label(e, systemImage: "circle.fill")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("无演示事项")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
    }

    private var disclaimer: some View {
        Label("演示数据，不读取、不修改真实日历与事项", systemImage: "checkmark.shield")
            .font(.footnote)
            .foregroundStyle(.secondary)
    }

    // MARK: - 日期计算（纯展示）

    private func monthDays() -> [Date] {
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: Date()))!
        guard let range = calendar.range(of: .day, in: .month, for: startOfMonth) else { return [] }
        return range.compactMap { calendar.date(byAdding: .day, value: $0 - 1, to: startOfMonth) }
    }

    private func weekDays(containing date: Date) -> [Date] {
        // 周一起始（与生产日历口径一致：Schedule 周一开头）
        var cal = calendar
        cal.firstWeekday = 2
        let startOfWeek = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date))!
        return (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: startOfWeek) }
    }

    private func monthName(of date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "M月"
        return f.string(from: date)
    }
}

#if DEBUG
#Preview("Schedule Anchor / Light") {
    NavigationStack { ScheduleAnchorDemoView() }
        .preferredColorScheme(.light)
}

#Preview("Schedule Anchor / Dark") {
    NavigationStack { ScheduleAnchorDemoView() }
        .preferredColorScheme(.dark)
}
#endif
