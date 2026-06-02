import SwiftUI
import Charts

// MARK: - Dashboard

struct DashboardView: View {
    @EnvironmentObject var viewModel: SyncViewModel
    @State private var ringsAppeared = false
    @State private var dashTab: DashTab = .sleep

    enum DashTab: String, CaseIterable {
        case sleep     = "Sleep"
        case activity  = "Activity"
        case readiness = "Readiness"
        case stress    = "Stress"

        var icon: String {
            switch self {
            case .sleep:     return "moon.zzz.fill"
            case .activity:  return "figure.run"
            case .readiness: return "bolt.heart.fill"
            case .stress:    return "brain.head.profile"
            }
        }

        var color: Color {
            switch self {
            case .sleep:     return .ouraSleep
            case .activity:  return .ouraActivity
            case .readiness: return .ouraReadiness
            case .stress:    return Color(red: 0.85, green: 0.35, blue: 0.35)
            }
        }
    }

    var body: some View {
        ZStack {
            Color.surfaceBg.ignoresSafeArea()

            if viewModel.dailySummaries.isEmpty {
                EmptyDashboard()
            } else {
                VStack(spacing: 0) {
                    // Score rings header (always visible)
                    if let today = viewModel.dailySummaries.first {
                        scoreRingsCard(today)
                    }

                    // Sub-tab picker
                    tabPicker

                    // Tab content
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 20) {
                            if let today = viewModel.dailySummaries.first {
                                switch dashTab {
                                case .sleep:
                                    sleepCard(today)
                                    vitalsCard(today)
                                case .activity:
                                    activityCard(today)
                                case .readiness:
                                    readinessCard(today)
                                case .stress:
                                    stressTabContent(today)
                                }
                            }
                            recentDaysCard
                        }
                        .padding(.bottom, 40)
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { refreshButton }
        .task { await viewModel.loadDashboard() }
        .onAppear {
            ringsAppeared = false
            withAnimation(.easeOut(duration: 1.0).delay(0.15)) { ringsAppeared = true }
        }
    }

    // MARK: - Sub-tab picker

    private var tabPicker: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(DashTab.allCases, id: \.self) { tab in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { dashTab = tab }
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(dashTab == tab ? tab.color : Color.secondary)
                            Text(tab.rawValue)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(dashTab == tab ? tab.color : Color.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .overlay(alignment: .bottom) {
                            if dashTab == tab {
                                Capsule().fill(tab.color).frame(height: 2)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal)
            .background(Color.cardBg)
            Divider().background(Color.cardBg2)
        }
    }

    // MARK: - Score rings (always shown at top)

    private func scoreRingsCard(_ today: OuraDailySummary) -> some View {
        ZStack {
            // Subtle multi-colour ambient glow
            HStack(spacing: 0) {
                Color.heroReadiness.opacity(0.35)
                Color.heroSleep.opacity(0.50)
                Color.heroActivity.opacity(0.35)
            }
            .blur(radius: 28)
            .padding(.horizontal, -20)

            HStack(alignment: .center, spacing: 0) {
                ScoreRing(score: today.readinessScore, color: .ouraReadiness,
                          label: "Readiness", icon: "bolt.heart.fill", size: 88, appeared: ringsAppeared)
                Spacer()
                ScoreRing(score: today.sleepScore, color: .ouraSleep,
                          label: "Sleep", icon: "moon.zzz.fill", size: 110, appeared: ringsAppeared)
                Spacer()
                ScoreRing(score: today.activityScore, color: .ouraActivity,
                          label: "Activity", icon: "figure.run", size: 88, appeared: ringsAppeared)
            }
            .padding(.horizontal, 28).padding(.vertical, 22)
        }
        .background(
            LinearGradient(
                colors: [Color.cardBg, Color(red: 0.06, green: 0.07, blue: 0.10)],
                startPoint: .top, endPoint: .bottom
            )
        )
    }

    // MARK: - Stress tab (stress card + no-data state)

    @ViewBuilder
    private func stressTabContent(_ today: OuraDailySummary) -> some View {
        if today.stressSummary != nil || today.stressHighMinutes != nil {
            stressCard(today)
        } else {
            VStack(spacing: 16) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 40)).foregroundStyle(.secondary)
                Text("No Stress Data")
                    .font(.headline)
                Text("Stress data requires an Oura Ring plan that includes stress monitoring.")
                    .font(.subheadline).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center).padding(.horizontal, 32)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
        }
    }

    // MARK: - Sleep card

