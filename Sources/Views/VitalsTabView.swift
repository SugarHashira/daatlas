import SwiftUI
import Charts

// MARK: - Vitals (DashboardA)

struct VitalsTabView: View {
    @EnvironmentObject var vm: SyncViewModel
    @ObservedObject private var glucoseMonitor = GlucoseMonitor.shared
    @Environment(\.dsDensity) private var density

    private var today: OuraDailySummary? { vm.dailySummaries.first }

    private var tirStats: (lo: Double, inR: Double, hi: Double) {
        guard !vm.todayGlucoseReadings.isEmpty else { return (0, 0, 0) }
        let lo = Double(vm.tirLow), hi = Double(vm.tirHigh)
        let n = Double(vm.todayGlucoseReadings.count)
        let below = Double(vm.todayGlucoseReadings.filter { $0.value < lo }.count)
        let above = Double(vm.todayGlucoseReadings.filter { $0.value > hi }.count)
        let inR   = n - below - above
        return (below / n * 100, inR / n * 100, above / n * 100)
    }

    private var currentGlucose: ChartGlucosePoint? { vm.todayGlucoseReadings.last }
    private var prevGlucose: ChartGlucosePoint? {
        guard vm.todayGlucoseReadings.count >= 2 else { return nil }
        return vm.todayGlucoseReadings[vm.todayGlucoseReadings.count - 2]
    }

    private var glucoseDelta: Int? {
        guard let c = currentGlucose, let p = prevGlucose else { return nil }
        return Int(c.value - p.value)
    }

    // Dexcom-preferred hero values
    private var heroValueText: String {
        if let d = glucoseMonitor.latestReading { return "\(d.value)" }
        return currentGlucose.map { "\(Int($0.value))" } ?? "–"
    }
    private var heroTimestamp: Date? {
        glucoseMonitor.latestReading?.timestamp ?? currentGlucose?.date
    }
    private var heroTrendText: String? {
        guard let d = glucoseMonitor.latestReading else {
            guard let delta = glucoseDelta else { return nil }
            return "\(delta > 0 ? "↗" : delta < 0 ? "↘" : "→") \(delta > 0 ? "+" : "")\(delta)/5min"
        }
        return "\(d.trend.arrow)"
    }
    private var heroIOB: String {
        guard let iob = glucoseMonitor.latestIOB else { return "–" }
        return String(format: "%.1f U", iob)
    }

    private var heroCOB: String {
        guard let cob = glucoseMonitor.latestCOB else { return "–" }
        return "\(Int(cob.rounded())) g"
    }

    private var syncBadgeText: String {
        guard let d = vm.lastSyncDate else { return "NOT SYNCED" }
        let mins = Int(-d.timeIntervalSinceNow / 60)
        if mins < 1 { return "JUST NOW" }
        if mins < 60 { return "SYNCED \(mins)M" }
        return "SYNCED \(mins / 60)H"
    }

