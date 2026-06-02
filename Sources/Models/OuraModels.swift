import Foundation

// MARK: - Pagination wrapper (all list endpoints)

struct OuraPage<T: Decodable>: Decodable {
    let data: [T]
    let nextToken: String?

    enum CodingKeys: String, CodingKey {
        case data
        case nextToken = "next_token"
    }
}

// MARK: - Sleep

struct OuraSleepResponse: Codable {
    let data: [OuraSleepEntry]
    let nextToken: String?
    enum CodingKeys: String, CodingKey {
        case data
        case nextToken = "next_token"
    }
}

struct OuraSleepEntry: Codable {
    let id: String
    let day: String
    let type: String?                           // "long_sleep" | "nap" | "rest"
    let bedtimeStart: String
    let bedtimeEnd: String
    let totalSleepDuration: Int?
    let deepSleepDuration: Int?
    let remSleepDuration: Int?
    let lightSleepDuration: Int?
    let awakeTime: Int?
    let timeInBed: Int?                         // seconds total time in bed
    let efficiency: Int?                        // sleep efficiency %
    let averageHeartRate: Double?
    let averageHrv: Int?
    let lowestHeartRate: Int?
    let averageBreathingRate: Double?           // average_breath in spec
    let averageSpO2Percentage: Double?
    let averageSkinTemperatureDeviation: Double?
    let restlessPeriods: Int?
    let readinessScoreDelta: Int?
    let sleepScoreDelta: Int?
    let sleepPhase5Min: String?                 // 5-min hypnogram: 1=deep 2=light 3=REM 4=awake
    let sleepPhase30Sec: String?                // 30-sec resolution hypnogram
    let movement30Sec: String?                  // 30-sec movement data
    let latency: Int?                           // seconds to fall asleep
    let hrvTimeseries: OuraSample?              // 5-min HRV samples during sleep
    let heartRateTimeseries: OuraSample?        // 5-min HR samples during sleep

    var isMainSleep: Bool { type == "long_sleep" || type == nil }

    enum CodingKeys: String, CodingKey {
        case id, day, type, latency, efficiency
        case bedtimeStart                        = "bedtime_start"
        case bedtimeEnd                          = "bedtime_end"
        case totalSleepDuration                  = "total_sleep_duration"
        case deepSleepDuration                   = "deep_sleep_duration"
        case remSleepDuration                    = "rem_sleep_duration"
        case lightSleepDuration                  = "light_sleep_duration"
        case awakeTime                           = "awake_time"
        case timeInBed                           = "time_in_bed"
        case averageHeartRate                    = "average_heart_rate"
        case averageHrv                          = "average_hrv"
        case lowestHeartRate                     = "lowest_heart_rate"
        case averageBreathingRate                = "average_breath"
        case averageSpO2Percentage               = "average_spo2_percentage"
        case averageSkinTemperatureDeviation     = "average_skin_temperature_deviation"
        case restlessPeriods                     = "restless_periods"
        case readinessScoreDelta                 = "readiness_score_delta"
        case sleepScoreDelta                     = "sleep_score_delta"
        case sleepPhase5Min                      = "sleep_phase_5_min"
        case sleepPhase30Sec                     = "sleep_phase_30_sec"
        case movement30Sec                       = "movement_30_sec"
        case hrvTimeseries                       = "hrv"
        case heartRateTimeseries                 = "heart_rate"
    }

    var startDate: Date? { ISO8601DateFormatter().date(from: bedtimeStart) }
    var endDate:   Date? { ISO8601DateFormatter().date(from: bedtimeEnd) }

    /// Parse hypnogram string → [(stage, durationMinutes)].
    /// stage: 1=deep 2=light 3=REM 4=awake. intervalMinutes = 5 for 5-min, 0.5 for 30-sec.
    func parsedHypnogram(from string: String, intervalMinutes: Double = 5) -> [(stage: Int, minutes: Double)] {
        var result: [(Int, Double)] = []
        var current: Int? = nil
        var count: Double = 0
        for ch in string {
            guard let d = ch.wholeNumberValue else { continue }
            if d == current {
                count += intervalMinutes
            } else {
                if let c = current { result.append((c, count)) }
                current = d; count = intervalMinutes
            }
        }
        if let c = current { result.append((c, count)) }
        return result
    }

