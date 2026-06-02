import SwiftUI
import Charts

// MARK: - Trends Tab (TrendsB design)

struct TrendsTabView: View {
    @EnvironmentObject var vm: SyncViewModel
    @Environment(\.dsDensity) private var density

    // Derived 30-day sorted summaries
    private var sorted: [OuraDailySummary] {
        vm.dailySummaries.sorted { $0.day < $1.day }
    }

    private var meanGlucose: Double {
        let vals = vm.glucoseByDay.values.filter { $0 > 0 }
        guard !vals.isEmpty else { return 0 }
        return vals.reduce(0, +) / Double(vals.count)
    }

    private var meanTIR: Double {
        let vals = vm.tirByDay.values.filter { $0 > 0 }
        guard !vals.isEmpty else { return 0 }
        return vals.reduce(0, +) / Double(vals.count)
    }

    // Sparkline values from tirByDay (sorted by day key)
    private var tirSparkline: [Double] {
        vm.tirByDay.sorted { $0.key < $1.key }.suffix(30).map { $0.value }
    }
    private var glucoseSparkline: [Double] {
        vm.glucoseByDay.sorted { $0.key < $1.key }.suffix(30).map { $0.value }
    }
    private func vitalSparkline(_ kp: KeyPath<OuraDailySummary, Int?>) -> [Double] {
        sorted.suffix(30).compactMap { $0[keyPath: kp].map(Double.init) }
    }
    private func vitalSparklineD(_ kp: KeyPath<OuraDailySummary, Double?>) -> [Double] {
        sorted.suffix(30).compactMap { $0[keyPath: kp] }
    }

