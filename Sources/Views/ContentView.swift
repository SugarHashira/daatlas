import SwiftUI
import Charts

// MARK: - Design tokens (remapped to DS system)

extension Color {
    // Surfaces — aliased to DS
    static let surfaceBg = DS.bg        // #0B0C0E
    static let cardBg    = DS.bg1       // #121317
    static let cardBg2   = DS.bg2       // #181A1F

    // Metric accent — all lime per DS spec (no orange, no multi-color)
    static let ouraReadiness = DS.accent            // lime
    static let ouraActivity  = DS.accent            // lime
    static let ouraSleep     = Color(hex: 0x7BB7FF) // blue (sleep stages only)
    static let ouraStress    = DS.hi                // red

    // Hero backgrounds — flat dark (no colored tints)
    static let heroSleep     = DS.bg1
    static let heroReadiness = DS.bg1
    static let heroActivity  = DS.bg1
    static let heroStress    = DS.bg1
    static let heroGlucose   = DS.bg1
}

// MARK: - Score quality helpers

func scoreQuality(_ score: Int?) -> (label: String, color: Color) {
    guard let s = score else { return ("–", DS.fg4) }
    switch s {
    case 85...100: return ("OPTIMAL", DS.accent)
    case 70...84:  return ("GOOD",    DS.accent.opacity(0.8))
    case 60...69:  return ("FAIR",    DS.lo)
    default:       return ("POOR",    DS.hi)
    }
}

func scoreMessage(score: Int?, type: String) -> String {
    guard let s = score else { return "Sync your Oura Ring to see \(type) data." }
    switch type {
    case "sleep":
        switch s {
        case 85...: return "You slept really well last night."
        case 70...: return "Decent sleep — you should feel okay today."
        case 60...: return "Sleep was a bit disrupted. Take it easy."
        default:    return "Poor sleep last night. Rest when you can."
        }
    case "readiness":
        switch s {
        case 85...: return "You're well rested and ready to go."
        case 70...: return "Your body is in good shape today."
        case 60...: return "Consider lighter activity today."
        default:    return "Your body needs recovery. Be kind to yourself."
        }
    case "stress":
        switch s {
        case 85...: return "Low stress — you're recovered and resilient."
        case 70...: return "Moderate stress levels today."
        default:    return "High stress detected. Try to find moments to relax."
        }
    case "glucose":
        switch s {
        case 85...: return "Excellent glucose control today."
        case 70...: return "Good time in range. Keep it up."
        case 60...: return "Most readings in range. Small adjustments could help."
        default:    return "More readings outside target range today."
        }
    default: return ""
    }
}

// MARK: - Score ring chip (arc gauge)

struct ScoreChip: View {
    let icon: String
    let color: Color
    let label: String
    let value: String
    var fraction: Double = 0   // 0…1 arc fill

    private let size: CGFloat   = 84
    private let stroke: CGFloat = 10

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                // Dark background fill
                Circle()
                    .fill(Color(white: 0.08))
                // Track ring — padded so stroke stays inside frame
                Circle()
                    .stroke(color.opacity(0.18), lineWidth: stroke)
                    .padding(stroke / 2)
                // Progress arc
                if fraction > 0.005 {
                    Circle()
                        .trim(from: 0, to: CGFloat(min(fraction, 1.0)))
                        .stroke(color, style: StrokeStyle(lineWidth: stroke, lineCap: .round))
                        .padding(stroke / 2)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeOut(duration: 0.6), value: fraction)
                }
                // Center content
                VStack(spacing: 1) {
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(fraction > 0.005 ? color : Color(white: 0.40))
                    Text(value)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                }
            }
            .frame(width: size, height: size)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color(white: 0.50))
        }
        .frame(width: size + 8)
    }
}

struct ScorePillRow: View {
    let summaries: [OuraDailySummary]
    @Binding var selectedTab: Int
    @Binding var healthSubTab: Int
    @Binding var showGlucose: Bool
    var tirPct: Int? = nil

    private var latestReadiness:  OuraDailySummary? { summaries.first { $0.readinessScore != nil } }
    private var latestSleep:      OuraDailySummary? { summaries.first { $0.sleepScore != nil } }
    private var latestActivity:   OuraDailySummary? { summaries.first { $0.activityScore != nil } }
    private var latestStress:     OuraDailySummary? { summaries.first { $0.stressSummary != nil } }
    private var latestResilience: OuraDailySummary? { summaries.first { $0.resilienceLevel != nil } }

    private var tirColor: Color {
        guard let t = tirPct else { return Color(white: 0.4) }
        if t >= 70 { return .ouraActivity }
        if t >= 50 { return .ouraReadiness }
        return .red
    }

    // Resilience level → rough 0…1 fraction
    private func resilienceFraction(_ level: String?) -> Double {
        switch level?.lowercased() {
        case "exceptional": return 1.0
        case "strong":      return 0.80
        case "adequate":    return 0.60
        case "limited":     return 0.40
        default:            return 0
        }
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                // Glucose / TIR
                Button { showGlucose = true } label: {
                    ScoreChip(icon: "drop.fill", color: tirColor,
                              label: "Glucose",
                              value: tirPct.map { "\($0)%" } ?? "–",
                              fraction: tirPct.map { Double($0) / 100.0 } ?? 0)
                }
                .buttonStyle(.plain)

                // Readiness
                Button { healthSubTab = 1; selectedTab = 2 } label: {
                    ScoreChip(icon: "bolt.heart.fill", color: .ouraReadiness,
                              label: "Readiness",
                              value: latestReadiness?.readinessScore.map { "\($0)" } ?? "–",
                              fraction: latestReadiness?.readinessScore.map { Double($0) / 100.0 } ?? 0)
                }
                .buttonStyle(.plain)

                // Sleep
                Button { healthSubTab = 0; selectedTab = 2 } label: {
                    ScoreChip(icon: "moon.zzz.fill", color: .ouraSleep,
                              label: "Sleep",
                              value: latestSleep?.sleepScore.map { "\($0)" } ?? "–",
                              fraction: latestSleep?.sleepScore.map { Double($0) / 100.0 } ?? 0)
                }
                .buttonStyle(.plain)

                // Activity
                Button { healthSubTab = 2; selectedTab = 2 } label: {
                    ScoreChip(icon: "figure.run", color: .ouraActivity,
                              label: "Activity",
                              value: latestActivity?.activityScore.map { "\($0)" } ?? "–",
                              fraction: latestActivity?.activityScore.map { Double($0) / 100.0 } ?? 0)
                }
                .buttonStyle(.plain)

                // Resilience
                Button { healthSubTab = 3; selectedTab = 2 } label: {
                    let level = latestResilience?.resilienceLevel
                    ScoreChip(icon: "waveform.path.ecg.rectangle.fill",
                              color: DS.accent,
                              label: "Resilience",
                              value: level?.capitalized ?? "–",
                              fraction: resilienceFraction(level))
                }
                .buttonStyle(.plain)

                // Stress
                Button { healthSubTab = 3; selectedTab = 2 } label: {
                    let sm = latestStress?.stressHighMinutes ?? 0
                    let rm = latestStress?.recoveryHighMinutes ?? 0
                    let total = max(sm + rm, 1)
                    let recovFrac = Double(rm) / Double(total)
                    ScoreChip(icon: "brain.head.profile", color: .ouraStress,
                              label: "Stress",
                              value: latestStress?.stressSummary?.capitalized ?? "–",
                              fraction: recovFrac)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
        }
    }
}

// MARK: - Tab hero header  (no pill row — pills are Home-only)

struct TabHeroView: View {
    let score: Int?
    let icon: String
    let color: Color
    let title: String
    let subtitle: String
    let type: String
    var heroBg: Color = .surfaceBg
    /// Optional secondary metric values: [(label, value, unit)]
    var metrics: [(String, String, String)] = []

    var body: some View {
        let quality = scoreQuality(score)
        ZStack(alignment: .bottom) {
            // Gradient hero background
            LinearGradient(
                stops: [
                    .init(color: heroBg, location: 0),
                    .init(color: heroBg.opacity(0.6), location: 0.55),
                    .init(color: Color.surfaceBg, location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(spacing: 0) {
                Spacer().frame(height: 32)

                // Icon circle
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(color)
                }
                .padding(.bottom, 12)

                // Big score
                Text(score.map { "\($0)" } ?? "–")
                    .font(.system(size: 86, weight: .thin, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.bottom, 4)

                // Title + quality badge
                HStack(spacing: 8) {
                    Text(title)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color(white: 0.50)).tracking(2)
                    Text(quality.label)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(quality.color).tracking(1.5)
                        .padding(.horizontal, 9).padding(.vertical, 4)
                        .background(quality.color.opacity(0.18), in: Capsule())
                        .overlay(Capsule().strokeBorder(quality.color.opacity(0.35), lineWidth: 0.5))
                }
                .padding(.bottom, subtitle.isEmpty ? 12 : 6)

                // Subtitle (e.g. duration, temp)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color(white: 0.45))
                        .padding(.bottom, 12)
                }

                // Narrative message (larger, more prominent)
                Text(scoreMessage(score: score, type: type))
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(Color(white: 0.65))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.horizontal, 28)
                    .padding(.bottom, metrics.isEmpty ? 28 : 20)

                // Optional inline metric pills
                if !metrics.isEmpty {
                    HStack(spacing: 0) {
                        ForEach(Array(metrics.enumerated()), id: \.offset) { idx, m in
                            if idx > 0 {
                                Divider().frame(height: 32).background(Color.white.opacity(0.12))
                            }
                            VStack(spacing: 2) {
                                HStack(alignment: .lastTextBaseline, spacing: 3) {
                                    Text(m.1)
                                        .font(.system(size: 16, weight: .bold, design: .rounded))
                                        .foregroundStyle(.white)
                                    if !m.2.isEmpty {
                                        Text(m.2).font(.system(size: 10)).foregroundStyle(.secondary)
                                    }
                                }
                                Text(m.0)
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundStyle(.secondary).tracking(0.5)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                    .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Health Monitor Grid (RHR / HRV / SpO₂ / Temp / RR / Sleep)

struct HealthMonitorGrid: View {
    let summary: OuraDailySummary?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("HEALTH MONITOR")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .tracking(1.5)

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8)
            ], spacing: 8) {
                monitorCell(
                    icon: "heart.fill",
                    label: "RHR",
                    value: summary?.lowestHR.map { "\($0)" } ?? "–",
                    unit: "bpm",
                    color: DS.hi
                )
                monitorCell(
                    icon: "waveform.path.ecg",
                    label: "HRV",
                    value: summary?.averageHrv.map { "\($0)" } ?? "–",
                    unit: "ms",
                    color: DS.fg2
                )
                monitorCell(
                    icon: "lungs.fill",
                    label: "SpO₂",
                    value: summary?.averageSpO2.map { String(format: "%.0f", $0) } ?? "–",
                    unit: "%",
                    color: DS.fg2
                )
                monitorCell(
                    icon: "thermometer.medium",
                    label: "Temp",
                    value: summary?.temperatureDeviation.map {
                        $0 >= 0 ? String(format: "+%.1f", $0) : String(format: "%.1f", $0)
                    } ?? "–",
                    unit: "°C dev",
                    color: DS.lo
                )
                monitorCell(
                    icon: "wind",
                    label: "Resp",
                    value: summary?.respiratoryRate.map { String(format: "%.1f", $0) } ?? "–",
                    unit: "br/min",
                    color: DS.accent
                )
                monitorCell(
                    icon: "moon.zzz.fill",
                    label: "Sleep",
                    value: summary?.totalSleepMinutes.map { m -> String in
                        let h = m / 60; let mn = m % 60
                        return mn > 0 ? "\(h)h\(mn)m" : "\(h)h"
                    } ?? "–",
                    unit: "total",
                    color: DS.fg2
                )
            }
        }
        .padding(18)
        .background(Color.cardBg, in: RoundedRectangle(cornerRadius: 20))
        .padding(.horizontal)
    }

    private func monitorCell(icon: String, label: String, value: String, unit: String, color: Color) -> some View {
        VStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: value.count > 5 ? 13 : 18, weight: .bold, design: .rounded))
                .foregroundStyle(value == "–" ? Color(white: 0.3) : .white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            if !unit.isEmpty {
                Text(unit)
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(Color(white: 0.38))
                    .lineLimit(1)
            }
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(Color(white: 0.45))
                .tracking(0.6)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color(white: 0.07), in: RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Activity Heatmap Card (14-day)

struct ActivityHeatmapCard: View {
    let summaries: [OuraDailySummary]

    // Oldest → newest left to right (last 14 days)
    private var last14: [OuraDailySummary] {
        Array(summaries.prefix(14).reversed())
    }

    private func activityColor(_ s: OuraDailySummary) -> Color {
        guard let score = s.activityScore else { return Color(white: 0.14) }
        if score >= 85 { return DS.accent }
        if score >= 70 { return DS.accent.opacity(0.75) }
        if score >= 55 { return DS.lo }
        return DS.hi
    }

    private func dayLabel(_ s: OuraDailySummary) -> String {
        let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
        guard let d = fmt.date(from: s.day) else { return "" }
        fmt.dateFormat = "d"; return fmt.string(from: d)
    }

    private func weekLabel(_ s: OuraDailySummary) -> String {
        let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
        guard let d = fmt.date(from: s.day) else { return "" }
        fmt.dateFormat = "EEE"; return fmt.string(from: d)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("14-DAY ACTIVITY")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .tracking(1.5)
                Spacer()
                HStack(spacing: 8) {
                    legendDot(Color(white: 0.14), "None")
                    legendDot(DS.hi, "Low")
                    legendDot(DS.lo, "Fair")
                    legendDot(DS.accent, "Good")
                }
            }

            HStack(spacing: 5) {
                ForEach(last14, id: \.day) { s in
                    VStack(spacing: 5) {
                        Text(weekLabel(s))
                            .font(.system(size: 8, weight: .medium))
                            .foregroundStyle(Color(white: 0.35))
                        RoundedRectangle(cornerRadius: 7)
                            .fill(activityColor(s))
                            .frame(height: 40)
                            .overlay(
                                Text(s.activityScore.map { "\($0)" } ?? "")
                                    .font(.system(size: 9, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white.opacity(s.activityScore != nil ? 0.85 : 0))
                            )
                        Text(dayLabel(s))
                            .font(.system(size: 8))
                            .foregroundStyle(Color(white: 0.35))
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(18)
        .background(Color.cardBg, in: RoundedRectangle(cornerRadius: 20))
        .padding(.horizontal)
    }

    private func legendDot(_ color: Color, _ label: String) -> some View {
        HStack(spacing: 3) {
            RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 8, height: 8)
            Text(label).font(.system(size: 8)).foregroundStyle(Color(white: 0.4))
        }
    }
}

// MARK: - VO2Max / Cardio Age mini card

struct CardioInsightCard: View {
    let summaries: [OuraDailySummary]

    private var latestVO2:   Int? { summaries.compactMap(\.vo2Max).first }
    private var latestCVAge: Int? { summaries.compactMap(\.cardiovascularAge).first }

    var body: some View {
        guard latestVO2 != nil || latestCVAge != nil else { return AnyView(EmptyView()) }

        return AnyView(
            HStack(spacing: 0) {
                if let v = latestVO2 {
                    cardCell(
                        icon: "lungs.fill",
                        label: "VO₂ MAX",
                        value: "\(v)",
                        unit: "mL/kg/min",
                        color: DS.fg2,
                        note: vo2Quality(v)
                    )
                }
                if latestVO2 != nil && latestCVAge != nil {
                    Divider().frame(height: 56).background(Color.cardBg2)
                }
                if let age = latestCVAge {
                    cardCell(
                        icon: "heart.text.square.fill",
                        label: "CARDIO AGE",
                        value: "\(age)",
                        unit: "years",
                        color: DS.hi,
                        note: nil
                    )
                }
            }
            .background(Color.cardBg, in: RoundedRectangle(cornerRadius: 20))
            .padding(.horizontal)
        )
    }

    private func cardCell(icon: String, label: String, value: String, unit: String,
                          color: Color, note: String?) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(color)
                Text(label)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .tracking(1.2)
            }
            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text(value)
                    .font(.system(size: 32, weight: .thin, design: .rounded))
                    .foregroundStyle(.white)
                Text(unit)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            if let note = note {
                Text(note)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(color)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
    }

    private func vo2Quality(_ v: Int) -> String {
        if v >= 55 { return "Excellent" }
        if v >= 47 { return "Good" }
        if v >= 39 { return "Average" }
        return "Below Average"
    }
}

// MARK: - ContentView

struct ContentView: View {
    @EnvironmentObject var viewModel: SyncViewModel
    @State private var selectedTab:  Int = 0
    @State private var healthSubTab: Int = 0   // 0=Sleep 1=Readiness 2=Activity 3=Stress
    @State private var showGlucose   = false
    @State private var isLoading     = true

    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                // 0 — Today
                HomeView(selectedTab: $selectedTab, healthSubTab: $healthSubTab, showGlucose: $showGlucose)
                    .tabItem { Label("Today", systemImage: "sun.max.fill") }
                    .tag(0)

                // 1 — Vitals overview
                NavigationStack { VitalsView(selectedTab: $selectedTab, healthSubTab: $healthSubTab) }
                    .tabItem { Label("Vitals", systemImage: "waveform.path.ecg") }
                    .tag(1)

                // 2 — My Health (Sleep / Readiness / Activity / Stress)
                NavigationStack { MyHealthView(subTab: $healthSubTab) }
                    .tabItem { Label("My Health", systemImage: "heart.text.square.fill") }
                    .tag(2)

                // 3 — Journal
                NavigationStack { JournalView() }
                    .tabItem { Label("Journal", systemImage: "note.text") }
                    .tag(3)

            }
            .preferredColorScheme(.dark)

            // Loading overlay
            if isLoading {
                LoadingView()
                    .transition(.opacity)
                    .zIndex(10)
            }
        }
        .fullScreenCover(isPresented: $showGlucose) {
            NavigationStack { GlucoseDetailView() }
                .preferredColorScheme(.dark)
        }
        .task {
            await viewModel.loadSettings()
            async let today: () = viewModel.loadTodayData()
            async let dash:  () = viewModel.loadDashboard()
            _ = await (today, dash)
            withAnimation(.easeOut(duration: 0.4)) { isLoading = false }
        }
    }

}

// MARK: - Vitals overview

struct VitalsView: View {
    @EnvironmentObject var viewModel: SyncViewModel
    @Binding var selectedTab: Int
    @Binding var healthSubTab: Int
    @State private var dayIndex: Int = 0

    private let accent = DS.accent

    private var current: OuraDailySummary? {
        viewModel.dailySummaries.indices.contains(dayIndex) ? viewModel.dailySummaries[dayIndex] : nil
    }

    // Last N values for a score keypath, index 0 = most recent
    private func history(_ kp: KeyPath<OuraDailySummary, Int?>, count: Int = 7) -> [Int?] {
        Array(viewModel.dailySummaries.prefix(count).map { $0[keyPath: kp] })
    }

    private func tirPct() -> Int? {
        guard !viewModel.todayGlucoseReadings.isEmpty else { return nil }
        let lo = Double(viewModel.tirLow), hi = Double(viewModel.tirHigh)
        let n = Double(viewModel.todayGlucoseReadings.count)
        let inR = Double(viewModel.todayGlucoseReadings.filter { $0.value >= lo && $0.value <= hi }.count)
        return Int((inR / n * 100).rounded())
    }

    private func dayTabLabel(_ idx: Int, _ s: OuraDailySummary) -> String {
        if idx == 0 { return "Today" }
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        let d = DateFormatter(); d.dateFormat = "EEE d"
        guard let date = f.date(from: s.day) else { return s.day }
        return d.string(from: date)
    }

    var body: some View {
        ZStack {
            Color.surfaceBg.ignoresSafeArea()
            VStack(spacing: 0) {
                // Scrollable day tabs
                if !viewModel.dailySummaries.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Array(viewModel.dailySummaries.prefix(10).enumerated()), id: \.offset) { idx, s in
                                let isSelected = idx == dayIndex
                                Button { dayIndex = idx } label: {
                                    Text(dayTabLabel(idx, s))
                                        .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                                        .foregroundStyle(isSelected ? .black : Color(white: 0.55))
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(isSelected ? .white : Color(white: 0.13),
                                                    in: RoundedRectangle(cornerRadius: 20))
                                }
                                .buttonStyle(.plain)
                                .animation(.easeInOut(duration: 0.2), value: dayIndex)
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                    .padding(.vertical, 12)
                }

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        if let score = current?.readinessScore {
                            let sub: [(String, String)] = [
                                current?.stressSummary.map { ("Stress Level", $0.capitalized) },
                                current?.resilienceLevel.map { ("Resilience", $0.capitalized) }
                            ].compactMap { $0 }
                            OuraVitalsCard(
                                title: "Readiness", score: score, unit: "",
                                color: .ouraReadiness, heroBg: .heroReadiness,
                                recentScores: history(\.readinessScore),
                                selectedIndex: dayIndex,
                                subMetrics: sub
                            ) { healthSubTab = 1; selectedTab = 2 }
                        }

                        if let score = current?.sleepScore {
                            let sub: [(String, String)] = [
                                current?.totalSleepMinutes.map { ("Duration", formatMinutes($0)) }
                            ].compactMap { $0 }
                            OuraVitalsCard(
                                title: "Sleep", score: score, unit: "",
                                color: .ouraSleep, heroBg: .heroSleep,
                                recentScores: history(\.sleepScore),
                                selectedIndex: dayIndex,
                                subMetrics: sub
                            ) { healthSubTab = 0; selectedTab = 2 }
                        }

                        if let score = current?.activityScore {
                            let sub: [(String, String)] = [
                                current?.steps.map { ("Steps", "\($0)") }
                            ].compactMap { $0 }
                            OuraVitalsCard(
                                title: "Activity", score: score, unit: "",
                                color: .ouraActivity, heroBg: .heroActivity,
                                recentScores: history(\.activityScore),
                                selectedIndex: dayIndex,
                                subMetrics: sub
                            ) { healthSubTab = 2; selectedTab = 2 }
                        }

                        if let hrv = current?.averageHrv {
                            let vals = history(\.averageHrv)
                            OuraVitalsCard(
                                title: "HRV", score: hrv, unit: "ms",
                                color: DS.accent,
                                heroBg: DS.bg1,
                                recentScores: vals,
                                selectedIndex: dayIndex,
                                subMetrics: [],
                                isRawValue: true
                            ) { healthSubTab = 0; selectedTab = 2 }
                        }

                        if dayIndex == 0, let tir = tirPct() {
                            OuraVitalsCard(
                                title: "Time in Range", score: tir, unit: "%",
                                color: tir >= 70 ? .ouraActivity : tir >= 50 ? .ouraReadiness : .red,
                                heroBg: .heroGlucose,
                                recentScores: [tir],
                                selectedIndex: 0,
                                subMetrics: [("Glucose", "Today only")]
                            ) { selectedTab = 0 }
                        }

                        Spacer().frame(height: 20)
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
        .navigationTitle("Vitals")
        .navigationBarTitleDisplayMode(.inline)
        .task { if viewModel.dailySummaries.isEmpty { await viewModel.loadDashboard() } }
    }

    private func formatMinutes(_ minutes: Int) -> String {
        let h = minutes / 60
        let m = minutes % 60
        return m > 0 ? "\(h)h \(m)m" : "\(h)h"
    }
}

// MARK: - Vitals card (Oura-style: gradient hero + ring + sparkline)

struct OuraVitalsCard: View {
    let title: String
    let score: Int
    let unit: String
    let color: Color
    let heroBg: Color
    let recentScores: [Int?]   // index 0 = most recent day
    let selectedIndex: Int
    var subMetrics: [(String, String)] = []
    var isRawValue: Bool = false
    var onTap: () -> Void = {}

    private let qualityGreen = DS.accent
    private let qualityAmber = DS.lo
    private let qualityRed   = DS.hi

    private var qualifier: (String, Color) {
        if isRawValue {
            return score >= 70 ? ("Good", qualityGreen) : score >= 50 ? ("Fair", qualityAmber) : ("Low", qualityRed)
        }
        if score >= 85 { return ("Optimal", qualityGreen) }
        if score >= 70 { return ("Good",    qualityGreen) }
        if score >= 60 { return ("Fair",    qualityAmber) }
        return ("Low", qualityRed)
    }

    private var ringFraction: Double {
        isRawValue
            ? Double(min(score, 120)) / 120.0
            : Double(min(score, 100)) / 100.0
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                // ── Gradient hero ──────────────────────────────────────
                ZStack(alignment: .topTrailing) {
                    LinearGradient(
                        colors: [heroBg, Color(white: 0.075)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )

                    // Ring gauge — top right
                    ZStack {
                        Circle()
                            .stroke(color.opacity(0.14), lineWidth: 10)
                        Circle()
                            .trim(from: 0, to: CGFloat(ringFraction))
                            .stroke(color, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .animation(.easeOut(duration: 0.7), value: score)
                    }
                    .frame(width: 82, height: 82)
                    .padding(22)

                    // Label + score + badge
                    VStack(alignment: .leading, spacing: 8) {
                        Text(title.uppercased())
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(color.opacity(0.75))
                            .tracking(1.5)

                        HStack(alignment: .lastTextBaseline, spacing: 5) {
                            Text("\(score)")
                                .font(.system(size: 76, weight: .thin, design: .rounded))
                                .foregroundStyle(.white)
                            if !unit.isEmpty {
                                Text(unit)
                                    .font(.system(size: 18, weight: .light))
                                    .foregroundStyle(Color(white: 0.45))
                            }
                        }

                        Text(qualifier.0)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(qualifier.1)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(qualifier.1.opacity(0.18), in: Capsule())
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(22)
                    .padding(.trailing, 112)
                }
                .frame(height: 162)

                // ── Bottom: sub-metrics + sparkline ────────────────────
                VStack(spacing: 12) {
                    if !subMetrics.isEmpty {
                        HStack(spacing: 0) {
                            ForEach(subMetrics.indices, id: \.self) { i in
                                if i > 0 {
                                    Divider().frame(height: 28).background(Color(white: 0.18))
                                }
                                VStack(spacing: 2) {
                                    Text(subMetrics[i].0)
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundStyle(Color(white: 0.40))
                                    Text(subMetrics[i].1)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(.white)
                                }
                                .frame(maxWidth: .infinity)
                            }
                        }
                        .padding(.vertical, 8)
                        .background(Color(white: 0.055), in: RoundedRectangle(cornerRadius: 10))
                    }

                    if recentScores.count > 1 {
                        miniSparkline
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .background(Color(white: 0.068))
            }
            .clipShape(RoundedRectangle(cornerRadius: 20))
        }
        .buttonStyle(.plain)
    }

    private var miniSparkline: some View {
        let valid = recentScores.compactMap { $0 }
        let maxV  = Double(valid.max() ?? 100)
        let minV  = Double(valid.min() ?? 0)
        let span  = max(maxV - minV, 1)
        let maxH: CGFloat = 36
        let minH: CGFloat = 6

        // Reversed so oldest = left, newest (idx 0) = rightmost
        return HStack(alignment: .bottom, spacing: 5) {
            ForEach(Array(recentScores.enumerated().reversed()), id: \.offset) { idx, valOpt in
                let isSelected = idx == selectedIndex
                let val  = valOpt ?? 0
                let frac = valOpt == nil ? 0 : CGFloat((Double(val) - minV) / span)
                let barH = minH + frac * (maxH - minH)
                VStack(spacing: 3) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(isSelected ? color : Color(white: 0.22))
                        .frame(height: barH)
                    if let v = valOpt {
                        Text("\(v)")
                            .font(.system(size: 9, weight: isSelected ? .semibold : .regular, design: .rounded))
                            .foregroundStyle(isSelected ? .white : Color(white: 0.38))
                    } else {
                        Text("–").font(.system(size: 9)).foregroundStyle(Color(white: 0.28))
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: maxH + 16)
        .animation(.easeOut(duration: 0.3), value: selectedIndex)
    }
}

// MARK: - Loading screen

struct LoadingView: View {
    @State private var pulse = false

    var body: some View {
        ZStack {
            Color.surfaceBg.ignoresSafeArea()
            VStack(spacing: 28) {
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.07), lineWidth: 2)
                        .frame(width: 100, height: 100)
                    Circle()
                        .stroke(Color.white.opacity(pulse ? 0.25 : 0.08), lineWidth: 2)
                        .frame(width: 100, height: 100)
                        .scaleEffect(pulse ? 1.18 : 1.0)
                        .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: pulse)
                    Image(systemName: "drop.fill")
                        .font(.system(size: 36, weight: .thin))
                        .foregroundStyle(.white)
                }
                VStack(spacing: 6) {
                    Text("HealthSync")
                        .font(.system(size: 22, weight: .light, design: .rounded))
                        .foregroundStyle(.white)
                    Text("Fetching your data…")
                        .font(.system(size: 13))
                        .foregroundStyle(Color(white: 0.45))
                }
            }
        }
        .onAppear { pulse = true }
    }
}

// MARK: - My Health (Sleep / Readiness / Activity / Stress sub-tabs)

struct MyHealthView: View {
    @EnvironmentObject var viewModel: SyncViewModel
    @Binding var subTab: Int
    @State private var dayIndex: Int = 0

    private var dayLabel: String {
        guard viewModel.dailySummaries.indices.contains(dayIndex) else { return "Today" }
        let s = viewModel.dailySummaries[dayIndex]
        let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
        guard let d = fmt.date(from: s.day) else { return s.day }
        fmt.dateFormat = "EEE, d MMM"
        return dayIndex == 0 ? "Today · \(fmt.string(from: d))" : fmt.string(from: d)
    }

    private var sharedDayNavigator: some View {
        HStack(spacing: 20) {
            Button {
                if dayIndex < viewModel.dailySummaries.count - 1 { dayIndex += 1 }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(dayIndex < viewModel.dailySummaries.count - 1 ? .white : Color(white: 0.3))
            }
            .disabled(dayIndex >= viewModel.dailySummaries.count - 1)

            Text(dayLabel)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(minWidth: 140)

            Button {
                if dayIndex > 0 { dayIndex -= 1 }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(dayIndex > 0 ? .white : Color(white: 0.3))
            }
            .disabled(dayIndex == 0)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 24)
        .background(Color.cardBg, in: Capsule())
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $subTab) {
                Text("Sleep").tag(0)
                Text("Readiness").tag(1)
                Text("Activity").tag(2)
                Text("Stress").tag(3)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)

            // Shared day navigator — persists when switching tabs
            if !viewModel.dailySummaries.isEmpty {
                sharedDayNavigator
                    .padding(.horizontal)
                    .padding(.bottom, 8)
            }

            switch subTab {
            case 0: SleepTabView(dayIndex: $dayIndex)
            case 1: ReadinessTabView(dayIndex: $dayIndex)
            case 2: ActivityTabView(dayIndex: $dayIndex)
            default: StressTabView(dayIndex: $dayIndex)
            }
        }
        .background(Color.surfaceBg.ignoresSafeArea())
        .navigationTitle("My Health")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Quick Log sheet (+ button)

struct QuickLogSheet: View {
    @EnvironmentObject var viewModel: SyncViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showWorkout    = false
    @State private var showPumpEvents = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.surfaceBg.ignoresSafeArea()
                VStack(spacing: 16) {
                    Text("Log an Event")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.top, 28)

                    VStack(spacing: 12) {
                        quickLogTile(icon: "figure.run", color: .ouraActivity,
                                     title: "Workout", subtitle: "Log how you felt") {
                            showWorkout = true
                        }
                        quickLogTile(icon: "cross.vial.fill", color: DS.fg2,
                                     title: "Pump / Pod Event",
                                     subtitle: "Reservoir · Pod · Cannula change") {
                            showPumpEvents = true
                        }
                    }
                    .padding(.horizontal)

                    Spacer()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(.white)
                }
            }
            .navigationDestination(isPresented: $showWorkout)    { OuraWorkoutsView() }
            .navigationDestination(isPresented: $showPumpEvents) { PumpEventsView() }
        }
        .preferredColorScheme(.dark)
    }

