import SwiftUI

// MARK: - V3.9 首页区块组件（高级质感 · 玻璃 + 渐变 + 大数字）
//
// 数据口径全部复用既有模型（TodaySummary / PerformanceTrend / IncomeSourceSummary /
// MonthlyBusinessMetrics），本文件零业务计算新增，只做呈现。
// 玻璃表面复用 V38HomeGlassSurface 三档降级（RT 实色 / 旧系统材质 / iOS 26 glass）。

// MARK: Hero · 本月营业额大卡（含月目标进度环）

struct V39HeroCard: View {
    let monthRevenue: Double
    let monthGoal: Double
    let todayRevenue: Double
    let changePercent: Double?
    let heroAmountSize: CGFloat
    let onTap: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var goalFraction: Double {
        V39Style.clampedProgress(numerator: monthRevenue, denominator: monthGoal)
    }

    var body: some View {
        Button {
            // 按压反馈：金色 Hero 卡是首页最大点击区，原实现只有视觉按压、没有触感。
            Haptic.light()
            onTap()
        } label: {
            HStack(alignment: .center, spacing: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("本月营业额")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white.opacity(0.72))
                    Text("¥" + Fmt.groupedAmount(monthRevenue))
                        .font(Font.custom("Georgia", fixedSize: heroAmountSize).monospacedDigit().weight(.semibold))
                        .tracking(-1.2)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.55)
                        .contentTransition(.numericText())
                    HStack(spacing: 8) {
                        Text("今日 ¥" + Fmt.groupedAmount(todayRevenue))
                            .font(.footnote.weight(.medium).monospacedDigit())
                            .foregroundStyle(.white.opacity(0.72))
                        if let change = changePercent {
                            HStack(spacing: 2) {
                                Image(systemName: change >= 0 ? "arrow.up.right" : "arrow.down.right")
                                    .font(.system(size: 9, weight: .bold))
                                // P1-1:涨跌必须明示口径——TodaySummary 对比的是昨日,不得只写百分比。
                                Text("较昨日 \(String(format: "%.1f", abs(change)))%")
                                    .font(.caption.weight(.semibold).monospacedDigit())
                            }
                            .foregroundStyle(change >= 0 ? V400Tokens.heroInk : V39Style.changeDown)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(
                                Capsule().fill(
                                    (change >= 0 ? V400Tokens.heroInk : V39Style.changeDown).opacity(0.18)
                                )
                            )
                        }
                    }
                }
                Spacer(minLength: 8)
                // P1-1:月目标为 0 时不得显示误导性 0% 环,改为明确的未设置态。
                if monthGoal > 0 {
                    V39GoalRing(fraction: goalFraction)
                } else {
                    VStack(spacing: 2) {
                        Text("未设置")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.85))
                        Text("月目标")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    .frame(width: 68, height: 68)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("未设置月目标")
                }
            }
            .padding(18)
            .background(V400Tokens.heroBackground, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(V39PressFeedbackStyle())
        .accessibilityIdentifier("v38.home.hero")
        .accessibilityLabel(heroAccessibilityLabel)
    }

    private var heroAccessibilityLabel: String {
        var parts = [
            "本月营业额 ¥\(Fmt.groupedAmount(monthRevenue))",
            "今日 ¥\(Fmt.groupedAmount(todayRevenue))",
        ]
        if let change = changePercent {
            parts.append("较昨日\(change >= 0 ? "上涨" : "下降") \(String(format: "%.1f", abs(change)))%")
        }
        if monthGoal > 0 {
            parts.append("月目标完成 \(Int((goalFraction * 100).rounded()))%")
            if monthRevenue >= monthGoal {
                parts.append("已达成月目标")
            }
        } else {
            parts.append("未设置月目标")
        }
        parts.append("查看经营详情")
        return parts.joined(separator: "，")
    }
}

// MARK: 月目标进度环

struct V39GoalRing: View {
    let fraction: Double

    var body: some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(0.16), lineWidth: 6)
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(V400Tokens.heroInk, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text("\(Int((fraction * 100).rounded()))")
                    .font(V400Tokens.serifAmount(size: 20, relativeTo: .title3).weight(.bold))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.6)
                Text("%")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.72))
            }
        }
        .frame(width: 68, height: 68)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("月目标完成百分之\(Int((fraction * 100).rounded()))")
    }
}

// MARK: 统计 chips 行（待办 / 逾期 / 临期 / 配送）

struct V39StatChip: View {
    let icon: String
    let title: String
    let count: Int
    let tint: Color
    let identifier: String
    var hint: String? = nil
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(height: 18)
                Text("\(count)")
                    .font(V400Tokens.serifAmount(size: 20, relativeTo: .title3).weight(.bold))
                    .foregroundStyle(.primary)
                    .contentTransition(.numericText())
                Text(title)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 76)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(V39PressFeedbackStyle())
        // P1-4:数量为 0 时降低视觉强调(弱化而非隐藏,布局不跳动)。
        .opacity(count == 0 ? 0.55 : 1)
        .accessibilityIdentifier(identifier)
        .accessibilityLabel("\(title)\(count)项")
        .accessibilityHint(hint ?? "")
    }
}

/// 按压反馈（scale 0.96,RM 不缩放）——与 V38 Todo 按钮同一纪律。
struct V39PressFeedbackStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.96 : 1)
            .animation(
                V38MotionTokens.animation(for: .press, reduceMotion: reduceMotion),
                value: configuration.isPressed
            )
    }
}