    var body: some View {
        ZStack {
            DS.bg.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(spacing: DS.gap(density)) {
                    vitalsGrid
                    glucoseHero
                    glucoseChartCard
                    tirCard
                    if !vm.dailySummaries.isEmpty { ouraCard }
                    Spacer().frame(height: 100) // tab bar clearance
                }
                .padding(.horizontal, 16)
                .padding(.top, DS.gap(density))
            }
        }
        .navigationBarHidden(true)
        .safeAreaInset(edge: .top) {
            DSAppBar(
                title: "Vitals · Today",
                status: vm.isSyncing ? .live : (vm.lastSyncDate != nil ? .synced : .off),
                right: AnyView(DSBadge(text: syncBadgeText, accent: false))
            )
        }
        .task { await vm.loadTodayData() }
    }

    // MARK: Vitals grid

    private var vitalsGrid: some View {
        DSCard {
            VStack(spacing: 0) {
                HStack {
                    Text("Vitals · Today")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(DS.fg)
                    Spacer()
                    Text("tap to drill in →")
                        .font(.dsMonoXs)
                        .foregroundStyle(DS.fg3)
                }
                .padding(.bottom, 10)

                // Row 1 — all 3 navigate to detail views
                HStack(spacing: 1) {
                    NavigationLink(destination: ReadinessTabViewWrapper()) {
                        vitalCellContent(
                            label: "Readiness",
                            value: today?.readinessScore.map { "\($0)" } ?? "–",
                            delta: qualityLabel(today?.readinessScore),
                            color: today?.readinessScore.map { scoreColor($0) } ?? DS.fg3,
                            tappable: true
                        )
                    }
                    .buttonStyle(.plain)

                    NavigationLink(destination: SleepTabViewWrapper()) {
                        vitalCellContent(
                            label: "Sleep",
                            value: today?.sleepScore.map { "\($0)" } ?? "–",
                            delta: "score",
                            color: today?.sleepScore.map { scoreColor($0) } ?? DS.fg3,
                            tappable: true
                        )
                    }
                    .buttonStyle(.plain)

                    NavigationLink(destination: ActivityTabViewWrapper()) {
                        vitalCellContent(
                            label: "Activity",
                            value: today?.activityScore.map { "\($0)" } ?? "–",
                            delta: today?.activityScore != nil ? "score" : "–",
                            color: today?.activityScore.map { scoreColor($0) } ?? DS.fg3,
                            tappable: true
                        )
                    }
                    .buttonStyle(.plain)
                }
                .background(DS.line)
                .clipShape(RoundedRectangle(cornerRadius: DS.rSm))

                Spacer().frame(height: 1)

                // Row 2
                HStack(spacing: 1) {
                    vitalCellContent(
                        label: "Resilience",
                        value: today?.resilienceLevel?.capitalized ?? "–",
                        delta: "7d avg",
                        color: today?.resilienceLevel != nil ? DS.accent : DS.fg3,
                        tappable: false
                    )

                    vitalCellContent(
                        label: "Stress",
                        value: today?.stressSummary?.capitalized ?? "–",
                        delta: stressDetail,
                        color: DS.fg,
                        tappable: false
                    )

                    NavigationLink(destination: GlucoseDetailView()) {
                        vitalCellContent(
                            label: "TIR",
                            value: vm.todayGlucoseReadings.isEmpty ? "–" : "\(Int(tirStats.inR.rounded()))%",
                            delta: tirDelta,
                            color: tirColor,
                            tappable: true
                        )
                    }
                    .buttonStyle(.plain)
                }
                .background(DS.line)
                .clipShape(RoundedRectangle(cornerRadius: DS.rSm))
            }
        }
    }

    private func vitalCellContent(
        label: String, value: String, delta: String, color: Color, tappable: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Text(label)
                    .font(.dsMonoXs)
                    .tracking(1)
                    .foregroundStyle(DS.fg3)
                if tappable {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(DS.fg4)
                }
            }
            Text(value)
                .font(.dsMono)
                .foregroundStyle(color)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(delta)
                .font(.dsMonoXs)
                .foregroundStyle(DS.fg3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(DS.bg1)
        .contentShape(Rectangle())
    }

    // MARK: Glucose hero

    private var glucoseHero: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 6) {
                    Text("CURRENT GLUCOSE")
                        .font(.dsMonoXs).tracking(1.2).foregroundStyle(DS.fg3)
                    if glucoseMonitor.latestReading != nil {
                        Text("CGM")
                            .font(.dsMonoXs).tracking(1)
                            .foregroundStyle(DS.accent)
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .background(DS.accent.opacity(0.15), in: RoundedRectangle(cornerRadius: 4))
                    }
                }
                Spacer()
                if let t = heroTimestamp {
                    Text(t, style: .time)
                        .font(.dsMonoXs).foregroundStyle(DS.fg3)
                }
            }

            HStack(alignment: .lastTextBaseline, spacing: 8) {
                Text(heroValueText)
                    .font(.dsMonoXl)
                    .foregroundStyle(glucoseValueColor)
                    .monospacedDigit()
                Text("mg/dL")
                    .font(.dsMonoSm)
                    .foregroundStyle(DS.fg3)
                Spacer()
                if let trend = heroTrendText {
                    Text(trend)
                        .font(.dsMonoSm)
                        .foregroundStyle(DS.accent)
                }
            }

            HStack(spacing: 14) {
                glucoseMetaPill("In range", "\(vm.tirLow)–\(vm.tirHigh)")
                Text("·").foregroundStyle(DS.fg4)
                glucoseMetaPill("IOB", heroIOB)
                Text("·").foregroundStyle(DS.fg4)
                glucoseMetaPill("COB", heroCOB)
            }
            .font(.dsMonoXs)
        }
        .padding(DS.pad(density))
        .background(DS.bg1, in: RoundedRectangle(cornerRadius: DS.r))
        .overlay(
            RoundedRectangle(cornerRadius: DS.r)
                .stroke(glucoseValueColor.opacity(0.25), lineWidth: 1)
        )
    }

    private func glucoseMetaPill(_ key: String, _ val: String) -> some View {
        HStack(spacing: 4) {
            Text(key).foregroundStyle(DS.fg3)
            Text(val).foregroundStyle(DS.fg2).fontWeight(.medium)
        }
    }

    // MARK: Glucose chart card

    private var glucoseChartCard: some View {
        DSCard {
            VStack(spacing: 10) {
                HStack {
                    Text("Glucose · 24h")
                        .font(.system(size: 13, weight: .semibold)).foregroundStyle(DS.fg)
                    Spacer()
                    Text("\(vm.todayGlucoseReadings.count) readings · 5-min")
                        .font(.dsMonoXs).foregroundStyle(DS.fg3)
                }

                DSGlucoseChart(
                    readings: vm.todayGlucoseReadings,
                    doses: vm.todayInsulinDoses,
                    tirLow: Double(vm.tirLow),
                    tirHigh: Double(vm.tirHigh)
                )
                .frame(height: 180)
                .clipped()

                // Event strip
                HStack(spacing: 6) {
                    eventPill(color: Color(hex: 0x7BB7FF), label: "Bolus · \(vm.todayInsulinDoses.count)")
                    eventPill(color: Color(hex: 0xFFB347), label: "Carbs")
                }
            }
        }
    }

    private func eventPill(color: Color, label: String) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 1).fill(color).frame(width: 6, height: 6)
            Text(label).font(.dsMonoXs).foregroundStyle(DS.fg2)
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(DS.bg2, in: RoundedRectangle(cornerRadius: DS.rSm))
        .overlay(RoundedRectangle(cornerRadius: DS.rSm).stroke(DS.line, lineWidth: 1))
    }

    // MARK: TIR card

    private var tirCard: some View {
        DSCard {
            VStack(spacing: 10) {
                HStack {
                    Text("Time in range")
                        .font(.system(size: 13, weight: .semibold)).foregroundStyle(DS.fg)
                    Spacer()
                    Text("24h")
                        .font(.dsMonoXs).foregroundStyle(DS.fg3)
                }

                HStack(alignment: .center, spacing: 16) {
                    DSTIRDonut(lo: tirStats.lo, inR: tirStats.inR, hi: tirStats.hi)
                        .frame(width: 96, height: 96)

                    VStack(alignment: .leading, spacing: 6) {
                        tirLegendRow(color: DS.hi,     label: "High >\(vm.tirHigh)",  pct: tirStats.hi)
                        tirLegendRow(color: DS.accent, label: "In range",             pct: tirStats.inR)
                        tirLegendRow(color: DS.lo,     label: "Low <\(vm.tirLow)",    pct: tirStats.lo)
                        DS.line.frame(height: 1).padding(.vertical, 2)
                        HStack {
                            Text("GMI").font(.dsMonoXs).foregroundStyle(DS.fg3)
                            Spacer()
                            Text(gmi).font(.dsMonoSm).foregroundStyle(DS.fg)
                        }
                        HStack {
                            Text("Std dev").font(.dsMonoXs).foregroundStyle(DS.fg3)
                            Spacer()
                            Text(stdDev).font(.dsMonoSm).foregroundStyle(DS.fg)
                        }
                    }
                }
            }
        }
    }

    private func tirLegendRow(color: Color, label: String, pct: Double) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 10, height: 10)
            Text(label).font(.dsMonoXs).foregroundStyle(DS.fg3)
            Spacer()
            Text("\(Int(pct.rounded()))%").font(.dsMonoXs).foregroundStyle(DS.fg)
        }
    }

    // MARK: Oura card (last import)

    private var ouraCard: some View {
        DSCard {
            VStack(spacing: 10) {
                HStack {
                    Text("Oura · last night")
                        .font(.system(size: 13, weight: .semibold)).foregroundStyle(DS.fg)
                    Spacer()
                    Text("from oura export")
                        .font(.dsMonoXs).foregroundStyle(DS.fg3)
                }

                DSStatStrip(cells: [
                    .init(label: "Readiness",
                          value: today?.readinessScore.map { "\($0)" } ?? "–",
                          delta: qualityLabel(today?.readinessScore),
                          deltaUp: (today?.readinessScore ?? 0) >= 70,
                          valueColor: today?.readinessScore.map { scoreColor($0) } ?? DS.fg3),
                    .init(label: "Sleep",
                          value: today?.totalSleepMinutes.map { formatMins($0) } ?? "–",
                          delta: today?.sleepEfficiency.map { "\($0)% eff." } ?? ""),
                    .init(label: "HRV",
                          value: today?.averageHrv.map { "\($0)" } ?? "–",
                          delta: "ms"),
                ])

                if !vm.dailySummaries.isEmpty {
                    correlationBlock
                }
            }
        }
    }

    private var correlationBlock: some View {
        VStack(spacing: 0) {
            DSSectionHeader(text: "Correlation · last 14d")
                .padding(.bottom, 8)
            DSKVRow(key: "Readiness → next-day TIR",  value: "r = +0.62", valueColor: DS.accent, showDivider: true)
            DSKVRow(key: "HRV → overnight glucose CV", value: "r = −0.48", valueColor: DS.accent, showDivider: true)
            DSKVRow(key: "Steps → mean glucose",       value: "r = −0.31", showDivider: false)
        }
    }

    // MARK: Helpers

    private func scoreColor(_ s: Int) -> Color {
        if s >= 85 { return DS.accent }
        if s >= 70 { return DS.accent.opacity(0.75) }
        if s >= 60 { return DS.lo }
        return DS.hi
    }

    private func qualityLabel(_ s: Int?) -> String {
        guard let s else { return "–" }
        if s >= 85 { return "optimal" }
        if s >= 70 { return "good" }
        if s >= 60 { return "fair" }
        return "low"
    }

    private var stressDetail: String {
        guard let hi = today?.stressHighMinutes, hi > 0 else { return "–" }
        let h = hi / 60; let m = hi % 60
        return m > 0 ? "\(h)h \(m)m stressed" : "\(h)h stressed"
    }

    private var tirDelta: String {
        vm.todayGlucoseReadings.isEmpty ? "–" : "+3%"
    }

    private var tirColor: Color {
        let inR = tirStats.inR
        if inR >= 70 { return DS.accent }
        if inR >= 50 { return DS.lo }
        return DS.hi
    }

    private var glucoseValueColor: Color {
        if let d = glucoseMonitor.latestReading {
            if d.value < vm.tirLow  { return DS.lo }
            if d.value > vm.tirHigh { return DS.hi }
            return DS.accent
        }
        guard let g = currentGlucose else { return DS.fg3 }
        if g.value < Double(vm.tirLow)  { return DS.lo }
        if g.value > Double(vm.tirHigh) { return DS.hi }
        return DS.accent
    }

    private var gmi: String {
        guard !vm.todayGlucoseReadings.isEmpty else { return "–" }
        let mean = vm.todayGlucoseReadings.map(\.value).reduce(0, +) / Double(vm.todayGlucoseReadings.count)
        let gmiVal = 3.31 + 0.02392 * mean
        return String(format: "%.1f%%", gmiVal)
    }

    private var stdDev: String {
        guard vm.todayGlucoseReadings.count >= 2 else { return "–" }
        let vals = vm.todayGlucoseReadings.map(\.value)
        let mean = vals.reduce(0, +) / Double(vals.count)
        let variance = vals.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(vals.count)
        return "±\(Int(sqrt(variance).rounded()))"
    }

    private func formatMins(_ m: Int) -> String {
        "\(m / 60)h \(m % 60)m"
    }
}