    private func sleepCard(_ today: OuraDailySummary) -> some View {
        OuraCard(title: "Sleep", icon: "moon.zzz.fill", color: .ouraSleep) {
            VStack(spacing: 18) {
                // Total duration
                if let total = today.totalSleepMinutes {
                    HStack(alignment: .lastTextBaseline, spacing: 2) {
                        let h = total / 60, m = total % 60
                        if h > 0 {
                            Text("\(h)").font(.system(size: 38, weight: .bold, design: .rounded)).foregroundStyle(Color.ouraSleep)
                            Text("h ").font(.subheadline).foregroundStyle(.secondary)
                        }
                        Text("\(m)").font(.system(size: 38, weight: .bold, design: .rounded)).foregroundStyle(Color.ouraSleep)
                        Text("m").font(.subheadline).foregroundStyle(.secondary)
                        Spacer()
                    }
                }

                // Phases bar
                let deep = today.deepSleepMinutes ?? 0
                let rem  = today.remSleepMinutes  ?? 0
                let lite = today.lightSleepMinutes ?? 0
                if deep + rem + lite > 0 {
                    SleepPhasesBar(deep: deep, rem: rem, light: lite)
                }

                // Contributors
                if let c = today.sleepContributors {
                    Divider().background(Color.cardBg2)
                    contributorsSection(title: "CONTRIBUTORS") {
                        SleepContributorBar(label: "Total Sleep",  value: c.totalSleep)
                        SleepContributorBar(label: "Efficiency",   value: c.efficiency)
                        SleepContributorBar(label: "REM Sleep",    value: c.remSleep)
                        SleepContributorBar(label: "Deep Sleep",   value: c.deepSleep)
                        SleepContributorBar(label: "Restfulness",  value: c.restfulness)
                        SleepContributorBar(label: "Latency",      value: c.latency)
                        SleepContributorBar(label: "Timing",       value: c.timing)
                    }
                }

                // HRV + Lowest HR
                if today.averageHrv != nil || today.lowestHR != nil {
                    Divider().background(Color.cardBg2)
                    HStack(spacing: 0) {
                        if let hrv = today.averageHrv {
                            OuraMetricCell(icon: "waveform.path.ecg", color: .ouraSleep,
                                           label: "Avg HRV", value: "\(hrv)", unit: "ms")
                        }
                        if today.averageHrv != nil && today.lowestHR != nil {
                            Divider().frame(height: 44).background(Color.cardBg2)
                        }
                        if let hr = today.lowestHR {
                            OuraMetricCell(icon: "heart.fill", color: Color(red: 0.9, green: 0.3, blue: 0.35),
                                           label: "Lowest HR", value: "\(hr)", unit: "bpm")
                        }
                    }
                }
            }
        }
    }

    // MARK: - Readiness card

    private func readinessCard(_ today: OuraDailySummary) -> some View {
        OuraCard(title: "Readiness", icon: "bolt.heart.fill", color: .ouraReadiness) {
            VStack(spacing: 18) {
                // Temp deviation
                if let temp = today.temperatureDeviation {
                    HStack(alignment: .lastTextBaseline, spacing: 4) {
                        let sign = temp >= 0 ? "+" : ""
                        Text("\(sign)\(String(format: "%.2f", temp))")
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .foregroundStyle(abs(temp) > 1 ? Color(red: 0.9, green: 0.4, blue: 0.3) : .ouraReadiness)
                        Text("°C deviation").font(.subheadline).foregroundStyle(.secondary)
                        Spacer()
                    }
                }

                // Contributors
                if let c = today.readinessContributors {
                    contributorsSection(title: "CONTRIBUTORS") {
                        SleepContributorBar(label: "HRV Balance",       value: c.hrvBalance)
                        SleepContributorBar(label: "Resting HR",        value: c.restingHeartRate)
                        SleepContributorBar(label: "Recovery Index",    value: c.recoveryIndex)
                        SleepContributorBar(label: "Sleep Balance",     value: c.sleepBalance)
                        SleepContributorBar(label: "Previous Night",    value: c.previousNight)
                        SleepContributorBar(label: "Activity Balance",  value: c.activityBalance)
                        SleepContributorBar(label: "Body Temperature",  value: c.bodyTemperature)
                    }
                }
            }
        }
    }

    // MARK: - Activity card