// MARK: 近 7 日迷你趋势卡（玻璃）

struct V39TrendCard: View {
    let points: [TrendPoint]
    let heroAmountSize: CGFloat
    let onTap: () -> Void

    private var maxValue: Double {
        max(points.map(\.value).max() ?? 0, 1)
    }

    private var total: Double {
        points.reduce(0) { $0 + $1.value }
    }

    var body: some View {
        Button(action: onTap) {
            // V3.9:玻璃表面按用户定稿扩展到首页数据卡(原 V3.8 仅瞬态控件);
            // RT/iOS18-25 降级由 V38HomeGlassSurface 三档门控保证。
            V38HomeGlassSurface(radius: 18) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("近7日营业额")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                        Spacer(minLength: 8)
                        Text("¥" + Fmt.groupedAmount(total))
                            .font(V400Tokens.serifAmount(size: 20, relativeTo: .title3).weight(.bold))
                            .foregroundStyle(V400Tokens.greenInk)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                            .contentTransition(.numericText())
                    }
                    if hasData {
                        HStack(alignment: .bottom, spacing: 8) {
                            ForEach(points) { point in
                                let isToday = point.id == (points.last?.id ?? -1)
                                RoundedRectangle(cornerRadius: 3, style: .continuous)
                                    .fill(isToday ? V400Tokens.brandGreen : Color.primary.opacity(0.22))
                                    .frame(height: barHeight(for: point))
                                    .frame(maxHeight: 44, alignment: .bottom)
                                    .accessibilityHidden(true)
                            }
                        }
                        .frame(height: 44, alignment: .bottom)
                        // P2-A:每柱下方标日期(M/d),不再是一排无解释的柱子。
                        HStack(spacing: 8) {
                            ForEach(points) { point in
                                Text(point.label)
                                    .font(.caption2.monospacedDigit())
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity)
                                    .accessibilityHidden(true)
                            }
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("近7日趋势柱形图")
                    } else {
                        // P2-A:无收入时给清晰空态,而非一排零柱子。
                        Text("近7日暂无营业额，记录第一笔收入后这里会显示趋势")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .buttonStyle(V39PressFeedbackStyle())
        .accessibilityIdentifier("v39.home.trend")
        .accessibilityLabel(trendAccessibilityLabel)
    }

    private var hasData: Bool {
        points.contains { $0.value > 0 }
    }

    private func barHeight(for point: TrendPoint) -> CGFloat {
        let ratio = point.value / maxValue
        return max(CGFloat(ratio) * 44, 3)
    }

    private var trendAccessibilityLabel: String {
        if !hasData { return "近7日暂无营业额,查看经营详情" }
        return "近7日营业额合计 ¥\(Fmt.groupedAmount(total)),查看趋势详情"
    }
}

// MARK: 本月收入来源占比条（门店 / 美团 / 其他）

struct V39SourceBar: View {
    let summaries: [IncomeSourceSummary]
    let onTap: () -> Void

    private var active: [IncomeSourceSummary] {
        summaries.filter { $0.amount > 0 }
    }

    private var total: Double {
        summaries.reduce(0) { $0 + $1.amount }
    }

    var body: some View {
        Button(action: onTap) {
            V38HomeGlassSurface(radius: 18) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("本月收入来源")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                        Spacer(minLength: 8)
                        Text("¥" + Fmt.groupedAmount(total))
                            .font(V400Tokens.serifAmount(size: 17, relativeTo: .headline))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .contentTransition(.numericText())
                    }
                    if total > 0 {
                        // 占比条:门店(夜蓝) / 美团(金) / 其他(灰) 按真实比例分段。
                        GeometryReader { geo in
                            HStack(spacing: 2) {
                                ForEach(active) { item in
                                    Capsule()
                                        .fill(color(for: item.source))
                                        .frame(width: max(geo.size.width * item.ratio - 2, 4))
                                }
                            }
                            .frame(height: 8)
                            .frame(maxHeight: .infinity, alignment: .center)
                        }
                        .frame(height: 10)
                        .accessibilityHidden(true)
                        // P2-A:图例用自适应网格换行,Dynamic Type 下不横向溢出;
                        // 百分比用最大余数法,合计恒为 100%。
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 12)], alignment: .leading, spacing: 6) {
                            ForEach(Array(active.enumerated()), id: \.element.id) { index, item in
                                HStack(spacing: 4) {
                                    Circle().fill(color(for: item.source)).frame(width: 6, height: 6)
                                    Text("\(item.source.rawValue) \(IncomeSourceSummary.displayPercents(for: active)[index])%")
                                        .font(.caption.weight(.medium).monospacedDigit())
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    } else {
                        Text("记录第一笔收入开始统计")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .buttonStyle(V39PressFeedbackStyle())
        .accessibilityIdentifier("v39.home.source")
        .accessibilityLabel(sourceAccessibilityLabel)
    }

    private func color(for source: IncomeSource) -> Color {
        switch source {
        case .store: return V400Tokens.greenInk
        case .meituan: return V400Tokens.brandGreen
        case .other: return V39Style.sourceOther
        }
    }

    private var sourceAccessibilityLabel: String {
        guard total > 0 else { return "本月暂无收入,查看经营详情" }
        let parts = active.map { "\($0.source.rawValue)占\(String(format: "%.0f%%", $0.ratio * 100))" }
        return "本月收入 ¥\(Fmt.groupedAmount(total))," + parts.joined(separator: ",") + ",查看经营详情"
    }
}