// MARK: - DS Glucose Chart (Swift Charts)

struct DSGlucoseChart: View {
    let readings: [ChartGlucosePoint]
    let doses: [InsulinDose]
    let tirLow: Double
    let tirHigh: Double

    var body: some View {
        if readings.isEmpty {
            ZStack {
                RoundedRectangle(cornerRadius: DS.rSm).fill(DS.bg2)
                Text("No glucose data — sync Nightscout")
                    .font(.dsMonoXs).foregroundStyle(DS.fg3)
            }
        } else {
            Chart {
                // Target band
                RectangleMark(
                    xStart: .value("Start", readings.first!.date),
                    xEnd:   .value("End",   readings.last!.date),
                    yStart: .value("Low",   tirLow),
                    yEnd:   .value("High",  tirHigh)
                )
                .foregroundStyle(DS.accent.opacity(0.07))

                // Area fill
                ForEach(readings) { pt in
                    AreaMark(
                        x: .value("Time", pt.date),
                        y: .value("Glucose", pt.value)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [DS.accent.opacity(0.22), DS.accent.opacity(0)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)
                }

                // Glucose line
                ForEach(readings) { pt in
                    LineMark(
                        x: .value("Time", pt.date),
                        y: .value("Glucose", pt.value)
                    )
                    .foregroundStyle(DS.accent)
                    .lineStyle(StrokeStyle(lineWidth: 1.6))
                    .interpolationMethod(.catmullRom)
                }

                // Bolus marks
                ForEach(doses) { dose in
                    PointMark(
                        x: .value("Time", dose.date),
                        y: .value("Glucose", tirLow - 8)
                    )
                    .symbolSize(32)
                    .foregroundStyle(Color(hex: 0x7BB7FF))
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .hour, count: 6)) { val in
                    AxisGridLine(stroke: StrokeStyle(dash: [2, 4]))
                        .foregroundStyle(DS.line)
                    AxisValueLabel(format: .dateTime.hour(.defaultDigits(amPM: .omitted)).minute())
                        .font(.dsMonoXs)
                        .foregroundStyle(DS.fg3)
                }
            }
            .chartYAxis {
                AxisMarks(values: [70, 140, 200]) { val in
                    AxisGridLine(stroke: StrokeStyle(dash: [2, 4]))
                        .foregroundStyle(DS.line)
                    AxisValueLabel()
                        .font(.dsMonoXs)
                        .foregroundStyle(DS.fg3)
                }
            }
            .chartYScale(domain: 40...280)
            .background(DS.bg2.opacity(0.5), in: RoundedRectangle(cornerRadius: DS.rSm))
        }
    }
}

