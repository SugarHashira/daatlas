import SwiftUI
import Charts

// MARK: - Trends root

struct TrendsView: View {
    @EnvironmentObject var viewModel: SyncViewModel
    @State private var tab: TrendTab = .oura

    enum TrendTab: String, CaseIterable {
        case oura    = "Oura"
        case glucose = "Glucose & Insulin"
    }

    var body: some View {
        ZStack {
            Color.surfaceBg.ignoresSafeArea()
            VStack(spacing: 0) {
                // Sub-tab bar
                HStack(spacing: 0) {
                    ForEach(TrendTab.allCases, id: \.self) { t in
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) { tab = t }
                        } label: {
                            Text(t.rawValue)
                                .font(.system(size: 13, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 11)
                                .foregroundStyle(tab == t ? Color.primary : Color.secondary)
                                .overlay(alignment: .bottom) {
                                    if tab == t {
                                        Capsule().fill(Color.ouraSleep).frame(height: 2).offset(y: 1)
                                    }
                                }
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.top, 6)

                Divider().background(Color.cardBg2)

                switch tab {
                case .oura:    OuraTrendsView()
                case .glucose: GlucoseInsulinView()
                }
            }
        }
        .navigationTitle("Trends")
    }
}

// MARK: - Oura trends

struct OuraTrendsView: View {
    @EnvironmentObject var viewModel: SyncViewModel
    @State private var selectedMetric: TrendMetric = .readiness
    @State private var rangeDays: Int = 30

    enum TrendMetric: String, CaseIterable, Identifiable {
        case readiness = "Readiness"
        case sleep     = "Sleep"
        case activity  = "Activity"
        case hrv       = "HRV"
        case lowestHR  = "Lowest HR"
        case steps     = "Steps"

        var id: String { rawValue }
        var icon: String {
            switch self {
            case .readiness: return "bolt.heart.fill"
            case .sleep:     return "moon.zzz.fill"
            case .activity:  return "figure.run"
            case .hrv:       return "waveform.path.ecg"
            case .lowestHR:  return "heart.fill"
            case .steps:     return "figure.walk"
            }
        }
        var color: Color {
            switch self {
            case .readiness: return .ouraReadiness
            case .sleep:     return .ouraSleep
            case .activity:  return .ouraActivity
            case .hrv:       return Color(red: 0.65, green: 0.40, blue: 0.90)
            case .lowestHR:  return Color(red: 0.90, green: 0.35, blue: 0.40)
            case .steps:     return .ouraActivity
            }
        }
        var unit: String {
            switch self {
            case .hrv:      return " ms"
            case .lowestHR: return " bpm"
            default:        return ""
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Metric chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(TrendMetric.allCases) { m in
                        TrendChip(label: m.rawValue, icon: m.icon, color: m.color,
                                  isSelected: selectedMetric == m)
                            .onTapGesture { withAnimation(.easeInOut(duration: 0.2)) { selectedMetric = m } }
                    }
                }
                .padding(.horizontal).padding(.vertical, 12)
            }

            // Range picker
            Picker("Range", selection: $rangeDays) {
                Text("7D").tag(7)
                Text("30D").tag(30)
                Text("3M").tag(90)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal).padding(.bottom, 8)