    private func activityCard(_ today: OuraDailySummary) -> some View {
        OuraCard(title: "Activity", icon: "figure.run", color: .ouraActivity) {
            VStack(spacing: 18) {
                // Steps hero
                if let steps = today.steps {
                    HStack(alignment: .lastTextBaseline, spacing: 4) {
                        Text(steps >= 1000 ? String(format: "%.1fk", Double(steps)/1000) : "\(steps)")
                            .font(.system(size: 38, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.ouraActivity)
                        Text("steps").font(.subheadline).foregroundStyle(.secondary)
                        Spacer()
                        if let km = today.equivalentWalkingKm {
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(String(format: "%.1f km", km))
                                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                                Text("equivalent")
                                    .font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                // Activity intensity breakdown
                let high = today.highActivityMinutes   ?? 0
                let med  = today.mediumActivityMinutes ?? 0
                let low  = today.lowActivityMinutes    ?? 0
                let sed  = today.sedentaryMinutes      ?? 0
                let rest = today.restMinutes           ?? 0
                if high + med + low + sed + rest > 0 {
                    ActivityIntensityBar(high: high, medium: med, low: low, sedentary: sed, rest: rest)
                }

                // Calories row
                if today.activeCalories != nil || today.totalCalories != nil {
                    Divider().background(Color.cardBg2)
                    HStack(spacing: 0) {
                        if let act = today.activeCalories {
                            OuraMetricCell(icon: "flame.fill", color: .ouraReadiness,
                                           label: "Active Cal", value: "\(act)", unit: "kcal")
                        }
                        if today.activeCalories != nil && today.totalCalories != nil {
                            Divider().frame(height: 44).background(Color.cardBg2)
                        }
                        if let tot = today.totalCalories {
                            OuraMetricCell(icon: "fork.knife", color: .ouraActivity,
                                           label: "Total Cal", value: "\(tot)", unit: "kcal")
                        }
                    }
                }

                // MET
                if let met = today.averageMet {
                    Divider().background(Color.cardBg2)
                    OuraMetricCell(icon: "bolt.fill", color: .yellow,
                                   label: "Avg MET", value: String(format: "%.1f", met), unit: "")
                }

                // Contributors
                if let c = today.activityContributors {
                    Divider().background(Color.cardBg2)
                    contributorsSection(title: "CONTRIBUTORS") {
                        SleepContributorBar(label: "Meet Daily Targets", value: c.meetDailyTargets)
                        SleepContributorBar(label: "Move Every Hour",    value: c.moveEveryHour)
                        SleepContributorBar(label: "Stay Active",        value: c.stayActive)
                        SleepContributorBar(label: "Recovery Time",      value: c.recoveryTime)
                        SleepContributorBar(label: "Training Frequency", value: c.trainingFrequency)
                        SleepContributorBar(label: "Training Volume",    value: c.trainingVolume)
                    }
                }
            }
        }
    }

    // MARK: - Stress card

    private func stressCard(_ today: OuraDailySummary) -> some View {
        let stressColor = Color(red: 0.85, green: 0.35, blue: 0.35)
        let recovColor  = Color(red: 0.30, green: 0.75, blue: 0.55)

        return OuraCard(title: "Stress", icon: "brain.head.profile", color: stressColor) {
            VStack(spacing: 16) {
                // Day summary badge
                if let summary = today.stressSummary {
                    HStack {
                        Text(summary.capitalized)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(summaryColor(summary))
                        Spacer()
                        Image(systemName: summaryIcon(summary))
                            .font(.title2)
                            .foregroundStyle(summaryColor(summary))
                    }
                }

                // Stress vs recovery time bar
                let stressMin = today.stressHighMinutes ?? 0
                let recovMin  = today.recoveryHighMinutes ?? 0
                let total     = max(stressMin + recovMin, 1)

                if stressMin + recovMin > 0 {
                    VStack(alignment: .leading, spacing: 8) {
                        GeometryReader { geo in
                            HStack(spacing: 3) {
                                if stressMin > 0 {
                                    Capsule().fill(stressColor)
                                        .frame(width: geo.size.width * CGFloat(stressMin) / CGFloat(total))
                                }
                                if recovMin > 0 {
                                    Capsule().fill(recovColor)
                                        .frame(width: geo.size.width * CGFloat(recovMin) / CGFloat(total))
                                }
                            }
                        }
                        .frame(height: 10)

                        HStack {
                            HStack(spacing: 5) {
                                RoundedRectangle(cornerRadius: 2).fill(stressColor).frame(width: 10, height: 10)
                                Text("Stress \(formatMinutes(stressMin))")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            HStack(spacing: 5) {
                                RoundedRectangle(cornerRadius: 2).fill(recovColor).frame(width: 10, height: 10)
                                Text("Recovery \(formatMinutes(recovMin))")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
    }

    private func summaryColor(_ s: String) -> Color {
        switch s.lowercased() {
        case "restored":  return Color(red: 0.30, green: 0.75, blue: 0.55)
        case "normal":    return .ouraReadiness
        case "stressful": return Color(red: 0.85, green: 0.35, blue: 0.35)
        case "demanding": return .ouraReadiness.opacity(0.8)
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

    // MARK: - Vitals card

    @ViewBuilder
    private func vitalsCard(_ today: OuraDailySummary) -> some View {
        let hasAny = today.averageSpO2 != nil || today.respiratoryRate != nil || today.temperatureDeviation != nil
        if hasAny {
            OuraCard(title: "Vitals", icon: "waveform.path.ecg.rectangle.fill", color: .ouraSleep) {
                HStack(spacing: 0) {
                    if let spo2 = today.averageSpO2 {
                        OuraMetricCell(icon: "lungs.fill", color: .cyan,
                                       label: "SpO₂", value: String(format: "%.1f", spo2), unit: "%")
                    }
                    if today.averageSpO2 != nil && today.respiratoryRate != nil {
                        Divider().frame(height: 44).background(Color.cardBg2)
                    }
                    if let rr = today.respiratoryRate {
                        OuraMetricCell(icon: "wind", color: .teal,
                                       label: "Resp Rate", value: String(format: "%.1f", rr), unit: "/min")
                    }
                }
            }
        }
    }

    // MARK: - Recent days card

    private var recentDaysCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("RECENT DAYS")
                    .font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary).tracking(2)
                Spacer()
            }
            .padding(.horizontal).padding(.bottom, 10)

            VStack(spacing: 0) {
                HStack {
                    Text("Day").frame(maxWidth: .infinity, alignment: .leading)
                    Text("RDY").foregroundStyle(Color.ouraReadiness)
                    Text("SLP").foregroundStyle(Color.ouraSleep).padding(.horizontal, 16)
                    Text("ACT").foregroundStyle(Color.ouraActivity)
                }
                .font(.system(size: 10, weight: .semibold)).tracking(1.5)
                .padding(.horizontal, 20).padding(.vertical, 8)

                Divider().background(Color.cardBg2)

                ForEach(viewModel.dailySummaries.prefix(14), id: \.day) { summary in
                    DayRow(summary: summary)
                }
            }
            .background(Color.cardBg, in: RoundedRectangle(cornerRadius: 20))
            .padding(.horizontal)
        }
    }

    private var refreshButton: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Button { Task { await viewModel.loadDashboard() } } label: {
                Image(systemName: "arrow.clockwise").font(.system(size: 14, weight: .semibold))
            }
            .disabled(viewModel.isSyncing)
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func contributorsSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary).tracking(1.5)
            content()
        }
    }

    private func formatMinutes(_ m: Int) -> String {
        m >= 60 ? "\(m/60)h \(m%60)m" : "\(m)m"
    }
}

// MARK: - Score ring

struct ScoreRing: View {
    let score: Int?
    let color: Color
    let label: String
    let icon: String
    var size: CGFloat = 100
    var appeared: Bool = true

    private var lineWidth: CGFloat { size * 0.105 }
    private var progress: Double {
        guard let s = score, s > 0 else { return 0 }
        return min(Double(s) / 100.0, 1.0)
    }

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle().stroke(color.opacity(0.13), lineWidth: lineWidth)
                Circle()
                    .trim(from: 0, to: appeared ? CGFloat(progress) : 0)
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(colors: [color.opacity(0.65), color]),
                            center: .center,
                            startAngle: .degrees(-90),
                            endAngle: .degrees(Double(progress) * 360 - 90)
                        ),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .shadow(color: color.opacity(0.4), radius: 6)
                if let s = score {
                    Text("\(s)")
                        .font(.system(size: size * 0.275, weight: .bold, design: .rounded))
                        .foregroundStyle(color)
                } else {
                    Text("--")
                        .font(.system(size: size * 0.26, weight: .bold, design: .rounded))
                        .foregroundStyle(.quaternary)
                }
            }
            .frame(width: size, height: size)

            VStack(spacing: 3) {
                Image(systemName: icon).font(.system(size: 11)).foregroundStyle(color)
                Text(label).font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Oura card shell

struct OuraCard<Content: View>: View {
    let title: String
    let icon: String
    let color: Color
    @ViewBuilder let content: Content

    init(title: String, icon: String, color: Color, @ViewBuilder content: () -> Content) {
        self.title = title; self.icon = icon; self.color = color; self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 12, weight: .semibold)).foregroundStyle(color)
                Text(title.uppercased())
                    .font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary).tracking(1.5)
            }
            content
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.cardBg, in: RoundedRectangle(cornerRadius: 20))
        .padding(.horizontal)
    }
}

// MARK: - Metric cell

struct OuraMetricCell: View {
    let icon: String
    let color: Color
    let label: String
    let value: String
    let unit: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 10, weight: .semibold)).foregroundStyle(color)
                Text(label).font(.system(size: 11)).foregroundStyle(.secondary)
            }
            HStack(alignment: .lastTextBaseline, spacing: 3) {
                Text(value).font(.system(size: 26, weight: .bold, design: .rounded))
                if !unit.isEmpty {
                    Text(unit).font(.system(size: 12)).foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
    }
}

