import ActivityKit
import WidgetKit
import SwiftUI

@available(iOS 16.2, *)
private func shortcutLabel(for url: String) -> String {
    guard let scheme = URL(string: url)?.scheme, !scheme.isEmpty else { return "Open" }
    let known: [String: String] = [
        "nightscout": "NS", "dexcom": "Dex",
        "loopkit": "Loop", "healthsync": "HS"
    ]
    return known[scheme] ?? scheme.capitalized
}

@available(iOS 16.2, *)
private func glucoseColor(_ value: Int, lo: Int, hi: Int) -> Color {
    if value < lo { return .red }
    if value > hi { return .orange }
    return .green
}

@available(iOS 16.2, *)
struct GlucoseLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: GlucoseActivityAttributes.self) { context in
            LockScreenGlucoseView(state: context.state, attributes: context.attributes)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(context.state.displayValue)
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundStyle(glucoseColor(context.state.value, lo: context.state.targetLow, hi: context.state.targetHigh))
                            Text(context.state.trendArrow)
                                .font(.title3.bold())
                                .foregroundStyle(glucoseColor(context.state.value, lo: context.state.targetLow, hi: context.state.targetHigh))
                        }
                        Text(context.state.unit)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 3) {
                        if !context.attributes.shortcutURLs.isEmpty {
                            ForEach(context.attributes.shortcutURLs.prefix(2), id: \.self) { urlStr in
                                if let url = URL(string: urlStr) {
                                    Link(destination: url) {
                                        Text(shortcutLabel(for: urlStr))
                                            .font(.system(size: 10, weight: .semibold))
                                            .foregroundStyle(.white.opacity(0.7))
                                            .padding(.horizontal, 7).padding(.vertical, 3)
                                            .background(.white.opacity(0.12), in: Capsule())
                                    }
                                }
                            }
                        } else {
                            Text("\(context.state.minutesAgo)m ago")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    GlucoseGraphView(
                        readings: context.state.recentReadings,
                        targetLow: context.state.targetLow,
                        targetHigh: context.state.targetHigh
                    )
                    .frame(height: 36)
                    .padding(.horizontal, 4)
                }
            } compactLeading: {
                Text(context.state.displayValue)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(glucoseColor(context.state.value, lo: context.state.targetLow, hi: context.state.targetHigh))
            } compactTrailing: {
                Text(context.state.trendArrow)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(glucoseColor(context.state.value, lo: context.state.targetLow, hi: context.state.targetHigh))
            } minimal: {
                Text(context.state.displayValue)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(glucoseColor(context.state.value, lo: context.state.targetLow, hi: context.state.targetHigh))
            }
            .widgetURL(URL(string: context.attributes.deeplinkURL))
            .keylineTint(glucoseColor(context.state.value, lo: context.state.targetLow, hi: context.state.targetHigh))
        }
    }
}

// MARK: - Lock Screen / Notification Banner

@available(iOS 16.2, *)
struct LockScreenGlucoseView: View {
    let state: GlucoseActivityAttributes.GlucoseContentState
    let attributes: GlucoseActivityAttributes

    private var color: Color {
        glucoseColor(state.value, lo: state.targetLow, hi: state.targetHigh)
    }

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            // Value + arrow
            VStack(alignment: .leading, spacing: 1) {
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(state.displayValue)
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(color)
                    Text(state.trendArrow)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(color)
                }
                Text("\(state.unit) · \(state.minutesAgo)m")
                    .font(.system(size: 9))
                    .foregroundStyle(.white.opacity(0.4))
            }
            .fixedSize(horizontal: true, vertical: false)

            // Graph
            GlucoseGraphView(
                readings: state.recentReadings,
                targetLow: state.targetLow,
                targetHigh: state.targetHigh
            )
            .frame(maxWidth: .infinity)
            .frame(height: 34)

            // Shortcut buttons (up to 3)
            if !attributes.shortcutURLs.isEmpty {
                VStack(alignment: .trailing, spacing: 3) {
                    ForEach(attributes.shortcutURLs.prefix(3), id: \.self) { urlStr in
                        if let url = URL(string: urlStr) {
                            Link(destination: url) {
                                Text(shortcutLabel(for: urlStr))
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.65))
                                    .padding(.horizontal, 7).padding(.vertical, 3)
                                    .background(.white.opacity(0.1), in: Capsule())
                            }
                        }
                    }
                }
                .fixedSize(horizontal: true, vertical: false)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .widgetURL(URL(string: attributes.deeplinkURL))
    }
}

// MARK: - Graph

@available(iOS 16.2, *)
struct GlucoseGraphView: View {
    let readings: [GlucosePoint]
    var targetLow: Int = 70
    var targetHigh: Int = 180
    let minVal: CGFloat = 40
    let maxVal: CGFloat = 300

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                targetBand(in: geo.size)
                glucosePath(in: geo.size)
                    .stroke(Color.white.opacity(0.9), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                if let last = readings.sorted(by: { $0.timestamp < $1.timestamp }).last {
                    let sorted = readings.sorted(by: { $0.timestamp < $1.timestamp })
                    let x = xPos(index: sorted.count - 1, total: sorted.count, width: geo.size.width)
                    let y = yPos(value: CGFloat(last.value), height: geo.size.height)
                    Circle()
                        .fill(glucoseColor(last.value))
                        .frame(width: 5, height: 5)
                        .position(x: x, y: y)
                }
            }
        }
    }

    private func yPos(value: CGFloat, height: CGFloat) -> CGFloat {
        let clamped = max(minVal, min(maxVal, value))
        return height * (1 - (clamped - minVal) / (maxVal - minVal))
    }

    private func xPos(index: Int, total: Int, width: CGFloat) -> CGFloat {
        guard total > 1 else { return width }
        return width * CGFloat(index) / CGFloat(total - 1)
    }

    private func glucosePath(in size: CGSize) -> Path {
        var path = Path()
        let sorted = readings.sorted(by: { $0.timestamp < $1.timestamp })
        for (i, r) in sorted.enumerated() {
            let pt = CGPoint(
                x: xPos(index: i, total: sorted.count, width: size.width),
                y: yPos(value: CGFloat(r.value), height: size.height)
            )
            if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
        }
        return path
    }

    private func targetBand(in size: CGSize) -> some View {
        let highY = yPos(value: CGFloat(targetHigh), height: size.height)
        let lowY  = yPos(value: CGFloat(targetLow),  height: size.height)
        return Rectangle()
            .fill(Color.green.opacity(0.12))
            .frame(height: max(0, lowY - highY))
            .offset(y: highY)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func glucoseColor(_ value: Int) -> Color {
        if value < targetLow  { return .red }
        if value > targetHigh { return .orange }
        return .green
    }
}