            if viewModel.dailySummaries.isEmpty {
                TrendsEmptyState(icon: "chart.line.uptrend.xyaxis",
                                 message: "Sync Oura data to see trends.")
            } else {
                let data   = chartData(for: selectedMetric)
                let accent = selectedMetric.color
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        // Big average
                        HStack(alignment: .bottom) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(selectedMetric.rawValue.uppercased())
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(.secondary).tracking(1.8)
                                if let avg = average(data) {
                                    HStack(alignment: .lastTextBaseline, spacing: 4) {
                                        Text(String(format: "%.0f", avg))
                                            .font(.system(size: 36, weight: .bold, design: .rounded))
                                            .foregroundStyle(accent)
                                        let u = selectedMetric.unit.trimmingCharacters(in: .whitespaces)
                                        if !u.isEmpty {
                                            Text(u).font(.subheadline).foregroundStyle(.secondary)
                                        }
                                    }
                                    Text("avg over \(data.count) days")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Image(systemName: selectedMetric.icon)
                                .font(.system(size: 28)).foregroundStyle(accent.opacity(0.6))
                        }
                        .padding(.horizontal)

                        singleLineChart(data: data, accent: accent, unit: selectedMetric.unit)
                        statsRow(data: data, unit: selectedMetric.unit, accent: accent)
                    }
                    .padding(.bottom, 32)
                }
            }
        }
    }

    // MARK: Helpers
    struct DataPoint { let day: Date; let value: Double }

    private func singleLineChart(data: [DataPoint], accent: Color, unit: String) -> some View {
        VStack {
            Chart(data, id: \.day) { pt in
                AreaMark(x: .value("Date", pt.day), y: .value("v", pt.value))
                    .foregroundStyle(LinearGradient(
                        colors: [accent.opacity(0.22), .clear], startPoint: .top, endPoint: .bottom))
                    .interpolationMethod(.catmullRom)
                LineMark(x: .value("Date", pt.day), y: .value("v", pt.value))
                    .foregroundStyle(accent).lineStyle(StrokeStyle(lineWidth: 2.5))
                    .interpolationMethod(.catmullRom)
                PointMark(x: .value("Date", pt.day), y: .value("v", pt.value))
                    .foregroundStyle(accent).symbolSize(18)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: strideDays(data.count))) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.4)).foregroundStyle(Color.cardBg2)
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day()).foregroundStyle(Color.secondary)
                }
            }
            .chartYAxis {
                AxisMarks { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.4)).foregroundStyle(Color.cardBg2)
                    AxisValueLabel().foregroundStyle(Color.secondary)
                }
            }
            .frame(height: 210).padding(.top, 8)
        }
        .padding().background(Color.cardBg, in: RoundedRectangle(cornerRadius: 20)).padding(.horizontal)
    }

    private func statsRow(data: [DataPoint], unit: String, accent: Color) -> some View {
        guard let minV = data.map(\.value).min(),
              let maxV = data.map(\.value).max(),
              let avgV = average(data) else { return AnyView(EmptyView()) }
        return AnyView(
            HStack(spacing: 0) {
                TrendStatBox(label: "MIN", value: "\(Int(minV))\(unit)", color: accent.opacity(0.6))
                Divider().frame(height: 44)
                TrendStatBox(label: "AVG", value: "\(Int(avgV))\(unit)", color: accent)
                Divider().frame(height: 44)
                TrendStatBox(label: "MAX", value: "\(Int(maxV))\(unit)", color: .ouraActivity)
            }
            .background(Color.cardBg, in: RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal)
        )
    }

    private func chartData(for metric: TrendMetric) -> [DataPoint] {
        let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
        return viewModel.dailySummaries.compactMap { s in
            guard let date = fmt.date(from: s.day) else { return nil }
            let v: Double?
            switch metric {
            case .readiness: v = s.readinessScore.map(Double.init)
            case .sleep:     v = s.sleepScore.map(Double.init)
            case .activity:  v = s.activityScore.map(Double.init)
            case .hrv:       v = s.averageHrv.map(Double.init)
            case .lowestHR:  v = s.lowestHR.map(Double.init)
            case .steps:     v = s.steps.map(Double.init)
            }
            guard let val = v else { return nil }
            return DataPoint(day: date, value: val)
        }.sorted { $0.day < $1.day }.suffix(rangeDays).map { $0 }
    }

    private func average(_ data: [DataPoint]) -> Double? {
        guard !data.isEmpty else { return nil }
        return data.map(\.value).reduce(0, +) / Double(data.count)
    }
    private func strideDays(_ count: Int) -> Int { count > 60 ? 14 : count > 14 ? 7 : count > 7 ? 3 : 1 }
}

// MARK: - Glucose & Insulin view

struct GlucoseInsulinView: View {
    @EnvironmentObject var viewModel: SyncViewModel
    @State private var ouraMetric: OuraCompareMetric = .sleep
    @State private var expandedSection: ExpandedSection? = .overview

    enum OuraCompareMetric: String, CaseIterable, Identifiable {
        case sleep     = "Sleep"
        case readiness = "Readiness"
        case hrv       = "HRV"
        case activity  = "Activity"
        var id: String { rawValue }
        var color: Color {
            switch self {
            case .sleep:     return .ouraSleep
            case .readiness: return .ouraReadiness
            case .hrv:       return Color(red: 0.65, green: 0.40, blue: 0.90)
            case .activity:  return .ouraActivity
            }
        }
        var icon: String {
            switch self {
            case .sleep:     return "moon.zzz.fill"
            case .readiness: return "bolt.heart.fill"
            case .hrv:       return "waveform.path.ecg"
            case .activity:  return "figure.run"
            }
        }
        var unit: String {
            switch self {
            case .sleep:     return "score"
            case .readiness: return "score"
            case .hrv:       return "ms"
            case .activity:  return "score"
            }
        }
    }

