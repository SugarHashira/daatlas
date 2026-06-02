import Foundation
import HealthKit

enum SyncError: Error, LocalizedError {
    case notConfigured
    case noHealthKit
    case nightscoutError(Error)
    case healthKitError(Error)
    
    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Nightscout is not configured"
        case .noHealthKit:
            return "HealthKit is not available"
        case .nightscoutError(let error):
            return "Nightscout error: \(error.localizedDescription)"
        case .healthKitError(let error):
            return "HealthKit error: \(error.localizedDescription)"
        }
    }
}

struct SyncResult {
    var treatmentsProcessed: Int = 0
    var treatmentsSynced: Int = 0
    var glucoseProcessed: Int = 0
    var glucoseSynced: Int = 0
    var insulinSynced: Int = 0
    var carbsSynced: Int = 0
    // Items found on Nightscout not yet in HealthKit at time of this sync
    var pendingGlucose: Int = 0
    var pendingInsulin: Int = 0
    var pendingCarbs: Int = 0
    var errors: [String] = []
}

actor SyncService {
    static let shared = SyncService()
    
    private init() {}
    
    func syncAll() async throws -> SyncResult {
        guard let healthKit = HealthKitService.shared else {
            throw SyncError.noHealthKit
        }

        let settings = UserSettings.shared
        guard await settings.nightscoutURL != nil, await settings.nightscoutAPISecret != nil else {
            throw SyncError.notConfigured
        }

        var result = SyncResult()

        let lookbackDays = await settings.lookbackDays
        let since = Calendar.current.date(byAdding: .day, value: -lookbackDays, to: Date()) ?? Date.distantPast
        let now = Date()

        let doCarbs = await settings.syncCarbs
        let doInsulin = await settings.syncInsulin
        let doGlucose = await settings.syncGlucose

        let syncedTreatmentIDs = await settings.syncedTreatmentIDs
        let syncedGlucoseIDs   = await settings.syncedGlucoseIDs

        do {
            let nightscout = try await NightscoutService.shared

            if doCarbs || doInsulin {
                guard
                    let insulinType = HKQuantityType.quantityType(forIdentifier: .insulinDelivery),
                    let carbsType   = HKQuantityType.quantityType(forIdentifier: .dietaryCarbohydrates)
                else { throw SyncError.noHealthKit }

                // --- Primary dedup: Nightscout treatment IDs stored in HK metadata ---
                // (source-filtered — only checks samples THIS app wrote)
                async let fetchCarbIDs    = doCarbs   ? healthKit.existingNightscoutTreatmentIDs(type: carbsType,   from: since, to: now) : Set<String>()
                async let fetchInsulinIDs = doInsulin ? healthKit.existingNightscoutTreatmentIDs(type: insulinType, from: since, to: now) : Set<String>()
                // --- Fallback dedup: minute-rounded timestamps for old entries without IDs ---
                async let fetchCarbDates    = doCarbs   ? healthKit.existingCarbsDates(from: since, to: now)   : Set<TimeInterval>()
                async let fetchInsulinDates = doInsulin ? healthKit.existingInsulinDates(from: since, to: now) : Set<TimeInterval>()

                let (existingCarbIDs, existingInsulinIDs, existingCarbDates, existingInsulinDates) =
                    await (fetchCarbIDs, fetchInsulinIDs, fetchCarbDates, fetchInsulinDates)

                let treatments = try await nightscout.fetchTreatments(since: since)
                result.treatmentsProcessed = treatments.count

                for treatment in treatments {
                    guard let date = treatment.treatmentDate else { continue }
                    let nsID = treatment.id   // Nightscout MongoDB _id (unique per treatment)

                    if doCarbs, let carbs = treatment.carbs, carbs > 0 {
                        result.pendingCarbs += 1
                        let alreadySynced = nsID.map { syncedTreatmentIDs.contains($0) || existingCarbIDs.contains($0) } ?? false
                        let byDate = alreadySynced ? false : healthKit.isDateAlreadySynced(date, in: existingCarbDates)
                        if !alreadySynced && !byDate {
                            do {
                                try await healthKit.saveCarbohydrates(grams: carbs, date: date, nightscoutID: nsID)
                                result.carbsSynced += 1
                                result.treatmentsSynced += 1
                                if let id = nsID { await settings.addSyncedTreatmentID(id) }
                            } catch {
                                result.errors.append("Failed to save carbs: \(error.localizedDescription)")
                            }
                        }
                    }

                    if doInsulin, let insulin = treatment.insulin, insulin > 0 {
                        result.pendingInsulin += 1
                        let alreadySynced = nsID.map { syncedTreatmentIDs.contains($0) || existingInsulinIDs.contains($0) } ?? false
                        let byDate = alreadySynced ? false : healthKit.isDateAlreadySynced(date, in: existingInsulinDates)
                        if !alreadySynced && !byDate {
                            let isBasal = treatment.eventType?.lowercased().contains("basal") ?? false
                            do {
                                try await healthKit.saveInsulin(units: insulin, date: date, isBasal: isBasal, nightscoutID: nsID)
                                result.insulinSynced += 1
                                result.treatmentsSynced += 1
                                if let id = nsID { await settings.addSyncedTreatmentID(id) }
                            } catch {
                                result.errors.append("Failed to save insulin: \(error.localizedDescription)")
                            }
                        }
                    }
                }
            }

            if doGlucose {
                let existingGlucoseDates = await healthKit.existingGlucoseDates(from: since, to: now)
                let glucoseEntries = try await nightscout.fetchGlucoseEntries(since: since)
                result.glucoseProcessed = glucoseEntries.count

                let unit = await settings.glucoseUnit

                for entry in glucoseEntries {
                    result.pendingGlucose += 1
                    let gID = entry.id
                    let alreadySynced = gID.map { syncedGlucoseIDs.contains($0) } ?? false
                    if alreadySynced { continue }
                    if healthKit.isDateAlreadySynced(entry.timestamp, in: existingGlucoseDates) { continue }

                    let value: Double
                    let hkUnit: HKUnit

                    switch unit {
                    case .mgdl:
                        value = entry.mgDlValue
                        hkUnit = HKUnit(from: "mg/dL")
                    case .mmol:
                        value = entry.mmolValue
                        hkUnit = HKUnit(from: "mmol/L")
                    }

                    do {
                        try await healthKit.saveBloodGlucose(value: value, unit: hkUnit, date: entry.timestamp)
                        result.glucoseSynced += 1
                        if let id = gID { await settings.addSyncedGlucoseID(id) }
                    } catch {
                        result.errors.append("Failed to save glucose: \(error.localizedDescription)")
                    }
                }
            }

            await settings.setLastSyncDate(now)
            let log = SyncLog(
                date: now,
                pendingGlucose: result.pendingGlucose,
                pendingInsulin: result.pendingInsulin,
                pendingCarbs: result.pendingCarbs,
                glucoseSynced: result.glucoseSynced,
                insulinSynced: result.insulinSynced,
                carbsSynced: result.carbsSynced,
                errors: result.errors
            )
            await settings.appendSyncLog(log)

        } catch let error as NightscoutError {
            throw SyncError.nightscoutError(error)
        } catch let error as HealthKitError {
            throw SyncError.healthKitError(error)
        }

        return result
    }
    
    func syncOuraToHealthKit(summaries: [OuraDailySummary]) async -> [String] {
        guard let healthKit = HealthKitService.shared else { return ["HealthKit unavailable"] }
        let settings = UserSettings.shared
        let syncedDays = await settings.syncedOuraDays
        let calendar = Calendar.current
        var errors: [String] = []

        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.timeZone = TimeZone.current

        for summary in summaries {
            let day = summary.day
            guard !syncedDays.contains(day) else { continue }
            guard let date = fmt.date(from: day) else { continue }

            let startOfDay = calendar.startOfDay(for: date)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay
            let noon = calendar.date(byAdding: .hour, value: 12, to: startOfDay) ?? startOfDay

            if let sleepStart = summary.sleepStart, let sleepEnd = summary.sleepEnd {
                do { try await healthKit.saveSleep(start: sleepStart, end: sleepEnd, stage: .asleepUnspecified) }
                catch { errors.append("Sleep \(day): \(error.localizedDescription)") }
            }

            if let hrv = summary.averageHrv {
                let ref = summary.sleepEnd ?? noon
                do { try await healthKit.saveHRV(rmssd: Double(hrv), date: ref) }
                catch { errors.append("HRV \(day): \(error.localizedDescription)") }
            }

            if let hr = summary.lowestHR {
                let ref = summary.sleepEnd ?? noon
                do { try await healthKit.saveHeartRate(bpm: Double(hr), date: ref) }
                catch { errors.append("HR \(day): \(error.localizedDescription)") }
            }

            if let spo2 = summary.averageSpO2 {
                let ref = summary.sleepStart.flatMap { s in summary.sleepEnd.map { e in s.addingTimeInterval(e.timeIntervalSince(s) / 2) } } ?? noon
                do { try await healthKit.saveSpO2(percentage: spo2, date: ref) }
                catch { errors.append("SpO2 \(day): \(error.localizedDescription)") }
            }

            if let temp = summary.temperatureDeviation {
                let ref = summary.sleepEnd ?? noon
                do { try await healthKit.saveBodyTemperatureDeviation(celsius: temp, date: ref) }
                catch { errors.append("Temp \(day): \(error.localizedDescription)") }
            }

            if let rr = summary.respiratoryRate {
                let ref = summary.sleepStart.flatMap { s in summary.sleepEnd.map { e in s.addingTimeInterval(e.timeIntervalSince(s) / 2) } } ?? noon
                do { try await healthKit.saveRespiratoryRate(breathsPerMinute: rr, date: ref) }
                catch { errors.append("RR \(day): \(error.localizedDescription)") }
            }

            if let kcal = summary.activeCalories, kcal > 0 {
                do { try await healthKit.saveActiveEnergy(kcal: Double(kcal), start: startOfDay, end: endOfDay) }
                catch { errors.append("ActiveEnergy \(day): \(error.localizedDescription)") }
            }

            if let steps = summary.steps, steps > 0 {
                do { try await healthKit.saveSteps(count: steps, start: startOfDay, end: endOfDay) }
                catch { errors.append("Steps \(day): \(error.localizedDescription)") }
            }

            await settings.addSyncedOuraDay(day)
        }

        return errors
    }

    func testConnection() async throws -> Bool {
        let nightscout = try await NightscoutService.shared
        return try await nightscout.testConnection()
    }

    func getLastSyncDate() async -> Date? {
        return await UserSettings.shared.lastSyncDate
    }
}