// MARK: - Activity intensity bar

struct ActivityIntensityBar: View {
    let high: Int
    let medium: Int
    let low: Int
    let sedentary: Int
    let rest: Int

    private var total: Int { max(high + medium + low + sedentary + rest, 1) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Stacked bar
            GeometryReader { geo in
                HStack(spacing: 2) {
                    if high > 0 {
                        Capsule().fill(Color.ouraActivity)
                            .frame(width: geo.size.width * CGFloat(high) / CGFloat(total))
                    }
                    if medium > 0 {
                        Capsule().fill(Color.ouraActivity.opacity(0.6))
                            .frame(width: geo.size.width * CGFloat(medium) / CGFloat(total))
                    }
                    if low > 0 {
                        Capsule().fill(Color.ouraActivity.opacity(0.3))
                            .frame(width: geo.size.width * CGFloat(low) / CGFloat(total))
                    }
                    if sedentary > 0 {
                        Capsule().fill(Color.cardBg2)
                            .frame(width: geo.size.width * CGFloat(sedentary) / CGFloat(total))
                    }
                    if rest > 0 {
                        Capsule().fill(Color.cardBg2.opacity(0.5))
                            .frame(width: geo.size.width * CGFloat(rest) / CGFloat(total))
                    }
                }
            }
            .frame(height: 10)

            // Labels grid
            VStack(spacing: 6) {
                if high > 0 {
                    ActivityIntensityRow(color: Color.ouraActivity,         label: "High Activity",  minutes: high)
                }
                if medium > 0 {
                    ActivityIntensityRow(color: Color.ouraActivity.opacity(0.6), label: "Medium Activity", minutes: medium)
                }
                if low > 0 {
                    ActivityIntensityRow(color: Color.ouraActivity.opacity(0.3), label: "Low Activity",    minutes: low)
                }
                if sedentary > 0 {
                    ActivityIntensityRow(color: Color.cardBg2,              label: "Sedentary",      minutes: sedentary)
                }
                if rest > 0 {
                    ActivityIntensityRow(color: Color.cardBg2.opacity(0.6), label: "Rest",           minutes: rest)
                }
            }
        }
    }
}

