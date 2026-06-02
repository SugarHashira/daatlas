import Foundation
import HealthKit

enum HealthKitError: Error, LocalizedError {
    case notAvailable
    case authorizationDenied
    case typeNotAvailable
    case saveFailed(Error)
    case queryFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "HealthKit is not available on this device"
        case .authorizationDenied:
            return "HealthKit authorization was denied"
        case .typeNotAvailable:
            return "Requested HealthKit type is not available"
        case .saveFailed(let error):
            return "Failed to save: \(error.localizedDescription)"
        case .queryFailed(let error):
            return "Query failed: \(error.localizedDescription)"
        }
    }
}

actor HealthKitService {
    private let healthStore: HKHealthStore

    /// Metadata key used to store the originating Nightscout treatment `_id`
    /// on every insulin / carbs sample we write. Used for robust deduplication.
    static let nightscoutIDKey = "NightscoutTreatmentID"
    
    static var shared: HealthKitService? {
        guard HKHealthStore.isHealthDataAvailable() else {
            return nil
        }
        return HealthKitService()
    }
    
    private init() {
        self.healthStore = HKHealthStore()
    }
    
    private var typesToShare: Set<HKSampleType> {
        let types: Set<HKSampleType> = [
            HKQuantityType.quantityType(forIdentifier: .bloodGlucose)!,
            HKQuantityType.quantityType(forIdentifier: .insulinDelivery)!,
            HKQuantityType.quantityType(forIdentifier: .dietaryCarbohydrates)!,
            HKQuantityType.quantityType(forIdentifier: .heartRate)!,
            HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!,
            HKQuantityType.quantityType(forIdentifier: .oxygenSaturation)!,
            HKQuantityType.quantityType(forIdentifier: .bodyTemperature)!,
            HKQuantityType.quantityType(forIdentifier: .respiratoryRate)!,
            HKCategoryType.categoryType(forIdentifier: .sleepAnalysis)!,
            HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKQuantityType.quantityType(forIdentifier: .stepCount)!
        ]
        return types
    }

    private var typesToRead: Set<HKObjectType> {
        [
            HKQuantityType.quantityType(forIdentifier: .bloodGlucose)!,
            HKQuantityType.quantityType(forIdentifier: .insulinDelivery)!,
            HKQuantityType.quantityType(forIdentifier: .dietaryCarbohydrates)!,
            HKQuantityType.quantityType(forIdentifier: .heartRate)!,
            HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!,
            HKQuantityType.quantityType(forIdentifier: .oxygenSaturation)!,
            HKQuantityType.quantityType(forIdentifier: .bodyTemperature)!,
            HKQuantityType.quantityType(forIdentifier: .respiratoryRate)!,
            HKCategoryType.categoryType(forIdentifier: .sleepAnalysis)!,
            HKCharacteristicType.characteristicType(forIdentifier: .dateOfBirth)!,
            HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKQuantityType.quantityType(forIdentifier: .stepCount)!
        ]
    }
    
    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitError.notAvailable
        }
        
        try await healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead)
    }
    
    func saveBloodGlucose(value: Double, unit: HKUnit, date: Date) async throws {
        guard let type = HKQuantityType.quantityType(forIdentifier: .bloodGlucose) else {
            throw HealthKitError.typeNotAvailable
        }
        
        let quantity = HKQuantity(unit: unit, doubleValue: value)
        
        let sample = HKQuantitySample(
            type: type,
            quantity: quantity,
            start: date,
            end: date,
            metadata: ["HKWasUserEntered": false]
        )
        
        do {
            try await healthStore.save(sample)
        } catch {
            throw HealthKitError.saveFailed(error)
        }
    }
    
    func saveInsulin(units: Double, date: Date, isBasal: Bool, nightscoutID: String? = nil) async throws {
        guard let type = HKQuantityType.quantityType(forIdentifier: .insulinDelivery) else {
            throw HealthKitError.typeNotAvailable
        }
        let quantity = HKQuantity(unit: .internationalUnit(), doubleValue: units)
        let reason: HKInsulinDeliveryReason = isBasal ? .basal : .bolus
        var metadata: [String: Any] = [HKMetadataKeyInsulinDeliveryReason: reason.rawValue]
        if let id = nightscoutID { metadata[HealthKitService.nightscoutIDKey] = id }
        let sample = HKQuantitySample(type: type, quantity: quantity,
                                      start: date, end: date, metadata: metadata)
        do {
            try await healthStore.save(sample)
        } catch {
            throw HealthKitError.saveFailed(error)
        }
    }

    func saveCarbohydrates(grams: Double, date: Date, nightscoutID: String? = nil) async throws {
        guard let type = HKQuantityType.quantityType(forIdentifier: .dietaryCarbohydrates) else {
            throw HealthKitError.typeNotAvailable
        }
        let quantity = HKQuantity(unit: .gram(), doubleValue: grams)
        var metadata: [String: Any] = ["HKWasUserEntered": false]
        if let id = nightscoutID { metadata[HealthKitService.nightscoutIDKey] = id }
        let sample = HKQuantitySample(type: type, quantity: quantity,
                                      start: date, end: date, metadata: metadata)
        do {
            try await healthStore.save(sample)
        } catch {
            throw HealthKitError.saveFailed(error)
        }
    }
    
    // Round a date to the nearest minute for fuzzy matching
    private func roundToMinute(_ date: Date) -> TimeInterval {
        return (date.timeIntervalSince1970 / 60).rounded() * 60
    }

    /// Fetch start-date timestamps (rounded to minute) for samples of `type` written by this app.
    /// Source-filtered so pump-app entries don't pollute the dedup check.
    private func fetchExistingSampleDates(type: HKQuantityType, from start: Date, to end: Date) async -> Set<TimeInterval> {
        let datePred   = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let sourcePred = HKQuery.predicateForObjects(from: [HKSource.default()])
        let predicate  = NSCompoundPredicate(andPredicateWithSubpredicates: [datePred, sourcePred])
        do {
            let samples = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[HKSample], Error>) in
                let query = HKSampleQuery(sampleType: type, predicate: predicate,
                                          limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, s, e in
                    if let e { continuation.resume(throwing: e) }
                    else      { continuation.resume(returning: s ?? []) }
                }
                healthStore.execute(query)
            }
            return Set(samples.map { roundToMinute($0.startDate) })
        } catch { return [] }
    }

    /// Returns the set of Nightscout treatment IDs already written to HealthKit by this app.
    /// Primary deduplication key — immune to timestamp drift and concurrent-sync races.
    func existingNightscoutTreatmentIDs(type: HKQuantityType, from start: Date, to end: Date) async -> Set<String> {
        let datePred   = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let sourcePred = HKQuery.predicateForObjects(from: [HKSource.default()])
        let predicate  = NSCompoundPredicate(andPredicateWithSubpredicates: [datePred, sourcePred])
        do {
            let samples = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[HKSample], Error>) in
                let query = HKSampleQuery(sampleType: type, predicate: predicate,
                                          limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, s, e in
                    if let e { continuation.resume(throwing: e) }
                    else      { continuation.resume(returning: s ?? []) }
                }
                healthStore.execute(query)
            }
            return Set(samples.compactMap { $0.metadata?[HealthKitService.nightscoutIDKey] as? String })
        } catch { return [] }
    }

    func existingGlucoseDates(from start: Date, to end: Date) async -> Set<TimeInterval> {
        guard let type = HKQuantityType.quantityType(forIdentifier: .bloodGlucose) else { return [] }
        return await fetchExistingSampleDates(type: type, from: start, to: end)
    }

    func existingInsulinDates(from start: Date, to end: Date) async -> Set<TimeInterval> {
        guard let type = HKQuantityType.quantityType(forIdentifier: .insulinDelivery) else { return [] }
        return await fetchExistingSampleDates(type: type, from: start, to: end)
    }

    func existingCarbsDates(from start: Date, to end: Date) async -> Set<TimeInterval> {
        guard let type = HKQuantityType.quantityType(forIdentifier: .dietaryCarbohydrates) else { return [] }
        return await fetchExistingSampleDates(type: type, from: start, to: end)
    }

    nonisolated func isDateAlreadySynced(_ date: Date, in existingDates: Set<TimeInterval>) -> Bool {
        let rounded = (date.timeIntervalSince1970 / 60).rounded() * 60
        return existingDates.contains(rounded)
    }

    func fetchLastSyncDate() async -> Date? {
        guard let type = HKQuantityType.quantityType(forIdentifier: .insulinDelivery) else {
            return nil
        }
        
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        
        do {
            let samples = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[HKSample], Error>) in
                let query = HKSampleQuery(
                    sampleType: type,
                    predicate: nil,
                    limit: 1,
                    sortDescriptors: [sortDescriptor]
                ) { _, samples, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: samples ?? [])
                    }
                }
                healthStore.execute(query)
            }
            
            return samples.first?.endDate
        } catch {
            return nil
        }
    }

    // MARK: - Oura writes

    func saveSleep(start: Date, end: Date, stage: HKCategoryValueSleepAnalysis) async throws {
        guard let type = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else {
            throw HealthKitError.typeNotAvailable
        }
        let sample = HKCategorySample(type: type, value: stage.rawValue, start: start, end: end)
        do { try await healthStore.save(sample) }
        catch { throw HealthKitError.saveFailed(error) }
    }

    func saveHeartRate(bpm: Double, date: Date) async throws {
        guard let type = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
            throw HealthKitError.typeNotAvailable
        }
        let quantity = HKQuantity(unit: HKUnit(from: "count/min"), doubleValue: bpm)
        let sample = HKQuantitySample(type: type, quantity: quantity, start: date, end: date)
        do { try await healthStore.save(sample) }
        catch { throw HealthKitError.saveFailed(error) }
    }

    func saveHRV(rmssd: Double, date: Date) async throws {
        guard let type = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else {
            throw HealthKitError.typeNotAvailable
        }
        let quantity = HKQuantity(unit: .secondUnit(with: .milli), doubleValue: rmssd)
        let sample = HKQuantitySample(type: type, quantity: quantity, start: date, end: date)
        do { try await healthStore.save(sample) }
        catch { throw HealthKitError.saveFailed(error) }
    }

    func saveSpO2(percentage: Double, date: Date) async throws {
        guard let type = HKQuantityType.quantityType(forIdentifier: .oxygenSaturation) else {
            throw HealthKitError.typeNotAvailable
        }
        let quantity = HKQuantity(unit: .percent(), doubleValue: percentage / 100.0)
        let sample = HKQuantitySample(type: type, quantity: quantity, start: date, end: date)
        do { try await healthStore.save(sample) }
        catch { throw HealthKitError.saveFailed(error) }
    }

    func saveBodyTemperatureDeviation(celsius: Double, date: Date) async throws {
        guard let type = HKQuantityType.quantityType(forIdentifier: .bodyTemperature) else {
            throw HealthKitError.typeNotAvailable
        }
        let quantity = HKQuantity(unit: .degreeCelsius(), doubleValue: celsius)
        let sample = HKQuantitySample(type: type, quantity: quantity, start: date, end: date)
        do { try await healthStore.save(sample) }
        catch { throw HealthKitError.saveFailed(error) }
    }

    func saveRespiratoryRate(breathsPerMinute: Double, date: Date) async throws {
        guard let type = HKQuantityType.quantityType(forIdentifier: .respiratoryRate) else {
            throw HealthKitError.typeNotAvailable
        }
        let quantity = HKQuantity(unit: HKUnit(from: "count/min"), doubleValue: breathsPerMinute)
        let sample = HKQuantitySample(type: type, quantity: quantity, start: date, end: date)
        do { try await healthStore.save(sample) }
        catch { throw HealthKitError.saveFailed(error) }
    }

    func saveActiveEnergy(kcal: Double, start: Date, end: Date) async throws {
        guard let type = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else {
            throw HealthKitError.typeNotAvailable
        }
        let quantity = HKQuantity(unit: .kilocalorie(), doubleValue: kcal)
        let sample = HKQuantitySample(type: type, quantity: quantity, start: start, end: end)
        do { try await healthStore.save(sample) }
        catch { throw HealthKitError.saveFailed(error) }
    }

    func saveSteps(count: Int, start: Date, end: Date) async throws {
        guard let type = HKQuantityType.quantityType(forIdentifier: .stepCount) else {
            throw HealthKitError.typeNotAvailable
        }
        let quantity = HKQuantity(unit: .count(), doubleValue: Double(count))
        let sample = HKQuantitySample(type: type, quantity: quantity, start: start, end: end)
        do { try await healthStore.save(sample) }
        catch { throw HealthKitError.saveFailed(error) }
    }

    // Existing sleep dates for diff
    func existingSleepDates(from start: Date, to end: Date) async -> Set<TimeInterval> {
        guard let type = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else { return [] }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        do {
            let samples = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[HKSample], Error>) in
                let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
                    if let error = error { continuation.resume(throwing: error) }
                    else { continuation.resume(returning: samples ?? []) }
                }
                healthStore.execute(query)
            }
            return Set(samples.map { roundToMinute($0.startDate) })
        } catch { return [] }
    }

    func existingHRDates(from start: Date, to end: Date) async -> Set<TimeInterval> {
        guard let type = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return [] }
        return await fetchExistingSampleDates(type: type, from: start, to: end)
    }

    func existingHRVDates(from start: Date, to end: Date) async -> Set<TimeInterval> {
        guard let type = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else { return [] }
        return await fetchExistingSampleDates(type: type, from: start, to: end)
    }

    /// Returns heart rate readings (bpm) in a date window, sorted by time.
    func heartRateReadings(from start: Date, to end: Date) async -> [(Date, Double)] {
        guard let type = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return [] }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        let unit = HKUnit(from: "count/min")
        do {
            let samples = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<[HKSample], Error>) in
                let q = HKSampleQuery(sampleType: type, predicate: predicate,
                                      limit: HKObjectQueryNoLimit, sortDescriptors: [sort]) { _, s, e in
                    if let e { cont.resume(throwing: e) } else { cont.resume(returning: s ?? []) }
                }
                healthStore.execute(q)
            }
            return samples.compactMap { s -> (Date, Double)? in
                guard let q = s as? HKQuantitySample else { return nil }
                return (q.startDate, q.quantity.doubleValue(for: unit))
            }
        } catch { return [] }
    }

    /// Returns HRV (SDNN ms) readings in a date window, sorted by time.
    func hrvReadings(from start: Date, to end: Date) async -> [(Date, Double)] {
        guard let type = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else { return [] }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        let unit = HKUnit.secondUnit(with: .milli)
        do {
            let samples = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<[HKSample], Error>) in
                let q = HKSampleQuery(sampleType: type, predicate: predicate,
                                      limit: HKObjectQueryNoLimit, sortDescriptors: [sort]) { _, s, e in
                    if let e { cont.resume(throwing: e) } else { cont.resume(returning: s ?? []) }
                }
                healthStore.execute(q)
            }
            return samples.compactMap { s -> (Date, Double)? in
                guard let q = s as? HKQuantitySample else { return nil }
                return (q.startDate, q.quantity.doubleValue(for: unit))
            }
        } catch { return [] }
    }

    /// Returns total insulin units grouped by calendar day (yyyy-MM-dd).
    func dailyTotalInsulin(from start: Date, to end: Date) async -> [String: Double] {
        guard let type = HKQuantityType.quantityType(forIdentifier: .insulinDelivery) else { return [:] }
        let datePredicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        // Only count insulin written by this app to avoid double-counting with pump apps or other sources
        let sourcePredicate = HKQuery.predicateForObjects(from: [HKSource.default()])
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [datePredicate, sourcePredicate])
        let unit = HKUnit.internationalUnit()
        let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
        do {
            let samples = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<[HKSample], Error>) in
                let q = HKSampleQuery(sampleType: type, predicate: predicate,
                                      limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, s, e in
                    if let e { cont.resume(throwing: e) } else { cont.resume(returning: s ?? []) }
                }
                healthStore.execute(q)
            }
            var groups: [String: Double] = [:]
            for sample in samples {
                guard let q = sample as? HKQuantitySample else { continue }
                let day = fmt.string(from: q.startDate)
                groups[day, default: 0] += q.quantity.doubleValue(for: unit)
            }
            return groups
        } catch { return [:] }
    }

    /// Returns all blood glucose readings (mg/dL) for the given day, sorted by time.
    func todayGlucoseReadings(on date: Date = Date()) async -> [(Date, Double)] {
        guard let type = HKQuantityType.quantityType(forIdentifier: .bloodGlucose) else { return [] }
        let cal   = Calendar.current
        let start = cal.startOfDay(for: date)
        let end   = min(cal.date(byAdding: .day, value: 1, to: start) ?? start, Date())
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        let unit = HKUnit(from: "mg/dL")
        do {
            let samples = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<[HKSample], Error>) in
                let q = HKSampleQuery(sampleType: type, predicate: predicate,
                                      limit: HKObjectQueryNoLimit, sortDescriptors: [sort]) { _, s, e in
                    if let e { cont.resume(throwing: e) } else { cont.resume(returning: s ?? []) }
                }
                healthStore.execute(q)
            }
            return samples.compactMap { s -> (Date, Double)? in
                guard let q = s as? HKQuantitySample else { return nil }
                return (q.startDate, q.quantity.doubleValue(for: unit))
            }
        } catch { return [] }
    }

    /// Returns all insulin doses (IU) for the given day from this app's source, sorted by time.
    func todayInsulinDoses(on date: Date = Date()) async -> [(Date, Double)] {
        guard let type = HKQuantityType.quantityType(forIdentifier: .insulinDelivery) else { return [] }
        let cal   = Calendar.current
        let start = cal.startOfDay(for: date)
        let end   = min(cal.date(byAdding: .day, value: 1, to: start) ?? start, Date())
        let datePred   = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let sourcePred = HKQuery.predicateForObjects(from: [HKSource.default()])
        let predicate  = NSCompoundPredicate(andPredicateWithSubpredicates: [datePred, sourcePred])
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        let unit = HKUnit.internationalUnit()
        do {
            let samples = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<[HKSample], Error>) in
                let q = HKSampleQuery(sampleType: type, predicate: predicate,
                                      limit: HKObjectQueryNoLimit, sortDescriptors: [sort]) { _, s, e in
                    if let e { cont.resume(throwing: e) } else { cont.resume(returning: s ?? []) }
                }
                healthStore.execute(q)
            }
            return samples.compactMap { s -> (Date, Double)? in
                guard let q = s as? HKQuantitySample else { return nil }
                return (q.startDate, q.quantity.doubleValue(for: unit))
            }
        } catch { return [] }
    }

    /// Returns blood glucose readings (mg/dL) between two arbitrary dates, sorted by time.
    func glucoseReadings(from start: Date, to end: Date) async -> [(Date, Double)] {
        guard let type = HKQuantityType.quantityType(forIdentifier: .bloodGlucose) else { return [] }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        let unit = HKUnit(from: "mg/dL")
        do {
            let samples = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<[HKSample], Error>) in
                let q = HKSampleQuery(sampleType: type, predicate: predicate,
                                      limit: HKObjectQueryNoLimit, sortDescriptors: [sort]) { _, s, e in
                    if let e { cont.resume(throwing: e) } else { cont.resume(returning: s ?? []) }
                }
                healthStore.execute(q)
            }
            return samples.compactMap { s -> (Date, Double)? in
                guard let q = s as? HKQuantitySample else { return nil }
                return (q.startDate, q.quantity.doubleValue(for: unit))
            }
        } catch { return [] }
    }

    /// Returns average blood glucose (mg/dL) grouped by calendar day (yyyy-MM-dd).
    func dailyAverageGlucose(from start: Date, to end: Date) async -> [String: Double] {
        guard let type = HKQuantityType.quantityType(forIdentifier: .bloodGlucose) else { return [:] }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let unit = HKUnit(from: "mg/dL")
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"

        do {
            let samples = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<[HKSample], Error>) in
                let q = HKSampleQuery(sampleType: type, predicate: predicate,
                                      limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, s, e in
                    if let e { cont.resume(throwing: e) }
                    else      { cont.resume(returning: s ?? []) }
                }
                healthStore.execute(q)
            }
            // Group by day, average each group
            var groups: [String: [Double]] = [:]
            for sample in samples {
                guard let q = sample as? HKQuantitySample else { continue }
                let day = fmt.string(from: q.startDate)
                let val = q.quantity.doubleValue(for: unit)
                groups[day, default: []].append(val)
            }
            return groups.mapValues { vals in vals.reduce(0, +) / Double(vals.count) }
        } catch {
            return [:]
        }
    }

    /// Returns Time-in-Range percentage (0–100) grouped by calendar day (yyyy-MM-dd).
    func dailyTIR(from start: Date, to end: Date, low: Double, high: Double) async -> [String: Double] {
        guard let type = HKQuantityType.quantityType(forIdentifier: .bloodGlucose) else { return [:] }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let unit = HKUnit(from: "mg/dL")
        let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
        do {
            let samples = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<[HKSample], Error>) in
                let q = HKSampleQuery(sampleType: type, predicate: predicate,
                                      limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, s, e in
                    if let e { cont.resume(throwing: e) } else { cont.resume(returning: s ?? []) }
                }
                healthStore.execute(q)
            }
            var groups: [String: [Double]] = [:]
            for sample in samples {
                guard let q = sample as? HKQuantitySample else { continue }
                groups[fmt.string(from: q.startDate), default: []].append(q.quantity.doubleValue(for: unit))
            }
            return groups.mapValues { vals in
                let inRange = vals.filter { $0 >= low && $0 <= high }.count
                return Double(inRange) / Double(vals.count) * 100.0
            }
        } catch { return [:] }
    }
}