    var parsedHypnogram: [(stage: Int, minutes: Double)] {
        guard let s = sleepPhase5Min, !s.isEmpty else { return [] }
        return parsedHypnogram(from: s, intervalMinutes: 5)
    }

    var parsedHypnogram30Sec: [(stage: Int, minutes: Double)] {
        guard let s = sleepPhase30Sec, !s.isEmpty else { return [] }
        return parsedHypnogram(from: s, intervalMinutes: 0.5)
    }
}

// MARK: - Timeseries sample (used in sleep HR + HRV)

struct OuraSample: Codable {
    let interval: Double        // seconds between samples
    let items: [Double?]        // nil = gap in recording
    let timestamp: String       // start of first sample

    var startDate: Date? { ISO8601DateFormatter().date(from: timestamp) }

    /// Expand to [(Date, Double)] pairs, skipping nil items
    var dateSeries: [(Date, Double)] {
        guard let start = startDate else { return [] }
        return items.enumerated().compactMap { idx, val in
            guard let v = val else { return nil }
            let date = start.addingTimeInterval(Double(idx) * interval)
            return (date, v)
        }
    }
}

// MARK: - Daily Sleep (score lives here, NOT in /sleep)

struct OuraDailySleepResponse: Decodable {
    let data: [OuraDailySleepEntry]
    let nextToken: String?
    enum CodingKeys: String, CodingKey {
        case data
        case nextToken = "next_token"
    }
}

struct OuraDailySleepEntry: Decodable {
    let id: String
    let day: String
    let score: Int?
    let contributors: SleepContributors?
}

struct SleepContributors: Codable {
    let deepSleep: Int?
    let efficiency: Int?
    let latency: Int?
    let remSleep: Int?
    let restfulness: Int?
    let timing: Int?
    let totalSleep: Int?

    enum CodingKeys: String, CodingKey {
        case deepSleep   = "deep_sleep"
        case efficiency
        case latency
        case remSleep    = "rem_sleep"
        case restfulness
        case timing
        case totalSleep  = "total_sleep"
    }
}

// MARK: - Daily SpO2  [BUG FIX: was "average_spo2" → "spo2_percentage", "percentage" → "average"]

struct OuraDailySpO2Response: Decodable {
    let data: [OuraDailySpO2Entry]
    let nextToken: String?
    enum CodingKeys: String, CodingKey {
        case data
        case nextToken = "next_token"
    }
}

struct OuraDailySpO2Entry: Decodable {
    let id: String
    let day: String
    let breathingDisturbanceIndex: Int?     // top-level field per spec
    let spo2Percentage: SpO2Aggregated?     // nested average

    enum CodingKeys: String, CodingKey {
        case id, day
        case breathingDisturbanceIndex = "breathing_disturbance_index"
        case spo2Percentage            = "spo2_percentage"
    }

    /// Convenience — average SpO2 %
    var averageSpo2: Double? { spo2Percentage?.average }
}

struct SpO2Aggregated: Decodable {
    let average: Double?
}

// MARK: - Cardiovascular Age

struct OuraCardiovascularAgeResponse: Decodable {
    let data: [OuraCardiovascularAgeEntry]
    let nextToken: String?
    enum CodingKeys: String, CodingKey {
        case data
        case nextToken = "next_token"
    }
}

struct OuraCardiovascularAgeEntry: Decodable {
    let id: String
    let day: String
    let vascularAge: Int?

    enum CodingKeys: String, CodingKey {
        case id, day
        case vascularAge = "vascular_age"
    }
}

// MARK: - VO2 Max  [NEW]

struct OuraVO2MaxResponse: Decodable {
    let data: [OuraVO2MaxEntry]
    let nextToken: String?
    enum CodingKeys: String, CodingKey {
        case data
        case nextToken = "next_token"
    }
}

struct OuraVO2MaxEntry: Decodable {
    let id: String
    let day: String
    let timestamp: String?
    let vo2Max: Int?            // mL/kg/min as integer

    enum CodingKeys: String, CodingKey {
        case id, day, timestamp
        case vo2Max = "vo2_max"
    }
}

// MARK: - Sleep Time (optimal bedtime recommendation)  [NEW]

struct OuraSleepTimeResponse: Decodable {
    let data: [OuraSleepTimeEntry]
    let nextToken: String?
    enum CodingKeys: String, CodingKey {
        case data
        case nextToken = "next_token"
    }
}