struct ActivityIntensityRow: View {
    let color: Color
    let label: String
    let minutes: Int

    private func fmt(_ m: Int) -> String { m >= 60 ? "\(m/60)h \(m%60)m" : "\(m)m" }

    var body: some View {
        HStack {
            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 10, height: 10)
                Text(label).font(.system(size: 12)).foregroundStyle(.secondary)
            }
            Spacer()
            Text(fmt(minutes))
                .font(.system(size: 12, weight: .semibold, design: .rounded))
        }
    }
}

// MARK: - Sleep contributor bar

struct SleepContributorBar: View {
    let label: String
    let value: Int?
    var accentColor: Color = .ouraSleep

    private var score: Double { Double(value ?? 0) }
    private var barColor: Color {
        guard let v = value else { return .secondary }
        if v >= 80 { return accentColor }
        if v >= 60 { return Color.ouraReadiness }
        return Color(red: 0.85, green: 0.3, blue: 0.3)
    }
    private var status: String {
        guard let v = value else { return "" }
        if v >= 85 { return "Optimal" }
        if v >= 70 { return "Good" }
        if v >= 60 { return "Fair" }
        return "Low"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white)
                Spacer()
                HStack(spacing: 5) {
                    if !status.isEmpty {
                        Text(status)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(barColor)
                    }
                    Text(value.map { "\($0)" } ?? "--")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(barColor)
                        .frame(minWidth: 26, alignment: .trailing)
                }
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.cardBg2).frame(height: 5)
                    Capsule().fill(
                        LinearGradient(
                            colors: [barColor.opacity(0.7), barColor],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geo.size.width * CGFloat(score / 100.0), height: 5)
                }
                .frame(maxHeight: .infinity, alignment: .center)
            }
            .frame(height: 10)
        }
    }
}

