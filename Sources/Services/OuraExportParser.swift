import Foundation
import ZIPFoundation

// MARK: - Errors

enum OuraExportError: Error, LocalizedError {
    case noCSVFound
    case invalidZIP
    case parseError(String)

    var errorDescription: String? {
        switch self {
        case .noCSVFound:          return "No Oura CSV files found in the archive"
        case .invalidZIP:          return "Could not open the ZIP archive"
        case .parseError(let msg): return "Parse error: \(msg)"
        }
    }
}

// MARK: - Result

struct OuraExportResult {
    var summaries: [OuraDailySummary] = []
    var workouts:  [OuraWorkoutEntry] = []
    var daysImported: Int { summaries.count }
}

// MARK: - Parser

struct OuraExportParser {

    // MARK: - Public entry point

    /// Parse an Oura data-export ZIP and return OuraDailySummary array (newest first).
    static func parse(zipURL: URL) throws -> OuraExportResult {
        guard let archive = Archive(url: zipURL, accessMode: .read) else {
            throw OuraExportError.invalidZIP
        }

        // --- Extract all CSV files by name ---
        var csvByName: [String: String] = [:]
        for entry in archive where entry.type == .file {
            let name = (entry.path as NSString).lastPathComponent.lowercased()
            guard name.hasSuffix(".csv") else { continue }
            var data = Data()
            _ = try? archive.extract(entry, consumer: { chunk in data.append(chunk) })
            if let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) {
                csvByName[name] = text
            }
        }

        guard !csvByName.isEmpty else { throw OuraExportError.noCSVFound }

        // --- Parse each file ---
        let sleepRows       = csvByName["dailysleep.csv"].map       { parseCSV($0) } ?? []
        let sleepModelRows  = csvByName["sleepmodel.csv"].map       { parseCSV($0) } ?? []
        let readinessRows   = csvByName["dailyreadiness.csv"].map   { parseCSV($0) } ?? []
        let activityRows    = csvByName["dailyactivity.csv"].map    { parseCSV($0) } ?? []
        let stressRows      = csvByName["dailystress.csv"].map      { parseCSV($0) } ?? []
        let resilienceRows  = csvByName["dailyresilience.csv"].map  { parseCSV($0) } ?? []
        let spo2Rows        = csvByName["dailyspo2.csv"].map        { parseCSV($0) } ?? []
        let cvAgeRows       = csvByName["dailycardiovascularage.csv"].map { parseCSV($0) } ?? []
        let sleepTimeRows   = csvByName["sleeptime.csv"].map        { parseCSV($0) } ?? []
        let workoutRows     = csvByName["workout.csv"].map          { parseCSV($0) } ?? []

        // --- Key each table by day ---
        let sleepByDay      = dict(sleepRows,      key: "day")
        let readinessByDay  = dict(readinessRows,  key: "day")
        let activityByDay   = dict(activityRows,   key: "day")
        let stressByDay     = dict(stressRows,     key: "day")
        let resilienceByDay = dict(resilienceRows, key: "day")
        let spo2ByDay       = dict(spo2Rows,       key: "day")
        let cvAgeByDay      = dict(cvAgeRows,      key: "day")
        let sleepTimeByDay  = dict(sleepTimeRows,  key: "day")

        // Sleep session — prefer long_sleep; fall back to longest total_sleep_duration
        var sleepModelByDay: [String: [String: String]] = [:]
        for row in sleepModelRows {
            guard let day = row["day"], !day.isEmpty else { continue }
            let sessionType = row["type"] ?? ""
            if let existing = sleepModelByDay[day] {
                let existingMain = (existing["type"] ?? "") == "long_sleep"
                let newMain      = sessionType == "long_sleep"
                if newMain && !existingMain {
                    sleepModelByDay[day] = row
                } else if newMain == existingMain {
                    let newDur = Int(row["total_sleep_duration"] ?? "0") ?? 0
                    let exDur  = Int(existing["total_sleep_duration"] ?? "0") ?? 0
                    if newDur > exDur { sleepModelByDay[day] = row }
                }
            } else {
                sleepModelByDay[day] = row
            }
        }

        // --- Build day set ---
        let allDays = Set(sleepByDay.keys)
            .union(sleepModelByDay.keys)
            .union(readinessByDay.keys)
            .union(activityByDay.keys)
            .union(stressByDay.keys)
            .union(resilienceByDay.keys)
            .union(spo2ByDay.keys)
            .union(cvAgeByDay.keys)
            .union(sleepTimeByDay.keys)