    enum ExpandedSection: Equatable {
        case overview, glucose, insulin, correlation, table
    }

    // Joined data point
    struct DayData: Identifiable {
        let id = UUID()
        let day: String
        let date: Date
        let glucose: Double?
        let insulin: Double?
        let ouraValue: Double?
    }

    var body: some View {
        let days = joinedData()
        let hasGlucose = days.contains { $0.glucose != nil }
        let hasInsulin = days.contains { $0.insulin != nil }
        let hasOura    = days.contains { $0.ouraValue != nil }

        if !hasGlucose && !hasInsulin {
            TrendsEmptyState(icon: "drop.triangle.fill",
                             message: "Sync Nightscout glucose and insulin data first, then sync Oura.")
        } else {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    // Oura metric picker
                    if hasOura {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("COMPARE WITH")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.secondary).tracking(1.5)
                                .padding(.horizontal)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(OuraCompareMetric.allCases) { m in
                                        TrendChip(label: m.rawValue, icon: m.icon,
                                                  color: m.color, isSelected: ouraMetric == m)
                                            .onTapGesture {
                                                withAnimation(.easeInOut(duration: 0.2)) { ouraMetric = m }
                                            }
                                    }
                                }
                                .padding(.horizontal).padding(.vertical, 4)
                            }
                        }
                    }

                    // Summary stats row
                    summaryStatsCard(days: days)

                    // Correlation insight
                    if hasGlucose && hasOura {
                        correlationCard(days: days)
                    }

                    // Glucose + Oura dual line
                    if hasGlucose {
                        sectionCard(title: "GLUCOSE TREND", icon: "drop.fill",
                                    color: glucoseColor, section: .glucose) {
                            glucoseChart(days: days)
                        }
                    }

                    // Insulin + Oura dual line
                    if hasInsulin {
                        sectionCard(title: "INSULIN INTAKE", icon: "syringe.fill",
                                    color: insulinColor, section: .insulin) {
                            insulinChart(days: days)
                        }
                    }

                    // Glucose vs Oura scatter
                    if hasGlucose && hasOura {
                        sectionCard(title: "GLUCOSE vs \(ouraMetric.rawValue.uppercased())",
                                    icon: "chart.dots.scatter", color: ouraMetric.color,
                                    section: .correlation) {
                            scatterChart(days: days)
                        }
                    }

                    // Day-by-day table
                    dayTable(days: days)
                }
                .padding(.top, 12)
                .padding(.bottom, 32)
            }
        }
    }

    // MARK: Summary stats card

    private func summaryStatsCard(days: [DayData]) -> some View {
        let glucoseDays  = days.compactMap(\.glucose)
        let insulinDays  = days.compactMap(\.insulin)

        return HStack(spacing: 0) {
            if !glucoseDays.isEmpty {
                let avg = glucoseDays.reduce(0,+) / Double(glucoseDays.count)
                miniStat(icon: "drop.fill", color: glucoseColor,
                         label: "Avg Glucose", value: String(format: "%.0f", avg), unit: "mg/dL")
            }
            if !glucoseDays.isEmpty && !insulinDays.isEmpty {
                Divider().frame(height: 48)
            }
            if !insulinDays.isEmpty {
                let avg = insulinDays.reduce(0,+) / Double(insulinDays.count)
                miniStat(icon: "syringe.fill", color: insulinColor,
                         label: "Avg Insulin", value: String(format: "%.1f", avg), unit: "U/day")
            }
            if (!glucoseDays.isEmpty || !insulinDays.isEmpty) && days.contains(where: { $0.ouraValue != nil }) {
                Divider().frame(height: 48)
                let ouraVals = days.compactMap(\.ouraValue)
                let avg = ouraVals.reduce(0,+) / Double(ouraVals.count)
                miniStat(icon: ouraMetric.icon, color: ouraMetric.color,
                         label: "Avg \(ouraMetric.rawValue)",
                         value: String(format: "%.0f", avg), unit: ouraMetric.unit)
            }
        }
        .background(Color.cardBg, in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    private func miniStat(icon: String, color: Color, label: String, value: String, unit: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 12)).foregroundStyle(color)
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value).font(.system(size: 20, weight: .bold, design: .rounded)).foregroundStyle(color)
                Text(unit).font(.system(size: 10)).foregroundStyle(.secondary)
            }
            Text(label).font(.system(size: 10)).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 14)
    }

    // MARK: Correlation card

    private func correlationCard(days: [DayData]) -> some View {
        let gVals = days.compactMap { d -> (Double, Double)? in
            guard let g = d.glucose, let o = d.ouraValue else { return nil }
            return (g, o)
        }
        let r = pearson(gVals.map(\.0), gVals.map(\.1))
        let iVals = days.compactMap { d -> (Double, Double)? in
            guard let i = d.insulin, let o = d.ouraValue else { return nil }
            return (i, o)
        }
        let ri = pearson(iVals.map(\.0), iVals.map(\.1))

        return OuraCard(title: "Correlation", icon: "function", color: ouraMetric.color) {
            HStack(spacing: 0) {
                correlationStat(label: "Glucose → \(ouraMetric.rawValue)", r: r, n: gVals.count,
                                color: glucoseColor)
                if ri != nil {
                    Divider().frame(height: 60)
                    correlationStat(label: "Insulin → \(ouraMetric.rawValue)", r: ri, n: iVals.count,
                                    color: insulinColor)
                }
            }
        }
    }

    private func correlationStat(label: String, r: Double?, n: Int, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label).font(.system(size: 11)).foregroundStyle(.secondary)
            if let r {
                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text(String(format: "%.2f", r))
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(abs(r) > 0.4 ? color : .secondary)
                    Text("r").font(.caption).foregroundStyle(.secondary)
                }
                Text(correlationLabel(r)).font(.caption).foregroundStyle(.secondary)
                Text("\(n) days").font(.caption2).foregroundStyle(.tertiary)
            } else {
                Text("Not enough data").font(.caption).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
    }

    private func correlationLabel(_ r: Double) -> String {
        switch abs(r) {
        case 0.7...: return r < 0 ? "Strong negative" : "Strong positive"
        case 0.4...: return r < 0 ? "Moderate negative" : "Moderate positive"
        case 0.2...: return r < 0 ? "Weak negative" : "Weak positive"
        default:     return "No clear relationship"
        }
    }

    // MARK: Glucose chart (glucose + oura on secondary axis via normalisation)

    private func glucoseChart(days: [DayData]) -> some View {
        let glucoseDays = days.filter { $0.glucose != nil }
        let ouraDays    = days.filter { $0.ouraValue != nil }

        return VStack(alignment: .leading, spacing: 10) {
            // Legend
            HStack(spacing: 16) {
                legendDot(color: glucoseColor, label: "Avg Glucose (mg/dL)")
                if !ouraDays.isEmpty {
                    legendDot(color: ouraMetric.color, label: "\(ouraMetric.rawValue) score", dashed: true)
                }
            }

            Chart {
                // Glucose bars
                ForEach(glucoseDays) { d in
                    BarMark(
                        x: .value("Day", d.date),
                        y: .value("Glucose", d.glucose ?? 0),
                        width: .ratio(0.4)
                    )
                    .foregroundStyle(glucoseColor.opacity(0.7))
                    .cornerRadius(3)
                }
                // Glucose line
                ForEach(glucoseDays) { d in
                    LineMark(
                        x: .value("Day", d.date),
                        y: .value("Glucose", d.glucose ?? 0),
                        series: .value("s", "glucose")
                    )
                    .foregroundStyle(glucoseColor)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    .interpolationMethod(.catmullRom)
                    PointMark(x: .value("Day", d.date), y: .value("Glucose", d.glucose ?? 0))
                        .foregroundStyle(glucoseColor).symbolSize(14)
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: strideDays(glucoseDays.count))) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.4)).foregroundStyle(Color.cardBg2)
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day()).foregroundStyle(Color.secondary)
                }
            }
            .chartYAxis {
                AxisMarks { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.4)).foregroundStyle(Color.cardBg2)
                    AxisValueLabel().foregroundStyle(Color.secondary)
                }
            }
            .frame(height: 200)

            // Oura overlay as a separate normalised line chart below
            if !ouraDays.isEmpty {
                Divider().background(Color.cardBg2)
                Text("\(ouraMetric.rawValue.uppercased()) SCORE")
                    .font(.system(size: 10, weight: .semibold)).foregroundStyle(ouraMetric.color).tracking(1.2)

                Chart {
                    ForEach(ouraDays) { d in
                        LineMark(
                            x: .value("Day", d.date),
                            y: .value(ouraMetric.rawValue, d.ouraValue ?? 0)
                        )
                        .foregroundStyle(ouraMetric.color)
                        .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 3]))
                        .interpolationMethod(.catmullRom)
                        AreaMark(
                            x: .value("Day", d.date),
                            y: .value(ouraMetric.rawValue, d.ouraValue ?? 0)
                        )
                        .foregroundStyle(LinearGradient(
                            colors: [ouraMetric.color.opacity(0.20), .clear],
                            startPoint: .top, endPoint: .bottom))
                        .interpolationMethod(.catmullRom)
                        PointMark(x: .value("Day", d.date), y: .value(ouraMetric.rawValue, d.ouraValue ?? 0))
                            .foregroundStyle(ouraMetric.color).symbolSize(14)
                    }
                }
                .chartXAxis(.hidden)
                .chartYAxis {
                    AxisMarks(values: [0, 50, 100]) { _ in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.4)).foregroundStyle(Color.cardBg2)
                        AxisValueLabel().foregroundStyle(Color.secondary)
                    }
                }
                .frame(height: 100)
            }
        }
    }

    // MARK: Insulin chart

    private func insulinChart(days: [DayData]) -> some View {
        let insulinDays = days.filter { $0.insulin != nil }
        let ouraDays    = days.filter { $0.ouraValue != nil }

        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 16) {
                legendDot(color: insulinColor, label: "Total Insulin (U)")
                if !ouraDays.isEmpty {
                    legendDot(color: ouraMetric.color, label: "\(ouraMetric.rawValue) score", dashed: true)
                }
            }

            Chart {
                ForEach(insulinDays) { d in
                    BarMark(
                        x: .value("Day", d.date),
                        y: .value("Insulin", d.insulin ?? 0),
                        width: .ratio(0.4)
                    )
                    .foregroundStyle(insulinColor.opacity(0.75))
                    .cornerRadius(3)
                }
                ForEach(insulinDays) { d in
                    LineMark(
                        x: .value("Day", d.date),
                        y: .value("Insulin", d.insulin ?? 0),
                        series: .value("s", "insulin")
                    )
                    .foregroundStyle(insulinColor)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    .interpolationMethod(.catmullRom)
                    PointMark(x: .value("Day", d.date), y: .value("Insulin", d.insulin ?? 0))
                        .foregroundStyle(insulinColor).symbolSize(14)
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: strideDays(insulinDays.count))) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.4)).foregroundStyle(Color.cardBg2)
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day()).foregroundStyle(Color.secondary)
                }
            }
            .chartYAxis {
                AxisMarks { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.4)).foregroundStyle(Color.cardBg2)
                    AxisValueLabel().foregroundStyle(Color.secondary)
                }
            }
            .frame(height: 200)

            if !ouraDays.isEmpty {
                Divider().background(Color.cardBg2)
                Text("\(ouraMetric.rawValue.uppercased()) SCORE")
                    .font(.system(size: 10, weight: .semibold)).foregroundStyle(ouraMetric.color).tracking(1.2)
                Chart {
                    ForEach(ouraDays) { d in
                        LineMark(
                            x: .value("Day", d.date),
                            y: .value(ouraMetric.rawValue, d.ouraValue ?? 0)
                        )
                        .foregroundStyle(ouraMetric.color)
                        .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 3]))
                        .interpolationMethod(.catmullRom)
                        AreaMark(
                            x: .value("Day", d.date),
                            y: .value(ouraMetric.rawValue, d.ouraValue ?? 0)
                        )
                        .foregroundStyle(LinearGradient(
                            colors: [ouraMetric.color.opacity(0.20), .clear],
                            startPoint: .top, endPoint: .bottom))
                        .interpolationMethod(.catmullRom)
                    }
                }
                .chartXAxis(.hidden)
                .chartYAxis {
                    AxisMarks(values: [0, 50, 100]) { _ in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.4)).foregroundStyle(Color.cardBg2)
                        AxisValueLabel().foregroundStyle(Color.secondary)
                    }
                }
                .frame(height: 100)
            }
        }
    }

    // MARK: Scatter

    private func scatterChart(days: [DayData]) -> some View {
        let pts = days.compactMap { d -> (glucose: Double, oura: Double)? in
            guard let g = d.glucose, let o = d.ouraValue else { return nil }
            return (g, o)
        }
        guard !pts.isEmpty else {
            return AnyView(Text("Not enough overlapping data")
                .font(.footnote).foregroundStyle(.secondary).padding())
        }
        return AnyView(
            Chart {
                ForEach(Array(pts.enumerated()), id: \.offset) { _, pt in
                    PointMark(
                        x: .value("Glucose (mg/dL)", pt.glucose),
                        y: .value(ouraMetric.rawValue, pt.oura)
                    )
                    .foregroundStyle(ouraMetric.color.opacity(0.7))
                    .symbolSize(45)
                }
            }
            .chartXAxisLabel("Avg Glucose (mg/dL)", alignment: .center)
            .chartYAxisLabel(ouraMetric.rawValue, position: .leading)
            .chartXAxis {
                AxisMarks { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.4)).foregroundStyle(Color.cardBg2)
                    AxisValueLabel().foregroundStyle(Color.secondary)
                }
            }
            .chartYAxis {
                AxisMarks { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.4)).foregroundStyle(Color.cardBg2)
                    AxisValueLabel().foregroundStyle(Color.secondary)
                }
            }
            .frame(height: 200)
        )
    }

    // MARK: Day table

    private func dayTable(days: [DayData]) -> some View {
        let hasG = days.contains { $0.glucose != nil }
        let hasI = days.contains { $0.insulin != nil }
        let hasO = days.contains { $0.ouraValue != nil }

        return VStack(alignment: .leading, spacing: 0) {
            Text("DAY BY DAY")
                .font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary).tracking(2)
                .padding(.horizontal).padding(.bottom, 8)

            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Date").frame(maxWidth: .infinity, alignment: .leading)
                    if hasG { Text("Gluc.").foregroundStyle(glucoseColor).frame(width: 52, alignment: .trailing) }
                    if hasI { Text("Ins.").foregroundStyle(insulinColor).frame(width: 44, alignment: .trailing) }
                    if hasO { Text(String(ouraMetric.rawValue.prefix(3)))
                                  .foregroundStyle(ouraMetric.color).frame(width: 40, alignment: .trailing) }
                }
                .font(.system(size: 10, weight: .semibold)).tracking(1.2)
                .padding(.horizontal, 20).padding(.vertical, 8)

                Divider().background(Color.cardBg2)

                ForEach(days.reversed()) { d in
                    HStack {
                        Text(fmtDay(d.day))
                            .font(.system(size: 13)).frame(maxWidth: .infinity, alignment: .leading)
                        if hasG {
                            Text(d.glucose.map { String(format: "%.0f", $0) } ?? "—")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(d.glucose != nil ? glucoseColor : Color.secondary)
                                .frame(width: 52, alignment: .trailing)
                        }
                        if hasI {
                            Text(d.insulin.map { String(format: "%.1f", $0) } ?? "—")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(d.insulin != nil ? insulinColor : Color.secondary)
                                .frame(width: 44, alignment: .trailing)
                        }
                        if hasO {
                            Text(d.ouraValue.map { String(format: "%.0f", $0) } ?? "—")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(d.ouraValue != nil ? ouraMetric.color : Color.secondary)
                                .frame(width: 40, alignment: .trailing)
                        }
                    }
                    .padding(.horizontal, 20).padding(.vertical, 10)
                    Divider().background(Color.cardBg2).padding(.leading, 20)
                }
            }
            .background(Color.cardBg, in: RoundedRectangle(cornerRadius: 20))
            .padding(.horizontal)
        }
    }

    // MARK: Section card helper

    private func sectionCard<Content: View>(title: String, icon: String, color: Color,
                                            section: ExpandedSection,
                                            @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    expandedSection = expandedSection == section ? nil : section
                }
            } label: {
                HStack {
                    Image(systemName: icon).font(.system(size: 12, weight: .semibold)).foregroundStyle(color)
                    Text(title).font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary).tracking(1.5)
                    Spacer()
                    Image(systemName: expandedSection == section ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                }
                .padding(20)
            }

            if expandedSection == section {
                Divider().background(Color.cardBg2)
                content().padding(20)
            }
        }
        .background(Color.cardBg, in: RoundedRectangle(cornerRadius: 20))
        .padding(.horizontal)
    }

    // MARK: Data helpers

    private func joinedData() -> [DayData] {
        let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
        let allDays = Set(viewModel.glucoseByDay.keys)
            .union(viewModel.insulinByDay.keys)
            .union(viewModel.dailySummaries.map(\.day))
            .sorted()

        return allDays.compactMap { day in
            guard let date = fmt.date(from: day) else { return nil }
            let ouraVal: Double?
            if let s = viewModel.dailySummaries.first(where: { $0.day == day }) {
                switch ouraMetric {
                case .sleep:     ouraVal = s.sleepScore.map(Double.init)
                case .readiness: ouraVal = s.readinessScore.map(Double.init)
                case .hrv:       ouraVal = s.averageHrv.map(Double.init)
                case .activity:  ouraVal = s.activityScore.map(Double.init)
                }
            } else { ouraVal = nil }
            let g = viewModel.glucoseByDay[day]
            let i = viewModel.insulinByDay[day]
            // Only include days that have at least one data point
            guard g != nil || i != nil || ouraVal != nil else { return nil }
            return DayData(day: day, date: date, glucose: g, insulin: i, ouraValue: ouraVal)
        }
    }

    private func pearson(_ x: [Double], _ y: [Double]) -> Double? {
        guard x.count == y.count, x.count > 2 else { return nil }
        let n = Double(x.count)
        let mx = x.reduce(0,+)/n, my = y.reduce(0,+)/n
        let num  = zip(x,y).map { ($0-mx)*($1-my) }.reduce(0,+)
        let denX = sqrt(x.map { ($0-mx)*($0-mx) }.reduce(0,+))
        let denY = sqrt(y.map { ($0-my)*($0-my) }.reduce(0,+))
        let den  = denX * denY
        guard den > 0 else { return nil }
        return num/den
    }

    private func fmtDay(_ day: String) -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        guard let d = f.date(from: day) else { return day }
        f.dateFormat = "EEE d MMM"; return f.string(from: d)
    }

    private func legendDot(color: Color, label: String, dashed: Bool = false) -> some View {
        HStack(spacing: 5) {
            if dashed {
                HStack(spacing: 2) {
                    Capsule().fill(color).frame(width: 8, height: 3)
                    Capsule().fill(color.opacity(0.4)).frame(width: 4, height: 3)
                }
            } else {
                Capsule().fill(color).frame(width: 14, height: 3)
            }
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
    }

    private var glucoseColor: Color { Color(red: 0.95, green: 0.38, blue: 0.32) }
    private var insulinColor:  Color { Color(red: 0.28, green: 0.58, blue: 0.95) }
    private var ouraMetricUnit: String {
        switch ouraMetric { case .hrv: return " ms"; default: return "" }
    }
    private func strideDays(_ count: Int) -> Int { count > 60 ? 14 : count > 14 ? 7 : count > 7 ? 3 : 1 }
}

// MARK: - Shared components

struct TrendChip: View {
    let label: String
    let icon: String
    let color: Color
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon).font(.system(size: 11))
            Text(label).font(.system(size: 13, weight: .medium))
        }
        .foregroundStyle(isSelected ? color : .secondary)
        .padding(.horizontal, 14).padding(.vertical, 8)
        .background(isSelected ? color.opacity(0.18) : Color.cardBg, in: Capsule())
        .overlay(Capsule().strokeBorder(isSelected ? color.opacity(0.4) : .clear, lineWidth: 1))
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}

struct TrendStatBox: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(label).font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary).tracking(1.2)
            Text(value).font(.system(size: 18, weight: .bold, design: .rounded)).foregroundStyle(color)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 14)
    }
}

struct TrendsEmptyState: View {
    let icon: String
    let message: String

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: icon).font(.system(size: 52)).foregroundStyle(.secondary)
            Text("No Data").font(.headline)
            Text(message).font(.subheadline).foregroundStyle(.secondary)
                .multilineTextAlignment(.center).padding(.horizontal, 40)
            Spacer()
        }
    }
}