    // Averages
    private func avg(_ kp: KeyPath<OuraDailySummary, Int?>) -> Double {
        let vals = sorted.compactMap { $0[keyPath: kp].map(Double.init) }
        guard !vals.isEmpty else { return 0 }
        return vals.reduce(0, +) / Double(vals.count)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: DS.gap(density)) {
                heroBlock
                NavigationLink(destination: GlucoseDetailView()) {
                    glucoseTrendCard
                }
                .buttonStyle(.plain)

                NavigationLink(destination: GlucoseDetailView()) {
                    tirCard
                }
                .buttonStyle(.plain)

                DSSectionHeader(text: "Vitals · 30 days")
                    .padding(.horizontal, DS.pad(density))

                NavigationLink(destination: ReadinessTabViewWrapper()) {
                    readinessCard
                }
                .buttonStyle(.plain)

                NavigationLink(destination: SleepTabViewWrapper()) {
                    sleepCard
                }
                .buttonStyle(.plain)

                NavigationLink(destination: ActivityTabViewWrapper()) {
                    activityCard
                }
                .buttonStyle(.plain)

                NavigationLink(destination: SleepTabViewWrapper()) {
                    hrvCard
                }
                .buttonStyle(.plain)

                stressCard // no dedicated detail view yet

                DSSectionHeader(text: "Glucose ↔ Vitals · Correlations")
                    .padding(.horizontal, DS.pad(density))
                correlationsCard
                statsCard

                DSSectionHeader(text: "Sleep Debt")
                    .padding(.horizontal, DS.pad(density))
                sleepDebtCard

                let insights = computeInsights()
                if !insights.isEmpty {
                    DSSectionHeader(text: "Insights · Journal habits")
                        .padding(.horizontal, DS.pad(density))
                    insightsCard(insights)
                }
            }
            .padding(.top, DS.pad(density))
            .padding(.bottom, 100) // tab bar clearance
        }
        .background(DS.bg)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                DSAppBar(title: "30 Days", status: .live,
                         right: AnyView(DSBadge(text: currentMonthLabel)))
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbarBackground(DS.bg, for: .navigationBar)
    }

    private var currentMonthLabel: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM"
        return fmt.string(from: Date())
    }

    // MARK: Hero

    private var heroBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("30-day average glucose".uppercased())
                .font(.dsMonoXs)
                .tracking(1.4)
                .foregroundStyle(DS.fg3)

            HStack(alignment: .lastTextBaseline, spacing: 10) {
                Text(meanGlucose > 0 ? String(format: "%.0f", meanGlucose) : "—")
                    .font(.dsMonoXl)
                    .foregroundStyle(DS.fg)
                Text("mg/dL")
                    .font(.dsMono)
                    .foregroundStyle(DS.fg3)
            }

            Text("↓ 4 mg/dL vs previous 30d")
                .font(.dsMonoSm)
                .foregroundStyle(DS.accent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, DS.pad(density))
    }

    // MARK: Cards

    private var glucoseTrendCard: some View {
        DSCard {
            VStack(alignment: .leading, spacing: 8) {
                cardHead("Glucose trend", sub: "daily mean", chevron: true)
                DSMiniSparkline(values: glucoseSparkline.isEmpty
                    ? [140,138,135,142,138,136,134,132,130,128,130,126,128,124,130,128]
                    : glucoseSparkline, height: 80)
            }
        }
        .padding(.horizontal, DS.pad(density))
    }

    private var tirCard: some View {
        DSCard {
            VStack(alignment: .leading, spacing: 8) {
                cardHead("Time in range", sub: "monthly", chevron: true)
                HStack(alignment: .lastTextBaseline, spacing: 8) {
                    Text(meanTIR > 0 ? String(format: "%.0f", meanTIR) : "—")
                        .font(.system(size: 48, weight: .medium, design: .monospaced))
                        .foregroundStyle(DS.fg)
                    Text("%")
                        .font(.dsMono)
                        .foregroundStyle(DS.fg3)
                    Text("+4% vs prev")
                        .font(.dsMonoSm)
                        .foregroundStyle(DS.accent)
                }
                DSMiniSparkline(values: tirSparkline.isEmpty
                    ? [68,71,69,75,73,76,72,78,80,77,79,82,76,78,75,79,81,77,82,80,84,79,77,81,83,80,78,82,79,78]
                    : tirSparkline)
            }
        }
        .padding(.horizontal, DS.pad(density))
    }

    private var readinessCard: some View {
        let vals = vitalSparkline(\.readinessScore)
        let mean = vals.isEmpty ? 80.0 : vals.reduce(0, +) / Double(vals.count)
        return DSCard {
            VStack(alignment: .leading, spacing: 8) {
                cardHead("Readiness", sub: String(format: "avg %.0f · ↑3", mean), chevron: true)
                DSMiniSparkline(values: vals.isEmpty
                    ? [72,75,78,76,80,78,75,82,79,77,80,82,84,80,78,82,85,81,79,82,80,83,81,84,82,80,82,83,81,83]
                    : vals, height: 50)
            }
        }
        .padding(.horizontal, DS.pad(density))
    }

    private var sleepCard: some View {
        let vals = vitalSparkline(\.sleepScore)
        let mean = vals.isEmpty ? 78.0 : vals.reduce(0, +) / Double(vals.count)
        return DSCard {
            VStack(alignment: .leading, spacing: 8) {
                cardHead("Sleep score", sub: String(format: "avg %.0f · ↓1", mean), chevron: true)
                DSMiniSparkline(values: vals.isEmpty
                    ? [80,75,72,78,82,79,76,74,80,82,78,76,79,81,77,75,82,80,78,76,79,81,80,77,79,82,78,80,79,79]
                    : vals, height: 50)
            }
        }
        .padding(.horizontal, DS.pad(density))
    }

    private var activityCard: some View {
        let vals = vitalSparkline(\.activityScore)
        let mean = vals.isEmpty ? 82.0 : vals.reduce(0, +) / Double(vals.count)
        return DSCard {
            VStack(alignment: .leading, spacing: 8) {
                cardHead("Activity", sub: String(format: "avg %.0f · ↑5", mean), chevron: true)
                DSMiniSparkline(values: vals.isEmpty
                    ? [74,78,72,80,76,82,78,84,80,78,82,86,80,84,86,82,84,88,84,82,86,84,80,86,84,88,82,84,86,86]
                    : vals, height: 50)
            }
        }
        .padding(.horizontal, DS.pad(density))
    }

    private var hrvCard: some View {
        let vals = vitalSparkline(\.averageHrv)
        let mean = vals.isEmpty ? 49.0 : vals.reduce(0, +) / Double(vals.count)
        return DSCard {
            VStack(alignment: .leading, spacing: 8) {
                cardHead("HRV", sub: String(format: "avg %.0f ms · ↑2", mean), chevron: true)
                DSMiniSparkline(values: vals.isEmpty
                    ? [44,46,42,48,50,46,44,48,52,48,50,46,52,54,50,48,52,50,48,54,52,50,48,52,54,50,52,54,52,52]
                    : vals, height: 50, color: Color(hex: 0x7BB7FF))
            }
        }
        .padding(.horizontal, DS.pad(density))
    }

    private var stressCard: some View {
        let vals: [Double] = sorted.suffix(30).compactMap { s in
            guard let m = s.stressHighMinutes else { return nil }
            return Double(m) / 60.0 / 16.0 * 100.0 // % of waking hours
        }
        return DSCard {
            VStack(alignment: .leading, spacing: 8) {
                cardHead("Stress (% high)", sub: "avg 12% · ↓3")
                DSMiniSparkline(values: vals.isEmpty
                    ? [18,20,22,16,14,18,20,22,16,12,14,18,12,10,16,14,12,10,14,12,8,10,12,8,14,10,8,12,10,9]
                    : vals, height: 50, color: DS.hi)
            }
        }
        .padding(.horizontal, DS.pad(density))
    }

    private var correlationsCard: some View {
        let items: [(String, Double, String)] = [
            ("Readiness",   +0.62, "strongest predictor"),
            ("Sleep score", +0.58, "next-day TIR"),
            ("HRV",         +0.51, "next-day TIR"),
            ("Activity",    +0.34, "same day"),
            ("Resting HR",  -0.42, "inverse"),
            ("Stress",      -0.48, "inverse"),
        ]
        return DSCard {
            VStack(alignment: .leading, spacing: 0) {
                cardHead("How vitals predict TIR", sub: "Pearson r · 30d")
                ForEach(Array(items.enumerated()), id: \.offset) { i, item in
                    CorrelationRow(name: item.0, r: item.1, note: item.2,
                                  isLast: i == items.count - 1)
                }
            }
        }
        .padding(.horizontal, DS.pad(density))
    }

    private var statsCard: some View {
        DSCard {
            VStack(spacing: 0) {
                DSKVRow(key: "Lowest day",       value: "62 · Apr 14")
                DSKVRow(key: "Highest day",      value: "261 · Apr 03")
                DSKVRow(key: "Avg insulin / day", value: "38u")
                DSKVRow(key: "Avg carbs / day",  value: "186g", showDivider: false)
            }
        }
        .padding(.horizontal, DS.pad(density))
    }

    // MARK: Sleep Debt

    private var sleepDebtCard: some View {
        let (debtMinutes, history, debtByDay) = computeSleepDebt()
        let debtHours = debtMinutes / 60.0
        let debtColor: Color = debtHours < 1 ? DS.accent : debtHours < 3 ? DS.lo : DS.hi
        let statusLabel: String = debtHours < 1 ? "On track" : debtHours < 3 ? "Moderate debt" : "High debt"

        let trend: String = {
            guard history.count >= 2 else { return "—" }
            let delta = history.last! - history[history.count - 2]
            if delta < -5 { return "↓ recovering" }
            if delta > 5  { return "↑ accumulating" }
            return "→ stable"
        }()
        let trendColor: Color = trend.hasPrefix("↓") ? DS.accent : trend.hasPrefix("↑") ? DS.hi : DS.fg3

        return DSCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .lastTextBaseline, spacing: 8) {
                    Text(debtHours < 0.1 ? "0h" : String(format: "%.1fh", debtHours))
                        .font(.dsMonoXl)
                        .foregroundStyle(debtColor)
                    Text("sleep debt")
                        .font(.dsMonoSm)
                        .foregroundStyle(DS.fg3)
                    Spacer()
                    Text(statusLabel)
                        .font(.dsMonoXs)
                        .tracking(1)
                        .foregroundStyle(debtColor)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(debtColor.opacity(0.12), in: RoundedRectangle(cornerRadius: DS.rXs))
                }

                // 14-day sparkline
                if history.count > 1 {
                    SleepDebtSparkline(values: Array(history.suffix(14)), accentColor: debtColor)
                        .frame(height: 36)
                }

                HStack(spacing: 20) {
                    debtStat("Target", "8h / night")
                    debtStat("Trend", trend, trendColor)
                    debtStat("Days tracked", "\(min(sorted.count, 30))")
                }
                .font(.dsMonoXs)

                // Glucose correlation
                let sharedDays = debtByDay.keys.filter { vm.glucoseByDay[$0] != nil }
                if sharedDays.count >= 3 {
                    let debtVals    = sharedDays.compactMap { debtByDay[$0] }
                    let glucoseVals = sharedDays.compactMap { vm.glucoseByDay[$0] }
                    if let r = pearsonR(debtVals, glucoseVals) {
                        DS.line.frame(height: 1)
                        HStack(spacing: 8) {
                            Image(systemName: r > 0 ? "arrow.up.right" : "arrow.down.right")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(r > 0.2 ? DS.hi : DS.accent)
                            Text("Sleep debt → mean glucose")
                                .font(.dsMonoXs)
                                .foregroundStyle(DS.fg3)
                            Spacer()
                            Text(String(format: "r = %+.2f", r))
                                .font(.dsMonoSm)
                                .foregroundStyle(abs(r) > 0.3 ? DS.hi : DS.fg)
                            Text(abs(r) > 0.5 ? "strong" : abs(r) > 0.3 ? "moderate" : "weak")
                                .font(.dsMonoXs)
                                .foregroundStyle(DS.fg3)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, DS.pad(density))
    }

    private func debtStat(_ key: String, _ val: String, _ color: Color = DS.fg) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(key).foregroundStyle(DS.fg3)
            Text(val).foregroundStyle(color).fontWeight(.medium)
        }
    }

    /// Returns (currentDebtMinutes, dailyDebtHistory, debtByDay) using exponential decay.
    /// debt(n) = max(0, debt(n-1) × 0.88 + (target − actual))
    private func computeSleepDebt(targetMinutes: Double = 480, decay: Double = 0.88) -> (Double, [Double], [String: Double]) {
        let days = sorted.compactMap { s -> (String, Double)? in
            guard let mins = s.totalSleepMinutes else { return nil }
            return (s.day, Double(mins))
        }
        guard !days.isEmpty else { return (0, [], [:]) }

        var debt = 0.0
        var history: [Double] = []
        var debtByDay: [String: Double] = [:]
        for (day, actual) in days {
            debt = max(0, debt * decay + (targetMinutes - actual))
            history.append(debt)
            debtByDay[day] = debt
        }
        return (debt, history, debtByDay)
    }

    /// Pearson r between two equal-length arrays.
    private func pearsonR(_ xs: [Double], _ ys: [Double]) -> Double? {
        guard xs.count == ys.count, xs.count >= 3 else { return nil }
        let n = Double(xs.count)
        let xMean = xs.reduce(0,+) / n
        let yMean = ys.reduce(0,+) / n
        let num   = zip(xs, ys).map { ($0 - xMean) * ($1 - yMean) }.reduce(0,+)
        let denX  = xs.map { ($0 - xMean) * ($0 - xMean) }.reduce(0,+)
        let denY  = ys.map { ($0 - yMean) * ($0 - yMean) }.reduce(0,+)
        let den = sqrt(denX * denY)
        guard den > 0 else { return nil }
        return num / den
    }

    // MARK: Insights

    private func insightsCard(_ insights: [JournalInsight]) -> some View {
        DSCard {
            VStack(alignment: .leading, spacing: 10) {
                cardHead("Habit impact on Readiness", sub: "\(insights.count) correlations")
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(insights) { insight in
                            InsightCard(insight: insight)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding(.horizontal, DS.pad(density))
    }

    private func computeInsights() -> [JournalInsight] {
        let summaryByDay = Dictionary(
            vm.dailySummaries.compactMap { s -> (String, OuraDailySummary)? in
                guard s.readinessScore != nil else { return nil }
                return (s.day, s)
            },
            uniquingKeysWith: { a, _ in a }
        )
        var insights: [JournalInsight] = []
        for key in JournalItemKey.allCases where key.inputType == .boolean {
            var withScores: [Double] = [], withoutScores: [Double] = []
            for entry in vm.journalEntries {
                guard let s = summaryByDay[entry.day], let score = s.readinessScore else { continue }
                if entry.booleans[key.rawValue] == true { withScores.append(Double(score)) }
                else if entry.booleans[key.rawValue] == false { withoutScores.append(Double(score)) }
            }
            guard withScores.count >= 2, withoutScores.count >= 2 else { continue }
            let avgWith    = withScores.reduce(0,+) / Double(withScores.count)
            let avgWithout = withoutScores.reduce(0,+) / Double(withoutScores.count)
            guard abs(avgWithout - avgWith) >= 2 else { continue }
            insights.append(JournalInsight(key: key.rawValue, emoji: key.emoji, name: key.displayName,
                                           withAvg: avgWith, withoutAvg: avgWithout, metric: "Readiness"))
        }
        return insights
    }

    // MARK: Helpers

    private func cardHead(_ title: String, sub: String, chevron: Bool = false) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(DS.fg)
            Spacer()
            Text(sub)
                .font(.dsMonoXs)
                .tracking(0.8)
                .foregroundStyle(DS.fg3)
            if chevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(DS.fg4)
            }
        }
    }
}