struct OuraSleepTimeEntry: Decodable {
    let id: String
    let day: String
    let recommendation: String?     // "improve_efficiency"|"earlier_bedtime"|"later_bedtime"|"earlier_wake_up_time"|"later_wake_up_time"|"follow_optimal_bedtime"
    let status: String?             // "not_enough_nights"|"not_enough_recent_nights"|"bad_sleep_quality"|"only_recommended_found"|"optimal_found"
    let optimalBedtime: SleepTimeWindow?

    enum CodingKeys: String, CodingKey {
        case id, day, recommendation, status
        case optimalBedtime = "optimal_bedtime"
    }
}

struct SleepTimeWindow: Decodable {
    let dayTz: Int?             // timezone offset in seconds
    let endOffset: Int?         // seconds from midnight for end of window
    let startOffset: Int?       // seconds from midnight for start of window

    enum CodingKeys: String, CodingKey {
        case dayTz      = "day_tz"
        case endOffset  = "end_offset"
        case startOffset = "start_offset"
    }

    /// Convenience: start as HH:MM string
    var startTimeString: String? {
        guard let s = startOffset else { return nil }
        let h = (s / 3600) % 24
        let m = (s % 3600) / 60
        return String(format: "%02d:%02d", h, m)
    }
    var endTimeString: String? {
        guard let e = endOffset else { return nil }
        let h = (e / 3600) % 24
        let m = (e % 3600) / 60
        return String(format: "%02d:%02d", h, m)
    }
}

// MARK: - Interbeat Interval (per-sample HRV)  [NEW]

struct OuraInterbeatIntervalResponse: Decodable {
    let data: [OuraInterbeatIntervalEntry]
    let nextToken: String?
    enum CodingKeys: String, CodingKey {
        case data
        case nextToken = "next_token"
    }
}

struct OuraInterbeatIntervalEntry: Decodable {
    let timestamp: String       // UTC ISO8601
    let timestampUnix: Int?
    let ibi: Int                // interbeat interval in milliseconds
    let validity: Int?          // 1 = valid, 0 = invalid/artefact

    var date: Date? { ISO8601DateFormatter().date(from: timestamp) }
    var isValid: Bool { validity == 1 || validity == nil }

    enum CodingKeys: String, CodingKey {
        case timestamp, ibi, validity
        case timestampUnix = "timestamp_unix"
    }
}

// MARK: - Ring Configuration  [NEW]

struct OuraRingConfigurationResponse: Decodable {
    let data: [OuraRingConfiguration]
    let nextToken: String?
    enum CodingKeys: String, CodingKey {
        case data
        case nextToken = "next_token"
    }
}

struct OuraRingConfiguration: Decodable {
    let id: String
    let color: String?
    let design: String?
    let firmwareVersion: String?
    let hardwareType: String?
    let setUpAt: String?
    let size: Int?

    enum CodingKeys: String, CodingKey {
        case id, color, design, size
        case firmwareVersion = "firmware_version"
        case hardwareType    = "hardware_type"
        case setUpAt         = "set_up_at"
    }
}

// MARK: - Ring Battery Level  [NEW]

struct OuraRingBatteryLevelResponse: Decodable {
    let data: [OuraRingBatteryLevelEntry]
    let nextToken: String?
    enum CodingKeys: String, CodingKey {
        case data
        case nextToken = "next_token"
    }
}

struct OuraRingBatteryLevelEntry: Decodable {
    let timestamp: String
    let timestampUnix: Int?
    let charging: Bool?
    let inCharger: Bool?
    let level: Int?             // battery percentage 0-100

    var date: Date? { ISO8601DateFormatter().date(from: timestamp) }

    enum CodingKeys: String, CodingKey {
        case timestamp, charging, level
        case timestampUnix = "timestamp_unix"
        case inCharger     = "in_charger"
    }
}

// MARK: - Rest Mode Period  [NEW]

struct OuraRestModePeriodResponse: Decodable {
    let data: [OuraRestModePeriodEntry]
    let nextToken: String?
    enum CodingKeys: String, CodingKey {
        case data
        case nextToken = "next_token"
    }
}

struct OuraRestModePeriodEntry: Decodable, Identifiable {
    let id: String
    let startDay: String
    let endDay: String?
    let startTime: String?
    let endTime: String?