// MARK: - Sleep phases bar

struct SleepPhasesBar: View {
    let deep: Int
    let rem: Int
    let light: Int

    private var total: Int { max(deep + rem + light, 1) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            GeometryReader { geo in
                HStack(spacing: 3) {
                    Capsule().fill(Color.ouraSleep)
                        .frame(width: geo.size.width * CGFloat(deep) / CGFloat(total))
                    Capsule().fill(Color.ouraSleep.opacity(0.55))
                        .frame(width: geo.size.width * CGFloat(rem) / CGFloat(total))
                    Capsule().fill(Color.ouraSleep.opacity(0.25))
                        .frame(width: geo.size.width * CGFloat(light) / CGFloat(total))
                }
            }
            .frame(height: 10)

            HStack {
                PhasePill(color: Color.ouraSleep,          label: "Deep",  minutes: deep)
                Spacer()
                PhasePill(color: Color.ouraSleep.opacity(0.55), label: "REM",   minutes: rem)
                Spacer()
                PhasePill(color: Color.ouraSleep.opacity(0.3),  label: "Light", minutes: light)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    let t = deep + rem + light
                    Text(t >= 60 ? "\(t/60)h \(t%60)m" : "\(t)m")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                    Text("Total").font(.system(size: 10)).foregroundStyle(.secondary)
                }
            }
        }
    }
}

struct PhasePill: View {
    let color: Color
    let label: String
    let minutes: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 5) {
                RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 10, height: 10)
                Text(label).font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Text(minutes >= 60 ? "\(minutes/60)h \(minutes%60)m" : "\(minutes)m")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
        }
    }
}

// MARK: - Recent day row

struct DayRow: View {
    let summary: OuraDailySummary

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(formattedDay)
                    .font(.system(size: 14)).frame(maxWidth: .infinity, alignment: .leading)
                ScorePill(value: summary.readinessScore, color: .ouraReadiness)
                ScorePill(value: summary.sleepScore,     color: .ouraSleep).padding(.horizontal, 16)
                ScorePill(value: summary.activityScore,  color: .ouraActivity)
            }
            .padding(.horizontal, 20).padding(.vertical, 13)
            Divider().background(Color.cardBg2).padding(.leading, 20)
        }
    }

    private var formattedDay: String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        guard let date = f.date(from: summary.day) else { return summary.day }
        f.dateFormat = "EEE, d MMM"; return f.string(from: date)
    }
}

struct ScorePill: View {
    let value: Int?
    let color: Color

    private var fg: Color {
        guard let v = value else { return Color(white: 0.35) }
        if v >= 85 { return color }
        if v >= 70 { return color.opacity(0.75) }
        return .red
    }

    var body: some View {
        Text(value.map { "\($0)" } ?? "--")
            .font(.system(size: 14, weight: .bold, design: .rounded))
            .foregroundStyle(fg).frame(width: 36)
    }
}

// MARK: - Empty state

// MARK: - Range bar (like Oura Vitals: shows 7-day low/high + current position)

struct RangeBar: View {
    let current: Int?
    let values: [Int]           // historical values (up to 14 days)
    let color: Color

    private var lo: Int { values.min() ?? 0 }
    private var hi: Int { values.max() ?? 100 }
    private var range: Double { Double(max(hi - lo, 1)) }
    private var position: Double {
        guard let c = current else { return 0 }
        return Double(c - lo) / range
    }