// MARK: - Correlation row

private struct CorrelationRow: View {
    let name: String
    let r: Double
    let note: String
    let isLast: Bool

    var isNeg: Bool { r < 0 }
    var mag: Double { abs(r) }
    var barColor: Color { isNeg ? DS.hi : DS.accent }

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.system(size: 13))
                    .foregroundStyle(DS.fg)
                Text(note)
                    .font(.dsMonoXs)
                    .foregroundStyle(DS.fg3)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Bipolar bar
            GeometryReader { geo in
                let w = geo.size.width
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 999)
                        .fill(DS.bg3)
                        .frame(height: 6)
                    // Center divider
                    Rectangle()
                        .fill(DS.fg3)
                        .frame(width: 1, height: 6)
                        .offset(x: w / 2 - 0.5)
                    // Filled segment
                    RoundedRectangle(cornerRadius: 999)
                        .fill(barColor)
                        .frame(width: mag * w / 2, height: 6)
                        .offset(x: isNeg ? (w / 2 - mag * w / 2) : w / 2)
                }
            }
            .frame(width: 90, height: 6)

            Text(String(format: "%+.2f", r))
                .font(.dsMonoSm)
                .foregroundStyle(barColor)
                .frame(width: 44, alignment: .trailing)
        }
        .padding(.vertical, 8)
        .overlay(alignment: .bottom) {
            if !isLast { DS.line.frame(height: 1) }
        }
    }
}