    private func quickLogTile(icon: String, color: Color, title: String,
                               subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    Circle().fill(color.opacity(0.18)).frame(width: 50, height: 50)
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(color)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.system(size: 16, weight: .semibold)).foregroundStyle(.white)
                    Text(subtitle).font(.system(size: 13)).foregroundStyle(Color(white: 0.5))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color(white: 0.3))
            }
            .padding(16)
            .background(Color.cardBg, in: RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Home

struct HomeView: View {
    @EnvironmentObject var viewModel: SyncViewModel
    @Binding var selectedTab: Int
    @Binding var healthSubTab: Int
    @Binding var showGlucose: Bool

    var body: some View {
        // Background lives OUTSIDE NavigationStack so its material never bleeds through
        ZStack(alignment: .top) {
            Color.surfaceBg.ignoresSafeArea()

            NavigationStack {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        homeHero
                        VStack(spacing: 16) {
                            if !viewModel.dailySummaries.isEmpty {
                                vitalsRow
                            }
                            syncStatusRow
                            if let error = viewModel.errorMessage { ErrorBanner(message: error) }
                            logsLink
                        }
                        .padding(.top, 20)
                        .padding(.bottom, 40)
                    }
                }
                .background(.clear)
                .scrollContentBackground(.hidden)
                .ignoresSafeArea(edges: .top)
                .toolbar(.hidden, for: .navigationBar)
                .toolbarBackground(.hidden, for: .navigationBar)
                .task {
                    await viewModel.loadTodayData()
                    if viewModel.dailySummaries.isEmpty { await viewModel.loadDashboard() }
                }
            }
            .background(.clear)
        }
    }

    // MARK: Hero

    private var homeHero: some View {
        let tir    = tirPercentage()
        let tirPct = Int(tir * 100)
        let tirColor: Color = tir >= 0.7 ? Color.ouraActivity
                            : tir >= 0.5 ? Color.ouraReadiness
                            : .red
        let tirLabel  = tir >= 0.7 ? "ON TARGET" : tir >= 0.5 ? "IMPROVING" : "OFF TARGET"
        let tirMsg    = tir >= 0.7
            ? "Great glucose control today. Keep it up."
            : tir >= 0.5
            ? "More than half your readings are in range."
            : "Most readings are outside range. Check your levels."

        // Plain surface — no gradient overlay, eliminates all line rendering artifacts
        return VStack(spacing: 0) {
            // Top bar: date left, settings right
            HStack {
                Text(Date(), format: .dateTime.weekday(.wide).day().month(.wide))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color(white: 0.6))
                Spacer()
                NavigationLink(destination: SettingsHubView()) {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color(white: 0.7))
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 60)
            .padding(.bottom, 20)

            // Score pills (tappable — navigate to respective tab)
            ScorePillRow(summaries: viewModel.dailySummaries,
                         selectedTab: $selectedTab,
                         healthSubTab: $healthSubTab,
                         showGlucose: $showGlucose,
                         tirPct: viewModel.todayGlucoseReadings.isEmpty ? nil : Int(tirPercentage() * 100))
                .padding(.bottom, 28)

            // Featured metric: Time In Range
            Image(systemName: "drop.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(tirColor)
                .padding(.bottom, 6)

            Text(viewModel.todayGlucoseReadings.isEmpty ? "–" : "\(tirPct)%")
                .font(.system(size: 88, weight: .thin, design: .rounded))
                .foregroundStyle(.white)

            HStack(spacing: 8) {
                Text("TIME IN RANGE")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color(white: 0.5))
                    .tracking(2)
                Text(viewModel.todayGlucoseReadings.isEmpty ? "–" : tirLabel)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(tirColor)
                    .tracking(1.5)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(tirColor.opacity(0.15), in: Capsule())
            }
            .padding(.bottom, 10)

            Text(viewModel.todayGlucoseReadings.isEmpty
                 ? "Sync Nightscout to see your glucose control."
                 : tirMsg)
                .font(.system(size: 14))
                .foregroundStyle(Color(white: 0.55))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 36)
                .padding(.bottom, 32)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Glucose + TIR card

    private var glucoseCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text("BLOOD GLUCOSE")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.secondary)
                    .tracking(1.5)
                Spacer()
                Button { showGlucose = true } label: {
                    HStack(spacing: 3) {
                        Text("Details")
                            .font(.system(size: 11, weight: .medium))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .semibold))
                    }
                    .foregroundStyle(DS.accent)
                }
            }

            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    if let last = viewModel.todayGlucoseReadings.last {
                        HStack(alignment: .lastTextBaseline, spacing: 4) {
                            Text("\(Int(last.value))")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundStyle(glucoseColor(last.value))
                            Text("mg/dL").font(.caption).foregroundStyle(.secondary)
                        }
                    } else {
                        Text("No data").font(.subheadline).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                // TIR summary
                VStack(alignment: .trailing, spacing: 3) {
                    Text("TIME IN RANGE")
                        .font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary).tracking(1.5)
                    let pct = tirPercentage()
                    Text("\(Int(pct * 100))%")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(pct >= 0.7 ? Color.ouraActivity : pct >= 0.5 ? Color.ouraReadiness : .red)
                }
            }

            if viewModel.todayGlucoseReadings.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "drop.triangle.fill")
                        .font(.system(size: 28)).foregroundStyle(.secondary)
                    Text("Sync Nightscout to see today's glucose")
                        .font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity).frame(height: 120)
            } else {
                glucoseChart
                tirBar
            }

            // Legend
            HStack(spacing: 16) {
                legendItem(color: .white, label: "Glucose")
                legendItem(color: Color.ouraActivity.opacity(0.5), label: "In Range")
                Spacer()
            }
        }
        .padding(20)
        .background(Color.cardBg, in: RoundedRectangle(cornerRadius: 20))
        .padding(.horizontal)
    }

    private var glucoseChart: some View {
        let readings = viewModel.todayGlucoseReadings
        let tirLo    = Double(viewModel.tirLow)
        let tirHi    = Double(viewModel.tirHigh)
        let startDay = Calendar.current.startOfDay(for: Date())
        let now      = Date()
        let maxG     = readings.map(\.value).max() ?? tirHi
        let yMax     = max(maxG + 40, tirHi + 60)
        let yMin     = 40.0

        return Chart {
            // TIR green band
            RectangleMark(
                xStart: .value("s", startDay), xEnd: .value("e", now),
                yStart: .value("lo", tirLo),   yEnd: .value("hi", tirHi)
            )
            .foregroundStyle(Color.ouraActivity.opacity(0.07))

            // Low threshold dashed line
            RuleMark(y: .value("Low", tirLo))
                .foregroundStyle(Color.red.opacity(0.45))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))

            // High threshold dashed line
            RuleMark(y: .value("High", tirHi))
                .foregroundStyle(Color.ouraReadiness.opacity(0.45))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))

            // Glucose line + area
            ForEach(readings) { pt in
                AreaMark(x: .value("t", pt.date), y: .value("g", pt.value))
                    .foregroundStyle(
                        LinearGradient(colors: [Color.white.opacity(0.12), Color.white.opacity(0)],
                                       startPoint: .top, endPoint: .bottom)
                    )
                    .interpolationMethod(.catmullRom)

                LineMark(x: .value("t", pt.date), y: .value("g", pt.value))
                    .foregroundStyle(glucoseColor(pt.value))
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 2))
            }

            // Current reading badge point
            if let last = readings.last {
                PointMark(x: .value("t", last.date), y: .value("g", last.value))
                    .foregroundStyle(glucoseColor(last.value))
                    .symbolSize(50)
                    .annotation(position: .top, spacing: 4) {
                        Text("\(Int(last.value))")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6).padding(.vertical, 3)
                            .background(glucoseColor(last.value), in: Capsule())
                    }
            }
        }
        .chartYScale(domain: yMin...yMax)
        .chartXScale(domain: startDay...now)
        .chartXAxis {
            AxisMarks(values: .stride(by: .hour, count: 4)) { _ in
                AxisGridLine().foregroundStyle(Color.white.opacity(0.05))
                AxisValueLabel(format: .dateTime.hour(.defaultDigits(amPM: .abbreviated)))
                    .foregroundStyle(Color.secondary)
                    .font(.system(size: 9))
            }
        }
        .chartYAxis {
            AxisMarks(values: [Int(tirLo), 180, Int(tirHi)]) { value in
                AxisGridLine().foregroundStyle(Color.white.opacity(0.05))
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text(String(format: "%.0f", v))
                            .font(.system(size: 9))
                            .foregroundStyle(Color.secondary)
                    }
                }
            }
        }
        .frame(height: 160)
    }

    private var tirBar: some View {
        let readings = viewModel.todayGlucoseReadings
        guard !readings.isEmpty else { return AnyView(EmptyView()) }
        let lo  = Double(viewModel.tirLow)
        let hi  = Double(viewModel.tirHigh)
        let n   = Double(readings.count)
        let below    = Double(readings.filter { $0.value < lo }.count) / n
        let inRange  = Double(readings.filter { $0.value >= lo && $0.value <= hi }.count) / n
        let above    = max(0, 1.0 - below - inRange)

        return AnyView(VStack(spacing: 8) {
            GeometryReader { geo in
                HStack(spacing: 2) {
                    if below > 0.005 {
                        Capsule().fill(Color.red.opacity(0.8))
                            .frame(width: geo.size.width * CGFloat(below))
                    }
                    if inRange > 0.005 {
                        Capsule().fill(Color.ouraActivity.opacity(0.85))
                            .frame(width: geo.size.width * CGFloat(inRange))
                    }
                    if above > 0.005 {
                        Capsule().fill(Color.ouraReadiness.opacity(0.8))
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .frame(height: 8)
            .clipShape(Capsule())

            HStack {
                HStack(spacing: 4) {
                    Circle().fill(Color.red).frame(width: 7, height: 7)
                    Text("Low \(Int(below * 100))%")
                        .font(.system(size: 10)).foregroundStyle(.secondary)
                }
                Spacer()
                HStack(spacing: 4) {
                    Circle().fill(Color.ouraActivity).frame(width: 7, height: 7)
                    Text("In Range \(Int(inRange * 100))%")
                        .font(.system(size: 10)).foregroundStyle(.secondary)
                }
                Spacer()
                HStack(spacing: 4) {
                    Circle().fill(Color.ouraReadiness).frame(width: 7, height: 7)
                    Text("High \(Int(above * 100))%")
                        .font(.system(size: 10)).foregroundStyle(.secondary)
                }
            }
        })
    }

    private func glucoseColor(_ value: Double) -> Color {
        let lo = Double(viewModel.tirLow)
        let hi = Double(viewModel.tirHigh)
        if value < lo { return .red }
        if value > hi { return Color.ouraReadiness }
        return Color.ouraActivity
    }

    private func tirPercentage() -> Double {
        let readings = viewModel.todayGlucoseReadings
        guard !readings.isEmpty else { return 0 }
        let lo = Double(viewModel.tirLow)
        let hi = Double(viewModel.tirHigh)
        let count = readings.filter { $0.value >= lo && $0.value <= hi }.count
        return Double(count) / Double(readings.count)
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 12, height: 4)
            Text(label).font(.system(size: 10)).foregroundStyle(.secondary)
        }
    }

    // MARK: Vitals row (readiness / sleep / activity cards + new health cards)

    private var vitalsRow: some View {
        let today = viewModel.dailySummaries.first

        return VStack(spacing: 14) {
            HStack {
                Text("TODAY'S VITALS")
                    .font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary).tracking(1.5)
                Spacer()
            }
            .padding(.horizontal)

            // Full-width stacked cards — Oura style
            OuraVitalsMetricCard(
                icon: "bolt.heart.fill",
                label: "Readiness",
                color: .ouraReadiness,
                heroBg: .heroReadiness,
                score: viewModel.dailySummaries.first { $0.readinessScore != nil }?.readinessScore,
                summaries: viewModel.dailySummaries,
                keyPath: \.readinessScore
            ) { healthSubTab = 1; selectedTab = 2 }
            .padding(.horizontal)

            OuraVitalsMetricCard(
                icon: "moon.zzz.fill",
                label: "Sleep",
                color: .ouraSleep,
                heroBg: .heroSleep,
                score: viewModel.dailySummaries.first { $0.sleepScore != nil }?.sleepScore,
                summaries: viewModel.dailySummaries,
                keyPath: \.sleepScore
            ) { healthSubTab = 0; selectedTab = 2 }
            .padding(.horizontal)

            OuraVitalsMetricCard(
                icon: "figure.run",
                label: "Activity",
                color: .ouraActivity,
                heroBg: .heroActivity,
                score: viewModel.dailySummaries.first { $0.activityScore != nil }?.activityScore,
                summaries: viewModel.dailySummaries,
                keyPath: \.activityScore
            ) { healthSubTab = 2; selectedTab = 2 }
            .padding(.horizontal)

            // Health Monitor grid (RHR / HRV / SpO₂ / Temp / RR / Sleep hrs)
            if today?.lowestHR != nil || today?.averageHrv != nil
                || today?.averageSpO2 != nil || today?.respiratoryRate != nil {
                HealthMonitorGrid(summary: today)
            }

            // Activity heatmap
            if viewModel.dailySummaries.count >= 3 {
                ActivityHeatmapCard(summaries: viewModel.dailySummaries)
            }

            // VO2Max + Cardio Age card
            CardioInsightCard(summaries: viewModel.dailySummaries)
        }
    }

    // MARK: Sync status (read-only, no buttons)

    private var syncStatusRow: some View {
        HStack(spacing: 0) {
            statusCell(icon: "cross.vial.fill",
                       color: DS.accent,
                       label: "Nightscout",
                       date: viewModel.lastSyncDate,
                       syncing: viewModel.isSyncing)
        }
        .background(Color.cardBg, in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    private func statusCell(icon: String, color: Color, label: String, date: Date?, syncing: Bool) -> some View {
        VStack(spacing: 5) {
            Image(systemName: icon).font(.system(size: 14)).foregroundStyle(color)
            Text(label).font(.system(size: 10, weight: .medium)).foregroundStyle(.secondary)
            if syncing {
                ProgressView().scaleEffect(0.7)
            } else if let d = date {
                HStack(spacing: 2) {
                    Text(d, style: .relative)
                        .font(.system(size: 11, weight: .semibold))
                    Text("ago")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.secondary)
                }
            } else {
                Text("Not synced").font(.system(size: 11)).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
    }

    // MARK: Logs link

    private var logsLink: some View {
        NavigationLink(destination: LogsView()) {
            HStack {
                Image(systemName: "list.bullet.rectangle.portrait.fill")
                    .foregroundStyle(DS.accent)
                Text("Sync Logs").foregroundStyle(.primary)
                Spacer()
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
            }
            .padding()
            .background(Color.cardBg, in: RoundedRectangle(cornerRadius: 16))
        }
        .padding(.horizontal)
    }
}

// MARK: - Blood Glucose Detail

struct GlucoseDetailView: View {
    @EnvironmentObject var viewModel: SyncViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.surfaceBg.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {

                    // Hero — same style as Sleep / Readiness / Stress tabs
                    glucoseHero

                    // Current reading + 14-day avg stat row
                    HStack(spacing: 0) {
                        statCell(label: "CURRENT",
                                 value: viewModel.todayGlucoseReadings.last.map { "\(Int($0.value))" } ?? "–",
                                 unit: "mg/dL",
                                 color: viewModel.todayGlucoseReadings.last.map { glucoseColor($0.value) } ?? Color.secondary)
                        Divider().frame(height: 48).background(Color.cardBg2)
                        statCell(label: "14-DAY AVG",
                                 value: avgGlucose14d().map { "\(Int($0))" } ?? "–",
                                 unit: "mg/dL",
                                 color: .white)
                    }
                    .background(Color.cardBg, in: RoundedRectangle(cornerRadius: 20))
                    .padding(.horizontal)

                    // Today's glucose + insulin chart
                    if !viewModel.todayGlucoseReadings.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            sectionHeader("TODAY'S GLUCOSE & INSULIN")
                            todayChart
                            tirBarDetail
                        }
                        .padding(20)
                        .background(Color.cardBg, in: RoundedRectangle(cornerRadius: 20))
                        .padding(.horizontal)
                    }

                    // 14-day average glucose trend
                    let days14 = last14DaysGlucose()
                    if !days14.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            sectionHeader("14-DAY AVERAGE GLUCOSE")
                            avgGlucoseChart(days14)
                        }
                        .padding(20)
                        .background(Color.cardBg, in: RoundedRectangle(cornerRadius: 20))
                        .padding(.horizontal)
                    }

                    // 14-day TIR trend
                    let tir14 = last14DaysTIR()
                    if !tir14.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            sectionHeader("14-DAY TIME IN RANGE")
                            tirTrendChart(tir14)
                        }
                        .padding(20)
                        .background(Color.cardBg, in: RoundedRectangle(cornerRadius: 20))
                        .padding(.horizontal)
                    }
                }
                .padding(.bottom, 40)
            }

            // Dismiss button — top-right, floats over scroll content
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(Color(white: 0.4))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            .padding(.top, 52).padding(.trailing, 16)
        }
        .toolbar(.hidden, for: .navigationBar)
        .toolbarBackground(.hidden, for: .navigationBar)
        .task { await viewModel.loadTodayData() }
    }

    // MARK: - Glucose hero (matches TabHeroView style)
    private var glucoseHero: some View {
        let pct  = tirPct() ?? 0
        let score = Int(pct * 100)          // 0-100, matches scoreQuality thresholds
        let avgG  = avgGlucose14d()
        let subtitle = avgG.map { "Avg \(Int($0)) mg/dL over 14 days" } ?? ""
        var mets: [(String, String, String)] = []
        if let avg = avgG { mets.append(("14d Avg", "\(Int(avg))", "mg/dL")) }
        if let last = viewModel.todayGlucoseReadings.last { mets.append(("Current", "\(Int(last.value))", "mg/dL")) }
        return TabHeroView(
            score: viewModel.todayGlucoseReadings.isEmpty ? nil : score,
            icon: "drop.fill",
            color: DS.accent,
            title: "TIME IN RANGE",
            subtitle: subtitle,
            type: "glucose",
            heroBg: .heroGlucose,
            metrics: mets
        )
    }

    // MARK: - Helpers

    private func glucoseColor(_ value: Double) -> Color {
        let lo = Double(viewModel.tirLow)
        let hi = Double(viewModel.tirHigh)
        if value < lo { return .red }
        if value > hi { return Color.ouraReadiness }
        return Color.ouraActivity
    }

    private func tirPct() -> Double? {
        let readings = viewModel.todayGlucoseReadings
        guard !readings.isEmpty else { return nil }
        let lo = Double(viewModel.tirLow)
        let hi = Double(viewModel.tirHigh)
        return Double(readings.filter { $0.value >= lo && $0.value <= hi }.count) / Double(readings.count)
    }

    private func avgGlucose14d() -> Double? {
        guard !viewModel.glucoseByDay.isEmpty else { return nil }
        let vals = Array(viewModel.glucoseByDay.values)
        return vals.reduce(0, +) / Double(vals.count)
    }

    private func last14DaysGlucose() -> [(day: String, avg: Double)] {
        let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
        let cutoff = Calendar.current.date(byAdding: .day, value: -14, to: Date()) ?? Date.distantPast
        return viewModel.glucoseByDay
            .compactMap { (key, val) -> (String, Double)? in
                guard let d = fmt.date(from: key), d >= cutoff else { return nil }
                return (key, val)
            }
            .sorted { $0.0 < $1.0 }
            .map { (day: $0.0, avg: $0.1) }
    }

    private func last14DaysTIR() -> [(day: String, tir: Double)] {
        let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
        let cutoff = Calendar.current.date(byAdding: .day, value: -14, to: Date()) ?? Date.distantPast
        return viewModel.tirByDay
            .compactMap { (key, val) -> (String, Double)? in
                guard let d = fmt.date(from: key), d >= cutoff else { return nil }
                return (key, val)
            }
            .sorted { $0.0 < $1.0 }
            .map { (day: $0.0, tir: $0.1) }
    }

    // MARK: - Sub-views

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(Color.secondary)
            .tracking(1.5)
    }

    private func statCell(label: String, value: String, unit: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(Color.secondary)
                .tracking(1)
            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(unit)
                .font(.system(size: 10))
                .foregroundStyle(Color.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
    }

    private var todayChart: some View {
        let readings = viewModel.todayGlucoseReadings
        let tirLo    = Double(viewModel.tirLow)
        let tirHi    = Double(viewModel.tirHigh)
        let startDay = Calendar.current.startOfDay(for: Date())
        let now      = Date()
        let maxG     = readings.map(\.value).max() ?? tirHi
        let yMax     = max(maxG + 40, tirHi + 60)
        let yMin     = 40.0

        return Chart {
            RectangleMark(
                xStart: .value("s", startDay), xEnd: .value("e", now),
                yStart: .value("lo", tirLo),   yEnd: .value("hi", tirHi)
            )
            .foregroundStyle(Color.ouraActivity.opacity(0.07))

            RuleMark(y: .value("Low", tirLo))
                .foregroundStyle(Color.red.opacity(0.45))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))

            RuleMark(y: .value("High", tirHi))
                .foregroundStyle(Color.ouraReadiness.opacity(0.45))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))

            ForEach(readings) { pt in
                AreaMark(x: .value("t", pt.date), y: .value("g", pt.value))
                    .foregroundStyle(
                        LinearGradient(colors: [Color.white.opacity(0.12), Color.white.opacity(0)],
                                       startPoint: .top, endPoint: .bottom)
                    )
                    .interpolationMethod(.catmullRom)

                LineMark(x: .value("t", pt.date), y: .value("g", pt.value))
                    .foregroundStyle(glucoseColor(pt.value))
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 2))
            }

            if let last = readings.last {
                PointMark(x: .value("t", last.date), y: .value("g", last.value))
                    .foregroundStyle(glucoseColor(last.value))
                    .symbolSize(60)
                    .annotation(position: .top, spacing: 4) {
                        Text("\(Int(last.value))")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6).padding(.vertical, 3)
                            .background(glucoseColor(last.value), in: Capsule())
                    }
            }
        }
        .chartYScale(domain: yMin...yMax)
        .chartXScale(domain: startDay...now)
        .chartXAxis {
            AxisMarks(values: .stride(by: .hour, count: 4)) { _ in
                AxisGridLine().foregroundStyle(Color.white.opacity(0.05))
                AxisValueLabel(format: .dateTime.hour(.defaultDigits(amPM: .abbreviated)))
                    .foregroundStyle(Color.secondary)
                    .font(.system(size: 9))
            }
        }
        .chartYAxis {
            AxisMarks(values: [Int(tirLo), 180, Int(tirHi)]) { value in
                AxisGridLine().foregroundStyle(Color.white.opacity(0.05))
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text(String(format: "%.0f", v))
                            .font(.system(size: 9))
                            .foregroundStyle(Color.secondary)
                    }
                }
            }
        }
        .frame(height: 220)
    }

    private var tirBarDetail: some View {
        let readings = viewModel.todayGlucoseReadings
        guard !readings.isEmpty else { return AnyView(EmptyView()) }
        let lo  = Double(viewModel.tirLow)
        let hi  = Double(viewModel.tirHigh)
        let n   = Double(readings.count)
        let below   = Double(readings.filter { $0.value < lo }.count) / n
        let inRange = Double(readings.filter { $0.value >= lo && $0.value <= hi }.count) / n
        let above   = max(0, 1.0 - below - inRange)

        return AnyView(VStack(spacing: 8) {
            GeometryReader { geo in
                HStack(spacing: 2) {
                    if below > 0.005 {
                        Capsule().fill(Color.red.opacity(0.8))
                            .frame(width: geo.size.width * CGFloat(below))
                    }
                    if inRange > 0.005 {
                        Capsule().fill(Color.ouraActivity.opacity(0.85))
                            .frame(width: geo.size.width * CGFloat(inRange))
                    }
                    if above > 0.005 {
                        Capsule().fill(Color.ouraReadiness.opacity(0.8))
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .frame(height: 8)
            .clipShape(Capsule())

            HStack {
                HStack(spacing: 4) {
                    Circle().fill(Color.red).frame(width: 7, height: 7)
                    Text("Low \(Int(below * 100))%").font(.system(size: 10)).foregroundStyle(.secondary)
                }
                Spacer()
                HStack(spacing: 4) {
                    Circle().fill(Color.ouraActivity).frame(width: 7, height: 7)
                    Text("In Range \(Int(inRange * 100))%").font(.system(size: 10)).foregroundStyle(.secondary)
                }
                Spacer()
                HStack(spacing: 4) {
                    Circle().fill(Color.ouraReadiness).frame(width: 7, height: 7)
                    Text("High \(Int(above * 100))%").font(.system(size: 10)).foregroundStyle(.secondary)
                }
            }
        })
    }

    private func avgGlucoseChart(_ data: [(day: String, avg: Double)]) -> some View {
        let tirLo = Double(viewModel.tirLow)
        let tirHi = Double(viewModel.tirHigh)
        let maxV  = data.map(\.avg).max() ?? tirHi
        let yMax  = max(maxV + 40, tirHi + 40)
        let yMin  = 50.0
        let fmt   = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"

        return Chart {
            RuleMark(y: .value("Low", tirLo))
                .foregroundStyle(Color.red.opacity(0.4))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
            RuleMark(y: .value("High", tirHi))
                .foregroundStyle(Color.ouraReadiness.opacity(0.4))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
            ForEach(data, id: \.day) { pt in
                if let d = fmt.date(from: pt.day) {
                    BarMark(x: .value("Day", d, unit: .day),
                            y: .value("Avg", pt.avg))
                    .foregroundStyle(
                        pt.avg < tirLo ? Color.red.opacity(0.8)
                        : pt.avg > tirHi ? Color.ouraReadiness.opacity(0.8)
                        : Color.ouraActivity.opacity(0.8)
                    )
                    .cornerRadius(4)
                }
            }
        }
        .chartYScale(domain: yMin...yMax)
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: 2)) { _ in
                AxisGridLine().foregroundStyle(Color.white.opacity(0.05))
                AxisValueLabel(format: .dateTime.month().day())
                    .font(.system(size: 9))
                    .foregroundStyle(Color.secondary)
            }
        }
        .chartYAxis {
            AxisMarks(values: [Int(tirLo), 180, Int(tirHi)]) { value in
                AxisGridLine().foregroundStyle(Color.white.opacity(0.05))
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text(String(format: "%.0f", v))
                            .font(.system(size: 9))
                            .foregroundStyle(Color.secondary)
                    }
                }
            }
        }
        .frame(height: 160)
    }

    private func tirTrendChart(_ data: [(day: String, tir: Double)]) -> some View {
        let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
        return Chart {
            RuleMark(y: .value("Target", 70.0))
                .foregroundStyle(Color.ouraActivity.opacity(0.5))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
            ForEach(data, id: \.day) { pt in
                if let d = fmt.date(from: pt.day) {
                    BarMark(x: .value("Day", d, unit: .day),
                            y: .value("TIR %", pt.tir))
                    .foregroundStyle(
                        pt.tir >= 70 ? Color.ouraActivity.opacity(0.85)
                        : pt.tir >= 50 ? Color.ouraReadiness.opacity(0.85)
                        : Color.red.opacity(0.8)
                    )
                    .cornerRadius(4)
                }
            }
        }
        .chartYScale(domain: 0...100)
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: 2)) { _ in
                AxisGridLine().foregroundStyle(Color.white.opacity(0.05))
                AxisValueLabel(format: .dateTime.month().day())
                    .font(.system(size: 9))
                    .foregroundStyle(Color.secondary)
            }
        }
        .chartYAxis {
            AxisMarks(values: [0, 50, 70, 100]) { value in
                AxisGridLine().foregroundStyle(Color.white.opacity(0.05))
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text("\(Int(v))%")
                            .font(.system(size: 9))
                            .foregroundStyle(Color.secondary)
                    }
                }
            }
        }
        .frame(height: 160)
    }
}

