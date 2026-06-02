import Foundation
import SwiftUI
import UIKit

// MARK: - Identifiable point types for charts

struct ChartGlucosePoint: Identifiable {
    let id  = UUID()
    let date: Date
    let value: Double   // mg/dL
}

struct InsulinDose: Identifiable {
    let id  = UUID()
    let date: Date
    let units: Double
}

@MainActor
class SyncViewModel: ObservableObject {
    @Published var isSyncing = false
    @Published var lastSyncDate: Date?
    @Published var syncResult: SyncResult?
    @Published var errorMessage: String?
    @Published var isConfigured = false
    
    @Published var nightscoutURL: String = ""
    @Published var nightscoutSecret: String = ""
    @Published var selectedGlucoseUnit: GlucoseUnit = .mgdl
    @Published var autoSyncEnabled: Bool = false
    @Published var syncCarbs: Bool = true
    @Published var syncInsulin: Bool = true
    @Published var syncGlucose: Bool = true
    @Published var backgroundSyncInterval: Int = 15
    @Published var lookbackDays: Int = 30
    @Published var syncLogs: [SyncLog] = []

    // Oura
    @Published var dailySummaries: [OuraDailySummary] = []
    @Published var glucoseByDay: [String: Double] = [:]
    @Published var insulinByDay: [String: Double] = [:]
    @Published var tirByDay: [String: Double] = [:]

    // Today's detailed readings (for Home chart)
    @Published var todayGlucoseReadings: [ChartGlucosePoint] = []
    @Published var todayInsulinDoses: [InsulinDose]     = []

    // Glucose during last night's sleep window (for Sleep tab)
    @Published var sleepGlucoseReadings: [ChartGlucosePoint] = []

    // Nocturnal (sleep-window) glucose stats per night — keyed by OuraDailySummary.day
    @Published var nocturnalTIRByDay:     [String: Double] = [:]
    @Published var nocturnalAvgByDay:     [String: Double] = [:]
    @Published var nocturnalStdDevByDay:  [String: Double] = [:]
    @Published var nocturnalHypoByDay:    [String: Int]    = [:]   // readings < tirLow

    // Time in Range settings
    @Published var tirLow:  Int = 70
    @Published var tirHigh: Int = 200

    // Workout log
    @Published var workoutLogs: [WorkoutEntry] = []

    // Pump event log
    @Published var pumpEventLogs: [PumpEventEntry] = []

    // Oura workouts
    @Published var ouraWorkouts: [OuraWorkoutEntry] = []

    // Journal
    @Published var journalEntries: [JournalDayEntry] = []
    @Published var hiddenJournalItems: Set<String>   = []
    @Published var customJournalItems: [CustomJournalItem] = []

    // Oura export import
    @Published var isImportingExport    = false
    @Published var importResult: OuraExportResult?
    @Published var importError: String?

    // Food log
    @Published var foodEntries: [FoodEntry] = []
    @Published var kiloAPIKey: String = ""
    @Published var kiloModel: String  = "anthropic/claude-sonnet-4-6"

    private let settings = UserSettings.shared
    var appDelegate: AppDelegate?
    
    init() {
        Task {
            await loadSettings()
        }
    }
    
    func loadSettings() async {
        nightscoutURL = await settings.nightscoutURL ?? ""
        nightscoutSecret = await settings.nightscoutAPISecret ?? ""
        selectedGlucoseUnit = await settings.glucoseUnit
        autoSyncEnabled = await settings.autoSyncEnabled
        syncCarbs = await settings.syncCarbs
        syncInsulin = await settings.syncInsulin
        syncGlucose = await settings.syncGlucose
        backgroundSyncInterval = await settings.backgroundSyncInterval
        lookbackDays = await settings.lookbackDays
        lastSyncDate = await settings.lastSyncDate
        syncLogs = await settings.syncLogs.reversed()
        isConfigured = nightscoutURL.isEmpty == false && nightscoutSecret.isEmpty == false
        tirLow  = await settings.tirLow
        tirHigh = await settings.tirHigh
        workoutLogs = await settings.workoutLogs
        pumpEventLogs = await settings.pumpEventLogs
        journalEntries = await settings.journalEntries
        hiddenJournalItems  = await settings.hiddenJournalItems
        customJournalItems  = await settings.customJournalItems
        foodEntries = await settings.foodEntries
        kiloAPIKey  = await settings.kiloAPIKey
        kiloModel   = await settings.kiloModel
    }