    var startDate: Date? {
        guard let s = startTime else { return nil }
        return ISO8601DateFormatter().date(from: s)
    }
    var endDate: Date? {
        guard let e = endTime else { return nil }
        return ISO8601DateFormatter().date(from: e)
    }
    var isActive: Bool { endDay == nil }

    enum CodingKeys: String, CodingKey {
        case id
        case startDay  = "start_day"
        case endDay    = "end_day"
        case startTime = "start_time"
        case endTime   = "end_time"
    }
}

// MARK: - Enhanced Tag  [NEW]

struct OuraEnhancedTagResponse: Decodable {
    let data: [OuraEnhancedTagEntry]
    let nextToken: String?
    enum CodingKeys: String, CodingKey {
        case data
        case nextToken = "next_token"
    }
}

struct OuraEnhancedTagEntry: Decodable, Identifiable {
    let id: String
    let tagTypeCode: String?    // built-in type e.g. "tag_generic_sick"
    let startTime: String
    let endTime: String?
    let startDay: String
    let endDay: String?
    let comment: String?
    let customName: String?     // user-defined tag name

    var startDate: Date? { ISO8601DateFormatter().date(from: startTime) }
    var endDate:   Date? {
        guard let e = endTime else { return nil }
        return ISO8601DateFormatter().date(from: e)
    }

    var displayName: String {
        customName ?? tagTypeCode?.replacingOccurrences(of: "_", with: " ").capitalized ?? "Tag"
    }

    enum CodingKeys: String, CodingKey {
        case id, comment
        case tagTypeCode = "tag_type_code"
        case startTime   = "start_time"
        case endTime     = "end_time"
        case startDay    = "start_day"
        case endDay      = "end_day"
        case customName  = "custom_name"
    }
}

// MARK: - Sessions (meditation / breathwork / nap)

struct OuraSessionResponse: Decodable {
    let data: [OuraSessionEntry]
    let nextToken: String?
    enum CodingKeys: String, CodingKey {
        case data
        case nextToken = "next_token"
    }
}

struct OuraSessionEntry: Decodable, Identifiable {
    let id: String
    let day: String
    let startDatetime: String
    let endDatetime: String
    let type: String            // "meditation" | "breathwork" | "power_nap" | etc.
    let mood: String?           // "bad"|"worse"|"same"|"good"|"great"
    let heartRate: OuraSample?
    let heartRateVariability: OuraSample?

    enum CodingKeys: String, CodingKey {
        case id, day, type, mood
        case startDatetime        = "start_datetime"
        case endDatetime          = "end_datetime"
        case heartRate            = "heart_rate"
        case heartRateVariability = "heart_rate_variability"
    }

    var startDate: Date? { ISO8601DateFormatter().date(from: startDatetime) }
    var endDate:   Date? { ISO8601DateFormatter().date(from: endDatetime) }

    var durationMinutes: Int? {
        guard let s = startDate, let e = endDate else { return nil }
        return Int(e.timeIntervalSince(s) / 60)
    }

    var typeDisplayName: String {
        type.replacingOccurrences(of: "_", with: " ").capitalized
    }
}

// MARK: - Readiness

struct OuraReadinessResponse: Decodable {
    let data: [OuraReadinessEntry]
    let nextToken: String?
    enum CodingKeys: String, CodingKey {
        case data
        case nextToken = "next_token"
    }
}

struct OuraReadinessEntry: Decodable {
    let id: String
    let day: String
    let score: Int?
    let temperatureDeviation: Double?
    let temperatureTrendDeviation: Double?
    let contributors: ReadinessContributors?

    enum CodingKeys: String, CodingKey {
        case id, day, score, contributors
        case temperatureDeviation      = "temperature_deviation"
        case temperatureTrendDeviation = "temperature_trend_deviation"
    }
}

struct ReadinessContributors: Codable {
    let activityBalance: Int?
    let bodyTemperature: Int?
    let hrvBalance: Int?
    let previousDayActivity: Int?
    let previousNight: Int?
    let recoveryIndex: Int?
    let restingHeartRate: Int?
    let sleepBalance: Int?
    let sleepRegularity: Int?   // [BUG FIX: was missing]