// MARK: - Mini score cell (kept for compatibility)

struct MiniScoreCell: View {
    let label: String
    let value: Int?
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value.map { "\($0)" } ?? "--")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(value != nil ? color : Color(white: 0.35))
            Text(label)
                .font(.system(size: 10, weight: .medium)).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 12)
    }
}

// MARK: - Small helpers

struct SyncingRow: View {
    let label: String
    var body: some View {
        HStack(spacing: 8) {
            ProgressView().scaleEffect(0.8)
            Text(label).font(.footnote).foregroundStyle(.secondary)
        }
    }
}

struct OuraStatRow: View {
    let icon: String
    let color: Color
    let label: String
    let synced: Int
    let fetched: Int

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon).foregroundStyle(color).frame(width: 14)
            Text(label).font(.caption).foregroundStyle(.secondary)
            Spacer()
            Text("\(synced)/\(fetched) synced")
                .font(.caption)
                .foregroundStyle(synced == fetched && fetched > 0 ? .green : .orange)
        }
    }
}

struct ErrorBanner: View {
    let message: String
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.yellow)
            Text(message).font(.footnote)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.yellow.opacity(0.10), in: RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal)
    }
}

// MARK: - Settings hub (with sync buttons + TIR)

struct SettingsHubView: View {
    @EnvironmentObject var viewModel: SyncViewModel
    @State private var showingSaved = false

    var body: some View {
        ZStack {
            Color.surfaceBg.ignoresSafeArea()
            List {
                // SYNC SECTION
                Section {
                    Button {
                        Task { await viewModel.syncAll() }
                    } label: {
                        HStack(spacing: 10) {
                            if viewModel.isSyncing {
                                ProgressView().scaleEffect(0.85)
                            } else {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(Color(red: 0.25, green: 0.55, blue: 0.95))
                            }
                            Text(viewModel.isSyncing ? "Syncing…" : "Sync Now")
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(viewModel.isSyncing || !viewModel.isConfigured)

                    syncStatusItem(icon: "cross.vial.fill",
                                   color: DS.accent,
                                   label: "Nightscout",
                                   date: viewModel.lastSyncDate,
                                   syncing: viewModel.isSyncing,
                                   configured: viewModel.isConfigured)
                } header: { Text("Sync") }
                .listRowBackground(Color.cardBg)

                // TIME IN RANGE
                Section {
                    HStack {
                        Text("Low threshold")
                        Spacer()
                        Stepper("\(viewModel.tirLow) mg/dL", value: $viewModel.tirLow, in: 40...150, step: 5)
                    }
                    HStack {
                        Text("High threshold")
                        Spacer()
                        Stepper("\(viewModel.tirHigh) mg/dL", value: $viewModel.tirHigh, in: 120...400, step: 5)
                    }
                    Button {
                        Task {
                            await viewModel.saveSettings()
                            showingSaved = true
                            try? await Task.sleep(for: .seconds(1.2))
                            showingSaved = false
                        }
                    } label: {
                        Text("Save Targets").frame(maxWidth: .infinity)
                    }
                } header: { Text("Glucose Targets (Time in Range)") }
                .listRowBackground(Color.cardBg)

                // SOURCES
                Section {
                    NavigationLink(destination: SettingsView()) {
                        Label("Nightscout", systemImage: "cross.vial.fill")
                    }
                    NavigationLink(destination: OuraSettingsView()) {
                        Label("Oura Ring", systemImage: "circle.hexagongrid.fill")
                    }
                } header: { Text("Sources") }
                .listRowBackground(Color.cardBg)

                // OTHER
                Section {
                    NavigationLink(destination: LogsView()) {
                        Label("Sync Logs", systemImage: "list.bullet.rectangle.portrait.fill")
                    }
                } header: { Text("Other") }
                .listRowBackground(Color.cardBg)
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Settings")
        .overlay(savedToast, alignment: .bottom)
        .animation(.easeInOut(duration: 0.3), value: showingSaved)
    }

    private func syncStatusItem(icon: String, color: Color, label: String,
                                date: Date?, syncing: Bool, configured: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).foregroundStyle(color).frame(width: 20)
            Text(label).foregroundStyle(.secondary)
            Spacer()
            if syncing {
                ProgressView().scaleEffect(0.75)
            } else if let d = date {
                Text(d, style: .relative)
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                Text(configured ? "Not synced" : "Not configured")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder private var savedToast: some View {
        if showingSaved {
            Label("Saved", systemImage: "checkmark.circle.fill")
                .padding(.horizontal, 20).padding(.vertical, 12)
                .background(.green, in: Capsule())
                .foregroundStyle(.white).padding(.bottom, 24)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}

// MARK: - Nightscout settings

struct SettingsView: View {
    @EnvironmentObject var viewModel: SyncViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var testingConnection = false
    @State private var connectionTestResult: Bool?
    @State private var showingHealthKitAlert = false
    @State private var showingSaved = false

    var body: some View {
        ZStack {
            Color.surfaceBg.ignoresSafeArea()
            Form {
                Section {
                    TextField("https://your-nightscout.com", text: $viewModel.nightscoutURL)
                        .textContentType(.URL).autocapitalization(.none)
                        .keyboardType(.URL).autocorrectionDisabled()
                    SecureField("API Secret", text: $viewModel.nightscoutSecret)
                        .autocapitalization(.none).autocorrectionDisabled()
                    Button {
                        Task {
                            testingConnection = true
                            connectionTestResult = await viewModel.testConnection()
                            testingConnection = false
                        }
                    } label: {
                        HStack {
                            if testingConnection { ProgressView().scaleEffect(0.8) }
                            Text(testingConnection ? "Testing…" : "Test Connection")
                        }
                    }
                    .disabled(viewModel.nightscoutURL.isEmpty || viewModel.nightscoutSecret.isEmpty)
                    if let result = connectionTestResult {
                        Label(result ? "Connection successful!" : "Connection failed",
                              systemImage: result ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(result ? .green : .red).font(.footnote)
                    }
                } header: { Text("Nightscout") }
                .listRowBackground(Color.cardBg)

                Section {
                    Button("Request HealthKit Authorization") {
                        Task { await viewModel.requestHealthKitAuthorization(); showingHealthKitAlert = true }
                    }
                } header: { Text("Apple Health") }
                .listRowBackground(Color.cardBg)

                Section {
                    Picker("Glucose Unit", selection: $viewModel.selectedGlucoseUnit) {
                        Text("mg/dL").tag(GlucoseUnit.mgdl)
                        Text("mmol/L").tag(GlucoseUnit.mmol)
                    }
                    Toggle("Sync Glucose", isOn: $viewModel.syncGlucose)
                    Toggle("Sync Insulin", isOn: $viewModel.syncInsulin)
                    Toggle("Sync Carbs",   isOn: $viewModel.syncCarbs)
                    Picker("Look back", selection: $viewModel.lookbackDays) {
                        Text("7 days").tag(7); Text("14 days").tag(14); Text("30 days").tag(30)
                        Text("60 days").tag(60); Text("90 days").tag(90)
                        Text("180 days").tag(180); Text("1 year").tag(365)
                    }
                } header: { Text("Sync Options") }
                .listRowBackground(Color.cardBg)

                Section {
                    Toggle("Background Sync", isOn: $viewModel.autoSyncEnabled)
                    if viewModel.autoSyncEnabled {
                        Picker("Interval", selection: $viewModel.backgroundSyncInterval) {
                            Text("5 min").tag(5); Text("10 min").tag(10); Text("15 min").tag(15)
                            Text("30 min").tag(30); Text("1 hour").tag(60); Text("2 hours").tag(120)
                        }
                    }
                } header: { Text("Background Sync") }
                .listRowBackground(Color.cardBg)

                Section {
                    Button {
                        Task {
                            await viewModel.saveSettings()
                            showingSaved = true
                            try? await Task.sleep(for: .seconds(1.2))
                            showingSaved = false
                            dismiss()
                        }
                    } label: {
                        Text("Save Settings").frame(maxWidth: .infinity).fontWeight(.semibold)
                    }
                    .listRowBackground(DS.bg2)
                }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Nightscout")
        .overlay(savedToast, alignment: .bottom)
        .animation(.easeInOut(duration: 0.3), value: showingSaved)
        .alert("HealthKit", isPresented: $showingHealthKitAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Authorization requested. Please allow access in the Health app settings.")
        }
    }

    @ViewBuilder private var savedToast: some View {
        if showingSaved {
            Label("Settings saved", systemImage: "checkmark.circle.fill")
                .padding(.horizontal, 20).padding(.vertical, 12)
                .background(.green, in: Capsule())
                .foregroundStyle(.white).padding(.bottom, 24)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}

// MARK: - Sync diff row (used in LogsView)

struct SyncDiffRow: View {
    let label: String
    let systemImage: String
    let color: Color
    let pending: Int
    let synced: Int

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage).foregroundStyle(color).frame(width: 16)
            Text(label).foregroundStyle(.secondary)
            Spacer()
            if pending == 0 {
                Text("Up to date").foregroundStyle(.green)
            } else {
                Text("\(synced)/\(pending)").foregroundStyle(synced == pending ? .green : .orange)
            }
        }
        .font(.caption)
    }
}

// MARK: - Logs view

struct LogsView: View {
    @EnvironmentObject var viewModel: SyncViewModel

    var body: some View {
        ZStack {
            Color.surfaceBg.ignoresSafeArea()
            Group {
                if viewModel.syncLogs.isEmpty {
                    VStack(spacing: 16) {
                        Spacer()
                        Image(systemName: "list.bullet.rectangle.portrait")
                            .font(.system(size: 52)).foregroundStyle(.secondary)
                        Text("No Logs Yet").font(.headline)
                        Text("Sync logs will appear here after your first sync.")
                            .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                        Spacer()
                    }.padding()
                } else {
                    List(viewModel.syncLogs) { log in
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text(log.date, style: .date).font(.subheadline).fontWeight(.semibold)
                                Spacer()
                                Text(log.date, style: .time).font(.caption).foregroundStyle(.secondary)
                            }
                            VStack(spacing: 5) {
                                SyncDiffRow(label: "Glucose", systemImage: "drop.fill",   color: .red,    pending: log.pendingGlucose, synced: log.glucoseSynced)
                                SyncDiffRow(label: "Insulin", systemImage: "syringe.fill", color: .blue,  pending: log.pendingInsulin, synced: log.insulinSynced)
                                SyncDiffRow(label: "Carbs",   systemImage: "fork.knife",   color: .orange, pending: log.pendingCarbs,   synced: log.carbsSynced)
                            }
                            if log.hasErrors {
                                ForEach(log.errors, id: \.self) { error in
                                    Label(error, systemImage: "exclamationmark.triangle.fill")
                                        .font(.caption).foregroundStyle(.red)
                                }
                            }
                        }
                        .padding(.vertical, 6)
                        .listRowBackground(Color.cardBg)
                    }
                    .scrollContentBackground(.hidden)
                }
            }
        }
        .navigationTitle("Sync Logs")
    }
}

// MARK: - Workouts tab

struct WorkoutsView: View {
    @EnvironmentObject var viewModel: SyncViewModel
    @State private var showingLog = false

    var body: some View {
        ZStack {
            Color.surfaceBg.ignoresSafeArea()
            if viewModel.workoutLogs.isEmpty {
                emptyState
            } else {
                workoutList
            }
        }
        .navigationTitle("Workouts")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showingLog = true } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(Color.ouraActivity)
                }
            }
        }
        .sheet(isPresented: $showingLog) {
            LogWorkoutSheet { entry in
                Task { await viewModel.logWorkout(entry) }
            }
        }
        .task { await viewModel.loadSettings() }
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()
            ZStack {
                Circle().fill(Color.ouraActivity.opacity(0.1)).frame(width: 100, height: 100)
                Image(systemName: "figure.run").font(.system(size: 40)).foregroundStyle(Color.ouraActivity)
            }
            Text("No Workouts Logged").font(.title3).bold()
            Text("Tap + to log your first workout and track how you felt.")
                .font(.subheadline).foregroundStyle(.secondary)
                .multilineTextAlignment(.center).padding(.horizontal, 40)
            Button { showingLog = true } label: {
                Label("Log Workout", systemImage: "plus")
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 28).padding(.vertical, 14)
                    .background(Color.ouraActivity, in: Capsule())
            }
            Spacer()
        }
    }

    private var workoutList: some View {
        List {
            ForEach(groupedLogs, id: \.0) { (section, entries) in
                Section(header: Text(section).foregroundStyle(.secondary)) {
                    ForEach(entries) { entry in
                        WorkoutRow(entry: entry).listRowBackground(Color.cardBg)
                    }
                    .onDelete { idxs in
                        let ids = idxs.map { entries[$0].id }
                        Task { for id in ids { await viewModel.deleteWorkout(id: id) } }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showingLog = true } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20)).foregroundStyle(Color.ouraActivity)
                }
            }
        }
    }

    private var groupedLogs: [(String, [WorkoutEntry])] {
        let fmt = DateFormatter(); fmt.dateStyle = .medium; fmt.timeStyle = .none
        let grouped = Dictionary(grouping: viewModel.workoutLogs) { fmt.string(from: $0.date) }
        return grouped.sorted { a, b in
            (viewModel.workoutLogs.first { fmt.string(from: $0.date) == a.0 }?.date ?? .distantPast) >
            (viewModel.workoutLogs.first { fmt.string(from: $0.date) == b.0 }?.date ?? .distantPast)
        }
    }
}

// MARK: - Workout row

struct WorkoutRow: View {
    let entry: WorkoutEntry

    var body: some View {
        HStack(spacing: 14) {
            Text(entry.activityType)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(activityColor(entry.activityType), in: Capsule())

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(entry.feeling.emoji)
                    Text(entry.feeling.rawValue)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(entry.feeling.color)
                }
                if !entry.notes.isEmpty {
                    Text(entry.notes)
                        .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            Spacer()
            Text(entry.date, format: .dateTime.hour().minute())
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private func activityColor(_ type: String) -> Color {
        switch type {
        case "Running", "Cycling", "Rowing", "HIIT": return Color.ouraActivity
        case "Swimming": return Color(red: 0.20, green: 0.65, blue: 0.90)
        case "Walking", "Hiking": return Color(red: 0.40, green: 0.75, blue: 0.50)
        case "Weight Training": return Color(red: 0.70, green: 0.35, blue: 0.90)
        case "Yoga": return Color(red: 0.90, green: 0.55, blue: 0.30)
        case "Basketball", "Tennis": return Color.ouraReadiness
        default: return Color(white: 0.40)
        }
    }
}

// MARK: - Log workout sheet

struct LogWorkoutSheet: View {
    let onSave: (WorkoutEntry) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var selectedType: String = workoutActivityTypes[0]
    @State private var selectedFeeling: WorkoutFeeling = .good
    @State private var notes: String = ""
    @State private var date: Date = Date()

    var body: some View {
        NavigationStack {
            ZStack {
                Color.surfaceBg.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {

                        // Activity type chips
                        VStack(alignment: .leading, spacing: 12) {
                            sectionLabel("ACTIVITY TYPE")
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(workoutActivityTypes, id: \.self) { type in
                                        Button {
                                            selectedType = type
                                        } label: {
                                            Text(type)
                                                .font(.system(size: 13, weight: .semibold))
                                                .foregroundStyle(selectedType == type ? .white : Color.primary)
                                                .padding(.horizontal, 14).padding(.vertical, 8)
                                                .background(
                                                    selectedType == type ? Color.ouraActivity : Color.cardBg2,
                                                    in: Capsule()
                                                )
                                        }
                                    }
                                }
                                .padding(.horizontal, 20)
                            }
                            .padding(.horizontal, -20)
                        }

                        // Feeling scale
                        VStack(alignment: .leading, spacing: 12) {
                            sectionLabel("HOW DID IT FEEL?")
                            HStack(spacing: 8) {
                                ForEach(WorkoutFeeling.allCases, id: \.self) { feeling in
                                    Button {
                                        selectedFeeling = feeling
                                    } label: {
                                        VStack(spacing: 6) {
                                            Text(feeling.emoji).font(.system(size: 24))
                                                .scaleEffect(selectedFeeling == feeling ? 1.25 : 1.0)
                                                .animation(.spring(response: 0.3), value: selectedFeeling)
                                            Text(feeling.rawValue)
                                                .font(.system(size: 9, weight: .semibold))
                                                .foregroundStyle(selectedFeeling == feeling
                                                                 ? feeling.color : Color.secondary)
                                                .multilineTextAlignment(.center)
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(
                                            selectedFeeling == feeling
                                                ? feeling.color.opacity(0.15) : Color.cardBg2,
                                            in: RoundedRectangle(cornerRadius: 12)
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(selectedFeeling == feeling
                                                        ? feeling.color.opacity(0.6) : Color.clear,
                                                        lineWidth: 1.5)
                                        )
                                    }
                                }
                            }
                        }

                        // Date & time
                        VStack(alignment: .leading, spacing: 8) {
                            sectionLabel("DATE & TIME")
                            DatePicker("", selection: $date, displayedComponents: [.date, .hourAndMinute])
                                .datePickerStyle(.compact).labelsHidden()
                        }

                        // Notes
                        VStack(alignment: .leading, spacing: 8) {
                            sectionLabel("NOTES (OPTIONAL)")
                            TextField("E.g. 5 km run, felt strong in the last mile",
                                      text: $notes, axis: .vertical)
                                .lineLimit(2...4)
                                .padding(12)
                                .background(Color.cardBg2, in: RoundedRectangle(cornerRadius: 12))
                        }

                        // Save
                        Button {
                            let entry = WorkoutEntry(
                                date: date, activityType: selectedType,
                                feeling: selectedFeeling,
                                notes: notes.trimmingCharacters(in: .whitespacesAndNewlines)
                            )
                            onSave(entry)
                            dismiss()
                        } label: {
                            Text("Save Workout")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.ouraActivity, in: RoundedRectangle(cornerRadius: 16))
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Log Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)
            .tracking(1.5)
    }
}

// MARK: - Day navigation bar (shared across Sleep / Readiness / Activity)

struct DayNavigationBar: View {
    let summaries: [OuraDailySummary]
    @Binding var dayIndex: Int

    private var dayLabel: String {
        guard summaries.indices.contains(dayIndex) else { return "—" }
        let day = summaries[dayIndex].day
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        guard let date = f.date(from: day) else { return day }
        let out = DateFormatter(); out.dateFormat = "EEE, MMM d"
        return out.string(from: date)
    }

    private var isToday: Bool { dayIndex == 0 }
    private var canGoBack: Bool { dayIndex < summaries.count - 1 }
    private var canGoForward: Bool { dayIndex > 0 }

    var body: some View {
        HStack(spacing: 0) {
            Button { if canGoBack { dayIndex += 1 } } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(canGoBack ? Color(white: 0.75) : Color(white: 0.25))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .disabled(!canGoBack)

            Spacer()

            VStack(spacing: 2) {
                Text(dayLabel)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                if isToday {
                    Text("Today")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color(red: 0.72, green: 0.55, blue: 0.98))
                }
            }

            Spacer()

            Button { if canGoForward { dayIndex -= 1 } } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(canGoForward ? Color(white: 0.75) : Color(white: 0.25))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .disabled(!canGoForward)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(white: 0.10), in: RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }
}

// MARK: - Shared tab helpers

private func ouraEmptyState(icon: String, title: String, message: String) -> some View {
    VStack(spacing: 20) {
        Spacer()
        ZStack {
            Circle().fill(Color.ouraSleep.opacity(0.1)).frame(width: 90, height: 90)
            Image(systemName: icon).font(.system(size: 36)).foregroundStyle(.secondary)
        }
        Text(title).font(.title3).bold()
        Text(message).font(.subheadline).foregroundStyle(.secondary)
            .multilineTextAlignment(.center).padding(.horizontal, 40)
        Spacer()
    }
}

private func ouraFormattedDay(_ s: String) -> String {
    let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
    guard let d = f.date(from: s) else { return s }
    f.dateFormat = "EEE, d MMM"; return f.string(from: d)
}

private func ouraTrendChart(
    data: [(Date, Double)],
    color: Color,
    yDomain: ClosedRange<Double> = 0...100,
    goodThreshold: Double? = 85
) -> some View {
    Chart {
        ForEach(data, id: \.0) { (date, val) in
            AreaMark(x: .value("D", date), y: .value("V", val))
                .foregroundStyle(color.opacity(0.12)).interpolationMethod(.catmullRom)
            LineMark(x: .value("D", date), y: .value("V", val))
                .foregroundStyle(color).interpolationMethod(.catmullRom)
                .lineStyle(StrokeStyle(lineWidth: 2))
            PointMark(x: .value("D", date), y: .value("V", val))
                .foregroundStyle(color).symbolSize(28)
        }
        if let t = goodThreshold {
            RuleMark(y: .value("Good", t))
                .foregroundStyle(Color.ouraActivity.opacity(0.3))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
        }
    }
    .chartYScale(domain: yDomain)
    .chartXAxis {
        AxisMarks(values: .stride(by: .day, count: max(data.count / 5, 1))) { _ in
            AxisGridLine().foregroundStyle(Color.white.opacity(0.05))
            AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                .foregroundStyle(Color.secondary).font(.system(size: 9))
        }
    }
    .chartYAxis {
        AxisMarks(values: .automatic(desiredCount: 4)) { _ in
            AxisGridLine().foregroundStyle(Color.white.opacity(0.05))
            AxisValueLabel().foregroundStyle(Color.secondary).font(.system(size: 9))
        }
    }
    .frame(height: 150)
}

// MARK: - Shared correlation chart

struct CorrelationPoint: Identifiable {
    let id     = UUID()
    let date:   Date
    let insulin: Double?   // normalized 0–100
    let glucose: Double?   // normalized 0–100
    let tir:     Double?   // 0–100 (%)
    let metric:  Double?   // normalized 0–100
}

// Flat entry used inside the chart — each row = one point on one series
private struct CorrSeries: Identifiable {
    let id   = UUID()
    let date: Date
    let val:  Double
    let name: String
}

private let corrTIRColor  = Color(red: 0.20, green: 0.80, blue: 1.00)  // sky blue

struct CorrelationChartView: View {
    let title:       String
    let icon:        String
    let accentColor: Color
    let metricLabel: String
    let metricColor: Color
    let points:      [CorrelationPoint]

    @State private var showTIR    = true
    @State private var showMetric = true

    private var flatSeries: [CorrSeries] {
        var out: [CorrSeries] = []
        if showTIR    { out += points.compactMap { p in p.tir.map    { CorrSeries(date: p.date, val: $0,  name: "TIR %")     } } }
        if showMetric { out += points.compactMap { p in p.metric.map { CorrSeries(date: p.date, val: $0,  name: metricLabel) } } }
        return out
    }

    var body: some View {
        if points.isEmpty { return AnyView(EmptyView()) }
        let stride = max(points.count / 5, 1)
        let domain = ["TIR %", metricLabel]
        let range: [Color] = [corrTIRColor, metricColor]

        return AnyView(OuraCard(title: title, icon: icon, color: accentColor) {
            VStack(alignment: .leading, spacing: 12) {
                Chart {
                    ForEach(flatSeries) { pt in
                        LineMark(x: .value("D", pt.date), y: .value("V", pt.val))
                            .foregroundStyle(by: .value("S", pt.name))
                            .interpolationMethod(.catmullRom)
                            .lineStyle(StrokeStyle(lineWidth: 2.5))
                        PointMark(x: .value("D", pt.date), y: .value("V", pt.val))
                            .foregroundStyle(by: .value("S", pt.name))
                            .symbolSize(22)
                    }
                }
                .chartForegroundStyleScale(domain: domain, range: range)
                .chartLegend(.hidden)
                .chartYScale(domain: 0...100)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: stride)) { _ in
                        AxisGridLine().foregroundStyle(Color.white.opacity(0.05))
                        AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                            .foregroundStyle(Color.secondary).font(.system(size: 9))
                    }
                }
                .chartYAxis {
                    AxisMarks(values: [0, 25, 50, 75, 100]) { value in
                        AxisGridLine().foregroundStyle(Color.white.opacity(0.05))
                        AxisValueLabel {
                            if let v = value.as(Int.self) {
                                Text("\(v)").foregroundStyle(Color.secondary).font(.system(size: 9))
                            }
                        }
                    }
                }
                .frame(height: 170)

                HStack(spacing: 12) {
                    corrToggleChip(color: corrTIRColor, dash: false, label: "TIR %",     on: $showTIR)
                    corrToggleChip(color: metricColor,  dash: false, label: metricLabel, on: $showMetric)
                    Spacer()
                }
            }
        })
    }
}