        // --- Build summaries ---
        let summaries: [OuraDailySummary] = allDays.sorted().reversed().compactMap { day in
            buildSummary(
                day: day,
                sleep:      sleepByDay[day],
                sleepModel: sleepModelByDay[day],
                readiness:  readinessByDay[day],
                activity:   activityByDay[day],
                stress:     stressByDay[day],
                resilience: resilienceByDay[day],
                spo2:       spo2ByDay[day],
                cvAge:      cvAgeByDay[day],
                sleepTime:  sleepTimeByDay[day]
            )
        }

        // --- Workouts ---
        let isoIn = ISO8601DateFormatter()
        isoIn.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let workouts: [OuraWorkoutEntry] = workoutRows.compactMap { row in
            guard let id  = row["id"], !id.isEmpty,
                  let day = row["day"], !day.isEmpty else { return nil }
            let start = row["start_datetime"].flatMap { isoIn.date(from: $0) }
            let end   = row["end_datetime"].flatMap   { isoIn.date(from: $0) }
            return OuraWorkoutEntry(
                id: id, day: day,
                activity: row["activity"],
                calories: row["calories"].flatMap(Double.init),
                distance: row["distance"].flatMap(Double.init),
                intensity: row["intensity"],
                label: row["label"],
                startDatetime: row["start_datetime"],
                endDatetime: row["end_datetime"],
                startDate: start,
                endDate: end
            )
        }