    enum CodingKeys: String, CodingKey {
        case activityBalance     = "activity_balance"
        case bodyTemperature     = "body_temperature"
        case hrvBalance          = "hrv_balance"
        case previousDayActivity = "previous_day_activity"
        case previousNight       = "previous_night"
        case recoveryIndex       = "recovery_index"
        case restingHeartRate    = "resting_heart_rate"
        case sleepBalance        = "sleep_balance"
        case sleepRegularity     = "sleep_regularity"
    }
}

// MARK: - Daily Stress

struct OuraDailyStressResponse: Codable {
    let data: [OuraDailyStressEntry]
    let nextToken: String?
    enum CodingKeys: String, CodingKey {
        case data
        case nextToken = "next_token"
    }
}

struct OuraDailyStressEntry: Codable {
    let id: String
    let day: String
    let stressHigh: Int?        // seconds in high-stress state
    let recoveryHigh: Int?      // seconds in high-recovery state
    let daySummary: String?     // "restored" | "normal" | "stressful" | "demanding"

    enum CodingKeys: String, CodingKey {
        case id, day
        case stressHigh   = "stress_high"
        case recoveryHigh = "recovery_high"
        case daySummary   = "day_summary"
    }
}

// MARK: - Daily Resilience

struct OuraResilienceResponse: Codable {
    let data: [OuraResilienceEntry]
    let nextToken: String?
    enum CodingKeys: String, CodingKey {
        case data
        case nextToken = "next_token"
    }
}

struct OuraResilienceEntry: Codable {
    let id: String
    let day: String
    let level: String?          // "exceptional"|"strong"|"solid"|"adequate"|"limited"
    let contributors: ResilienceContributors?

    enum CodingKeys: String, CodingKey {
        case id, day, level, contributors
    }
}

struct ResilienceContributors: Codable {
    // [BUG FIX: were String? and wrong key "daytime_stress" → "stress"; types are Double not String]
    let sleepRecovery: Double?
    let daytimeRecovery: Double?
    let stress: Double?

    enum CodingKeys: String, CodingKey {
        case sleepRecovery   = "sleep_recovery"
        case daytimeRecovery = "daytime_recovery"
        case stress          = "stress"
    }
}

// MARK: - Activity

struct OuraActivityResponse: Decodable {
    let data: [OuraActivityEntry]
    let nextToken: String?
    enum CodingKeys: String, CodingKey {
        case data
        case nextToken = "next_token"
    }
}

struct OuraActivityEntry: Decodable {
    let id: String
    let day: String
    let score: Int?
    let activeCalories: Int?
    let totalCalories: Int?
    let steps: Int?
    let equivalentWalkingDistance: Int?
    let highActivityTime: Int?
    let mediumActivityTime: Int?
    let lowActivityTime: Int?
    let sedentaryTime: Int?
    let restTime: Int?
    let nonWearTime: Int?
    let inactivityAlerts: Int?
    let targetCalories: Int?
    let targetMeters: Int?
    let metersToTarget: Int?
    let highActivityMet: Double?
    let mediumActivityMet: Double?
    let lowActivityMet: Double?
    let averageMet: Double?
    let contributors: ActivityContributors?

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id  = try c.decode(String.self, forKey: .id)
        day = try c.decode(String.self, forKey: .day)
        score                     = try? c.decodeIfPresent(Int.self, forKey: .score)
        activeCalories            = try? c.decodeIfPresent(Int.self, forKey: .activeCalories)
        totalCalories             = try? c.decodeIfPresent(Int.self, forKey: .totalCalories)
        steps                     = try? c.decodeIfPresent(Int.self, forKey: .steps)
        equivalentWalkingDistance = try? c.decodeIfPresent(Int.self, forKey: .equivalentWalkingDistance)
        highActivityTime          = try? c.decodeIfPresent(Int.self, forKey: .highActivityTime)
        mediumActivityTime        = try? c.decodeIfPresent(Int.self, forKey: .mediumActivityTime)
        lowActivityTime           = try? c.decodeIfPresent(Int.self, forKey: .lowActivityTime)
        sedentaryTime             = try? c.decodeIfPresent(Int.self, forKey: .sedentaryTime)
        restTime                  = try? c.decodeIfPresent(Int.self, forKey: .restTime)
        nonWearTime               = try? c.decodeIfPresent(Int.self, forKey: .nonWearTime)
        inactivityAlerts          = try? c.decodeIfPresent(Int.self, forKey: .inactivityAlerts)
        targetCalories            = try? c.decodeIfPresent(Int.self, forKey: .targetCalories)
        targetMeters              = try? c.decodeIfPresent(Int.self, forKey: .targetMeters)
        metersToTarget            = try? c.decodeIfPresent(Int.self, forKey: .metersToTarget)
        func decodeMet(_ key: CodingKeys) -> Double? {
            if let d = try? c.decodeIfPresent(Double.self, forKey: key) { return d }
            if let i = try? c.decodeIfPresent(Int.self,    forKey: key) { return Double(i) }
            return nil
        }
        averageMet        = decodeMet(.averageMet)
        highActivityMet   = decodeMet(.highActivityMet)
        mediumActivityMet = decodeMet(.mediumActivityMet)
        lowActivityMet    = decodeMet(.lowActivityMet)
        contributors = try? c.decodeIfPresent(ActivityContributors.self, forKey: .contributors)
    }

    enum CodingKeys: String, CodingKey {
        case id, day, score, steps, contributors
        case activeCalories            = "active_calories"
        case totalCalories             = "total_calories"
        case equivalentWalkingDistance = "equivalent_walking_distance"
        case highActivityTime          = "high_activity_time"
        case mediumActivityTime        = "medium_activity_time"
        case lowActivityTime           = "low_activity_time"
        case sedentaryTime             = "sedentary_time"
        case restTime                  = "rest_time"
        case nonWearTime               = "non_wear_time"
        case inactivityAlerts          = "inactivity_alerts"
        case targetCalories            = "target_calories"
        case targetMeters              = "target_meters"
        case metersToTarget            = "meters_to_target"
        case averageMet                = "average_met_minutes"
        case highActivityMet           = "high_activity_met_minutes"
        case mediumActivityMet         = "medium_activity_met_minutes"
        case lowActivityMet            = "low_activity_met_minutes"
    }
}