private func corrToggleChip(color: Color, dash: Bool, label: String, on: Binding<Bool>) -> some View {
    Button { on.wrappedValue.toggle() } label: {
        HStack(spacing: 6) {
            if dash {
                HStack(spacing: 2) {
                    ForEach(0..<3, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 1)
                            .fill(on.wrappedValue ? color : Color(white: 0.3))
                            .frame(width: 5, height: 3)
                    }
                }
            } else {
                RoundedRectangle(cornerRadius: 1)
                    .fill(on.wrappedValue ? color : Color(white: 0.3))
                    .frame(width: 14, height: 3)
            }
            Text(label)
                .font(.system(size: 11, weight: on.wrappedValue ? .semibold : .regular))
                .foregroundStyle(on.wrappedValue ? Color.primary : Color(white: 0.4))
            Spacer()
        }
        .padding(.horizontal, 10).padding(.vertical, 7)
        .background(on.wrappedValue ? color.opacity(0.14) : Color.cardBg2,
                    in: RoundedRectangle(cornerRadius: 10))
    }
    .buttonStyle(.plain)
}

private func correlationChart(
    title: String,
    icon: String,
    accentColor: Color,
    metricLabel: String,
    metricColor: Color,
    points: [CorrelationPoint]
) -> some View {
    CorrelationChartView(
        title: title, icon: icon, accentColor: accentColor,
        metricLabel: metricLabel, metricColor: metricColor,
        points: points
    )
}

// MARK: - Sleep tab

struct SleepTabView: View {
    @EnvironmentObject var viewModel: SyncViewModel
    @Binding var dayIndex: Int
    @State private var sleepHRReadings:  [(Date, Double)] = []
    @State private var sleepHRVReadings: [(Date, Double)] = []

    private var today: OuraDailySummary? {
        viewModel.dailySummaries.indices.contains(dayIndex)
            ? viewModel.dailySummaries[dayIndex] : nil
    }

    private func minStr(_ m: Int) -> String { m >= 60 ? "\(m/60)h \(m%60)m" : "\(m)m" }

    // Narrative headline based on sleep data
    private func sleepNarrative(_ s: OuraDailySummary) -> String {
        let total = s.totalSleepMinutes ?? 0
        let deep  = s.deepSleepMinutes  ?? 0
        let rem   = s.remSleepMinutes   ?? 0
        let lite  = s.lightSleepMinutes ?? 0
        let phase = deep + rem + lite
        let deepPct = phase > 0 ? Double(deep) / Double(phase) * 100 : 0
        let hrs = Double(total) / 60.0
        if hrs < 5             { return "Very short night" }
        if hrs < 6.5 && deepPct >= 25 { return "Short night, deep sleep" }
        if hrs < 6.5           { return "Short night" }
        if deepPct >= 30       { return "Deep sleep night" }
        if rem > 90            { return "REM-rich night" }
        if hrs >= 8            { return "Long, restful night" }
        return "Solid night's sleep"
    }

    private func narrativeBody(_ s: OuraDailySummary) -> String {
        let total = s.totalSleepMinutes ?? 0
        let deep  = s.deepSleepMinutes  ?? 0
        let rem   = s.remSleepMinutes   ?? 0
        let phase = (deep + rem + (s.lightSleepMinutes ?? 0))
        let deepPct = phase > 0 ? Int(Double(deep) / Double(phase) * 100) : 0
        let hrs = Double(total) / 60.0
        if hrs < 5 { return "You got very little sleep. Prioritise rest tonight to recover." }
        if hrs < 6.5 && deepPct >= 25 { return "Last night's sleep wasn't long, but your deep sleep was on point, which is great!" }
        if hrs < 6.5 { return "A shorter night than ideal. Try to get to bed a bit earlier tonight." }
        if deepPct >= 30 { return "You had an above-average amount of deep sleep last night — great for physical recovery." }
        if rem > 90 { return "You had plenty of REM sleep, which supports memory consolidation and mood." }
        return "You had a solid night of sleep overall. Your recovery should be in good shape."
    }

    var body: some View {
        ZStack {
            Color.surfaceBg.ignoresSafeArea()
            if viewModel.dailySummaries.isEmpty {
                ouraEmptyState(icon: "moon.zzz.fill", title: "No Sleep Data",
                               message: "Sync your Oura Ring to see sleep data.")
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        DayNavigationBar(summaries: viewModel.dailySummaries, dayIndex: $dayIndex)
                        if let s = today {
                            // Score section
                            sleepScoreSection(s)
                            // Contributor rows
                            sleepContributorsSection(s)
                            // Key metrics grid
                            keyMetricsGrid(s)
                            // Sleep phases detail
                            sleepPhasesDetail(s)
                            // Hypnogram (if available)
                            if !s.hypnogramPhases.isEmpty {
                                hypnogramCard(s)
                            }
                            // Vitals: SpO2 + Breathing
                            vitalsCard(s)
                            // HR chart
                            sleepHRCard(s)
                            // HRV chart
                            sleepHRVCard(s)
                            // Glucose during sleep
                            sleepGlucoseCard(s)
                        }
                        // Trend + table
                        sleepTrendCard.padding(.top, 20)
                        recentNightsTable.padding(.top, 8)
                        nocturnalGlucoseComparisonCard.padding(.top, 8)
                        sleepGlucoseCorrelationCard.padding(.top, 8)
                        Spacer().frame(height: 40)
                    }
                }
            }
        }
        .navigationTitle("Sleep")
        .toolbar { refreshToolbarButton }
        .task { if viewModel.dailySummaries.isEmpty { await viewModel.loadDashboard() } }
        .task(id: dayIndex) { await loadSleepVitals() }
    }

    // MARK: - Score section

    private func sleepScoreSection(_ s: OuraDailySummary) -> some View {
        let quality = scoreQuality(s.sleepScore)
        return VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(s.sleepScore.map { "\($0)" } ?? "–")
                    .font(.system(size: 72, weight: .thin, design: .rounded))
                    .foregroundStyle(.white)
                Text(quality.label)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(quality.color)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(quality.color.opacity(0.18), in: Capsule())
            }

            Text(sleepNarrative(s))
                .font(.system(size: 28, weight: .semibold, design: .serif))
                .foregroundStyle(.white)
                .lineSpacing(2)

            Text(narrativeBody(s))
                .font(.system(size: 15))
                .foregroundStyle(Color(white: 0.60))
                .lineSpacing(4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
    }

    // MARK: - Contributors (Oura-style with real values)

    private func sleepContributorsSection(_ s: OuraDailySummary) -> some View {
        guard let c = s.sleepContributors else { return AnyView(EmptyView()) }
        let total = s.totalSleepMinutes ?? 0
        let deep  = s.deepSleepMinutes  ?? 0
        let rem   = s.remSleepMinutes   ?? 0
        let lite  = s.lightSleepMinutes ?? 0
        let phase = deep + rem + lite
        let deepPct = phase > 0 ? Int(Double(deep)/Double(phase)*100) : 0
        let remPct  = phase > 0 ? Int(Double(rem)/Double(phase)*100)  : 0

        return AnyView(VStack(alignment: .leading, spacing: 0) {
            Text("Contributors")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
                .padding(.bottom, 8)

            VStack(spacing: 0) {
                OuraContributorRow(label: "Total sleep",
                                   score: c.totalSleep,
                                   valueOverride: total > 0 ? minStr(total) : nil,
                                   accentColor: .ouraSleep)
                OuraContributorRow(label: "Efficiency",
                                   score: c.efficiency,
                                   valueOverride: efficiencyStr(s),
                                   accentColor: .ouraSleep)
                OuraContributorRow(label: "Restfulness",
                                   score: c.restfulness,
                                   accentColor: .ouraSleep)
                OuraContributorRow(label: "REM sleep",
                                   score: c.remSleep,
                                   valueOverride: rem > 0 ? "\(minStr(rem)), \(remPct)%" : nil,
                                   accentColor: .ouraSleep)
                OuraContributorRow(label: "Deep sleep",
                                   score: c.deepSleep,
                                   valueOverride: deep > 0 ? "\(minStr(deep)), \(deepPct)%" : nil,
                                   accentColor: .ouraSleep)
                OuraContributorRow(label: "Latency",
                                   score: c.latency,
                                   accentColor: .ouraSleep)
                OuraContributorRow(label: "Timing",
                                   score: c.timing,
                                   accentColor: .ouraSleep,
                                   showDivider: false)
            }
            .background(Color.cardBg, in: RoundedRectangle(cornerRadius: 20))
            .padding(.horizontal)
        })
    }

    private func efficiencyStr(_ s: OuraDailySummary) -> String? {
        let total = s.totalSleepMinutes ?? 0
        let awake = s.awakeMinutes ?? 0
        let inBed = total + awake
        guard inBed > 0 else { return nil }
        return "\(Int(Double(total)/Double(inBed)*100))%"
    }

    // MARK: - Key metrics 2×2 grid

    private func keyMetricsGrid(_ s: OuraDailySummary) -> some View {
        let total = s.totalSleepMinutes ?? 0
        let awake = s.awakeMinutes ?? 0
        let inBed = total + awake
        let eff   = efficiencyStr(s)

        return VStack(alignment: .leading, spacing: 12) {
            Text("Key metrics")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                keyMetricCell(label: "TOTAL SLEEP",
                              value: total > 0 ? minStr(total) : "–")
                keyMetricCell(label: "TIME IN BED",
                              value: inBed > 0 ? minStr(inBed) : "–")
                keyMetricCell(label: "SLEEP EFFICIENCY",
                              value: eff ?? "–")
                keyMetricCell(label: "LOWEST HR",
                              value: s.lowestHR.map { "\($0) bpm" } ?? "–")
            }
        }
        .padding(20)
    }

    private func keyMetricCell(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Color(white: 0.45))
                .tracking(1.2)
            Text(value)
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color(white: 0.25))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.cardBg, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Sleep phases detail

    @ViewBuilder
    private func sleepPhasesDetail(_ s: OuraDailySummary) -> some View {
        let deep  = s.deepSleepMinutes  ?? 0
        let rem   = s.remSleepMinutes   ?? 0
        let lite  = s.lightSleepMinutes ?? 0
        let awake = s.awakeMinutes      ?? 0
        let phase = deep + rem + lite
        if phase > 0 {
            VStack(alignment: .leading, spacing: 16) {
                Text("Details")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)

                VStack(alignment: .leading, spacing: 12) {
                    if let total = s.totalSleepMinutes, let awakeM = s.awakeMinutes {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("TIME ASLEEP")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(Color(white: 0.40))
                                .tracking(1.2)
                            Spacer()
                        }
                        HStack(alignment: .lastTextBaseline, spacing: 4) {
                            Text(minStr(total))
                                .font(.system(size: 28, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white)
                            Text("Total duration \(minStr(total + awakeM))")
                                .font(.system(size: 13))
                                .foregroundStyle(Color(white: 0.45))
                        }
                        Divider().background(Color(white: 0.15))
                    }

                    VStack(spacing: 8) {
                        if awake > 0 {
                            SleepPhaseRow(label: "Awake", color: Color(white: 0.85), minutes: awake, totalMinutes: phase + awake)
                        }
                        SleepPhaseRow(label: "REM",   color: Color(red: 0.45, green: 0.60, blue: 1.00), minutes: rem,  totalMinutes: phase)
                        SleepPhaseRow(label: "Light",  color: DS.fg2, minutes: lite, totalMinutes: phase)
                        SleepPhaseRow(label: "Deep",   color: Color(red: 0.15, green: 0.30, blue: 0.72), minutes: deep, totalMinutes: phase)
                    }
                }
                .padding(18)
                .background(Color.cardBg, in: RoundedRectangle(cornerRadius: 20))
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Vitals

    // MARK: - Hypnogram chart (sleep_phase_5_min)

    @ViewBuilder
    private func hypnogramCard(_ s: OuraDailySummary) -> some View {
        let phases = s.hypnogramPhases
        guard !phases.isEmpty else { return AnyView(EmptyView()) }

        let deepColor  = Color(red: 0.20, green: 0.45, blue: 0.90)
        let lightColor = Color(red: 0.35, green: 0.65, blue: 0.95)
        let remColor   = Color(red: 0.50, green: 0.85, blue: 0.80)
        let awakeColor = Color(white: 0.35)

        func stageColor(_ stage: Int) -> Color {
            switch stage { case 1: return deepColor; case 3: return remColor; case 4: return awakeColor; default: return lightColor }
        }
        func stageName(_ stage: Int) -> String {
            switch stage { case 1: return "Deep"; case 3: return "REM"; case 4: return "Awake"; default: return "Light" }
        }

        let total = max(phases.map(\.minutes).reduce(0, +), 1)

        return AnyView(
            VStack(alignment: .leading, spacing: 14) {
                Text("SLEEP STAGES")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color(white: 0.40)).tracking(1.2)
                    .padding(.horizontal, 18)

                // Proportional stacked bar
                GeometryReader { geo in
                    HStack(spacing: 1) {
                        ForEach(Array(phases.enumerated()), id: \.offset) { _, phase in
                            Rectangle()
                                .fill(stageColor(phase.stage))
                                .frame(width: geo.size.width * CGFloat(phase.minutes) / CGFloat(total))
                                .cornerRadius(1)
                        }
                    }
                }
                .frame(height: 20)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .padding(.horizontal, 18)

                // Legend with durations
                HStack(spacing: 14) {
                    ForEach([1, 2, 3, 4], id: \.self) { stage in
                        let mins = phases.filter { $0.stage == stage }.map(\.minutes).reduce(0, +)
                        if mins > 0 {
                            HStack(spacing: 4) {
                                RoundedRectangle(cornerRadius: 2).fill(stageColor(stage)).frame(width: 10, height: 10)
                                VStack(alignment: .leading, spacing: 0) {
                                    Text(stageName(stage))
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundStyle(Color(white: 0.50))
                                    Text(mins >= 60 ? "\(Int(mins)/60)h \(Int(mins)%60)m" : "\(Int(mins))m")
                                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                                        .foregroundStyle(.white)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 18)
            }
            .padding(.vertical, 18)
            .background(Color.cardBg, in: RoundedRectangle(cornerRadius: 20))
            .padding(.horizontal)
        )
    }

    @ViewBuilder
    private func vitalsCard(_ s: OuraDailySummary) -> some View {
        let hasData = s.averageSpO2 != nil || s.respiratoryRate != nil
            || s.breathingDisturbanceIndex != nil || s.restlessPeriods != nil
        if hasData {
            VStack(alignment: .leading, spacing: 12) {
                // SpO2 + Breathing Disturbance row
                if s.averageSpO2 != nil || s.breathingDisturbanceIndex != nil {
                    HStack(spacing: 12) {
                        if let spo2 = s.averageSpO2 {
                            let spo2Color: Color = spo2 >= 95 ? DS.accent
                                                 : spo2 >= 90 ? DS.lo
                                                 : DS.hi
                            vitalsMinCard(
                                label: "AVG SPO2",
                                value: String(format: "%.1f%%", spo2),
                                icon: "lungs.fill",
                                color: spo2Color
                            )
                        }
                        if let bdi = s.breathingDisturbanceIndex {
                            let bdiColor: Color = bdi < 5 ? Color(red: 0.24, green: 0.85, blue: 0.55)
                                                : bdi < 15 ? Color(red: 0.98, green: 0.72, blue: 0.18)
                                                : DS.hi
                            vitalsMinCard(
                                label: "BREATHING DIST.",
                                value: String(format: "%.0f", bdi),
                                icon: "waveform",
                                color: bdiColor,
                                footnote: bdi < 5 ? "Minimal" : bdi < 15 ? "Some" : "Elevated"
                            )
                        }
                        if let rp = s.restlessPeriods {
                            let rpColor: Color = rp < 5 ? Color(red: 0.24, green: 0.85, blue: 0.55)
                                              : rp < 15 ? Color(red: 0.98, green: 0.72, blue: 0.18)
                                              : DS.hi
                            vitalsMinCard(
                                label: "RESTLESS",
                                value: "\(rp)×",
                                icon: "figure.roll",
                                color: rpColor
                            )
                        }
                    }
                    .padding(.horizontal)
                }

                if let rr = s.respiratoryRate {
                    let isOptimal = rr >= 12 && rr <= 20
                    let statusColor: Color = isOptimal ? Color(red: 0.24, green: 0.85, blue: 0.55) : Color(red: 0.98, green: 0.72, blue: 0.18)
                    VStack(alignment: .leading, spacing: 10) {
                        Text("BREATHING REGULARITY")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color(white: 0.40)).tracking(1.2)
                        Text(isOptimal ? "Good" : "Below Optimal")
                            .font(.system(size: 28, weight: .semibold, design: .rounded))
                            .foregroundStyle(statusColor)
                        Text(String(format: "%.1f /min avg", rr))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color(white: 0.45))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(18)
                    .background(Color.cardBg, in: RoundedRectangle(cornerRadius: 20))
                    .padding(.horizontal)
                }
            }
            .padding(.top, 8)
        }
    }

    private func vitalsMinCard(label: String, value: String, icon: String, color: Color, footnote: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 11)).foregroundStyle(color)
                Text(label).font(.system(size: 9, weight: .bold)).foregroundStyle(Color(white: 0.40)).tracking(0.8)
            }
            Text(value)
                .font(.system(size: 24, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
            if let fn = footnote {
                Text(fn).font(.system(size: 10)).foregroundStyle(color.opacity(0.8))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.cardBg, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - HR chart

    @ViewBuilder
    private func sleepHRCard(_ s: OuraDailySummary) -> some View {
        if !sleepHRReadings.isEmpty || s.lowestHR != nil {
            VStack(alignment: .leading, spacing: 10) {
                Text("LOWEST HEART RATE")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color(white: 0.40))
                    .tracking(1.2)
                if let lr = s.lowestHR {
                    HStack(alignment: .lastTextBaseline, spacing: 4) {
                        Text("\(lr)")
                            .font(.system(size: 42, weight: .thin, design: .rounded))
                            .foregroundStyle(.white)
                        Text("bpm")
                            .font(.system(size: 14, weight: .light))
                            .foregroundStyle(Color(white: 0.50))
                    }
                    if let avg = sleepHRReadings.isEmpty ? nil : sleepHRReadings.map(\.1).reduce(0,+) / Double(sleepHRReadings.count) {
                        Text("Average \(Int(avg.rounded())) bpm")
                            .font(.system(size: 13))
                            .foregroundStyle(Color(white: 0.45))
                    }
                }
                if !sleepHRReadings.isEmpty {
                    SleepVitalsChart(readings: sleepHRReadings,
                                     color: Color(red: 0.9, green: 0.3, blue: 0.35),
                                     unit: "bpm")
                    .frame(height: 120)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(Color.cardBg, in: RoundedRectangle(cornerRadius: 20))
            .padding(.horizontal)
            .padding(.top, 8)
        }
    }

    // MARK: - HRV chart

    @ViewBuilder
    private func sleepHRVCard(_ s: OuraDailySummary) -> some View {
        if !sleepHRVReadings.isEmpty || s.averageHrv != nil {
            VStack(alignment: .leading, spacing: 10) {
                Text("HEART RATE VARIABILITY")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color(white: 0.40))
                    .tracking(1.2)
                if let h = s.averageHrv {
                    HStack(alignment: .lastTextBaseline, spacing: 4) {
                        Text("\(h)")
                            .font(.system(size: 42, weight: .thin, design: .rounded))
                            .foregroundStyle(.white)
                        Text("ms avg")
                            .font(.system(size: 14, weight: .light))
                            .foregroundStyle(Color(white: 0.50))
                    }
                }
                if !sleepHRVReadings.isEmpty {
                    SleepVitalsChart(readings: sleepHRVReadings,
                                     color: .ouraSleep,
                                     unit: "ms",
                                     domainPadding: 5)
                    .frame(height: 120)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(Color.cardBg, in: RoundedRectangle(cornerRadius: 20))
            .padding(.horizontal)
            .padding(.top, 8)
        }
    }

    // MARK: - Glucose during sleep

    @ViewBuilder
    private func sleepGlucoseCard(_ s: OuraDailySummary) -> some View {
        let readings = viewModel.sleepGlucoseReadings
        guard !readings.isEmpty, let sleepStart = s.sleepStart, let sleepEnd = s.sleepEnd else {
            return AnyView(EmptyView())
        }
        let tirLo = Double(viewModel.tirLow)
        let tirHi = Double(viewModel.tirHigh)

        // --- Nocturnal stats ---
        let vals   = readings.map(\.value)
        let avg    = vals.reduce(0, +) / Double(vals.count)
        let stdDev = sqrt(vals.map { ($0 - avg) * ($0 - avg) }.reduce(0, +) / Double(vals.count))
        let inRange = readings.filter { $0.value >= 70 && $0.value <= 100 }.count
        let tightRangePct = Int(Double(inRange) / Double(readings.count) * 100)
        let hypoEvents = readings.filter { $0.value < 70 }.count
        let hyperEvents = readings.filter { $0.value > tirHi }.count

        // Dawn phenomenon: glucose slope 3-6am
        let cal = Calendar.current
        let dawnStart = cal.date(bySettingHour: 3, minute: 0, second: 0, of: sleepStart) ?? sleepStart
        let dawnEnd   = cal.date(bySettingHour: 7, minute: 0, second: 0, of: sleepStart) ?? sleepEnd
        let dawnReadings = readings.filter { $0.date >= dawnStart && $0.date <= dawnEnd }.sorted { $0.date < $1.date }
        let dawnRise: Double? = {
            guard dawnReadings.count >= 2 else { return nil }
            return dawnReadings.last!.value - dawnReadings.first!.value
        }()

        let maxG = vals.max() ?? tirHi
        let yMax = max(maxG + 30, tirHi + 40)
        let yMin = 40.0

        return AnyView(
            VStack(alignment: .leading, spacing: 16) {
                // Header
                Text("GLUCOSE DURING SLEEP")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color(white: 0.40)).tracking(1.2)

                // Stat chips row
                HStack(spacing: 8) {
                    nocturnalStatChip(label: "Avg", value: String(format: "%.0f mg/dL", avg),
                                      color: avg >= 70 && avg <= 100 ? Color(red: 0.24, green: 0.85, blue: 0.55) : Color.ouraReadiness)
                    nocturnalStatChip(label: "Variability", value: String(format: "±%.0f", stdDev),
                                      color: stdDev < 15 ? Color(red: 0.24, green: 0.85, blue: 0.55) : stdDev < 30 ? Color.ouraReadiness : Color.red)
                    nocturnalStatChip(label: "Tight range", value: "\(tightRangePct)%",
                                      color: tightRangePct >= 70 ? Color(red: 0.24, green: 0.85, blue: 0.55) : Color.ouraReadiness)
                    if hypoEvents > 0 {
                        nocturnalStatChip(label: "Low events", value: "\(hypoEvents)×", color: Color.red)
                    }
                }

                // Chart with dawn-zone shading
                Chart {
                    // In-range band
                    RectangleMark(xStart: .value("s", sleepStart), xEnd: .value("e", sleepEnd),
                                  yStart: .value("lo", 70.0), yEnd: .value("hi", 100.0))
                        .foregroundStyle(Color.ouraActivity.opacity(0.06))
                    // Dawn phenomenon zone (3–7am)
                    if dawnReadings.count >= 2 {
                        RectangleMark(xStart: .value("ds", dawnStart), xEnd: .value("de", dawnEnd),
                                      yStart: .value("lo", yMin), yEnd: .value("hi", yMax))
                            .foregroundStyle(Color.ouraReadiness.opacity(0.05))
                    }
                    // Threshold lines
                    RuleMark(y: .value("Low", 70.0)).foregroundStyle(Color.red.opacity(0.35))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    RuleMark(y: .value("High", tirHi)).foregroundStyle(Color.ouraReadiness.opacity(0.35))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    // Glucose line + area
                    ForEach(readings) { pt in
                        AreaMark(x: .value("t", pt.date), y: .value("g", pt.value))
                            .foregroundStyle(LinearGradient(colors: [Color.ouraSleep.opacity(0.25), .clear], startPoint: .top, endPoint: .bottom))
                            .interpolationMethod(.catmullRom)
                        LineMark(x: .value("t", pt.date), y: .value("g", pt.value))
                            .foregroundStyle(Color.ouraSleep)
                            .interpolationMethod(.catmullRom)
                            .lineStyle(StrokeStyle(lineWidth: 2))
                    }
                    // Hypo events — red dots
                    ForEach(readings.filter { $0.value < 70 }) { pt in
                        PointMark(x: .value("t", pt.date), y: .value("g", pt.value))
                            .foregroundStyle(Color.red)
                            .symbolSize(40)
                    }
                }
                .chartYScale(domain: yMin...yMax)
                .chartXScale(domain: sleepStart...sleepEnd)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .hour, count: 2)) { _ in
                        AxisGridLine().foregroundStyle(Color.white.opacity(0.05))
                        AxisValueLabel(format: .dateTime.hour(.defaultDigits(amPM: .abbreviated)))
                            .foregroundStyle(Color.secondary).font(.system(size: 9))
                    }
                }
                .chartYAxis {
                    AxisMarks(values: [70, 100, Int(tirHi), 180]) { _ in
                        AxisGridLine().foregroundStyle(Color.white.opacity(0.05))
                        AxisValueLabel().foregroundStyle(Color.secondary).font(.system(size: 9))
                    }
                }
                .frame(height: 150)

                // Dawn phenomenon callout
                if let rise = dawnRise, abs(rise) >= 10 {
                    HStack(spacing: 8) {
                        Image(systemName: rise > 0 ? "sunrise.fill" : "moon.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(rise > 0 ? Color.ouraReadiness : Color.ouraSleep)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(rise > 0 ? "Dawn Phenomenon detected" : "Nocturnal dip detected")
                                .font(.system(size: 12, weight: .semibold)).foregroundStyle(.white)
                            Text(rise > 0
                                 ? "Glucose rose +\(Int(rise)) mg/dL between 3–7am as cortisol and growth hormone trigger hepatic glucose release."
                                 : "Glucose dropped \(Int(rise)) mg/dL in the early morning hours.")
                                .font(.system(size: 11)).foregroundStyle(Color(white: 0.50)).lineSpacing(3)
                        }
                    }
                    .padding(12)
                    .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
                }

                // Hypo callout
                if hypoEvents > 0 {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 12)).foregroundStyle(Color.red)
                        Text("\(hypoEvents) reading\(hypoEvents > 1 ? "s" : "") below 70 mg/dL during sleep. Low glucose can trigger adrenaline release, causing waking and restless sleep.")
                            .font(.system(size: 11)).foregroundStyle(Color(white: 0.50)).lineSpacing(3)
                    }
                    .padding(12)
                    .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                }

                // High glucose callout
                if hyperEvents > 0 {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 12)).foregroundStyle(Color.ouraReadiness)
                        Text("\(hyperEvents) reading\(hyperEvents > 1 ? "s" : "") above \(Int(tirHi)) mg/dL. Elevated glucose disrupts sleep architecture and increases bathroom trips.")
                            .font(.system(size: 11)).foregroundStyle(Color(white: 0.50)).lineSpacing(3)
                    }
                    .padding(12)
                    .background(Color.ouraReadiness.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(Color.cardBg, in: RoundedRectangle(cornerRadius: 20))
            .padding(.horizontal)
            .padding(.top, 8)
        )
    }

    private func nocturnalStatChip(label: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.system(size: 8, weight: .semibold)).foregroundStyle(Color(white: 0.40)).tracking(0.5)
            Text(value).font(.system(size: 12, weight: .bold, design: .rounded)).foregroundStyle(color)
        }
        .padding(.horizontal, 10).padding(.vertical, 7)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Nocturnal glucose comparison across nights

    private var nocturnalGlucoseComparisonCard: some View {
        let rows = buildNightRows(limit: 14)
        guard rows.count >= 3 else { return AnyView(EmptyView()) }
        return AnyView(NocturnalGlucoseCard(rows: rows))
    }

    private func buildNightRows(limit: Int) -> [NightRow] {
        viewModel.dailySummaries.prefix(limit).compactMap { s in
            guard let tir = viewModel.nocturnalTIRByDay[s.day],
                  let avg = viewModel.nocturnalAvgByDay[s.day] else { return nil }
            return NightRow(
                day: s.day,
                sleepScore: s.sleepScore,
                noctTIR: tir,
                noctAvg: avg,
                noctStdDev: viewModel.nocturnalStdDevByDay[s.day] ?? 0,
                hypoCount: viewModel.nocturnalHypoByDay[s.day] ?? 0
            )
        }
    }

    // MARK: - Sleep × Glucose correlation (14-day insight)

    private var sleepGlucoseCorrelationCard: some View {
        let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"

        // Pair sleep score with same-day TIR, next-day TIR, and HRV
        struct DayPair: Identifiable {
            let id = UUID()
            let sleepScore: Double
            let tirSameDay: Double?
            let tirNextDay: Double?
            let hrv: Double?
            let dateLabel: String
        }

        let pairs: [DayPair] = viewModel.dailySummaries.prefix(30).enumerated().compactMap { idx, s in
            guard let sc = s.sleepScore else { return nil }
            let tirSame = viewModel.tirByDay[s.day]
            // Next day = index idx-1 (summaries are newest-first)
            let nextDay = idx > 0 ? viewModel.dailySummaries[idx - 1] : nil
            let tirNext = nextDay.flatMap { viewModel.tirByDay[$0.day] }
            return DayPair(sleepScore: Double(sc), tirSameDay: tirSame, tirNextDay: tirNext,
                           hrv: s.averageHrv.map { Double($0) }, dateLabel: s.day)
        }

        guard pairs.count >= 5 else { return AnyView(EmptyView()) }

        // Compute simple correlation label
        let sameDayPts = pairs.compactMap { $0.tirSameDay != nil ? ($0.sleepScore, $0.tirSameDay!) : nil }
        let nextDayPts = pairs.compactMap { $0.tirNextDay != nil ? ($0.sleepScore, $0.tirNextDay!) : nil }

        func meanCorr(_ pts: [(Double, Double)]) -> Double {
            guard pts.count >= 3 else { return 0 }
            let n = Double(pts.count)
            let mx = pts.map(\.0).reduce(0,+)/n, my = pts.map(\.1).reduce(0,+)/n
            let cov = pts.map { ($0.0-mx)*($0.1-my) }.reduce(0,+)
            let sx = sqrt(pts.map { ($0.0-mx)*($0.0-mx) }.reduce(0,+))
            let sy = sqrt(pts.map { ($0.1-my)*($0.1-my) }.reduce(0,+))
            guard sx > 0, sy > 0 else { return 0 }
            return cov/(sx*sy)
        }
        let rSame = meanCorr(sameDayPts)
        let rNext = meanCorr(nextDayPts)

        // Split nights: good sleep (≥75) vs poor (<70)
        let goodNights = pairs.filter { $0.sleepScore >= 75 }
        let poorNights = pairs.filter { $0.sleepScore < 70 }
        let goodTIR = goodNights.compactMap(\.tirNextDay).reduce(0,+) / max(Double(goodNights.compactMap(\.tirNextDay).count), 1)
        let poorTIR = poorNights.compactMap(\.tirNextDay).reduce(0,+) / max(Double(poorNights.compactMap(\.tirNextDay).count), 1)

        let corrColor: Color = rSame > 0.3 ? Color(red: 0.24, green: 0.85, blue: 0.55)
                             : rSame < -0.1 ? Color.red : Color.ouraReadiness

        return AnyView(
            OuraCard(title: "Sleep × Glucose Insights", icon: "waveform.path.ecg", color: Color.ouraSleep) {
                VStack(spacing: 20) {
                    // Correlation summary
                    VStack(alignment: .leading, spacing: 10) {
                        Text("HOW YOUR SLEEP AFFECTS GLUCOSE")
                            .font(.system(size: 10, weight: .semibold)).foregroundStyle(Color(white: 0.40)).tracking(1.2)

                        HStack(spacing: 12) {
                            corrStatBlock(
                                label: "Same-day r",
                                value: String(format: "%.2f", rSame),
                                color: corrColor,
                                footnote: abs(rSame) > 0.3 ? "Significant" : "Weak link"
                            )
                            corrStatBlock(
                                label: "Next-day r",
                                value: String(format: "%.2f", rNext),
                                color: rNext > 0.3 ? Color(red: 0.24, green: 0.85, blue: 0.55) : Color.ouraReadiness,
                                footnote: "Sleep → tomorrow"
                            )
                        }

                        Text(rSame > 0.3
                             ? "Better sleep clearly links to higher time in range. Prioritising sleep directly improves your glucose control."
                             : rSame < -0.1
                             ? "Interesting — in your data, worse sleep nights showed higher TIR. This can happen with hypoglycaemia disrupting sleep."
                             : "Sleep score and TIR show a weak link in your data so far. More data will strengthen this picture.")
                            .font(.system(size: 13)).foregroundStyle(Color(white: 0.55)).lineSpacing(3)
                    }

                    Divider().background(Color.cardBg2)

                    // Good vs poor sleep nights TIR comparison
                    if goodNights.count >= 2 && poorNights.count >= 2 {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("NEXT-DAY TIR BY SLEEP QUALITY")
                                .font(.system(size: 10, weight: .semibold)).foregroundStyle(Color(white: 0.40)).tracking(1.2)

                            HStack(spacing: 12) {
                                splitNightBlock(label: "Good nights\n(score ≥75)", tir: goodTIR,
                                                count: goodNights.count, color: Color(red: 0.24, green: 0.85, blue: 0.55))
                                splitNightBlock(label: "Poor nights\n(score <70)", tir: poorTIR,
                                                count: poorNights.count, color: Color.ouraReadiness)
                            }

                            let diff = goodTIR - poorTIR
                            if abs(diff) >= 3 {
                                Text(diff > 0
                                     ? "On nights you sleep well, your glucose control the next day is \(Int(diff))% better. Sleep is your free insulin."
                                     : "Your data shows a reversed pattern. Consider whether overnight lows are disrupting your sleep.")
                                    .font(.system(size: 12)).foregroundStyle(Color(white: 0.50)).lineSpacing(3)
                                    .padding(.top, 2)
                            }
                        }
                    }

                    Divider().background(Color.cardBg2)

                    // Scatter: sleep score vs same-day TIR
                    if sameDayPts.count >= 5 {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("SLEEP SCORE vs TIME IN RANGE")
                                .font(.system(size: 10, weight: .semibold)).foregroundStyle(Color(white: 0.40)).tracking(1.2)
                            Chart {
                                ForEach(pairs.filter { $0.tirSameDay != nil }) { p in
                                    PointMark(x: .value("Sleep", p.sleepScore), y: .value("TIR", p.tirSameDay!))
                                        .foregroundStyle(Color.ouraSleep.opacity(0.7))
                                        .symbolSize(50)
                                }
                            }
                            .chartXScale(domain: 40...100)
                            .chartYScale(domain: 0...100)
                            .chartXAxis {
                                AxisMarks(values: [50, 60, 70, 80, 90, 100]) { _ in
                                    AxisGridLine().foregroundStyle(Color.white.opacity(0.05))
                                    AxisValueLabel().foregroundStyle(Color.secondary).font(.system(size: 9))
                                }
                            }
                            .chartYAxis {
                                AxisMarks(values: [0, 25, 50, 70, 100]) { v in
                                    AxisGridLine().foregroundStyle(Color.white.opacity(0.05))
                                    AxisValueLabel {
                                        if let val = v.as(Int.self) { Text("\(val)%").font(.system(size: 9)).foregroundStyle(Color.secondary) }
                                    }
                                }
                            }
                            .frame(height: 140)
                            Text("Each dot = one day. Cluster toward top-right = better sleep → better glucose control.")
                                .font(.system(size: 10)).foregroundStyle(Color(white: 0.40)).lineSpacing(2)
                        }
                    }
                }
            }
        )
    }

    private func corrStatBlock(label: String, value: String, color: Color, footnote: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.system(size: 9, weight: .semibold)).foregroundStyle(Color(white: 0.40)).tracking(0.5)
            Text(value).font(.system(size: 28, weight: .thin, design: .rounded)).foregroundStyle(color)
            Text(footnote).font(.system(size: 10)).foregroundStyle(Color(white: 0.45))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))
    }

    private func splitNightBlock(label: String, tir: Double, count: Int, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.system(size: 10, weight: .medium)).foregroundStyle(Color(white: 0.50)).lineSpacing(2)
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(String(format: "%.0f", tir))
                    .font(.system(size: 32, weight: .thin, design: .rounded)).foregroundStyle(color)
                Text("%").font(.system(size: 14)).foregroundStyle(Color(white: 0.40))
            }
            Text("avg next-day TIR · \(count) nights")
                .font(.system(size: 10)).foregroundStyle(Color(white: 0.40))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Trend + table

    private var sleepTrendCard: some View {
        let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
        let pts: [(Date, Double)] = viewModel.dailySummaries
            .compactMap { s -> (Date, Double)? in
                guard let score = s.sleepScore, let d = fmt.date(from: s.day) else { return nil }
                return (d, Double(score))
            }
            .suffix(14).reversed()
        guard !pts.isEmpty else { return AnyView(EmptyView()) }
        return AnyView(OuraCard(title: "Sleep Score Trend", icon: "chart.line.uptrend.xyaxis", color: .ouraSleep) {
            ouraTrendChart(data: Array(pts), color: .ouraSleep)
        })
    }

    private var recentNightsTable: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("RECENT NIGHTS")
                .font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
                .tracking(2).padding(.horizontal).padding(.bottom, 10)
            VStack(spacing: 0) {
                HStack {
                    Text("Night").frame(maxWidth: .infinity, alignment: .leading)
                    Text("Score").foregroundStyle(Color.ouraSleep).frame(width: 52, alignment: .center)
                    Text("Duration").frame(width: 72, alignment: .trailing)
                }
                .font(.system(size: 10, weight: .semibold)).tracking(1.5)
                .padding(.horizontal, 20).padding(.vertical, 8)
                Divider().background(Color.cardBg2)
                ForEach(Array(viewModel.dailySummaries.prefix(14).enumerated()), id: \.offset) { idx, s in
                    HStack {
                        Text(ouraFormattedDay(s.day))
                            .font(.system(size: 14)).frame(maxWidth: .infinity, alignment: .leading)
                        Text(s.sleepScore.map { "\($0)" } ?? "--")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(s.sleepScore.map { $0 >= 85 ? Color.ouraSleep : $0 >= 70 ? Color.ouraSleep.opacity(0.7) : .red } ?? Color(white: 0.35))
                            .frame(width: 52, alignment: .center)
                        Text(s.totalSleepMinutes.map { m in m >= 60 ? "\(m/60)h \(m%60)m" : "\(m)m" } ?? "--")
                            .font(.system(size: 13, design: .rounded)).foregroundStyle(.secondary)
                            .frame(width: 72, alignment: .trailing)
                    }
                    .padding(.horizontal, 20).padding(.vertical, 13)
                    .contentShape(Rectangle())
                    .onTapGesture { dayIndex = idx }
                    Divider().background(Color.cardBg2).padding(.leading, 20)
                }
            }
            .background(Color.cardBg, in: RoundedRectangle(cornerRadius: 20)).padding(.horizontal)
        }
    }

    // MARK: - Helpers

    private func loadSleepVitals() async {
        guard let s   = today,
              let start = s.sleepStart,
              let end   = s.sleepEnd,
              let hk    = HealthKitService.shared else { return }
        async let hr  = hk.heartRateReadings(from: start, to: end)
        async let hrv = hk.hrvReadings(from: start, to: end)
        sleepHRReadings  = await hr
        sleepHRVReadings = await hrv
    }

    private var refreshToolbarButton: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Button { Task { await viewModel.loadDashboard() } } label: {
                Image(systemName: "arrow.clockwise").font(.system(size: 14, weight: .semibold))
            }
        }
    }
}