        return OuraExportResult(summaries: summaries, workouts: workouts)
    }

    // MARK: - Summary builder

    private static func buildSummary(
        day: String,
        sleep:      [String: String]?,
        sleepModel: [String: String]?,
        readiness:  [String: String]?,
        activity:   [String: String]?,
        stress:     [String: String]?,
        resilience: [String: String]?,
        spo2:       [String: String]?,
        cvAge:      [String: String]?,
        sleepTime:  [String: String]?
    ) -> OuraDailySummary {

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let isoBasic = ISO8601DateFormatter()

        func date(_ str: String?) -> Date? {
            guard let s = str, !s.isEmpty else { return nil }
            return iso.date(from: s) ?? isoBasic.date(from: s)
        }
        func intVal(_ d: [String: String]?, _ k: String) -> Int? {
            guard let v = d?[k], !v.isEmpty else { return nil }
            return Int(v) ?? Int(Double(v) ?? -999999)
        }
        func dblVal(_ d: [String: String]?, _ k: String) -> Double? {
            guard let v = d?[k], !v.isEmpty else { return nil }
            return Double(v)
        }
        func strVal(_ d: [String: String]?, _ k: String) -> String? {
            guard let v = d?[k], !v.isEmpty else { return nil }
            return v
        }

        // --- Sleep score contributors (JSON string) ---
        var sleepContribs: SleepContributors? = nil
        if let raw = sleep?["contributors"] {
            sleepContribs = decodeSleepContributors(raw)
        }

        // --- Readiness contributors ---
        var readinessContribs: ReadinessContributors? = nil
        if let raw = readiness?["contributors"] {
            readinessContribs = decodeReadinessContributors(raw)
        }

        // --- Activity contributors ---
        var activityContribs: ActivityContributors? = nil
        if let raw = activity?["contributors"] {
            activityContribs = decodeActivityContributors(raw)
        }

        // --- Resilience contributors ---
        var resilienceContribs: ResilienceContributors? = nil
        if let res = resilience {
            func dblFromAny(_ d: [String: Any]?, _ k: String) -> Double? {
                guard let v = d?[k] else { return nil }
                return Double("\(v)")
            }
            let contribDict = jsonDict(res["contributors"])
            resilienceContribs = ResilienceContributors(
                sleepRecovery:   dblVal(res, "sleep_recovery")   ?? dblFromAny(contribDict, "sleep_recovery"),
                daytimeRecovery: dblVal(res, "daytime_recovery") ?? dblFromAny(contribDict, "daytime_recovery"),
                stress:          dblVal(res, "stress")           ?? dblFromAny(contribDict, "stress")
            )
        }

        // --- SpO2 ---
        var avgSpO2: Double? = nil
        if let raw = spo2?["spo2_percentage"] {
            avgSpO2 = jsonDict(raw)?["average"].flatMap { Double("\($0)") }
                   ?? dblVal(spo2, "average_spo2")
        }

        // --- Sleep model session ---
        let sm = sleepModel
        let sleepStart = date(sm?["bedtime_start"])
        let sleepEnd   = date(sm?["bedtime_end"])

        // durations are in seconds in the CSV
        func minutes(_ d: [String: String]?, _ k: String) -> Int? {
            guard let secs = intVal(d, k) else { return nil }
            return secs / 60
        }

        // --- Stress ---
        // CSV stress_high / recovery_high are in seconds per Cracked-Oura
        let stressHighMin    = minutes(stress, "stress_high")
        let recoveryHighMin  = minutes(stress, "recovery_high")

        // --- Sleep time ---
        var bedStart: String? = nil
        var bedEnd:   String? = nil
        if let raw = sleepTime?["optimal_bedtime"] {
            let d = jsonDict(raw)
            // API stores offsets in seconds from midnight → convert to HH:MM
            if let startOff = d?["start_offset"].flatMap({ Int("\($0)") }) {
                bedStart = secondsToHHMM(startOff)
            }
            if let endOff = d?["end_offset"].flatMap({ Int("\($0)") }) {
                bedEnd = secondsToHHMM(endOff)
            }
        }

        return OuraDailySummary(
            day:                       day,
            sleepStart:                sleepStart,
            sleepEnd:                  sleepEnd,
            sleepScore:                intVal(sleep, "score"),
            sleepContributors:         sleepContribs,
            deepSleepMinutes:          minutes(sm, "deep_sleep_duration"),
            remSleepMinutes:           minutes(sm, "rem_sleep_duration"),
            lightSleepMinutes:         minutes(sm, "light_sleep_duration"),
            totalSleepMinutes:         minutes(sm, "total_sleep_duration"),
            awakeMinutes:              minutes(sm, "awake_time"),
            timeInBedMinutes:          minutes(sm, "time_in_bed"),
            sleepEfficiency:           intVal(sm, "efficiency"),
            averageHrv:                intVal(sm, "average_hrv"),
            lowestHR:                  intVal(sm, "lowest_heart_rate"),
            averageSpO2:               avgSpO2,
            temperatureDeviation:      dblVal(readiness, "temperature_deviation"),
            temperatureTrendDeviation: dblVal(readiness, "temperature_trend_deviation"),
            respiratoryRate:           dblVal(sm, "average_breath"),
            restlessPeriods:           intVal(sm, "restless_periods"),
            sleepLatencySeconds:       intVal(sm, "latency"),
            sleepPhase5Min:            strVal(sm, "sleep_phase_5_min"),
            sleepPhase30Sec:           strVal(sm, "sleep_phase_30_sec"),
            breathingDisturbanceIndex: intVal(spo2, "breathing_disturbance_index"),
            readinessScore:            intVal(readiness, "score"),
            readinessContributors:     readinessContribs,
            activityScore:             intVal(activity, "score"),
            activityContributors:      activityContribs,
            steps:                     intVal(activity, "steps"),
            activeCalories:            intVal(activity, "active_calories"),
            totalCalories:             intVal(activity, "total_calories"),
            highActivityMinutes:       minutes(activity, "high_activity_time"),
            mediumActivityMinutes:     minutes(activity, "medium_activity_time"),
            lowActivityMinutes:        minutes(activity, "low_activity_time"),
            sedentaryMinutes:          minutes(activity, "sedentary_time"),
            restMinutes:               minutes(activity, "resting_time"),
            nonWearMinutes:            minutes(activity, "non_wear_time"),
            inactivityAlerts:          intVal(activity, "inactivity_alerts"),
            targetCalories:            intVal(activity, "target_calories"),
            metersToTarget:            intVal(activity, "meters_to_target"),
            equivalentWalkingKm:       dblVal(activity, "equivalent_walking_distance").map { $0 / 1000.0 },
            averageMet:                dblVal(activity, "average_met_minutes"),
            stressHighMinutes:         stressHighMin,
            recoveryHighMinutes:       recoveryHighMin,
            stressSummary:             strVal(stress, "day_summary"),
            resilienceLevel:           strVal(resilience, "level"),
            resilienceContributors:    resilienceContribs,
            cardiovascularAge:         intVal(cvAge, "vascular_age"),
            vo2Max:                    nil,   // not in standard export
            sleepTimeRecommendation:   strVal(sleepTime, "recommendation"),
            optimalBedtimeStart:       bedStart,
            optimalBedtimeEnd:         bedEnd
        )
    }

    // MARK: - CSV parser

    /// Parse semicolon-delimited CSV with optional quoting. Returns [{header: value}].
    static func parseCSV(_ text: String) -> [[String: String]] {
        let lines = text.components(separatedBy: "\n")
        var result: [[String: String]] = []
        var headers: [String] = []

        for (i, rawLine) in lines.enumerated() {
            let line = rawLine.trimmingCharacters(in: .init(charactersIn: "\r"))
            guard !line.isEmpty else { continue }
            let fields = splitCSVRow(line, separator: ";")
            if i == 0 || headers.isEmpty {
                headers = fields.map { $0.lowercased().trimmingCharacters(in: .whitespaces) }
                continue
            }
            var row: [String: String] = [:]
            for (j, h) in headers.enumerated() {
                row[h] = j < fields.count ? fields[j] : ""
            }
            result.append(row)
        }
        return result
    }

    private static func splitCSVRow(_ line: String, separator: Character) -> [String] {
        var fields: [String] = []
        var current = ""
        var inQuotes = false

        for char in line {
            if char == "\"" {
                inQuotes.toggle()
            } else if char == separator && !inQuotes {
                fields.append(unquote(current))
                current = ""
            } else {
                current.append(char)
            }
        }
        fields.append(unquote(current))
        return fields
    }

    private static func unquote(_ s: String) -> String {
        var t = s.trimmingCharacters(in: .whitespaces)
        if t.hasPrefix("\"") && t.hasSuffix("\"") && t.count >= 2 {
            t = String(t.dropFirst().dropLast())
        }
        return t
    }

    // MARK: - Helpers

    private static func dict(_ rows: [[String: String]], key: String) -> [String: [String: String]] {
        var d: [String: [String: String]] = [:]
        for row in rows {
            if let k = row[key], !k.isEmpty { d[k] = row }
        }
        return d
    }

    private static func jsonDict(_ raw: String?) -> [String: Any]? {
        guard let raw, !raw.isEmpty,
              let data = raw.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        return obj
    }

    private static func secondsToHHMM(_ secs: Int) -> String {
        let h = (secs / 3600) % 24
        let m = (secs % 3600) / 60
        return String(format: "%02d:%02d", h, m)
    }

    // MARK: - Contributor decoders

    private static func decodeSleepContributors(_ raw: String) -> SleepContributors? {
        guard let d = jsonDict(raw) else { return nil }
        func i(_ k: String) -> Int? { d[k].flatMap { Int("\($0)") } }
        return SleepContributors(
            deepSleep: i("deep_sleep"),
            efficiency: i("efficiency"),
            latency: i("latency"),
            remSleep: i("rem_sleep"),
            restfulness: i("restfulness"),
            timing: i("timing"),
            totalSleep: i("total_sleep")
        )
    }

    private static func decodeReadinessContributors(_ raw: String) -> ReadinessContributors? {
        guard let d = jsonDict(raw) else { return nil }
        func i(_ k: String) -> Int? { d[k].flatMap { Int("\($0)") } }
        return ReadinessContributors(
            activityBalance: i("activity_balance"),
            bodyTemperature: i("body_temperature"),
            hrvBalance: i("hrv_balance"),
            previousDayActivity: i("previous_day_activity"),
            previousNight: i("previous_night"),
            recoveryIndex: i("recovery_index"),
            restingHeartRate: i("resting_heart_rate"),
            sleepBalance: i("sleep_balance"),
            sleepRegularity: i("sleep_regularity")
        )
    }

    private static func decodeActivityContributors(_ raw: String) -> ActivityContributors? {
        guard let d = jsonDict(raw) else { return nil }
        func i(_ k: String) -> Int? { d[k].flatMap { Int("\($0)") } }
        return ActivityContributors(
            meetDailyTargets: i("meet_daily_targets"),
            moveEveryHour: i("move_every_hour"),
            recoveryTime: i("recovery_time"),
            stayActive: i("stay_active"),
            trainingFrequency: i("training_frequency"),
            trainingVolume: i("training_volume")
        )
    }
}