struct ActivityContributors: Codable {
    let meetDailyTargets: Int?
    let moveEveryHour: Int?
    let recoveryTime: Int?
    let stayActive: Int?
    let trainingFrequency: Int?
    let trainingVolume: Int?

    enum CodingKeys: String, CodingKey {
        case meetDailyTargets  = "meet_daily_targets"
        case moveEveryHour     = "move_every_hour"
        case recoveryTime      = "recovery_time"
        case stayActive        = "stay_active"
        case trainingFrequency = "training_frequency"
        case trainingVolume    = "training_volume"
    }
}

// MARK: - Heart Rate

struct OuraHeartRateResponse: Codable {
    let data: [OuraHeartRateSample]
    let nextToken: String?
    enum CodingKeys: String, CodingKey {
        case data
        case nextToken = "next_token"
    }
}

struct OuraHeartRateSample: Codable {
    let bpm: Int
    let source: String
    let timestamp: String
    let timestampUnix: Int?

    var date: Date? { ISO8601DateFormatter().date(from: timestamp) }

    enum CodingKeys: String, CodingKey {
        case bpm, source, timestamp
        case timestampUnix = "timestamp_unix"
    }
}

// MARK: - Workout

struct OuraWorkoutResponse: Decodable {
    let data: [OuraWorkoutEntry]
    let nextToken: String?
    enum CodingKeys: String, CodingKey {
        case data
        case nextToken = "next_token"
    }
}

struct OuraWorkoutEntry: Decodable, Identifiable {
    let id: String
    let activity: String
    let calories: Double?
    let day: String
    let distance: Double?
    let endDatetime: String
    let intensity: String?
    let label: String?
    let source: String?
    let startDatetime: String