// MARK: - Nocturnal data model

struct NightRow: Identifiable {
    let id   = UUID()
    let day:        String
    let sleepScore: Int?
    let noctTIR:    Double
    let noctAvg:    Double
    let noctStdDev: Double
    let hypoCount:  Int
    var cv: Double { noctAvg > 0 ? noctStdDev / noctAvg * 100 : 0 }
    var fmt: DateFormatter {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f
    }
    var date: Date { fmt.date(from: day) ?? Date() }
}

// MARK: - Correlation math helpers (free functions)

private func statPearson(_ xs: [Double], _ ys: [Double]) -> Double {
    guard xs.count == ys.count, xs.count >= 3 else { return 0 }
    let n = Double(xs.count)
    let mx = xs.reduce(0,+)/n, my = ys.reduce(0,+)/n
    let cov = zip(xs,ys).map { ($0-mx)*($1-my) }.reduce(0,+)
    let sx  = sqrt(xs.map { ($0-mx)*($0-mx) }.reduce(0,+))
    let sy  = sqrt(ys.map { ($0-my)*($0-my) }.reduce(0,+))
    guard sx > 0, sy > 0 else { return 0 }
    return cov/(sx*sy)
}

private func statSpearman(_ xs: [Double], _ ys: [Double]) -> Double {
    guard xs.count == ys.count, xs.count >= 3 else { return 0 }
    func rank(_ arr: [Double]) -> [Double] {
        let sorted = arr.enumerated().sorted { $0.element < $1.element }
        var result = Array(repeating: 0.0, count: arr.count)
        var i = 0
        while i < sorted.count {
            var j = i
            while j < sorted.count - 1 && sorted[j].element == sorted[j+1].element { j += 1 }
            let avg = Double(i + j) / 2.0 + 1.0
            for k in i...j { result[sorted[k].offset] = avg }
            i = j + 1
        }
        return result
    }
    return statPearson(rank(xs), rank(ys))
}

private func statRolling7(_ xs: [Double], _ ys: [Double]) -> Double {
    // Most-recent 7 paired points
    let n = min(xs.count, ys.count, 7)
    guard n >= 3 else { return 0 }
    return statPearson(Array(xs.suffix(n)), Array(ys.suffix(n)))
}

private func corrLabel(_ r: Double) -> String {
    switch abs(r) {
    case 0.5...:  return "Strong"
    case 0.3...:  return "Moderate"
    case 0.15...: return "Weak"
    default:       return "Negligible"
    }
}

private func corrColor(_ r: Double, positive goodIsPositive: Bool = true) -> Color {
    let isGood = goodIsPositive ? r > 0 : r < 0
    if abs(r) < 0.15 { return Color(white: 0.45) }
    return isGood
        ? Color(red: 0.24, green: 0.85, blue: 0.55)
        : Color(red: 0.95, green: 0.38, blue: 0.38)
}

// MARK: - NocturnalGlucoseCard (full view — needs @State for chart picker)

struct NocturnalGlucoseCard: View {
    let rows: [NightRow]

    // 0 = Time series, 1 = Scatter, 2 = Variability
    @State private var chartTab: Int = 0

    private let green  = DS.accent
    private let orange = DS.lo
    private let red    = DS.hi
    private let sleep  = Color.ouraSleep

    // paired (nocturnal TIR, sleep score) for all rows that have a score
    private var pairs: [(tir: Double, score: Double)] {
        rows.compactMap { r in r.sleepScore.map { (r.noctTIR, Double($0)) } }
    }

    private var rPearson:  Double { statPearson(pairs.map(\.tir),  pairs.map(\.score)) }
    private var rSpearman: Double { statSpearman(pairs.map(\.tir), pairs.map(\.score)) }
    private var rRolling:  Double { statRolling7(pairs.map(\.tir), pairs.map(\.score)) }

    // Good (≥70) vs poor (<50) nocturnal TIR nights
    private var goodNights: [NightRow] { rows.filter { $0.noctTIR >= 70 } }
    private var poorNights: [NightRow] { rows.filter { $0.noctTIR < 50  } }
    private func avgScore(_ ns: [NightRow]) -> Double {
        let sc = ns.compactMap(\.sleepScore)
        return sc.isEmpty ? 0 : sc.map { Double($0) }.reduce(0,+) / Double(sc.count)
    }

    var body: some View {
        OuraCard(title: "Nocturnal Glucose vs Sleep Quality", icon: "drop.fill", color: sleep) {
            VStack(spacing: 20) {
                correlationModelsSection
                Divider().background(Color.cardBg2)
                narrativeSection
                Divider().background(Color.cardBg2)
                splitSection
                Divider().background(Color.cardBg2)
                chartSection
                Divider().background(Color.cardBg2)
                tableSection
            }
        }
    }

    // MARK: 1 — Three model stats