    func saveSettings() async {
        await settings.setNightscoutURL(nightscoutURL)
        await settings.setNightscoutAPISecret(nightscoutSecret)
        await settings.setGlucoseUnit(selectedGlucoseUnit)
        await settings.setAutoSyncEnabled(autoSyncEnabled)
        await settings.setSyncCarbs(syncCarbs)
        await settings.setSyncInsulin(syncInsulin)
        await settings.setSyncGlucose(syncGlucose)
        await settings.setBackgroundSyncInterval(backgroundSyncInterval)
        await settings.setLookbackDays(lookbackDays)
        await settings.setTirLow(tirLow)
        await settings.setTirHigh(tirHigh)
        await settings.setKiloAPIKey(kiloAPIKey)
        await settings.setKiloModel(kiloModel)
        isConfigured = nightscoutURL.isEmpty == false && nightscoutSecret.isEmpty == false
        await appDelegate?.scheduleIfEnabled()
    }
    
    func syncNow() async {
        guard isConfigured else {
            errorMessage = "Please configure Nightscout first"
            return
        }
        
        isSyncing = true
        errorMessage = nil
        
        do {
            syncResult = try await SyncService.shared.syncAll()
            lastSyncDate = await SyncService.shared.getLastSyncDate()
            syncLogs = await settings.syncLogs.reversed()
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isSyncing = false
    }
    
    func testConnection() async -> Bool {
        guard !nightscoutURL.isEmpty else { return false }
        
        do {
            await saveSettings()
            return try await SyncService.shared.testConnection()
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
    
    func loadDashboard() async {
        // Load CSV-imported summaries into dailySummaries
        await loadImportedSummaries()

        // HealthKit glucose / insulin / TIR correlation
        guard let hk = HealthKitService.shared else { return }
        let lookback = await settings.lookbackDays
        let defaultSince = Calendar.current.date(byAdding: .day, value: -lookback, to: Date()) ?? Date.distantPast
        let now = Date()

        // Extend the query window back to the oldest Oura summary so TIR
        // values exist for all correlation chart data points.
        let summaryFmt = DateFormatter(); summaryFmt.dateFormat = "yyyy-MM-dd"
        let oldestSummary = dailySummaries.compactMap { summaryFmt.date(from: $0.day) }.min()
        let since = min(defaultSince, oldestSummary ?? defaultSince)
        let lo = Double(await settings.tirLow)
        let hi = Double(await settings.tirHigh)

        async let glucoseFetch    = hk.dailyAverageGlucose(from: since, to: now)
        async let insulinFetch    = hk.dailyTotalInsulin(from: since, to: now)
        async let tirFetch        = hk.dailyTIR(from: since, to: now, low: lo, high: hi)
        async let allGlucoseFetch = hk.glucoseReadings(from: since, to: now)
        glucoseByDay = await glucoseFetch
        insulinByDay = await insulinFetch
        tirByDay     = await tirFetch
        let allGlucose = await allGlucoseFetch

        // Glucose readings during last night's sleep window (for chart)
        if let firstSummary = dailySummaries.first,
           let sleepStart = firstSummary.sleepStart,
           let sleepEnd   = firstSummary.sleepEnd {
            sleepGlucoseReadings = allGlucose
                .filter { $0.0 >= sleepStart && $0.0 <= sleepEnd }
                .map { ChartGlucosePoint(date: $0.0, value: $0.1) }
        }

        // Nocturnal stats per night: TIR, avg, std dev, hypo count
        var nTIR:    [String: Double] = [:]
        var nAvg:    [String: Double] = [:]
        var nStdDev: [String: Double] = [:]
        var nHypo:   [String: Int]    = [:]
        for s in dailySummaries {
            guard let start = s.sleepStart, let end = s.sleepEnd else { continue }
            let vals = allGlucose.filter { $0.0 >= start && $0.0 <= end }.map(\.1)
            guard vals.count >= 3 else { continue }
            let avg      = vals.reduce(0, +) / Double(vals.count)
            let variance = vals.map { ($0 - avg) * ($0 - avg) }.reduce(0, +) / Double(vals.count)
            let inRange  = vals.filter { $0 >= lo && $0 <= hi }
            nTIR[s.day]    = Double(inRange.count) / Double(vals.count) * 100
            nAvg[s.day]    = avg
            nStdDev[s.day] = sqrt(variance)
            nHypo[s.day]   = vals.filter { $0 < lo }.count
        }
        nocturnalTIRByDay    = nTIR
        nocturnalAvgByDay    = nAvg
        nocturnalStdDevByDay = nStdDev
        nocturnalHypoByDay   = nHypo
    }

    func requestHealthKitAuthorization() async {
        guard let healthKit = HealthKitService.shared else {
            errorMessage = "HealthKit not available"
            return
        }

        do {
            try await healthKit.requestAuthorization()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Today data (Home chart)

    func loadTodayData() async {
        guard let hk = HealthKitService.shared else { return }
        let glucose = await hk.todayGlucoseReadings()
        let insulin = await hk.todayInsulinDoses()
        todayGlucoseReadings = glucose.map { ChartGlucosePoint(date: $0.0, value: $0.1) }
        todayInsulinDoses    = insulin.map { InsulinDose(date: $0.0, units: $0.1) }
    }

    // MARK: - Sync all (Nightscout)

    func syncAll() async {
        await syncNow()
        let ouraErrors = await SyncService.shared.syncOuraToHealthKit(summaries: dailySummaries)
        if !ouraErrors.isEmpty {
            // surface errors if needed — for now just proceed
        }
    }

    // MARK: - Workout log

    func logWorkout(_ entry: WorkoutEntry) async {
        await settings.appendWorkout(entry)
        workoutLogs = await settings.workoutLogs
    }

    func deleteWorkout(id: UUID) async {
        await settings.deleteWorkout(id: id)
        workoutLogs = await settings.workoutLogs
    }

    // MARK: - Pump event log

    func logPumpEvent(_ entry: PumpEventEntry) async {
        await settings.appendPumpEvent(entry)
        pumpEventLogs = await settings.pumpEventLogs
    }

    func deletePumpEvent(id: UUID) async {
        await settings.deletePumpEvent(id: id)
        pumpEventLogs = await settings.pumpEventLogs
    }

    // MARK: - Journal

    func upsertJournalEntry(_ entry: JournalDayEntry) async {
        await settings.upsertJournalEntry(entry)
        journalEntries = await settings.journalEntries
    }

    func setHiddenJournalItems(_ items: Set<String>) async {
        await settings.setHiddenJournalItems(items)
        hiddenJournalItems = items
    }

    func upsertCustomJournalItem(_ item: CustomJournalItem) async {
        await settings.upsertCustomJournalItem(item)
        customJournalItems = await settings.customJournalItems
    }

    func deleteCustomJournalItem(id: UUID) async {
        await settings.deleteCustomJournalItem(id: id)
        customJournalItems = await settings.customJournalItems
    }

    // MARK: - Oura export import

    /// Apply a parsed export result — shared by ZIP picker and web download paths.
    func applyExportResult(_ result: OuraExportResult) async {
        importResult = result
        await settings.setImportedDailySummaries(result.summaries)
        mergeDailySummaries(imported: result.summaries)
        let existingIDs = Set(ouraWorkouts.map(\.id))
        let newWorkouts = result.workouts.filter { !existingIDs.contains($0.id) }
        ouraWorkouts = (newWorkouts + ouraWorkouts)
            .sorted { ($0.startDate ?? .distantPast) > ($1.startDate ?? .distantPast) }
    }

    func importOuraExport(from zipURL: URL) async {
        isImportingExport = true
        importError = nil
        importResult = nil
        defer { isImportingExport = false }

        do {
            let result = try OuraExportParser.parse(zipURL: zipURL)
            await applyExportResult(result)
        } catch {
            importError = error.localizedDescription
        }
    }

    /// Merge imported summaries into dailySummaries using field-level supplement.
    /// API (live) values take precedence; imported fills nil gaps.
    func mergeDailySummaries(imported: [OuraDailySummary]) {
        guard !imported.isEmpty else { return }
        var byDay = Dictionary(imported.map { ($0.day, $0) }, uniquingKeysWith: { _, b in b })
        // Overlay live API summaries — supplement each with imported data for same day
        for s in dailySummaries {
            let merged = imported.first(where: { $0.day == s.day })
                .map { s.supplemented(with: $0) } ?? s
            byDay[s.day] = merged
        }
        dailySummaries = byDay.values.sorted { $0.day > $1.day }
    }

    /// Load imported summaries from UserDefaults and merge with any current API data.
    func loadImportedSummaries() async {
        let imported = await settings.importedDailySummaries
        guard !imported.isEmpty else { return }
        mergeDailySummaries(imported: imported)
    }

    func clearImportedData() async {
        await settings.clearImportedDailySummaries()
        dailySummaries = []
        ouraWorkouts   = []
        importResult   = nil
    }

    // MARK: - Food log

    func upsertFoodEntry(_ entry: FoodEntry) async {
        await settings.upsertFoodEntry(entry)
        foodEntries = await settings.foodEntries
    }

    func deleteFoodEntry(id: UUID) async {
        await settings.deleteFoodEntry(id: id)
        foodEntries = await settings.foodEntries
    }

    func estimateCarbs(description: String) async throws -> CarbEstimate {
        let svc = KiloService(apiKey: kiloAPIKey, model: kiloModel)
        return try await svc.estimateCarbs(description: description)
    }

    func estimateCarbs(image: UIImage, hint: String) async throws -> CarbEstimate {
        let svc = KiloService(apiKey: kiloAPIKey, model: kiloModel)
        return try await svc.estimateCarbs(image: image, hint: hint)
    }

    /// Glucose readings in the 0–3h window after a meal, for impact chart.
    func postMealGlucose(after entry: FoodEntry) -> [ChartGlucosePoint] {
        let end = entry.date.addingTimeInterval(3 * 3600)
        return todayGlucoseReadings.filter { $0.date >= entry.date && $0.date <= end }
    }

    // MARK: - Claude export

    func buildClaudeExport(from start: Date, to end: Date) async -> String {
        guard let hk = HealthKitService.shared else { return "" }

        let lo = Double(await settings.tirLow)
        let hi = Double(await settings.tirHigh)

        async let glcFetch = hk.dailyAverageGlucose(from: start, to: end)
        async let insFetch = hk.dailyTotalInsulin(from: start, to: end)
        async let tirFetch = hk.dailyTIR(from: start, to: end, low: lo, high: hi)

        let glcByDay = await glcFetch
        let insByDay = await insFetch
        let tirByDayLocal = await tirFetch

        let dayFmt = DateFormatter(); dayFmt.dateFormat = "yyyy-MM-dd"
        let displayFmt = DateFormatter(); displayFmt.dateFormat = "MMM d, yyyy"

        // All calendar days in the range
        var days: [String] = []
        var cursor = Calendar.current.startOfDay(for: start)
        let endDay  = Calendar.current.startOfDay(for: end)
        while cursor <= endDay {
            days.append(dayFmt.string(from: cursor))
            cursor = Calendar.current.date(byAdding: .day, value: 1, to: cursor) ?? cursor
        }

        // Summaries indexed by day
        let summaryByDay = Dictionary(dailySummaries.map { ($0.day, $0) },
                                      uniquingKeysWith: { a, _ in a })

        // Aggregate stats
        let glcVals  = days.compactMap { glcByDay[$0] }
        let tirVals  = days.compactMap { tirByDayLocal[$0] }
        let insVals  = days.compactMap { insByDay[$0] }
        let readVals = days.compactMap { summaryByDay[$0]?.readinessScore.map(Double.init) }
        let sleepVals = days.compactMap { summaryByDay[$0]?.sleepScore.map(Double.init) }
        let hrvVals  = days.compactMap { summaryByDay[$0]?.averageHrv.map(Double.init) }

        func avg(_ v: [Double]) -> String {
            guard !v.isEmpty else { return "n/a" }
            return String(format: "%.1f", v.reduce(0, +) / Double(v.count))
        }

        var lines: [String] = []
        lines.append("# Health Data Export · \(displayFmt.string(from: start)) – \(displayFmt.string(from: end))")
        lines.append("")
        lines.append("## Summary (\(days.count) days)")
        lines.append("- Average glucose: \(avg(glcVals)) mg/dL")
        lines.append("- Average TIR (\(Int(lo))–\(Int(hi)) mg/dL): \(avg(tirVals))%")
        lines.append("- Average daily insulin: \(avg(insVals)) units")
        if !readVals.isEmpty  { lines.append("- Average readiness: \(avg(readVals))/100") }
        if !sleepVals.isEmpty { lines.append("- Average sleep score: \(avg(sleepVals))/100") }
        if !hrvVals.isEmpty   { lines.append("- Average HRV: \(avg(hrvVals)) ms") }
        lines.append("")
        lines.append("## Daily Breakdown")

        // Pre-sort pump events for age lookups
        let sortedPumpEvents = pumpEventLogs.sorted { $0.date < $1.date }

        func pumpAge(for day: String, types: [PumpEventType]) -> Int? {
            guard let dayDate = dayFmt.date(from: day) else { return nil }
            guard let last = sortedPumpEvents
                .filter({ types.contains($0.eventType) && $0.date < dayDate })
                .last else { return nil }
            return Calendar.current.dateComponents([.day], from: last.date, to: dayDate).day
        }

        // Food index (group entries by day)
        let foodByDay: [String: [FoodEntry]] = Dictionary(
            grouping: foodEntries.filter { $0.date >= start && $0.date <= end },
            by: { dayFmt.string(from: $0.date) }
        )

        // Journal index
        let journalByDay = Dictionary(journalEntries.map { ($0.day, $0) },
                                      uniquingKeysWith: { a, _ in a })
        let customItemIndex = Dictionary(customJournalItems.map { ($0.id.uuidString, $0) },
                                         uniquingKeysWith: { a, _ in a })

        for day in days {
            var row = "### \(day)"
            var parts: [String] = []

            // Glucose / insulin
            if let g = glcByDay[day]      { parts.append("Glucose avg \(Int(g)) mg/dL") }
            if let t = tirByDayLocal[day] { parts.append("TIR \(Int(t.rounded()))%") }
            if let i = insByDay[day]      { parts.append("Insulin \(String(format: "%.1f", i))u") }

            // Cannula age (cannula change or pod change resets it)
            if let age = pumpAge(for: day, types: [.cannulaChange, .podChange]) {
                parts.append("Cannula day \(age)")
            }
            // Reservoir age (reservoir change or pod change resets it)
            if let age = pumpAge(for: day, types: [.reservoirChange, .podChange]) {
                parts.append("Reservoir day \(age)")
            }
            // Pump events that happened on this day
            for e in sortedPumpEvents where dayFmt.string(from: e.date) == day {
                let note = e.notes.isEmpty ? "" : " (\(e.notes))"
                parts.append("\(e.eventType.rawValue)\(note)")
            }

            // Oura vitals
            if let s = summaryByDay[day] {
                if let r = s.readinessScore { parts.append("Readiness \(r)") }
                if let sl = s.sleepScore    { parts.append("Sleep \(sl)") }
                if let h = s.averageHrv     { parts.append("HRV \(Int(h))ms") }
                if let steps = s.steps      { parts.append("Steps \(steps)") }
                if let stress = s.stressHighMinutes, stress > 0 {
                    parts.append("High-stress \(stress)min")
                }
            }

            // Journal entries
            if let j = journalByDay[day] {
                for key in JournalItemKey.allCases {
                    if let v = j.boolValue(for: key), v {
                        parts.append("\(key.displayName): yes")
                    } else if let v = j.numericValue(for: key), v > 0 {
                        let unit: String
                        if case .numeric(let u) = key.inputType { unit = u } else { unit = "" }
                        parts.append("\(key.displayName): \(Int(v))\(unit)")
                    } else if let v = j.scaleValue(for: key) {
                        parts.append("\(key.displayName): \(v)/5")
                    }
                }
                // Custom journal items
                for (idStr, item) in customItemIndex {
                    if let v = j.boolValue(customID: idStr), v {
                        parts.append("\(item.name): yes")
                    } else if let v = j.numericValue(customID: idStr), v > 0 {
                        parts.append("\(item.name): \(Int(v))\(item.unit)")
                    } else if let v = j.scaleValue(customID: idStr) {
                        parts.append("\(item.name): \(v)/5")
                    }
                }
            }

            // Food entries
            if let meals = foodByDay[day] {
                let timeFmt = DateFormatter(); timeFmt.dateFormat = "HH:mm"
                for meal in meals.sorted(by: { $0.date < $1.date }) {
                    let carbs = meal.carbs.map { " (\(Int($0))g carbs)" } ?? ""
                    parts.append("Meal \(timeFmt.string(from: meal.date)): \(meal.description)\(carbs)")
                }
                let totalCarbs = meals.compactMap(\.carbs).reduce(0, +)
                if totalCarbs > 0 { parts.append("Total carbs logged: \(Int(totalCarbs))g") }
            }

            if parts.isEmpty { row += " — no data" } else { row += "\n" + parts.map { "- \($0)" }.joined(separator: "\n") }
            lines.append(row)
            lines.append("")
        }

        lines.append("## Analysis Questions")
        lines.append("Please analyze the above data and answer:")
        lines.append("1. What patterns exist between readiness/sleep scores and next-day glucose control (TIR)?")
        lines.append("2. Does cannula or reservoir age correlate with worse insulin absorption (higher glucose, lower TIR)? At which day does it typically degrade?")
        lines.append("3. Are there specific days where multiple metrics declined together — what might explain that?")
        lines.append("4. How does insulin dosing correlate with TIR on the same and following day?")
        lines.append("5. Do logged meals (carb amounts, meal timing) correlate with glucose spikes or poor TIR on that day?")
        lines.append("6. Do any journal entries (alcohol, exercise, mood, sleep aids) show a pattern with glucose outcomes?")
        lines.append("7. What are the top 2–3 actionable recommendations based on these trends?")
        lines.append("8. Identify any outlier days that stand out and suggest what might have caused them.")

        return lines.joined(separator: "\n")
    }
}