    // Direct init for CSV import
    init(id: String, day: String, activity: String?, calories: Double?, distance: Double?,
         intensity: String?, label: String?, startDatetime: String?, endDatetime: String?,
         startDate: Date? = nil, endDate: Date? = nil) {
        self.id            = id
        self.day           = day
        self.activity      = activity ?? "unknown"
        self.calories      = calories
        self.distance      = distance
        self.intensity     = intensity
        self.label         = label
        self.source        = "csv_import"
        self.startDatetime = startDatetime ?? ""
        self.endDatetime   = endDatetime   ?? ""
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id            = try c.decode(String.self, forKey: .id)
        activity      = try c.decode(String.self, forKey: .activity)
        day           = try c.decode(String.self, forKey: .day)
        endDatetime   = (try? c.decodeIfPresent(String.self, forKey: .endDatetime))   ?? ""
        startDatetime = (try? c.decodeIfPresent(String.self, forKey: .startDatetime)) ?? ""
        if let d = try? c.decodeIfPresent(Double.self, forKey: .calories) {
            calories = d
        } else if let i = try? c.decodeIfPresent(Int.self, forKey: .calories) {
            calories = Double(i)
        } else { calories = nil }
        distance  = try? c.decodeIfPresent(Double.self, forKey: .distance)
        intensity = try? c.decodeIfPresent(String.self, forKey: .intensity)
        label     = try? c.decodeIfPresent(String.self, forKey: .label)
        source    = try? c.decodeIfPresent(String.self, forKey: .source)
    }

    enum CodingKeys: String, CodingKey {
        case id, activity, calories, day, distance, intensity, label, source
        case endDatetime   = "end_datetime"
        case startDatetime = "start_datetime"
    }

    var startDate: Date? { ISO8601DateFormatter().date(from: startDatetime) }
    var endDate:   Date? { ISO8601DateFormatter().date(from: endDatetime) }

    var durationMinutes: Int? {
        guard let s = startDate, let e = endDate else { return nil }
        return Int(e.timeIntervalSince(s) / 60)
    }

    var activityDisplayName: String {
        activity.replacingOccurrences(of: "_", with: " ").capitalized
    }
}

// MARK: - Dashboard summary (aggregated locally from all endpoints)

struct OuraDailySummary: Codable {
    let day: String
    let sleepStart: Date?
    let sleepEnd: Date?
    // Sleep core
    let sleepScore: Int?
    let sleepContributors: SleepContributors?
    let deepSleepMinutes: Int?
    let remSleepMinutes: Int?
    let lightSleepMinutes: Int?
    let totalSleepMinutes: Int?
    let awakeMinutes: Int?
    let timeInBedMinutes: Int?
    let sleepEfficiency: Int?
    let averageHrv: Int?
    let lowestHR: Int?
    let averageSpO2: Double?
    let temperatureDeviation: Double?
    let temperatureTrendDeviation: Double?
    let respiratoryRate: Double?
    let restlessPeriods: Int?
    let sleepLatencySeconds: Int?
    let sleepPhase5Min: String?
    let sleepPhase30Sec: String?
    let breathingDisturbanceIndex: Int?     // [BUG FIX: was Double, spec is Int]
    // Readiness
    let readinessScore: Int?
    let readinessContributors: ReadinessContributors?
    // Activity
    let activityScore: Int?
    let activityContributors: ActivityContributors?
    let steps: Int?
    let activeCalories: Int?
    let totalCalories: Int?
    let highActivityMinutes: Int?
    let mediumActivityMinutes: Int?
    let lowActivityMinutes: Int?
    let sedentaryMinutes: Int?
    let restMinutes: Int?
    let nonWearMinutes: Int?
    let inactivityAlerts: Int?
    let targetCalories: Int?
    let metersToTarget: Int?
    let equivalentWalkingKm: Double?
    let averageMet: Double?
    // Stress
    let stressHighMinutes: Int?
    let recoveryHighMinutes: Int?
    let stressSummary: String?
    // Resilience
    let resilienceLevel: String?
    let resilienceContributors: ResilienceContributors?
    // Cardiovascular age
    let cardiovascularAge: Int?
    // VO2 Max  [NEW]
    let vo2Max: Int?
    // Sleep time recommendation  [NEW]
    let sleepTimeRecommendation: String?
    let optimalBedtimeStart: String?    // "HH:MM"
    let optimalBedtimeEnd: String?      // "HH:MM"

    /// Parse 5-min hypnogram into consolidated phases
    var hypnogramPhases: [(stage: Int, minutes: Double)] {
        guard let s = sleepPhase5Min, !s.isEmpty else { return [] }
        var result: [(Int, Double)] = []
        var current: Int? = nil
        var count: Double = 0
        for ch in s {
            guard let d = ch.wholeNumberValue else { continue }
            if d == current { count += 5 }
            else { if let c = current { result.append((c, count)) }; current = d; count = 5 }
        }
        if let c = current { result.append((c, count)) }
        return result
    }
}