    private var correlationModelsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("CORRELATION MODELS · \(rows.count) NIGHTS")
                    .font(.system(size: 10, weight: .semibold)).foregroundStyle(Color(white: 0.40)).tracking(1.2)
                Spacer()
                Text("TIR → Sleep score")
                    .font(.system(size: 9)).foregroundStyle(Color(white: 0.35))
            }
            HStack(spacing: 8) {
                modelStatBlock(label: "Pearson r", subtitle: "Linear", value: rPearson)
                modelStatBlock(label: "Spearman ρ", subtitle: "Rank / robust", value: rSpearman)
                modelStatBlock(label: "7-day r", subtitle: "Recent trend", value: rRolling)
            }
            // Agreement badge
            let agreement = [rPearson, rSpearman, rRolling].filter { abs($0) > 0.2 }
            if agreement.count >= 2 {
                let allPos = agreement.allSatisfy { $0 > 0 }
                let allNeg = agreement.allSatisfy { $0 < 0 }
                if allPos || allNeg {
                    HStack(spacing: 6) {
                        Image(systemName: allPos ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                            .font(.system(size: 11)).foregroundStyle(allPos ? green : red)
                        Text(allPos
                             ? "All 3 models agree: higher nocturnal TIR → better sleep score."
                             : "All 3 models agree on an inverse pattern — investigate hypo/alert disruption.")
                            .font(.system(size: 11)).foregroundStyle(Color(white: 0.55)).lineSpacing(2)
                    }
                    .padding(10).background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))
                }
            }
        }
    }

    private func modelStatBlock(label: String, subtitle: String, value: Double) -> some View {
        let col = corrColor(value)
        return VStack(alignment: .leading, spacing: 3) {
            Text(label).font(.system(size: 9, weight: .semibold)).foregroundStyle(Color(white: 0.40)).tracking(0.4)
            Text(String(format: "%.2f", value))
                .font(.system(size: 24, weight: .thin, design: .rounded)).foregroundStyle(col)
            Text(corrLabel(value)).font(.system(size: 9)).foregroundStyle(col.opacity(0.8))
            Text(subtitle).font(.system(size: 8)).foregroundStyle(Color(white: 0.35))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10).background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: 2 — Narrative

    private var narrativeSection: some View {
        let r = rPearson
        return Text(r > 0.3
             ? "Across all 3 models, stable nocturnal glucose clearly links to higher sleep scores. Spikes and dips during the night fragment deep and REM sleep."
             : r > 0.1
             ? "A positive but modest pattern. On nights your glucose stays in range your sleep tends to score higher — more data will sharpen this."
             : r < -0.1
             ? "Counterintuitive signal: lower nocturnal TIR correlating with better sleep. This sometimes occurs when CGM alerts or correction activity disturb the ring's motion data."
             : "No strong link detected yet between nocturnal glucose and sleep score in your current data window.")
            .font(.system(size: 13)).foregroundStyle(Color(white: 0.55)).lineSpacing(3)
    }

    // MARK: 3 — Good vs poor split

    @ViewBuilder
    private var splitSection: some View {
        if goodNights.count >= 2 && poorNights.count >= 2 {
            VStack(alignment: .leading, spacing: 10) {
                Text("SLEEP SCORE BY NOCTURNAL GLUCOSE")
                    .font(.system(size: 10, weight: .semibold)).foregroundStyle(Color(white: 0.40)).tracking(1.2)
                HStack(spacing: 8) {
                    splitBlock(label: "Stable\n(TIR ≥70%)", nights: goodNights, accent: green)
                    splitBlock(label: "Moderate\n(TIR 50–70%)", nights: rows.filter { $0.noctTIR >= 50 && $0.noctTIR < 70 }, accent: orange)
                    splitBlock(label: "Unstable\n(TIR <50%)", nights: poorNights, accent: red)
                }
                let diff = avgScore(goodNights) - avgScore(poorNights)
                if abs(diff) >= 3 {
                    Text(diff > 0
                         ? "In-range nights score \(Int(abs(diff)))pts higher on average. Stable glucose = uninterrupted architecture."
                         : "Inverted pattern by \(Int(abs(diff)))pts. Check for correction boluses or CGM alerts waking you.")
                        .font(.system(size: 11)).foregroundStyle(Color(white: 0.45)).lineSpacing(2)
                }
            }
        }
    }

    private func splitBlock(label: String, nights: [NightRow], accent: Color) -> some View {
        let sc = nights.compactMap(\.sleepScore)
        let avg = sc.isEmpty ? 0.0 : sc.map { Double($0) }.reduce(0,+) / Double(sc.count)
        return VStack(alignment: .leading, spacing: 3) {
            Text(label).font(.system(size: 9, weight: .medium)).foregroundStyle(Color(white: 0.45)).lineSpacing(1.5)
            Text(sc.isEmpty ? "--" : String(format: "%.0f", avg))
                .font(.system(size: 22, weight: .thin, design: .rounded)).foregroundStyle(accent)
            Text("\(nights.count) nights").font(.system(size: 9)).foregroundStyle(Color(white: 0.35))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10).background(accent.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: 4 — Charts (tabbed)

    @ViewBuilder
    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("", selection: $chartTab) {
                Text("Trend").tag(0)
                Text("Scatter").tag(1)
                Text("Variability").tag(2)
            }
            .pickerStyle(.segmented)
        }
        // if/else used — switch creates opaque-type conflicts in @ViewBuilder
        if chartTab == 0 {
            trendChart
        } else if chartTab == 1 {
            scatterChart
        } else {
            variabilityChart
        }
    }

    // Chart A — Time series: TIR bars + sleep score line (both 0-100 scale)
    @ViewBuilder
    private var trendChart: some View {
        let sorted = rows.sorted { $0.date < $1.date }
        VStack(alignment: .leading, spacing: 6) {
            Text("NOCTURNAL TIR & SLEEP SCORE OVER TIME")
                .font(.system(size: 10, weight: .semibold)).foregroundStyle(Color(white: 0.40)).tracking(1.2)
            Chart {
                ForEach(sorted) { row in
                    BarMark(x: .value("Date", row.date, unit: .day),
                            y: .value("TIR%", row.noctTIR))
                        .foregroundStyle(tirColor(row.noctTIR).opacity(0.55))
                        .cornerRadius(3)
                }
                ForEach(sorted.filter { $0.sleepScore != nil }) { row in
                    LineMark(x: .value("Date", row.date, unit: .day),
                             y: .value("Sleep", Double(row.sleepScore!)))
                        .foregroundStyle(sleep)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                    PointMark(x: .value("Date", row.date, unit: .day),
                              y: .value("Sleep", Double(row.sleepScore!)))
                        .foregroundStyle(sleep)
                        .symbolSize(28)
                }
                RuleMark(y: .value("Target TIR", 70))
                    .foregroundStyle(green.opacity(0.25))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4,3]))
            }
            .chartYScale(domain: 0...100)
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: max(sorted.count / 5, 1))) { _ in
                    AxisGridLine().foregroundStyle(Color.white.opacity(0.05))
                    AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                        .foregroundStyle(Color.secondary).font(.system(size: 9))
                }
            }
            .chartYAxis {
                AxisMarks(values: [0, 25, 50, 70, 100]) { v in
                    AxisGridLine().foregroundStyle(Color.white.opacity(0.05))
                    AxisValueLabel {
                        if let val = v.as(Int.self) { Text("\(val)").font(.system(size: 9)).foregroundStyle(Color.secondary) }
                    }
                }
            }
            .frame(height: 160)
            HStack(spacing: 14) {
                legendDot(color: green.opacity(0.6), label: "Nocturnal TIR%")
                legendDot(color: sleep, label: "Sleep score", line: true)
                legendDot(color: green.opacity(0.4), label: "TIR 70% target", line: true, dashed: true)
            }
        }
    }

    // Chart B — Scatter: nocturnal TIR vs sleep score, sized by CV%
    @ViewBuilder
    private var scatterChart: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("NOCTURNAL TIR vs SLEEP SCORE (size = variability)")
                .font(.system(size: 10, weight: .semibold)).foregroundStyle(Color(white: 0.40)).tracking(1.2)
            Chart {
                ForEach(rows.filter { $0.sleepScore != nil }) { row in
                    let cvClamped = min(max(row.cv, 5), 40)
                    PointMark(x: .value("TIR%", row.noctTIR),
                              y: .value("Sleep", Double(row.sleepScore!)))
                        .foregroundStyle(row.hypoCount > 0 ? red.opacity(0.80) : tirColor(row.noctTIR).opacity(0.80))
                        .symbolSize(CGFloat(cvClamped) * 6)
                }
                // Threshold lines
                RuleMark(x: .value("TIR 70", 70))
                    .foregroundStyle(green.opacity(0.20)).lineStyle(StrokeStyle(lineWidth: 1, dash: [3,3]))
                RuleMark(y: .value("Sleep 75", 75))
                    .foregroundStyle(sleep.opacity(0.20)).lineStyle(StrokeStyle(lineWidth: 1, dash: [3,3]))
            }
            .chartXScale(domain: 0...100)
            .chartYScale(domain: 40...100)
            .chartXAxis {
                AxisMarks(values: [0,25,50,70,85,100]) { _ in
                    AxisGridLine().foregroundStyle(Color.white.opacity(0.05))
                    AxisValueLabel().foregroundStyle(Color.secondary).font(.system(size: 9))
                }
            }
            .chartYAxis {
                AxisMarks(values: [50,60,70,80,90,100]) { _ in
                    AxisGridLine().foregroundStyle(Color.white.opacity(0.05))
                    AxisValueLabel().foregroundStyle(Color.secondary).font(.system(size: 9))
                }
            }
            .frame(height: 170)
            HStack(spacing: 14) {
                legendDot(color: green.opacity(0.8), label: "In-range night")
                legendDot(color: red.opacity(0.8), label: "Hypo night")
            }
            Text("Dot size = glucose variability (CV%). Top-right quadrant = stable glucose + great sleep.")
                .font(.system(size: 9)).foregroundStyle(Color(white: 0.38)).lineSpacing(2)
        }
    }

    // Chart C — Variability (CV%) bars, colored by sleep score
    @ViewBuilder
    private var variabilityChart: some View {
        let sorted = rows.sorted { $0.date < $1.date }
        VStack(alignment: .leading, spacing: 6) {
            Text("NOCTURNAL GLUCOSE VARIABILITY (CV%) BY NIGHT")
                .font(.system(size: 10, weight: .semibold)).foregroundStyle(Color(white: 0.40)).tracking(1.2)
            Chart {
                ForEach(sorted) { row in
                    BarMark(x: .value("Date", row.date, unit: .day),
                            y: .value("CV%", row.cv))
                        .foregroundStyle(sleepScoreColor(row.sleepScore).opacity(0.75))
                        .cornerRadius(3)
                }
                RuleMark(y: .value("CV 20%", 20))
                    .foregroundStyle(orange.opacity(0.35))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4,3]))
            }
            .chartYScale(domain: 0...(sorted.map(\.cv).max().map { $0 * 1.2 } ?? 40))
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: max(sorted.count / 5, 1))) { _ in
                    AxisGridLine().foregroundStyle(Color.white.opacity(0.05))
                    AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                        .foregroundStyle(Color.secondary).font(.system(size: 9))
                }
            }
            .chartYAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { v in
                    AxisGridLine().foregroundStyle(Color.white.opacity(0.05))
                    AxisValueLabel {
                        if let val = v.as(Int.self) { Text("\(val)%").font(.system(size: 9)).foregroundStyle(Color.secondary) }
                    }
                }
            }
            .frame(height: 150)
            HStack(spacing: 14) {
                legendDot(color: green.opacity(0.8), label: "Sleep ≥80")
                legendDot(color: sleep.opacity(0.8), label: "Sleep 65–79")
                legendDot(color: red.opacity(0.8), label: "Sleep <65")
            }
            Text("Bar colour = sleep score quality that night. High CV% + poor sleep → glucose instability disrupting rest.")
                .font(.system(size: 9)).foregroundStyle(Color(white: 0.38)).lineSpacing(2)
        }
    }

    // MARK: 5 — Night-by-night table

    private var tableSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("NIGHT-BY-NIGHT BREAKDOWN")
                .font(.system(size: 10, weight: .semibold)).foregroundStyle(Color(white: 0.40)).tracking(1.2)
                .padding(.bottom, 8)
            HStack {
                Text("Night").frame(maxWidth: .infinity, alignment: .leading)
                Text("TIR").foregroundStyle(green).frame(width: 42, alignment: .center)
                Text("Avg").foregroundStyle(Color.ouraActivity).frame(width: 40, alignment: .center)
                Text("CV%").foregroundStyle(.secondary).frame(width: 36, alignment: .center)
                Text("Slp").foregroundStyle(sleep).frame(width: 30, alignment: .trailing)
            }
            .font(.system(size: 10, weight: .semibold)).tracking(1.2)
            .padding(.horizontal, 4).padding(.bottom, 6)
            Divider().background(Color.cardBg2)
            ForEach(rows) { row in
                HStack {
                    Text(shortDay(row.day))
                        .font(.system(size: 12)).frame(maxWidth: .infinity, alignment: .leading)
                    Text(String(format: "%.0f%%", row.noctTIR))
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(tirColor(row.noctTIR)).frame(width: 42, alignment: .center)
                    Text(String(format: "%.0f", row.noctAvg))
                        .font(.system(size: 11, design: .rounded)).foregroundStyle(Color.ouraActivity)
                        .frame(width: 40, alignment: .center)
                    Text(String(format: "%.0f%%", row.cv))
                        .font(.system(size: 10, design: .rounded)).foregroundStyle(.secondary)
                        .frame(width: 36, alignment: .center)
                    HStack(spacing: 2) {
                        Text(row.sleepScore.map { "\($0)" } ?? "--")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(sleepScoreColor(row.sleepScore))
                        if row.hypoCount > 0 {
                            Image(systemName: "exclamationmark.circle.fill")
                                .font(.system(size: 8)).foregroundStyle(red)
                        }
                    }
                    .frame(width: 30, alignment: .trailing)
                }
                .padding(.vertical, 8).padding(.horizontal, 4)
                Divider().background(Color.cardBg2)
            }
            Text("CV% = glucose variability. ! = hypo during sleep window.")
                .font(.system(size: 9)).foregroundStyle(Color(white: 0.35)).lineSpacing(2).padding(.top, 5)
        }
    }

    // MARK: Helpers

    private func tirColor(_ tir: Double) -> Color {
        tir >= 70 ? green : tir >= 50 ? orange : red
    }

    private func sleepScoreColor(_ sc: Int?) -> Color {
        guard let sc else { return Color(white: 0.35) }
        return sc >= 80 ? green : sc >= 65 ? Color.ouraSleep : red
    }

    private func shortDay(_ day: String) -> String {
        let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
        guard let d = fmt.date(from: day) else { return day }
        let out = DateFormatter(); out.dateFormat = "EEE d MMM"
        return out.string(from: d)
    }

    private func legendDot(color: Color, label: String, line: Bool = false, dashed: Bool = false) -> some View {
        HStack(spacing: 4) {
            if line {
                Rectangle().fill(color).frame(width: 14, height: dashed ? 1.5 : 2)
            } else {
                Circle().fill(color).frame(width: 7, height: 7)
            }
            Text(label).font(.system(size: 9)).foregroundStyle(Color(white: 0.45))
        }
    }
}

// MARK: - Readiness tab

struct ReadinessTabView: View {
    @EnvironmentObject var viewModel: SyncViewModel
    @Binding var dayIndex: Int

    private var current: OuraDailySummary? {
        viewModel.dailySummaries.indices.contains(dayIndex)
            ? viewModel.dailySummaries[dayIndex] : nil
    }

    var body: some View {
        ZStack {
            Color.surfaceBg.ignoresSafeArea()
            if viewModel.dailySummaries.isEmpty {
                ouraEmptyState(icon: "bolt.heart.fill", title: "No Readiness Data",
                               message: "Sync your Oura Ring to see readiness data.")
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        DayNavigationBar(summaries: viewModel.dailySummaries, dayIndex: $dayIndex)
                        if let day = current {
                            readinessScoreSection(day)
                            readinessDetailCard(day)
                                .padding(.top, 8)
                        }
                        readinessTrendCard.padding(.top, 20)
                        insulinReadinessCard.padding(.top, 8)
                        recentReadinessTable.padding(.top, 8)
                        glucoseReadinessCorrelationCard.padding(.top, 8)
                        Spacer().frame(height: 40)
                    }
                }
            }
        }
        .navigationTitle("Readiness")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { Task { await viewModel.loadDashboard() } } label: {
                    Image(systemName: "arrow.clockwise").font(.system(size: 14, weight: .semibold))
                }
            }
        }
        .task { if viewModel.dailySummaries.isEmpty { await viewModel.loadDashboard() } }
    }

    // MARK: - Score section (Oura-style, no hero background)

    private func readinessScoreSection(_ s: OuraDailySummary) -> some View {
        let quality = scoreQuality(s.readinessScore)
        let narrative: String = {
            guard let sc = s.readinessScore else { return "Sync to see readiness." }
            if sc >= 85 { return "Your body is primed for whatever the day brings." }
            if sc >= 70 { return "You're in good shape — moderate activity is fine." }
            if sc >= 60 { return "Consider lighter activity today to allow recovery." }
            return "Your body needs rest. Avoid intense training today."
        }()
        return VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(s.readinessScore.map { "\($0)" } ?? "–")
                    .font(.system(size: 72, weight: .thin, design: .rounded))
                    .foregroundStyle(.white)
                Text(quality.label)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(quality.color)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(quality.color.opacity(0.18), in: Capsule())
            }
            // Key vitals inline
            HStack(spacing: 16) {
                if let hrv = s.averageHrv {
                    readinessPill(label: "HRV", value: "\(hrv) ms")
                }
                if let hr = s.lowestHR {
                    readinessPill(label: "Resting HR", value: "\(hr) bpm")
                }
                if let t = s.temperatureDeviation {
                    let sign = t >= 0 ? "+" : ""
                    readinessPill(label: "Body Temp", value: "\(sign)\(String(format: "%.1f", t))°C")
                }
            }
            Text(narrative)
                .font(.system(size: 15))
                .foregroundStyle(Color(white: 0.60))
                .lineSpacing(4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
    }

    private func readinessPill(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(Color(white: 0.45))
                .tracking(0.8)
            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(Color.cardBg, in: RoundedRectangle(cornerRadius: 10))
    }

    private func readinessDetailCard(_ today: OuraDailySummary) -> some View {
        OuraCard(title: "Contributors", icon: "chart.bar.fill", color: .ouraReadiness) {
            VStack(spacing: 0) {
                // History bar chart
                if viewModel.dailySummaries.count > 1 {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("LAST \(min(viewModel.dailySummaries.count, 10)) DAYS")
                            .font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary).tracking(1.5)
                        ScoreHistoryBarsView(
                            summaries: viewModel.dailySummaries,
                            keyPath: \.readinessScore,
                            color: .ouraReadiness
                        )
                    }
                    Divider().background(Color.cardBg2).padding(.vertical, 14)
                }

                if let c = today.readinessContributors {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Your body's readiness is shaped by your recovery, sleep, activity, and thermal balance.")
                            .font(.system(size: 13))
                            .foregroundStyle(Color(white: 0.50))
                            .lineSpacing(3)
                            .padding(.bottom, 14)
                        OuraContributorRow(label: "HRV Balance",      score: c.hrvBalance,       accentColor: .ouraReadiness)
                        OuraContributorRow(label: "Resting HR",        score: c.restingHeartRate, accentColor: .ouraReadiness)
                        OuraContributorRow(label: "Recovery Index",    score: c.recoveryIndex,    accentColor: .ouraReadiness)
                        OuraContributorRow(label: "Sleep Balance",     score: c.sleepBalance,     accentColor: .ouraReadiness)
                        OuraContributorRow(label: "Previous Night",    score: c.previousNight,    accentColor: .ouraReadiness)
                        OuraContributorRow(label: "Activity Balance",  score: c.activityBalance,  accentColor: .ouraReadiness)
                        OuraContributorRow(label: "Body Temperature",  score: c.bodyTemperature,  accentColor: .ouraReadiness, showDivider: false)
                    }
                }
            }
        }
    }

    private var readinessTrendCard: some View {
        let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
        let pts: [(Date, Double)] = viewModel.dailySummaries
            .compactMap { s -> (Date, Double)? in
                guard let score = s.readinessScore, let d = fmt.date(from: s.day) else { return nil }
                return (d, Double(score))
            }
            .suffix(14).reversed()
        guard !pts.isEmpty else { return AnyView(EmptyView()) }
        return AnyView(OuraCard(title: "Readiness Trend", icon: "chart.line.uptrend.xyaxis", color: .ouraReadiness) {
            ouraTrendChart(data: Array(pts), color: .ouraReadiness)
        })
    }

    private var insulinReadinessCard: some View {
        let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
        let maxIns = (viewModel.insulinByDay.values.max() ?? 1)
        let maxGlc = max(viewModel.glucoseByDay.values.max() ?? 200, 1)
        let pts: [CorrelationPoint] = viewModel.dailySummaries
            .compactMap { s -> CorrelationPoint? in
                guard let d = fmt.date(from: s.day) else { return nil }
                return CorrelationPoint(
                    date:    d,
                    insulin: viewModel.insulinByDay[s.day].map { $0 / maxIns * 100 },
                    glucose: viewModel.glucoseByDay[s.day].map { $0 / maxGlc * 100 },
                    tir:     viewModel.tirByDay[s.day],
                    metric:  s.readinessScore.map { Double($0) }
                )
            }
            .suffix(14).reversed()
        return correlationChart(
            title: "TIR · Readiness",
            icon: "syringe.fill",
            accentColor: Color.ouraReadiness,
            metricLabel: "Readiness",
            metricColor: Color.ouraReadiness,
            points: Array(pts)
        )
    }

    // MARK: - Glucose × Readiness lag correlation
    private var glucoseReadinessCorrelationCard: some View {
        let summaries = viewModel.dailySummaries

        // Same-day: TIR[i] vs readiness[i]
        let samePts: [(Double, Double)] = summaries.compactMap { s in
            guard let r = s.readinessScore, let tir = viewModel.tirByDay[s.day] else { return nil }
            return (tir, Double(r))
        }
        // Lag: TIR[i] (yesterday) → readiness[i-1] (today)
        // summaries[0]=today, summaries[1]=yesterday → TIR of yesterday predicts readiness of today
        let lagPts: [(Double, Double)] = (1..<summaries.count).compactMap { i in
            let yesterday = summaries[i]
            let today     = summaries[i - 1]
            guard let r = today.readinessScore, let tir = viewModel.tirByDay[yesterday.day] else { return nil }
            return (tir, Double(r))
        }

        guard samePts.count >= 5 else { return AnyView(EmptyView()) }

        func pearson(_ pts: [(Double, Double)]) -> Double {
            guard pts.count >= 3 else { return 0 }
            let n = Double(pts.count)
            let mx = pts.map(\.0).reduce(0,+)/n, my = pts.map(\.1).reduce(0,+)/n
            let cov = pts.map { ($0.0-mx)*($0.1-my) }.reduce(0,+)
            let sx = sqrt(pts.map { ($0.0-mx)*($0.0-mx) }.reduce(0,+))
            let sy = sqrt(pts.map { ($0.1-my)*($0.1-my) }.reduce(0,+))
            guard sx > 0, sy > 0 else { return 0 }
            return cov/(sx*sy)
        }
        let rSame = pearson(samePts)
        let rLag  = pearson(lagPts)

        // Split: high-TIR days (≥70%) vs low-TIR days (<60%) → next-day readiness
        struct TaggedPair { let tir: Double; let readiness: Double }
        let tagged: [TaggedPair] = lagPts.map { TaggedPair(tir: $0.0, readiness: $0.1) }
        let highTIR = tagged.filter { $0.tir >= 70 }
        let lowTIR  = tagged.filter { $0.tir < 60 }
        let highRdy = highTIR.isEmpty ? 0.0 : highTIR.map(\.readiness).reduce(0,+) / Double(highTIR.count)
        let lowRdy  = lowTIR.isEmpty  ? 0.0 : lowTIR.map(\.readiness).reduce(0,+)  / Double(lowTIR.count)

        let rColor: Color = rLag > 0.25 ? Color(red: 0.24, green: 0.85, blue: 0.55)
                          : rLag < -0.1  ? Color.red : Color.ouraReadiness

        return AnyView(
            OuraCard(title: "Glucose × Readiness Insights", icon: "waveform.path.ecg", color: Color.ouraReadiness) {
                VStack(spacing: 20) {

                    // Header stats
                    VStack(alignment: .leading, spacing: 10) {
                        Text("HOW YOUR GLUCOSE AFFECTS NEXT-DAY READINESS")
                            .font(.system(size: 10, weight: .semibold)).foregroundStyle(Color(white: 0.40)).tracking(1.2)

                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Same-day r").font(.system(size: 9, weight: .semibold))
                                    .foregroundStyle(Color(white: 0.40)).tracking(0.5)
                                Text(String(format: "%.2f", rSame))
                                    .font(.system(size: 28, weight: .thin, design: .rounded))
                                    .foregroundStyle(rSame > 0.25 ? Color(red: 0.24, green: 0.85, blue: 0.55) : Color.ouraReadiness)
                                Text(abs(rSame) > 0.25 ? "Significant" : "Weak link")
                                    .font(.system(size: 10)).foregroundStyle(Color(white: 0.45))
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12).background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Lag r (TIR→Rdy+1)").font(.system(size: 9, weight: .semibold))
                                    .foregroundStyle(Color(white: 0.40)).tracking(0.5)
                                Text(String(format: "%.2f", rLag))
                                    .font(.system(size: 28, weight: .thin, design: .rounded)).foregroundStyle(rColor)
                                Text("Yesterday's BG → today")
                                    .font(.system(size: 10)).foregroundStyle(Color(white: 0.45))
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12).background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))
                        }

                        Text(rLag > 0.25
                             ? "Good glucose control today clearly boosts tomorrow's readiness. Nail your TIR and your body recovers better."
                             : rLag < -0.1
                             ? "Counterintuitive pattern detected. Check whether correction doses or lows overnight are the real driver."
                             : "Glucose and readiness show a modest link in your data. Keep collecting — the pattern will sharpen.")
                            .font(.system(size: 13)).foregroundStyle(Color(white: 0.55)).lineSpacing(3)
                    }

                    // High vs low TIR split
                    if highTIR.count >= 2 && lowTIR.count >= 2 {
                        Divider().background(Color.cardBg2)
                        VStack(alignment: .leading, spacing: 10) {
                            Text("NEXT-DAY READINESS BY GLUCOSE CONTROL")
                                .font(.system(size: 10, weight: .semibold)).foregroundStyle(Color(white: 0.40)).tracking(1.2)
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("High TIR days\n(≥70% in range)").font(.system(size: 10, weight: .medium))
                                        .foregroundStyle(Color(white: 0.50)).lineSpacing(2)
                                    HStack(alignment: .lastTextBaseline, spacing: 2) {
                                        Text(String(format: "%.0f", highRdy))
                                            .font(.system(size: 32, weight: .thin, design: .rounded))
                                            .foregroundStyle(Color(red: 0.24, green: 0.85, blue: 0.55))
                                        Text("pts").font(.system(size: 14)).foregroundStyle(Color(white: 0.40))
                                    }
                                    Text("avg next-day · \(highTIR.count) days")
                                        .font(.system(size: 10)).foregroundStyle(Color(white: 0.40))
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(12).background(Color(red: 0.24, green: 0.85, blue: 0.55).opacity(0.08),
                                                        in: RoundedRectangle(cornerRadius: 12))

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Low TIR days\n(<60% in range)").font(.system(size: 10, weight: .medium))
                                        .foregroundStyle(Color(white: 0.50)).lineSpacing(2)
                                    HStack(alignment: .lastTextBaseline, spacing: 2) {
                                        Text(String(format: "%.0f", lowRdy))
                                            .font(.system(size: 32, weight: .thin, design: .rounded))
                                            .foregroundStyle(Color.ouraReadiness)
                                        Text("pts").font(.system(size: 14)).foregroundStyle(Color(white: 0.40))
                                    }
                                    Text("avg next-day · \(lowTIR.count) days")
                                        .font(.system(size: 10)).foregroundStyle(Color(white: 0.40))
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(12).background(Color.ouraReadiness.opacity(0.08),
                                                        in: RoundedRectangle(cornerRadius: 12))
                            }
                            let diff = highRdy - lowRdy
                            if abs(diff) >= 3 {
                                Text(diff > 0
                                     ? "On days you stay in range, your readiness the next day is \(Int(diff)) points higher. Controlled glucose = better recovery."
                                     : "Your data shows a reversed pattern — low TIR days followed by higher readiness. Investigate if correction episodes are masking the signal.")
                                    .font(.system(size: 12)).foregroundStyle(Color(white: 0.50)).lineSpacing(3)
                                    .padding(.top, 2)
                            }
                        }
                    }

                    // Scatter: TIR vs next-day readiness
                    if lagPts.count >= 5 {
                        Divider().background(Color.cardBg2)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("TIR vs NEXT-DAY READINESS SCORE")
                                .font(.system(size: 10, weight: .semibold)).foregroundStyle(Color(white: 0.40)).tracking(1.2)
                            Chart {
                                ForEach(Array(lagPts.enumerated()), id: \.offset) { _, pt in
                                    PointMark(x: .value("TIR%", pt.0), y: .value("Readiness", pt.1))
                                        .foregroundStyle(Color.ouraReadiness.opacity(0.75))
                                        .symbolSize(55)
                                }
                            }
                            .chartXScale(domain: 0...100)
                            .chartYScale(domain: 40...100)
                            .chartXAxis {
                                AxisMarks(values: [0, 25, 50, 70, 85, 100]) { _ in
                                    AxisGridLine().foregroundStyle(Color.white.opacity(0.05))
                                    AxisValueLabel().foregroundStyle(Color.secondary).font(.system(size: 9))
                                }
                            }
                            .chartYAxis {
                                AxisMarks(values: [50, 60, 70, 80, 90, 100]) { _ in
                                    AxisGridLine().foregroundStyle(Color.white.opacity(0.05))
                                    AxisValueLabel().foregroundStyle(Color.secondary).font(.system(size: 9))
                                }
                            }
                            .frame(height: 140)
                            Text("Each dot = one day. TIR% (x) vs next-day readiness (y). Cluster top-right = controlled glucose → higher readiness.")
                                .font(.system(size: 10)).foregroundStyle(Color(white: 0.40)).lineSpacing(2)
                        }
                    }
                }
            }
        )
    }

    private var recentReadinessTable: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("RECENT DAYS").font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary).tracking(2).padding(.horizontal).padding(.bottom, 10)
            VStack(spacing: 0) {
                HStack {
                    Text("Day").frame(maxWidth: .infinity, alignment: .leading)
                    Text("Rdy").foregroundStyle(Color.ouraReadiness).frame(width: 40, alignment: .center)
                    Text("Sleep").foregroundStyle(Color.ouraSleep).frame(width: 44, alignment: .center)
                    Text("BG").foregroundStyle(Color.ouraActivity).frame(width: 52, alignment: .trailing)
                }
                .font(.system(size: 10, weight: .semibold)).tracking(1.5)
                .padding(.horizontal, 20).padding(.vertical, 8)
                Divider().background(Color.cardBg2)
                ForEach(Array(viewModel.dailySummaries.prefix(14).enumerated()), id: \.element.day) { idx, s in
                    let glc = viewModel.glucoseByDay[s.day]
                    HStack {
                        Text(ouraFormattedDay(s.day)).font(.system(size: 13)).frame(maxWidth: .infinity, alignment: .leading)
                        Text(s.readinessScore.map { "\($0)" } ?? "--")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(s.readinessScore.map { $0 >= 85 ? Color.ouraReadiness : $0 >= 70 ? Color.ouraReadiness.opacity(0.7) : .red } ?? Color(white: 0.35))
                            .frame(width: 40, alignment: .center)
                        Text(s.sleepScore.map { "\($0)" } ?? "--")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.ouraSleep.opacity(0.8))
                            .frame(width: 44, alignment: .center)
                        Text(glc.map { String(format: "%.0f", $0) } ?? "--")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(glc.map { $0 < 120 ? Color.ouraActivity : $0 > 180 ? Color.ouraReadiness : Color.ouraActivity.opacity(0.7) } ?? Color(white: 0.35))
                            .frame(width: 52, alignment: .trailing)
                        if dayIndex == idx {
                            Image(systemName: "chevron.up").font(.system(size: 9)).foregroundStyle(Color.ouraReadiness)
                        }
                    }
                    .padding(.horizontal, 20).padding(.vertical, 12)
                    .contentShape(Rectangle())
                    .onTapGesture { dayIndex = idx }
                    Divider().background(Color.cardBg2).padding(.leading, 20)
                }
            }
            .background(Color.cardBg, in: RoundedRectangle(cornerRadius: 20)).padding(.horizontal)
        }
    }
}