    var body: some View {
        VStack(spacing: 6) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Track
                    Capsule()
                        .fill(Color.white.opacity(0.10))
                        .frame(height: 4)
                    // Fill to current
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [color.opacity(0.4), color],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * CGFloat(min(max(position, 0), 1)), height: 4)
                    // Current dot
                    Circle()
                        .fill(color)
                        .frame(width: 12, height: 12)
                        .shadow(color: color.opacity(0.6), radius: 4)
                        .offset(x: geo.size.width * CGFloat(min(max(position, 0), 1)) - 6)
                }
                .frame(maxHeight: .infinity, alignment: .center)
            }
            .frame(height: 14)

            HStack {
                Text("\(lo)")
                    .font(.system(size: 10)).foregroundStyle(.secondary)
                Spacer()
                Text("\(hi)")
                    .font(.system(size: 10)).foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Score history bars (compact bar chart, last N days)

struct ScoreHistoryBarsView: View {
    let summaries: [OuraDailySummary]
    let keyPath: KeyPath<OuraDailySummary, Int?>
    let color: Color
    var maxBars: Int = 10

    private var values: [(String, Int?)] {
        Array(summaries.prefix(maxBars).reversed()).map { ($0.day, $0[keyPath: keyPath]) }
    }
    private var maxVal: Int { values.compactMap(\.1).max() ?? 100 }

    var body: some View {
        HStack(alignment: .bottom, spacing: 5) {
            ForEach(values, id: \.0) { day, score in
                let isToday = day == values.last?.0
                VStack(spacing: 4) {
                    if let s = score {
                        Text("\(s)")
                            .font(.system(size: 9, weight: isToday ? .bold : .regular))
                            .foregroundStyle(isToday ? color : Color(white: 0.45))
                    }
                    RoundedRectangle(cornerRadius: 3)
                        .fill(isToday ? color : color.opacity(0.35))
                        .frame(
                            height: score.map { CGFloat($0) / CGFloat(max(maxVal, 1)) * 52 } ?? 6
                        )
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 72)
    }
}

// MARK: - Oura-style vitals metric card

struct OuraVitalsMetricCard: View {
    let icon: String
    let label: String
    let color: Color
    let heroBg: Color
    let score: Int?
    let summaries: [OuraDailySummary]
    let keyPath: KeyPath<OuraDailySummary, Int?>
    var onTap: () -> Void = {}

    private var historicValues: [Int] { Array(summaries.prefix(7).compactMap { $0[keyPath: keyPath] }) }
    private var quality: (label: String, color: Color) { scoreQuality(score) }
    private var ringFraction: Double { Double(min(score ?? 0, 100)) / 100.0 }

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

                    // Label + score + badge — left column
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: icon)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(color)
                            Text(label.uppercased())
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(color.opacity(0.75))
                                .tracking(1.5)
                        }

                        Text(score.map { "\($0)" } ?? "–")
                            .font(.system(size: 76, weight: .thin, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(1)

                        Text(quality.label)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(quality.color)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(quality.color.opacity(0.18), in: Capsule())
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(22)
                    .padding(.trailing, 112) // clear ring
                }
                .frame(height: 162)

                // ── Mini sparkline ─────────────────────────────────────
                if !historicValues.isEmpty {
                    miniSparkline
                        .padding(.horizontal, 18)
                        .padding(.vertical, 14)
                        .background(Color(white: 0.068))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 20))
        }
        .buttonStyle(.plain)
    }

    private var miniSparkline: some View {
        let maxV  = Double(historicValues.max() ?? 100)
        let minV  = Double(historicValues.min() ?? 0)
        let span  = max(maxV - minV, 1)
        let maxH: CGFloat = 36
        let minH: CGFloat = 6
        // oldest left, newest rightmost
        let vals  = Array(historicValues.reversed())

        return HStack(alignment: .bottom, spacing: 5) {
            ForEach(Array(vals.enumerated()), id: \.offset) { i, val in
                let isLatest = i == vals.count - 1
                let frac     = CGFloat((Double(val) - minV) / span)
                let barH     = minH + frac * (maxH - minH)
                VStack(spacing: 3) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(isLatest ? color : Color(white: 0.20))
                        .frame(height: barH)
                    Text("\(val)")
                        .font(.system(size: 9, weight: isLatest ? .semibold : .regular, design: .rounded))
                        .foregroundStyle(isLatest ? .white : Color(white: 0.38))
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: maxH + 16)
    }
}

// MARK: - Oura-exact contributor row (label left, status/value right, full-width bar below)

struct OuraContributorRow: View {
    let label: String
    let score: Int?
    var valueOverride: String? = nil   // e.g. "60 bpm" instead of derived text
    var accentColor: Color = .ouraSleep
    var showDivider: Bool = true

    private var statusText: String {
        guard let v = score else { return "–" }
        if v >= 85 { return "Optimal" }
        if v >= 70 { return "Good" }
        if v >= 55 { return "Fair" }
        return "Low"
    }
    private var barColor: Color {
        guard let v = score else { return .secondary }
        if v >= 70 { return accentColor }
        if v >= 55 { return Color.ouraReadiness }
        return Color(red: 0.85, green: 0.3, blue: 0.3)
    }
    private var fraction: Double { Double(score ?? 0) / 100.0 }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(label)
                    .font(.system(size: 15))
                    .foregroundStyle(.white)
                Spacer()
                HStack(spacing: 4) {
                    Text(valueOverride ?? statusText)
                        .font(.system(size: 14))
                        .foregroundStyle(barColor)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color(white: 0.30))
                }
            }
            .padding(.vertical, 14)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.10)).frame(height: 2)
                    Capsule().fill(barColor)
                        .frame(width: geo.size.width * CGFloat(min(max(fraction, 0), 1)), height: 2)
                }
                .frame(maxHeight: .infinity, alignment: .center)
            }
            .frame(height: 3)

            if showDivider {
                Divider().background(Color.white.opacity(0.07)).padding(.top, 1)
            }
        }
    }
}