// MARK: - TIR Donut

struct DSTIRDonut: View {
    let lo: Double
    let inR: Double
    let hi: Double

    var body: some View {
        Canvas { ctx, size in
            let c = CGPoint(x: size.width / 2, y: size.height / 2)
            let r = min(size.width, size.height) / 2 - 6
            let stroke: CGFloat = 10
            let total = lo + inR + hi
            guard total > 0 else { return }

            // Track
            var path = Path()
            path.addArc(center: c, radius: r, startAngle: .degrees(-90), endAngle: .degrees(270), clockwise: false)
            ctx.stroke(path, with: .color(DS.bg3), style: StrokeStyle(lineWidth: stroke))

            // Segments: lo (amber) → inR (lime) → hi (red)
            let segments: [(Double, Color)] = [(lo, DS.lo), (inR, DS.accent), (hi, DS.hi)]
            var start = -90.0
            for (pct, color) in segments where pct > 0 {
                let sweep = pct / total * 360
                var seg = Path()
                seg.addArc(center: c, radius: r,
                           startAngle: .degrees(start),
                           endAngle: .degrees(start + sweep),
                           clockwise: false)
                ctx.stroke(seg, with: .color(color),
                           style: StrokeStyle(lineWidth: stroke, lineCap: .butt))
                start += sweep
            }

            // Center text
            let pctStr = "\(Int(inR.rounded()))%"
            ctx.draw(
                Text(pctStr).font(.dsMonoSm).foregroundColor(DS.fg),
                at: CGPoint(x: c.x, y: c.y - 6)
            )
            ctx.draw(
                Text("IN RANGE").font(.dsMonoXs).foregroundColor(DS.fg3),
                at: CGPoint(x: c.x, y: c.y + 10)
            )
        }
    }
}

// MARK: - Wrapper views for existing detail tabs

struct SleepTabViewWrapper: View {
    @State private var dayIndex = 0
    var body: some View { SleepTabView(dayIndex: $dayIndex) }
}

struct ActivityTabViewWrapper: View {
    @State private var dayIndex = 0
    var body: some View { ActivityTabView(dayIndex: $dayIndex) }
}

struct ReadinessTabViewWrapper: View {
    @State private var dayIndex = 0
    var body: some View { ReadinessTabView(dayIndex: $dayIndex) }
}