// MARK: - Stress tab

struct StressTabView: View {
    @EnvironmentObject var viewModel: SyncViewModel
    @Binding var dayIndex: Int

    private var stressColor: Color { Color.ouraStress }
    private var recovColor:  Color { Color(red: 0.30, green: 0.75, blue: 0.55) }

    private var current: OuraDailySummary? {
        viewModel.dailySummaries.indices.contains(dayIndex)
            ? viewModel.dailySummaries[dayIndex] : nil
    }

    var body: some View {
        ZStack {
            Color.surfaceBg.ignoresSafeArea()
            if viewModel.dailySummaries.isEmpty {
                ouraEmptyState(icon: "brain.head.profile", title: "No Stress Data",
                               message: "Sync your Oura Ring to see stress data.")
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        if let day = current {
                            stressScoreSection(day)
                            stressTodayCard(day).padding(.top, 8)
                            resilienceCard(day).padding(.top, 8)
                        }
                        stressTrendCard.padding(.top, 20)
                        insulinStressCard.padding(.top, 8)
                        recentStressTable.padding(.top, 8)
                        stressGlucoseCorrelationCard.padding(.top, 8)
                        Spacer().frame(height: 40)
                    }
                }
            }
        }
        .navigationTitle("Stress")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { Task { await viewModel.loadDashboard() } } label: {
                    Image(systemName: "arrow.clockwise").font(.system(size: 14, weight: .semibold))
                }
            }
        }
        .task { if viewModel.dailySummaries.isEmpty { await viewModel.loadDashboard() } }
    }

    // MARK: - Score section

    private func stressScoreSection(_ s: OuraDailySummary) -> some View {
        let sm = s.stressHighMinutes ?? 0
        let rm = s.recoveryHighMinutes ?? 0
        let total = max(sm + rm, 1)
        let recovPct = Int(Double(rm) / Double(total) * 100)
        let statusColor = summaryColor(s.stressSummary ?? "")
        return VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(s.stressSummary?.capitalized ?? "–")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundStyle(statusColor)
                if sm + rm > 0 {
                    Text("\(recovPct)% recovery")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(recovColor)
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(recovColor.opacity(0.15), in: Capsule())
                }
            }
            // Inline metrics
            HStack(spacing: 12) {
                if sm > 0 {
                    stressPill(label: "Stressed", value: sm >= 60 ? "\(sm/60)h \(sm%60)m" : "\(sm)m", color: stressColor)
                }
                if rm > 0 {
                    stressPill(label: "Restored", value: rm >= 60 ? "\(rm/60)h \(rm%60)m" : "\(rm)m", color: recovColor)
                }
            }
            let narrative: String = {
                switch s.stressSummary?.lowercased() {
                case "restored":  return "Your body bounced back well. Recovery was the dominant state today."
                case "normal":    return "Stress and recovery were balanced today — a healthy mix."
                case "stressful": return "You spent more time in a stressed state today. Prioritise rest."
                case "demanding": return "A demanding day physiologically. Give your body time to recover."
                default:          return "Sync your Oura Ring to see stress and recovery data."
                }
            }()
            Text(narrative)
                .font(.system(size: 15))
                .foregroundStyle(Color(white: 0.60))
                .lineSpacing(4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
    }

    private func stressPill(label: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(Color(white: 0.45))
                .tracking(0.8)
            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(color)
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(Color.cardBg, in: RoundedRectangle(cornerRadius: 10))
    }

    private func stressTodayCard(_ today: OuraDailySummary) -> some View {
        OuraCard(title: "Stress Breakdown", icon: "brain.head.profile", color: stressColor) {
            VStack(spacing: 20) {
                let sm = today.stressHighMinutes ?? 0
                let rm = today.recoveryHighMinutes ?? 0

                // STRESSED / RESTORED side-by-side cards
                if sm + rm > 0 {
                    HStack(spacing: 12) {
                        // Stressed card
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 5) {
                                Circle().fill(stressColor).frame(width: 7, height: 7)
                                Text("STRESSED")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(Color(white: 0.45))
                                    .tracking(1.2)
                            }
                            Text(sm >= 60 ? "\(sm/60)h \(sm%60)m" : "\(sm)m")
                                .font(.system(size: 26, weight: .bold, design: .rounded))
                                .foregroundStyle(stressColor)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(stressColor.opacity(0.10), in: RoundedRectangle(cornerRadius: 14))

                        // Restored card
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 5) {
                                Circle().fill(recovColor).frame(width: 7, height: 7)
                                Text("RESTORED")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(Color(white: 0.45))
                                    .tracking(1.2)
                            }
                            Text(rm >= 60 ? "\(rm/60)h \(rm%60)m" : "\(rm)m")
                                .font(.system(size: 26, weight: .bold, design: .rounded))
                                .foregroundStyle(recovColor)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(recovColor.opacity(0.10), in: RoundedRectangle(cornerRadius: 14))
                    }

                    // Proportional bar
                    let total = max(sm + rm, 1)
                    GeometryReader { geo in
                        HStack(spacing: 3) {
                            if sm > 0 {
                                Capsule().fill(stressColor)
                                    .frame(width: geo.size.width * CGFloat(sm) / CGFloat(total))
                            }
                            if rm > 0 { Capsule().fill(recovColor).frame(maxWidth: .infinity) }
                        }
                    }
                    .frame(height: 8)
                }
            }
        }
    }

    // MARK: - Resilience card

    private let resilienceColor = Color(red: 0.20, green: 0.78, blue: 0.65)   // teal-green

    private func resilienceLevelColor(_ level: String?) -> Color {
        switch level?.lowercased() {
        case "exceptional", "strong": return Color(red: 0.24, green: 0.85, blue: 0.55)
        case "solid":                 return resilienceColor
        case "adequate":              return Color(red: 0.98, green: 0.72, blue: 0.18)
        default:                      return Color(red: 0.92, green: 0.32, blue: 0.32)
        }
    }

    // Resilience contributors are numeric scores (0.0–1.0) per Oura API spec
    private func contributorStatus(_ value: Double?) -> (label: String, color: Color, fraction: Double) {
        guard let v = value else { return ("–", Color(white: 0.4), 0) }
        switch v {
        case 0.8...: return ("Optimal",      Color(red: 0.24, green: 0.85, blue: 0.55), v)
        case 0.6...: return ("Good",          Color(red: 0.62, green: 0.88, blue: 0.38), v)
        case 0.4...: return ("Fair",          Color(red: 0.98, green: 0.72, blue: 0.18), v)
        case 0.2...: return ("Pay Attention", Color(red: 0.96, green: 0.55, blue: 0.25), v)
        default:     return ("Low",           Color(red: 0.92, green: 0.32, blue: 0.32), v)
        }
    }

    @ViewBuilder
    private func resilienceCard(_ today: OuraDailySummary) -> some View {
        // Show card even if only level is present; contributors optional
        if today.resilienceLevel != nil || today.resilienceContributors != nil {
            OuraCard(title: "Resilience", icon: "waveform.path.ecg.rectangle.fill", color: resilienceColor) {
                VStack(spacing: 18) {
                    // Level headline
                    if let level = today.resilienceLevel {
                        HStack(alignment: .center) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(level.capitalized)
                                    .font(.system(size: 32, weight: .bold, design: .rounded))
                                    .foregroundStyle(resilienceLevelColor(level))
                                Text("Today's resilience level")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Color(white: 0.45))
                            }
                            Spacer()
                            ZStack {
                                Circle()
                                    .fill(resilienceLevelColor(level).opacity(0.15))
                                    .frame(width: 52, height: 52)
                                Image(systemName: "waveform.path.ecg.rectangle.fill")
                                    .font(.system(size: 20))
                                    .foregroundStyle(resilienceLevelColor(level))
                            }
                        }
                    }

                    // Contributors
                    if let c = today.resilienceContributors {
                        Divider().background(Color.cardBg2)
                        VStack(alignment: .leading, spacing: 0) {
                            Text("CONTRIBUTORS · 14-DAY AVERAGE")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(Color(white: 0.40))
                                .tracking(1.2)
                                .padding(.bottom, 8)

                            resilienceContributorRow(
                                label: "Nighttime Recovery",
                                raw: c.sleepRecovery,
                                showDivider: true
                            )
                            resilienceContributorRow(
                                label: "Daytime Recovery",
                                raw: c.daytimeRecovery,
                                showDivider: true
                            )
                            resilienceContributorRow(
                                label: "Daytime Stress Load",
                                raw: c.stress,
                                showDivider: false
                            )
                        }
                    }

                    // Narrative
                    Text("Resilience reflects how well your body bounces back from stress, measured over the past 14 days from your nighttime recovery and daytime balance.")
                        .font(.system(size: 12))
                        .foregroundStyle(Color(white: 0.42))
                        .lineSpacing(3)
                }
            }
        }
    }

    private func resilienceContributorRow(label: String, raw: Double?, showDivider: Bool) -> some View {
        let status = contributorStatus(raw)
        return VStack(spacing: 0) {
            HStack {
                Text(label)
                    .font(.system(size: 15))
                    .foregroundStyle(.white)
                Spacer()
                HStack(spacing: 4) {
                    Text(status.label)
                        .font(.system(size: 14))
                        .foregroundStyle(status.color)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color(white: 0.28))
                }
            }
            .padding(.vertical, 14)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.08)).frame(height: 2)
                    Capsule().fill(status.color)
                        .frame(width: geo.size.width * status.fraction, height: 2)
                }
                .frame(maxHeight: .infinity, alignment: .center)
            }
            .frame(height: 3)

            if showDivider {
                Divider().background(Color.white.opacity(0.07)).padding(.top, 1)
            }
        }
    }

    private var stressTrendCard: some View {
        let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
        let pts: [(Date, Double)] = viewModel.dailySummaries
            .compactMap { s -> (Date, Double)? in
                guard let mins = s.stressHighMinutes, let d = fmt.date(from: s.day) else { return nil }
                return (d, Double(mins))
            }
            .suffix(14).reversed()
        guard !pts.isEmpty else { return AnyView(EmptyView()) }
        let maxVal = pts.map(\.1).max() ?? 60
        return AnyView(OuraCard(title: "Stress Minutes Trend", icon: "chart.bar.fill", color: stressColor) {
            Chart {
                ForEach(pts, id: \.0) { (date, val) in
                    BarMark(x: .value("D", date), y: .value("Stress", val))
                        .foregroundStyle(stressColor.opacity(0.8)).cornerRadius(3)
                }
            }
            .chartYScale(domain: 0...(maxVal * 1.2))
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: max(pts.count / 5, 1))) { _ in
                    AxisGridLine().foregroundStyle(Color.white.opacity(0.05))
                    AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                        .foregroundStyle(Color.secondary).font(.system(size: 9))
                }
            }
            .chartYAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                    AxisGridLine().foregroundStyle(Color.white.opacity(0.05))
                    AxisValueLabel().foregroundStyle(Color.secondary).font(.system(size: 9))
                }
            }
            .frame(height: 130)
        })
    }

    private var insulinStressCard: some View {
        let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
        let maxIns    = max(viewModel.insulinByDay.values.max() ?? 1, 1)
        let maxGlc    = max(viewModel.glucoseByDay.values.max() ?? 200, 1)
        let maxStress = max(viewModel.dailySummaries.compactMap(\.stressHighMinutes).map { Double($0) }.max() ?? 60, 1)
        let pts: [CorrelationPoint] = viewModel.dailySummaries
            .compactMap { s -> CorrelationPoint? in
                guard let d = fmt.date(from: s.day) else { return nil }
                return CorrelationPoint(
                    date:    d,
                    insulin: viewModel.insulinByDay[s.day].map { $0 / maxIns * 100 },
                    glucose: viewModel.glucoseByDay[s.day].map { $0 / maxGlc * 100 },
                    tir:     viewModel.tirByDay[s.day],
                    metric:  s.stressHighMinutes.map { Double($0) / maxStress * 100 }
                )
            }
            .suffix(14).reversed()
        return correlationChart(
            title: "TIR · Stress",
            icon: "syringe.fill",
            accentColor: stressColor,
            metricLabel: "Stress (norm.)",
            metricColor: stressColor,
            points: Array(pts)
        )
    }

    // MARK: - Stress × Glucose correlation
    private var stressGlucoseCorrelationCard: some View {
        let summaries = viewModel.dailySummaries

        // Pairs: stress high minutes vs same-day TIR
        struct StressPair: Identifiable {
            let id = UUID()
            let stressMin: Double
            let tir: Double
            let summary: String?
        }
        let pairs: [StressPair] = summaries.compactMap { s in
            guard let sm = s.stressHighMinutes, let tir = viewModel.tirByDay[s.day] else { return nil }
            return StressPair(stressMin: Double(sm), tir: tir, summary: s.stressSummary)
        }

        guard pairs.count >= 5 else { return AnyView(EmptyView()) }

        func pearson(_ xs: [Double], _ ys: [Double]) -> Double {
            guard xs.count == ys.count, xs.count >= 3 else { return 0 }
            let n = Double(xs.count)
            let mx = xs.reduce(0,+)/n, my = ys.reduce(0,+)/n
            let cov = zip(xs,ys).map { ($0-mx)*($1-my) }.reduce(0,+)
            let sx = sqrt(xs.map { ($0-mx)*($0-mx) }.reduce(0,+))
            let sy = sqrt(ys.map { ($0-my)*($0-my) }.reduce(0,+))
            guard sx > 0, sy > 0 else { return 0 }
            return cov/(sx*sy)
        }
        let r = pearson(pairs.map(\.stressMin), pairs.map(\.tir))

        // By stress category
        let stressfulDays  = pairs.filter { ($0.summary ?? "").lowercased() == "stressful" || ($0.summary ?? "").lowercased() == "demanding" }
        let restoredDays   = pairs.filter { ($0.summary ?? "").lowercased() == "restored" }
        let stressfulAvgTIR = stressfulDays.isEmpty ? 0.0 : stressfulDays.map(\.tir).reduce(0,+) / Double(stressfulDays.count)
        let restoredAvgTIR  = restoredDays.isEmpty  ? 0.0 : restoredDays.map(\.tir).reduce(0,+)  / Double(restoredDays.count)

        let rColor: Color = r < -0.25 ? Color(red: 0.24, green: 0.85, blue: 0.55)
                          : r >  0.25 ? Color.red : Color.ouraReadiness

        return AnyView(
            OuraCard(title: "Stress × Glucose Insights", icon: "brain.head.profile", color: stressColor) {
                VStack(spacing: 20) {

                    VStack(alignment: .leading, spacing: 10) {
                        Text("HOW STRESS RELATES TO YOUR GLUCOSE CONTROL")
                            .font(.system(size: 10, weight: .semibold)).foregroundStyle(Color(white: 0.40)).tracking(1.2)

                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Pearson r").font(.system(size: 9, weight: .semibold))
                                    .foregroundStyle(Color(white: 0.40)).tracking(0.5)
                                Text(String(format: "%.2f", r))
                                    .font(.system(size: 28, weight: .thin, design: .rounded)).foregroundStyle(rColor)
                                Text(abs(r) > 0.25 ? "Significant" : "Weak link")
                                    .font(.system(size: 10)).foregroundStyle(Color(white: 0.45))
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12).background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Stress pts analysed").font(.system(size: 9, weight: .semibold))
                                    .foregroundStyle(Color(white: 0.40)).tracking(0.5)
                                Text("\(pairs.count)")
                                    .font(.system(size: 28, weight: .thin, design: .rounded)).foregroundStyle(stressColor)
                                Text("days with both signals").font(.system(size: 10)).foregroundStyle(Color(white: 0.45))
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12).background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))
                        }

                        Text(r < -0.25
                             ? "Higher stress minutes clearly link to lower time in range in your data. Stress drives cortisol → glucose spikes and variability."
                             : r > 0.25
                             ? "Counterintuitive positive correlation. This can happen when stressful days involve more physical activity or fasting."
                             : "Stress and glucose show a mild pattern so far. More data will reveal if cortisol is a key driver for you.")
                            .font(.system(size: 13)).foregroundStyle(Color(white: 0.55)).lineSpacing(3)
                    }

                    // By category split
                    if stressfulDays.count >= 2 && restoredDays.count >= 2 {
                        Divider().background(Color.cardBg2)
                        VStack(alignment: .leading, spacing: 10) {
                            Text("TIR BY DAILY STRESS STATUS")
                                .font(.system(size: 10, weight: .semibold)).foregroundStyle(Color(white: 0.40)).tracking(1.2)
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Restored days").font(.system(size: 10, weight: .medium))
                                        .foregroundStyle(Color(white: 0.50))
                                    HStack(alignment: .lastTextBaseline, spacing: 2) {
                                        Text(String(format: "%.0f", restoredAvgTIR))
                                            .font(.system(size: 32, weight: .thin, design: .rounded))
                                            .foregroundStyle(recovColor)
                                        Text("%").font(.system(size: 14)).foregroundStyle(Color(white: 0.40))
                                    }
                                    Text("avg TIR · \(restoredDays.count) days")
                                        .font(.system(size: 10)).foregroundStyle(Color(white: 0.40))
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(12).background(recovColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Stressful days").font(.system(size: 10, weight: .medium))
                                        .foregroundStyle(Color(white: 0.50))
                                    HStack(alignment: .lastTextBaseline, spacing: 2) {
                                        Text(String(format: "%.0f", stressfulAvgTIR))
                                            .font(.system(size: 32, weight: .thin, design: .rounded))
                                            .foregroundStyle(stressColor)
                                        Text("%").font(.system(size: 14)).foregroundStyle(Color(white: 0.40))
                                    }
                                    Text("avg TIR · \(stressfulDays.count) days")
                                        .font(.system(size: 10)).foregroundStyle(Color(white: 0.40))
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(12).background(stressColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                            }
                            let diff = restoredAvgTIR - stressfulAvgTIR
                            if abs(diff) >= 3 {
                                Text(diff > 0
                                     ? "On restored days your TIR is \(Int(diff))% higher than stressful days. Managing stress is literally managing your blood sugar."
                                     : "Your stressful days actually show better TIR — possibly because you're more careful with food and doses when you're aware of stress.")
                                    .font(.system(size: 12)).foregroundStyle(Color(white: 0.50)).lineSpacing(3)
                                    .padding(.top, 2)
                            }
                        }
                    }

                    // Scatter: stress minutes vs TIR
                    Divider().background(Color.cardBg2)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("STRESS MINUTES vs TIME IN RANGE")
                            .font(.system(size: 10, weight: .semibold)).foregroundStyle(Color(white: 0.40)).tracking(1.2)
                        let maxStress = pairs.map(\.stressMin).max() ?? 120
                        Chart {
                            ForEach(pairs) { p in
                                PointMark(x: .value("Stress min", p.stressMin), y: .value("TIR%", p.tir))
                                    .foregroundStyle(stressColor.opacity(0.75))
                                    .symbolSize(55)
                            }
                        }
                        .chartXScale(domain: 0...(maxStress * 1.1))
                        .chartYScale(domain: 0...100)
                        .chartXAxis {
                            AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                                AxisGridLine().foregroundStyle(Color.white.opacity(0.05))
                                AxisValueLabel().foregroundStyle(Color.secondary).font(.system(size: 9))
                            }
                        }
                        .chartYAxis {
                            AxisMarks(values: [0, 25, 50, 70, 100]) { v in
                                AxisGridLine().foregroundStyle(Color.white.opacity(0.05))
                                AxisValueLabel {
                                    if let val = v.as(Int.self) { Text("\(val)%").font(.system(size: 9)).foregroundStyle(Color.secondary) }
                                }
                            }
                        }
                        .frame(height: 140)
                        Text("Each dot = one day. Stress minutes (x) vs TIR% (y). Trend down-right = more stress → worse glucose control.")
                            .font(.system(size: 10)).foregroundStyle(Color(white: 0.40)).lineSpacing(2)
                    }
                }
            }
        )
    }

    private var recentStressTable: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("RECENT DAYS").font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary).tracking(2).padding(.horizontal).padding(.bottom, 10)
            VStack(spacing: 0) {
                HStack {
                    Text("Day").frame(maxWidth: .infinity, alignment: .leading)
                    Text("Status").frame(width: 80, alignment: .center)
                    Text("Stress").foregroundStyle(stressColor).frame(width: 48, alignment: .center)
                    Text("BG").foregroundStyle(Color.ouraActivity).frame(width: 48, alignment: .trailing)
                }
                .font(.system(size: 10, weight: .semibold)).tracking(1.5)
                .padding(.horizontal, 20).padding(.vertical, 8)
                Divider().background(Color.cardBg2)
                ForEach(Array(viewModel.dailySummaries.prefix(14).enumerated()), id: \.element.day) { idx, s in
                    let glc = viewModel.glucoseByDay[s.day]
                    HStack {
                        Text(ouraFormattedDay(s.day)).font(.system(size: 13)).frame(maxWidth: .infinity, alignment: .leading)
                        Text(s.stressSummary?.capitalized ?? "--")
                            .font(.system(size: 11)).foregroundStyle(s.stressSummary.map { summaryColor($0) } ?? Color.secondary)
                            .frame(width: 80, alignment: .center)
                        Text(s.stressHighMinutes.map { m in m >= 60 ? "\(m/60)h\(m%60)m" : "\(m)m" } ?? "--")
                            .font(.system(size: 12, design: .rounded)).foregroundStyle(.secondary)
                            .frame(width: 48, alignment: .center)
                        Text(glc.map { String(format: "%.0f", $0) } ?? "--")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(glc.map { $0 < 120 ? Color.ouraActivity : $0 > 180 ? Color.ouraReadiness : Color.ouraActivity.opacity(0.7) } ?? Color(white: 0.35))
                            .frame(width: 48, alignment: .trailing)
                        if dayIndex == idx {
                            Image(systemName: "chevron.up").font(.system(size: 9)).foregroundStyle(stressColor)
                        }
                    }
                    .padding(.horizontal, 20).padding(.vertical, 12)
                    .contentShape(Rectangle())
                    .onTapGesture { dayIndex = idx }
                    Divider().background(Color.cardBg2).padding(.leading, 20)
                }
            }
            .background(Color.cardBg, in: RoundedRectangle(cornerRadius: 20)).padding(.horizontal)
        }
    }

    private func summaryColor(_ s: String) -> Color {
        switch s.lowercased() {
        case "restored": return recovColor
        case "normal":   return .ouraReadiness
        case "stressful": return stressColor
        default:          return .secondary
        }
    }

    private func summaryIcon(_ s: String) -> String {
        switch s.lowercased() {
        case "restored":  return "checkmark.seal.fill"
        case "normal":    return "equal.circle.fill"
        case "stressful": return "exclamationmark.triangle.fill"
        case "demanding": return "bolt.fill"
        default:          return "questionmark.circle"
        }
    }
}

// MARK: - Activity tab

struct ActivityTabView: View {
    @EnvironmentObject var viewModel: SyncViewModel
    @Binding var dayIndex: Int
    @State private var showWorkouts = false

    private var current: OuraDailySummary? {
        viewModel.dailySummaries.indices.contains(dayIndex)
            ? viewModel.dailySummaries[dayIndex] : nil
    }