// MARK: - Sleep vitals line chart (HR / HRV during sleep)

struct SleepVitalsChart: View {
    let readings: [(Date, Double)]
    let color: Color
    let unit: String
    var showAvgLine: Bool = true
    var domainPadding: Double = 10

    private var avg: Double {
        guard !readings.isEmpty else { return 0 }
        return readings.map(\.1).reduce(0, +) / Double(readings.count)
    }
    private var minV: Double { (readings.map(\.1).min() ?? 0) - domainPadding }
    private var maxV: Double { (readings.map(\.1).max() ?? 100) + domainPadding }
    private var startDate: Date { readings.first?.0 ?? Date() }
    private var endDate:   Date { readings.last?.0 ?? Date() }

    var body: some View {
        Chart {
            if showAvgLine {
                RuleMark(y: .value("Avg", avg))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 4]))
                    .foregroundStyle(Color.white.opacity(0.30))
                    .annotation(position: .leading, alignment: .center) {
                        Text("\(Int(avg.rounded()))")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color(white: 0.55))
                    }
            }
            ForEach(readings, id: \.0) { pt in
                LineMark(x: .value("Time", pt.0), y: .value(unit, pt.1))
                    .foregroundStyle(Color.white)
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 1.5))
            }
            // Dot at last point
            if let last = readings.last {
                PointMark(x: .value("Time", last.0), y: .value(unit, last.1))
                    .foregroundStyle(Color.white)
                    .symbolSize(30)
            }
        }
        .chartYScale(domain: minV...maxV)
        .chartXScale(domain: startDate...endDate)
        .chartXAxis {
            AxisMarks(values: .stride(by: .hour, count: 2)) { _ in
                AxisGridLine().foregroundStyle(Color.white.opacity(0.06))
                AxisValueLabel(format: .dateTime.hour(.defaultDigits(amPM: .omitted)))
                    .foregroundStyle(Color.secondary).font(.system(size: 9))
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing, values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine().foregroundStyle(Color.white.opacity(0.06))
                AxisValueLabel().foregroundStyle(Color.secondary).font(.system(size: 9))
            }
        }
    }
}

// MARK: - Sleep phase row (Oura-style: label + bar + duration + %)

struct SleepPhaseRow: View {
    let label: String
    let color: Color
    let minutes: Int
    let totalMinutes: Int

    private var fraction: Double { Double(minutes) / Double(max(totalMinutes, 1)) }
    private var pct: Int { Int((fraction * 100).rounded()) }
    private var durationStr: String { minutes >= 60 ? "\(minutes/60)h \(minutes%60)m" : "\(minutes)m" }

    var body: some View {
        HStack(spacing: 12) {
            // Color dot
            Circle().fill(color).frame(width: 8, height: 8)

            Text(label)
                .font(.system(size: 14))
                .foregroundStyle(.white)
                .frame(width: 44, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.08)).frame(height: 6)
                    Capsule().fill(color)
                        .frame(width: geo.size.width * CGFloat(fraction), height: 6)
                }
                .frame(maxHeight: .infinity, alignment: .center)
            }
            .frame(height: 20)

            HStack(spacing: 6) {
                Text(durationStr)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white)
                Text("\(pct)%")
                    .font(.system(size: 12))
                    .foregroundStyle(Color(white: 0.50))
            }
            .frame(width: 84, alignment: .trailing)
        }
    }
}

struct EmptyDashboard: View {
    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle().stroke(Color.ouraSleep.opacity(0.12), lineWidth: 14).frame(width: 110, height: 110)
                Image(systemName: "moon.zzz.fill").font(.system(size: 36)).foregroundStyle(.secondary)
            }
            Text("No Data Yet").font(.title3).bold()
            Text("Sync your Oura Ring from the Home tab to see your dashboard.")
                .font(.subheadline).foregroundStyle(.secondary)
                .multilineTextAlignment(.center).padding(.horizontal, 48)
        }
    }
}