// MARK: - OuraDailySummary merge (field-level supplement)

extension OuraDailySummary {
    /// Return a new summary using self's values where non-nil, filling gaps from `other`.
    func supplemented(with other: OuraDailySummary) -> OuraDailySummary {
        OuraDailySummary(
            day:                       day,
            sleepStart:                sleepStart                ?? other.sleepStart,
            sleepEnd:                  sleepEnd                  ?? other.sleepEnd,
            sleepScore:                sleepScore                ?? other.sleepScore,
            sleepContributors:         sleepContributors         ?? other.sleepContributors,
            deepSleepMinutes:          deepSleepMinutes          ?? other.deepSleepMinutes,
            remSleepMinutes:           remSleepMinutes           ?? other.remSleepMinutes,
            lightSleepMinutes:         lightSleepMinutes         ?? other.lightSleepMinutes,
            totalSleepMinutes:         totalSleepMinutes         ?? other.totalSleepMinutes,
            awakeMinutes:              awakeMinutes              ?? other.awakeMinutes,
            timeInBedMinutes:          timeInBedMinutes          ?? other.timeInBedMinutes,
            sleepEfficiency:           sleepEfficiency           ?? other.sleepEfficiency,
            averageHrv:                averageHrv                ?? other.averageHrv,
            lowestHR:                  lowestHR                  ?? other.lowestHR,
            averageSpO2:               averageSpO2               ?? other.averageSpO2,
            temperatureDeviation:      temperatureDeviation      ?? other.temperatureDeviation,
            temperatureTrendDeviation: temperatureTrendDeviation ?? other.temperatureTrendDeviation,
            respiratoryRate:           respiratoryRate           ?? other.respiratoryRate,
            restlessPeriods:           restlessPeriods           ?? other.restlessPeriods,
            sleepLatencySeconds:       sleepLatencySeconds       ?? other.sleepLatencySeconds,
            sleepPhase5Min:            sleepPhase5Min            ?? other.sleepPhase5Min,
            sleepPhase30Sec:           sleepPhase30Sec           ?? other.sleepPhase30Sec,
            breathingDisturbanceIndex: breathingDisturbanceIndex ?? other.breathingDisturbanceIndex,
            readinessScore:            readinessScore            ?? other.readinessScore,
            readinessContributors:     readinessContributors     ?? other.readinessContributors,
            activityScore:             activityScore             ?? other.activityScore,
            activityContributors:      activityContributors      ?? other.activityContributors,
            steps:                     steps                     ?? other.steps,
            activeCalories:            activeCalories            ?? other.activeCalories,
            totalCalories:             totalCalories             ?? other.totalCalories,
            highActivityMinutes:       highActivityMinutes       ?? other.highActivityMinutes,
            mediumActivityMinutes:     mediumActivityMinutes     ?? other.mediumActivityMinutes,
            lowActivityMinutes:        lowActivityMinutes        ?? other.lowActivityMinutes,
            sedentaryMinutes:          sedentaryMinutes          ?? other.sedentaryMinutes,
            restMinutes:               restMinutes               ?? other.restMinutes,
            nonWearMinutes:            nonWearMinutes            ?? other.nonWearMinutes,
            inactivityAlerts:          inactivityAlerts          ?? other.inactivityAlerts,
            targetCalories:            targetCalories            ?? other.targetCalories,
            metersToTarget:            metersToTarget            ?? other.metersToTarget,
            equivalentWalkingKm:       equivalentWalkingKm       ?? other.equivalentWalkingKm,
            averageMet:                averageMet                ?? other.averageMet,
            stressHighMinutes:         stressHighMinutes         ?? other.stressHighMinutes,
            recoveryHighMinutes:       recoveryHighMinutes       ?? other.recoveryHighMinutes,
            stressSummary:             stressSummary             ?? other.stressSummary,
            resilienceLevel:           resilienceLevel           ?? other.resilienceLevel,
            resilienceContributors:    resilienceContributors    ?? other.resilienceContributors,
            cardiovascularAge:         cardiovascularAge         ?? other.cardiovascularAge,
            vo2Max:                    vo2Max                    ?? other.vo2Max,
            sleepTimeRecommendation:   sleepTimeRecommendation   ?? other.sleepTimeRecommendation,
            optimalBedtimeStart:       optimalBedtimeStart       ?? other.optimalBedtimeStart,
            optimalBedtimeEnd:         optimalBedtimeEnd         ?? other.optimalBedtimeEnd
        )
    }
}