    var body: some View {
        ZStack {
            Color.surfaceBg.ignoresSafeArea()
            if viewModel.dailySummaries.isEmpty {
                ouraEmptyState(icon: "flame.fill", title: "No Activity Data",
                               message: "Sync your Oura Ring to see activity data.")
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        DayNavigationBar(summaries: viewModel.dailySummaries, dayIndex: $dayIndex)
                        if let day = current {
                            activityScoreSection(day)
                            activityMinutesBar(day).padding(.top, 4)
                            activityContributorsCard(day).padding(.top, 12)
                            activityMetricsGrid(day).padding(.top, 12)
                        }
                        activityTrendCard.padding(.top, 20)
                        // Workouts link
                        Button { showWorkouts = true } label: {
                            HStack {
                                Image(systemName: "figure.run").font(.system(size: 16, weight: .semibold)).foregroundStyle(Color.ouraActivity)
                                Text("View Workouts").font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
                                Spacer()
                                Image(systemName: "chevron.right").font(.system(size: 13)).foregroundStyle(Color(white: 0.3))
                            }
                            .padding(16)
                            .background(Color.cardBg, in: RoundedRectangle(cornerRadius: 16))
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal).padding(.top, 8)
                        recentActivityTable.padding(.top, 8)
                        Spacer().frame(height: 40)
                    }
                }
                .navigationDestination(isPresented: $showWorkouts) { OuraWorkoutsView() }
            }
        }
        .navigationTitle("Activity")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { Task { await viewModel.loadDashboard() } } label: {
                    Image(systemName: "arrow.clockwise").font(.system(size: 14, weight: .semibold))
                }
            }
        }
        .task { if viewModel.dailySummaries.isEmpty { await viewModel.loadDashboard() } }
    }

    // MARK: - Score section

    private func activityScoreSection(_ s: OuraDailySummary) -> some View {
        let quality = scoreQuality(s.activityScore)
        let narrative: String = {
            guard let sc = s.activityScore else { return "Sync to see activity data." }
            if sc >= 85 { return "You crushed your activity goals today." }
            if sc >= 70 { return "Good movement today — solid daily output." }
            if sc >= 60 { return "Decent activity. A little more movement would help." }
            return "Low activity today. Try to get up and move more."
        }()
        return VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(s.activityScore.map { "\($0)" } ?? "–")
                    .font(.system(size: 72, weight: .thin, design: .rounded))
                    .foregroundStyle(.white)
                Text(quality.label)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(quality.color)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(quality.color.opacity(0.18), in: Capsule())
            }
            // Key stats inline
            HStack(spacing: 12) {
                if let steps = s.steps {
                    activityPill(label: "Steps", value: "\(steps)", color: .ouraActivity)
                }
                if let cal = s.activeCalories {
                    activityPill(label: "Active kcal", value: "\(cal)", color: .ouraReadiness)
                }
                if let km = s.equivalentWalkingKm {
                    activityPill(label: "Distance", value: String(format: "%.1f km", km), color: Color(red: 0.45, green: 0.75, blue: 0.95))
                }
            }
            Text(narrative)
                .font(.system(size: 15))
                .foregroundStyle(Color(white: 0.60))
                .lineSpacing(4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
    }

    private func activityPill(label: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(Color(white: 0.45)).tracking(0.8)
            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(color)
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(Color.cardBg, in: RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Activity minutes bar (High / Medium / Low proportional)

    private func activityMinutesBar(_ s: OuraDailySummary) -> some View {
        let hi  = s.highActivityMinutes   ?? 0
        let med = s.mediumActivityMinutes ?? 0
        let lo  = s.lowActivityMinutes    ?? 0
        let sed = s.sedentaryMinutes      ?? 0
        let total = max(hi + med + lo + sed, 1)

        let hiColor  = Color(red: 0.20, green: 0.60, blue: 1.00)
        let medColor = Color(red: 0.40, green: 0.76, blue: 0.96)
        let loColor  = Color(red: 0.28, green: 0.28, blue: 0.36)
        let sedColor = Color(red: 0.18, green: 0.18, blue: 0.24)

        return VStack(alignment: .leading, spacing: 10) {
            GeometryReader { geo in
                HStack(spacing: 2) {
                    if hi > 0  { RoundedRectangle(cornerRadius: 4).fill(hiColor).frame(width: geo.size.width * CGFloat(hi)  / CGFloat(total)) }
                    if med > 0 { RoundedRectangle(cornerRadius: 4).fill(medColor).frame(width: geo.size.width * CGFloat(med) / CGFloat(total)) }
                    if lo > 0  { RoundedRectangle(cornerRadius: 4).fill(loColor).frame(width: geo.size.width * CGFloat(lo)  / CGFloat(total)) }
                    if sed > 0 { RoundedRectangle(cornerRadius: 4).fill(sedColor).frame(maxWidth: .infinity) }
                }
            }
            .frame(height: 12)

            HStack(spacing: 16) {
                legendDot(color: hiColor,  label: "High",  value: hi > 0  ? "\(hi)m"  : nil)
                legendDot(color: medColor, label: "Med",   value: med > 0 ? "\(med)m" : nil)
                legendDot(color: loColor,  label: "Low",   value: lo > 0  ? "\(lo)m"  : nil)
                legendDot(color: sedColor, label: "Sedentary", value: sed > 0 ? "\(sed >= 60 ? "\(sed/60)h \(sed%60)m" : "\(sed)m")" : nil)
            }
        }
        .padding(.horizontal, 20)
    }

    private func legendDot(color: Color, label: String, value: String?) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color(white: 0.50))
            if let v = value {
                Text(v)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
            }
        }
    }

    // MARK: - Contributors card

    private func activityContributorsCard(_ s: OuraDailySummary) -> some View {
        OuraCard(title: "Contributors", icon: "chart.bar.fill", color: .ouraActivity) {
            VStack(spacing: 0) {
                if viewModel.dailySummaries.count > 1 {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("LAST \(min(viewModel.dailySummaries.count, 10)) DAYS")
                            .font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary).tracking(1.5)
                        ScoreHistoryBarsView(
                            summaries: viewModel.dailySummaries,
                            keyPath: \.activityScore,
                            color: .ouraActivity
                        )
                    }
                    Divider().background(Color.cardBg2).padding(.vertical, 14)
                }

                if let c = s.activityContributors {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Your activity score reflects how well you moved, trained, and recovered today.")
                            .font(.system(size: 13)).foregroundStyle(Color(white: 0.50))
                            .lineSpacing(3).padding(.bottom, 14)
                        OuraContributorRow(label: "Stay Active",         score: c.stayActive,          accentColor: .ouraActivity)
                        OuraContributorRow(label: "Move Every Hour",     score: c.moveEveryHour,       accentColor: .ouraActivity)
                        OuraContributorRow(label: "Meet Daily Goals",    score: c.meetDailyTargets,    accentColor: .ouraActivity)
                        OuraContributorRow(label: "Training Frequency",  score: c.trainingFrequency,   accentColor: .ouraActivity)
                        OuraContributorRow(label: "Training Volume",     score: c.trainingVolume,      accentColor: .ouraActivity)
                        OuraContributorRow(label: "Recovery Time",       score: c.recoveryTime,        accentColor: .ouraActivity, showDivider: false)
                    }
                }
            }
        }
    }

    // MARK: - Metrics grid (2×2)

    private func activityMetricsGrid(_ s: OuraDailySummary) -> some View {
        let items: [(String, String, String)] = [
            ("Steps",          s.steps.map { "\($0)" } ?? "–",                 "figure.walk"),
            ("Active Cal",     s.activeCalories.map { "\($0) kcal" } ?? "–",   "flame.fill"),
            ("Total Cal",      s.totalCalories.map { "\($0) kcal" } ?? "–",    "bolt.fill"),
            ("High Activity",  s.highActivityMinutes.map { "\($0) min" } ?? "–","figure.run"),
        ]
        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            ForEach(items, id: \.0) { item in
                VStack(alignment: .leading, spacing: 6) {
                    Image(systemName: item.2)
                        .font(.system(size: 14))
                        .foregroundStyle(Color.ouraActivity)
                    Text(item.1)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text(item.0)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color(white: 0.45))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(Color.cardBg, in: RoundedRectangle(cornerRadius: 14))
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Activity trend

    private var activityTrendCard: some View {
        let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
        let pts: [(Date, Double)] = viewModel.dailySummaries
            .compactMap { s -> (Date, Double)? in
                guard let score = s.activityScore, let d = fmt.date(from: s.day) else { return nil }
                return (d, Double(score))
            }
            .suffix(14).reversed()
        guard !pts.isEmpty else { return AnyView(EmptyView()) }
        return AnyView(OuraCard(title: "Activity Trend", icon: "chart.line.uptrend.xyaxis", color: .ouraActivity) {
            ouraTrendChart(data: Array(pts), color: .ouraActivity)
        })
    }

    // MARK: - Recent days table

    private var recentActivityTable: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("RECENT DAYS").font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary).tracking(2).padding(.horizontal).padding(.bottom, 10)
            VStack(spacing: 0) {
                HStack {
                    Text("Day").frame(maxWidth: .infinity, alignment: .leading)
                    Text("Act").foregroundStyle(Color.ouraActivity).frame(width: 36, alignment: .center)
                    Text("Steps").foregroundStyle(Color(white: 0.6)).frame(width: 54, alignment: .center)
                    Text("Kcal").foregroundStyle(Color.ouraReadiness).frame(width: 48, alignment: .trailing)
                }
                .font(.system(size: 10, weight: .semibold)).tracking(1.5)
                .padding(.horizontal, 20).padding(.vertical, 8)
                Divider().background(Color.cardBg2)
                ForEach(Array(viewModel.dailySummaries.prefix(14).enumerated()), id: \.element.day) { idx, s in
                    HStack {
                        Text(ouraFormattedDay(s.day)).font(.system(size: 13)).frame(maxWidth: .infinity, alignment: .leading)
                        Text(s.activityScore.map { "\($0)" } ?? "--")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(s.activityScore.map { $0 >= 85 ? Color.ouraActivity : $0 >= 70 ? Color.ouraActivity.opacity(0.7) : .red } ?? Color(white: 0.35))
                            .frame(width: 36, alignment: .center)
                        Text(s.steps.map { $0 >= 1000 ? "\($0 / 1000).\(($0 % 1000) / 100)k" : "\($0)" } ?? "--")
                            .font(.system(size: 13, design: .rounded)).foregroundStyle(Color(white: 0.60))
                            .frame(width: 54, alignment: .center)
                        Text(s.activeCalories.map { "\($0)" } ?? "--")
                            .font(.system(size: 13, weight: .semibold, design: .rounded)).foregroundStyle(Color.ouraReadiness.opacity(0.8))
                            .frame(width: 48, alignment: .trailing)
                        if dayIndex == idx {
                            Image(systemName: "chevron.up").font(.system(size: 9)).foregroundStyle(Color.ouraActivity)
                        }
                    }
                    .padding(.horizontal, 20).padding(.vertical, 12)
                    .contentShape(Rectangle())
                    .onTapGesture { dayIndex = idx }
                    Divider().background(Color.cardBg2).padding(.leading, 20)
                }
            }
            .background(Color.cardBg, in: RoundedRectangle(cornerRadius: 20)).padding(.horizontal)
        }
    }
}

// MARK: - Oura Workouts tab

struct OuraWorkoutsView: View {
    @EnvironmentObject var viewModel: SyncViewModel

    var body: some View {
        ZStack {
            Color.surfaceBg.ignoresSafeArea()
            if viewModel.ouraWorkouts.isEmpty {
                ouraEmptyState(icon: "figure.run", title: "No Workouts",
                               message: "Sync your Oura Ring to see workouts recorded by your ring.")
            } else {
                List {
                    // Insulin context card at top
                    if !viewModel.insulinByDay.isEmpty {
                        Section {
                            insulinWorkoutCorrelationCard
                                .listRowInsets(EdgeInsets())
                                .listRowBackground(Color.clear)
                        }
                    }

                    ForEach(groupedWorkouts, id: \.0) { (section, entries) in
                        Section(header: Text(section).foregroundStyle(.secondary)) {
                            ForEach(entries) { workout in
                                OuraWorkoutRow(
                                    workout: workout,
                                    dailySummary: summaryForDay(workout.day),
                                    glucose: viewModel.glucoseByDay[workout.day]
                                )
                                .listRowBackground(Color.cardBg)
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
        }
        .navigationTitle("Workouts")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { Task { await viewModel.loadDashboard() } } label: {
                    Image(systemName: "arrow.clockwise").font(.system(size: 14, weight: .semibold))
                }
            }
        }
        .task { if viewModel.ouraWorkouts.isEmpty { await viewModel.loadDashboard() } }
    }

    private func summaryForDay(_ day: String) -> OuraDailySummary? {
        viewModel.dailySummaries.first { $0.day == day }
    }

    private var insulinWorkoutCorrelationCard: some View {
        let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
        let workoutDays = Set(viewModel.ouraWorkouts.map { $0.day })
        let maxIns = max(viewModel.insulinByDay.values.max() ?? 1, 1)
        let maxGlc = max(viewModel.glucoseByDay.values.max() ?? 200, 1)
        let pts: [CorrelationPoint] = viewModel.dailySummaries
            .compactMap { s -> CorrelationPoint? in
                guard let d = fmt.date(from: s.day) else { return nil }
                return CorrelationPoint(
                    date:    d,
                    insulin: viewModel.insulinByDay[s.day].map { $0 / maxIns * 100 },
                    glucose: viewModel.glucoseByDay[s.day].map { $0 / maxGlc * 100 },
                    tir:     viewModel.tirByDay[s.day],
                    metric:  workoutDays.contains(s.day) ? 100.0 : 10.0
                )
            }
            .suffix(14).reversed()
        return correlationChart(
            title: "TIR · Workouts",
            icon: "figure.run",
            accentColor: Color.ouraActivity,
            metricLabel: "Workout day",
            metricColor: Color.ouraActivity,
            points: Array(pts)
        )
    }

    private var groupedWorkouts: [(String, [OuraWorkoutEntry])] {
        let isoFmt = DateFormatter(); isoFmt.dateFormat = "yyyy-MM-dd"
        let display = DateFormatter(); display.dateStyle = .medium; display.timeStyle = .none
        // Group by the ISO day string — sorts reliably as lexicographic == chronological
        let grouped = Dictionary(grouping: viewModel.ouraWorkouts) { $0.day }
        return grouped.keys.sorted(by: >).map { day in
            let title = isoFmt.date(from: day).map { display.string(from: $0) } ?? day
            let entries = (grouped[day] ?? []).sorted {
                ($0.startDate ?? .distantPast) > ($1.startDate ?? .distantPast)
            }
            return (title, entries)
        }
    }
}

struct OuraWorkoutRow: View {
    let workout: OuraWorkoutEntry
    let dailySummary: OuraDailySummary?   // matching day's summary for HRV / scores
    let glucose: Double?                  // avg blood glucose for that day (mg/dL)

    private var intensityColor: Color {
        switch workout.intensity?.lowercased() {
        case "easy":     return Color.ouraActivity
        case "moderate": return Color.ouraReadiness
        case "hard":     return Color(red: 0.92, green: 0.28, blue: 0.28)
        default:         return Color(white: 0.45)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 14) {
                // Activity type tag
                Text(workout.activityDisplayName)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(activityColor, in: Capsule())

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        if let dur = workout.durationMinutes {
                            Label("\(dur) min", systemImage: "clock").font(.caption).foregroundStyle(.secondary)
                        }
                        if let dist = workout.distance, dist > 0 {
                            Label(String(format: "%.1f km", dist / 1000), systemImage: "arrow.forward")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    HStack(spacing: 8) {
                        if let cal = workout.calories, cal > 0 {
                            Label(String(format: "%.0f kcal", cal), systemImage: "flame.fill")
                                .font(.caption).foregroundStyle(Color.ouraReadiness)
                        }
                        if let intensity = workout.intensity {
                            Text(intensity.capitalized)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(intensityColor)
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background(intensityColor.opacity(0.15), in: Capsule())
                        }
                    }
                }
                Spacer()
                if let d = workout.startDate {
                    Text(d, format: .dateTime.hour().minute())
                        .font(.caption).foregroundStyle(.secondary)
                }
            }

            // Daily biometrics for workout's day
            let hasHRV = dailySummary?.averageHrv != nil
            let hasAct = dailySummary?.activityScore != nil
            let hasRdy = dailySummary?.readinessScore != nil
            if hasHRV || hasAct || hasRdy || glucose != nil {
                HStack(spacing: 8) {
                    if let hrv = dailySummary?.averageHrv {
                        workoutStatPill(icon: "waveform.path.ecg", color: Color.ouraSleep,
                                        label: "HRV", value: "\(hrv)ms")
                    }
                    if let act = dailySummary?.activityScore {
                        workoutStatPill(icon: "figure.run", color: Color.ouraActivity,
                                        label: "Act", value: "\(act)")
                    }
                    if let rdy = dailySummary?.readinessScore {
                        workoutStatPill(icon: "bolt.heart.fill", color: Color.ouraReadiness,
                                        label: "Rdy", value: "\(rdy)")
                    }
                    if let g = glucose {
                        workoutStatPill(icon: "drop.fill",
                                        color: g < Double(120) ? Color.ouraActivity : g > Double(180) ? Color.ouraReadiness : .white,
                                        label: "BG", value: String(format: "%.0f", g))
                    }
                    Spacer()
                }
            }
        }
        .padding(.vertical, 6)
    }

    private func workoutStatPill(icon: String, color: Color, label: String, value: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 10)).foregroundStyle(color)
            Text(value).font(.system(size: 11, weight: .semibold)).foregroundStyle(.primary)
        }
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(color.opacity(0.12), in: Capsule())
    }

    private var activityColor: Color {
        let a = workout.activity.lowercased()
        if a.contains("run") { return Color.ouraActivity }
        if a.contains("cycl") || a.contains("bike") { return Color(red: 0.31, green: 0.53, blue: 0.96) }
        if a.contains("swim") { return Color(red: 0.20, green: 0.65, blue: 0.90) }
        if a.contains("walk") || a.contains("hike") { return Color(red: 0.40, green: 0.75, blue: 0.50) }
        if a.contains("strength") || a.contains("weight") { return Color(red: 0.70, green: 0.35, blue: 0.90) }
        if a.contains("yoga") { return Color(red: 0.90, green: 0.55, blue: 0.30) }
        return Color(white: 0.40)
    }
}

// MARK: - Pump Events tab

struct PumpEventsView: View {
    @EnvironmentObject var viewModel: SyncViewModel
    @State private var showingLog = false

    var body: some View {
        ZStack {
            Color.surfaceBg.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    statsCards
                    if viewModel.pumpEventLogs.isEmpty {
                        emptyState
                    } else {
                        eventList
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 32)
            }
        }
        .navigationTitle("Pump Events")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showingLog = true } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(Color(red: 0.31, green: 0.53, blue: 0.96))
                }
            }
        }
        .sheet(isPresented: $showingLog) {
            LogPumpEventSheet { entry in
                Task { await viewModel.logPumpEvent(entry) }
            }
        }
        .task { await viewModel.loadSettings() }
    }

    // MARK: Stat cards

    private var statsCards: some View {
        HStack(spacing: 10) {
            ForEach(PumpEventType.allCases, id: \.self) { type in
                pumpStatCard(type)
            }
        }
    }

    private func pumpStatCard(_ type: PumpEventType) -> some View {
        let last = viewModel.pumpEventLogs.first { $0.eventType == type }
        let elapsed: String = {
            guard let d = last?.date else { return "Never" }
            let hours = Int(Date().timeIntervalSince(d) / 3600)
            if hours < 24 { return "\(hours)h ago" }
            let days = hours / 24
            return "\(days)d ago"
        }()

        return VStack(spacing: 6) {
            Image(systemName: type.icon)
                .font(.system(size: 18))
                .foregroundStyle(type.color)
            Text(elapsed)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
            Text(type.rawValue.components(separatedBy: " ").first ?? "")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color.cardBg, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: Event list

    private var eventList: some View {
        VStack(spacing: 0) {
            ForEach(groupedEvents, id: \.0) { section, entries in
                VStack(alignment: .leading, spacing: 0) {
                    Text(section)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)
                        .padding(.bottom, 6)
                        .padding(.top, 14)

                    VStack(spacing: 1) {
                        ForEach(entries) { entry in
                            PumpEventRow(entry: entry, onDelete: {
                                Task { await viewModel.deletePumpEvent(id: entry.id) }
                            })
                        }
                    }
                    .background(Color.cardBg, in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }

    private var groupedEvents: [(String, [PumpEventEntry])] {
        let fmt = DateFormatter(); fmt.dateStyle = .medium; fmt.timeStyle = .none
        let grouped = Dictionary(grouping: viewModel.pumpEventLogs) { fmt.string(from: $0.date) }
        return grouped.sorted { a, b in
            (viewModel.pumpEventLogs.first { fmt.string(from: $0.date) == a.0 }?.date ?? .distantPast) >
            (viewModel.pumpEventLogs.first { fmt.string(from: $0.date) == b.0 }?.date ?? .distantPast)
        }
    }

    // MARK: Empty state

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 40)
            ZStack {
                Circle()
                    .fill(Color(red: 0.31, green: 0.53, blue: 0.96).opacity(0.1))
                    .frame(width: 100, height: 100)
                Image(systemName: "cross.vial.fill")
                    .font(.system(size: 38))
                    .foregroundStyle(Color(red: 0.31, green: 0.53, blue: 0.96))
            }
            Text("No Pump Events")
                .font(.title3).bold()
            Text("Log reservoir changes, pod swaps, and cannula insertions to track your pump history.")
                .font(.subheadline).foregroundStyle(.secondary)
                .multilineTextAlignment(.center).padding(.horizontal, 32)
            Button { showingLog = true } label: {
                Label("Log Event", systemImage: "plus")
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 28).padding(.vertical, 14)
                    .background(Color(red: 0.31, green: 0.53, blue: 0.96), in: Capsule())
            }
            Spacer(minLength: 40)
        }
    }
}

// MARK: - Pump event row

struct PumpEventRow: View {
    let entry: PumpEventEntry
    let onDelete: () -> Void

    @State private var showDetail = false
    @State private var glucoseContext: [(Date, Double)] = []
    @State private var loadingGlucose = false

    var body: some View {
        VStack(spacing: 0) {
            Button { withAnimation { showDetail.toggle() } } label: {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(entry.eventType.color.opacity(0.15))
                            .frame(width: 36, height: 36)
                        Image(systemName: entry.eventType.icon)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(entry.eventType.color)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.eventType.rawValue)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                        if !entry.notes.isEmpty {
                            Text(entry.notes)
                                .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        }
                    }

                    Spacer()

                    Text(entry.date, format: .dateTime.hour().minute())
                        .font(.caption).foregroundStyle(.secondary)

                    Image(systemName: showDetail ? "chevron.up" : "chevron.down")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
            .buttonStyle(.plain)
            .contextMenu {
                Button(role: .destructive) { onDelete() } label: {
                    Label("Delete", systemImage: "trash")
                }
            }

            if showDetail {
                Divider().background(Color.cardBg2)
                pumpEventDetail
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .task { await loadGlucoseContext() }
            }
        }
    }

    // MARK: Detail / glucose context

    @ViewBuilder
    private var pumpEventDetail: some View {
        if loadingGlucose {
            HStack {
                Spacer()
                ProgressView().tint(.secondary)
                Spacer()
            }
            .frame(height: 80)
        } else if glucoseContext.isEmpty {
            Text("No glucose data around this event")
                .font(.caption).foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 16)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Text("Glucose context (±3 h)")
                    .font(.caption).foregroundStyle(.secondary)

                Chart {
                    ForEach(glucoseContext, id: \.0) { point in
                        LineMark(
                            x: .value("Time", point.0),
                            y: .value("mg/dL", point.1)
                        )
                        .foregroundStyle(Color(red: 0.31, green: 0.53, blue: 0.96))
                        .interpolationMethod(.catmullRom)

                        AreaMark(
                            x: .value("Time", point.0),
                            y: .value("mg/dL", point.1)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(red: 0.31, green: 0.53, blue: 0.96).opacity(0.25), .clear],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                        .interpolationMethod(.catmullRom)
                    }

                    RuleMark(x: .value("Event", entry.date))
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4]))
                        .foregroundStyle(entry.eventType.color.opacity(0.8))
                        .annotation(position: .top, alignment: .center) {
                            Image(systemName: entry.eventType.icon)
                                .font(.system(size: 9))
                                .foregroundStyle(entry.eventType.color)
                        }
                }
                .frame(height: 110)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .hour)) { _ in
                        AxisGridLine().foregroundStyle(Color.white.opacity(0.06))
                        AxisValueLabel(format: .dateTime.hour())
                            .foregroundStyle(Color.secondary)
                    }
                }
                .chartYAxis {
                    AxisMarks { _ in
                        AxisGridLine().foregroundStyle(Color.white.opacity(0.06))
                        AxisValueLabel().foregroundStyle(Color.secondary)
                    }
                }

                // Min / max stats
                let values = glucoseContext.map(\.1)
                if let lo = values.min(), let hi = values.max() {
                    HStack(spacing: 16) {
                        glucoseStat("Min", value: lo)
                        glucoseStat("Max", value: hi)
                        glucoseStat("Avg", value: values.reduce(0, +) / Double(values.count))
                    }
                }
            }
        }
    }

    private func glucoseStat(_ label: String, value: Double) -> some View {
        VStack(spacing: 2) {
            Text("\(Int(value.rounded()))")
                .font(.system(size: 13, weight: .bold)).foregroundStyle(.white)
            Text(label)
                .font(.system(size: 10)).foregroundStyle(.secondary)
        }
    }

    private func loadGlucoseContext() async {
        guard !loadingGlucose, glucoseContext.isEmpty else { return }
        loadingGlucose = true
        defer { loadingGlucose = false }
        guard let hk = HealthKitService.shared else { return }
        let windowBefore: TimeInterval = 3 * 3600
        let windowAfter:  TimeInterval = 3 * 3600
        let start = entry.date.addingTimeInterval(-windowBefore)
        let end   = entry.date.addingTimeInterval(windowAfter)
        glucoseContext = await hk.glucoseReadings(from: start, to: end)
    }
}

// MARK: - Log pump event sheet

struct LogPumpEventSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onSave: (PumpEventEntry) -> Void

    @State private var selectedType: PumpEventType = .cannulaChange
    @State private var date = Date()
    @State private var notes = ""

    var body: some View {
        NavigationStack {
            ZStack {
                Color.surfaceBg.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        typeSelector
                        dateSection
                        notesSection
                        saveButton
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Log Pump Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: Type selector

    private var typeSelector: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("EVENT TYPE")
                .font(.caption).fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)

            HStack(spacing: 10) {
                ForEach(PumpEventType.allCases, id: \.self) { type in
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) { selectedType = type }
                    } label: {
                        VStack(spacing: 8) {
                            ZStack {
                                Circle()
                                    .fill(selectedType == type ? type.color : Color.cardBg2)
                                    .frame(width: 48, height: 48)
                                Image(systemName: type.icon)
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(selectedType == type ? .white : .secondary)
                            }
                            Text(type.rawValue.components(separatedBy: " ").first ?? "")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(selectedType == type ? type.color : .secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            selectedType == type
                                ? type.color.opacity(0.12)
                                : Color.cardBg,
                            in: RoundedRectangle(cornerRadius: 12)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(
                                    selectedType == type ? type.color.opacity(0.5) : Color.clear,
                                    lineWidth: 1.5
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: Date

    private var dateSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("DATE & TIME")
                .font(.caption).fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)

            DatePicker("", selection: $date, in: ...Date(), displayedComponents: [.date, .hourAndMinute])
                .datePickerStyle(.compact)
                .labelsHidden()
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(Color.cardBg, in: RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: Notes

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("NOTES (OPTIONAL)")
                .font(.caption).fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)

            TextEditor(text: $notes)
                .frame(minHeight: 60, maxHeight: 90)
                .padding(10)
                .background(Color.cardBg, in: RoundedRectangle(cornerRadius: 12))
                .overlay(
                    Group {
                        if notes.isEmpty {
                            Text("Site location, insulin lot, issues…")
                                .foregroundStyle(.tertiary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 18)
                                .allowsHitTesting(false)
                        }
                    }, alignment: .topLeading
                )
        }
    }

    // MARK: Save

    private var saveButton: some View {
        Button {
            let entry = PumpEventEntry(date: date, eventType: selectedType, notes: notes.trimmingCharacters(in: .whitespacesAndNewlines))
            onSave(entry)
            dismiss()
        } label: {
            Text("Save Event")
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(selectedType.color, in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .padding(.top, 8)
    }
}