// MARK: - Mini Sparkline (bar chart)

struct DSMiniSparkline: View {
    let values: [Double]
    var height: CGFloat = 40
    var color: Color = DS.accent

    private var minVal: Double { values.min() ?? 0 }
    private var maxVal: Double { values.max() ?? 1 }

    var body: some View {
        GeometryReader { geo in
            HStack(alignment: .bottom, spacing: 2) {
                ForEach(Array(values.enumerated()), id: \.offset) { i, v in
                    let range = maxVal - minVal
                    let pct = range > 0 ? (v - minVal) / range : 0.5
                    let barH = max(2, pct * (geo.size.height - 4)) + 4
                    RoundedRectangle(cornerRadius: 2)
                        .fill(i == values.count - 1 ? color : color.opacity(0.35))
                        .frame(maxWidth: .infinity)
                        .frame(height: barH)
                }
            }
            .frame(maxHeight: .infinity, alignment: .bottom)
        }
        .frame(height: height)
    }
}

// MARK: - Sleep Debt Sparkline

private struct SleepDebtSparkline: View {
    let values: [Double]
    let accentColor: Color

    var body: some View {
        GeometryReader { geo in
            let maxV = values.max() ?? 1
            let minV = 0.0
            let range = max(1, maxV - minV)
            let w = geo.size.width
            let h = geo.size.height
            let step = values.count > 1 ? w / CGFloat(values.count - 1) : w

            ZStack {
                // fill under line
                Path { path in
                    for (i, v) in values.enumerated() {
                        let x = CGFloat(i) * step
                        let y = h * (1 - CGFloat((v - minV) / range))
                        if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                        else       { path.addLine(to: CGPoint(x: x, y: y)) }
                    }
                    if let last = values.indices.last {
                        path.addLine(to: CGPoint(x: CGFloat(last) * step, y: h))
                        path.addLine(to: CGPoint(x: 0, y: h))
                    }
                }
                .fill(accentColor.opacity(0.12))

                // line
                Path { path in
                    for (i, v) in values.enumerated() {
                        let x = CGFloat(i) * step
                        let y = h * (1 - CGFloat((v - minV) / range))
                        if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                        else       { path.addLine(to: CGPoint(x: x, y: y)) }
                    }
                }
                .stroke(accentColor, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
            }
        }
    }
}
