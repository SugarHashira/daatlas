import Foundation
import SwiftUI

// MARK: - Workout models (defined here so they share the same module as UserSettings)

struct WorkoutEntry: Codable, Identifiable {
    let id: UUID
    let date: Date
    let activityType: String
    let feeling: WorkoutFeeling
    let notes: String

    init(id: UUID = UUID(), date: Date = Date(), activityType: String,
         feeling: WorkoutFeeling, notes: String = "") {
        self.id = id; self.date = date; self.activityType = activityType
        self.feeling = feeling; self.notes = notes
    }
}

enum WorkoutFeeling: String, Codable, CaseIterable {
    case veryGood  = "Very Good"
    case good      = "Good"
    case okay      = "Okay"
    case tired     = "Tired"
    case exhausted = "Exhausted"

    var emoji: String {
        switch self {
        case .veryGood:  return "🔥"
        case .good:      return "💪"
        case .okay:      return "😊"
        case .tired:     return "😮‍💨"
        case .exhausted: return "😴"
        }
    }

    var color: Color {
        switch self {
        case .veryGood:  return Color(red: 0.24, green: 0.73, blue: 0.49)
        case .good:      return Color(red: 0.31, green: 0.53, blue: 0.96)
        case .okay:      return Color(red: 0.96, green: 0.85, blue: 0.27)
        case .tired:     return Color(red: 0.96, green: 0.65, blue: 0.27)
        case .exhausted: return Color(red: 0.92, green: 0.28, blue: 0.28)
        }
    }
}

let workoutActivityTypes: [String] = [
    "Running", "Cycling", "Swimming", "Walking", "Hiking",
    "Weight Training", "Yoga", "Basketball", "Tennis",
    "Climbing", "Rowing", "HIIT", "Other"
]

// MARK: - Pump event models

enum PumpEventType: String, Codable, CaseIterable {
    case reservoirChange = "Reservoir Change"
    case podChange       = "Pod Change"
    case cannulaChange   = "Cannula Change"

    var icon: String {
        switch self {
        case .reservoirChange: return "cross.vial.fill"
        case .podChange:       return "bandage.fill"
        case .cannulaChange:   return "syringe.fill"
        }
    }

    var color: Color {
        switch self {
        case .reservoirChange: return Color(red: 0.31, green: 0.53, blue: 0.96)
        case .podChange:       return Color(red: 0.24, green: 0.73, blue: 0.49)
        case .cannulaChange:   return Color(red: 0.96, green: 0.65, blue: 0.27)
        }
    }
}

struct PumpEventEntry: Codable, Identifiable {
    let id: UUID
    let date: Date
    let eventType: PumpEventType
    let notes: String

    init(id: UUID = UUID(), date: Date = Date(), eventType: PumpEventType, notes: String = "") {
        self.id = id; self.date = date; self.eventType = eventType; self.notes = notes
    }
}

// MARK: -

actor UserSettings {
    static let shared = UserSettings()
    
    private let defaults = UserDefaults.standard
    
    private enum Keys {
        static let nightscoutURL = "nightscoutURL"
        static let nightscoutAPISecret = "nightscoutAPISecret"
        static let lastSyncDate = "lastSyncDate"
        static let syncedTreatmentIDs = "syncedTreatmentIDs"
        static let syncedGlucoseIDs = "syncedGlucoseIDs"
        static let glucoseUnit = "glucoseUnit"
        static let autoSyncEnabled = "autoSyncEnabled"
        static let syncCarbs = "syncCarbs"
        static let syncInsulin = "syncInsulin"
        static let syncGlucose = "syncGlucose"
        static let backgroundSyncInterval = "backgroundSyncInterval"
        static let lookbackDays = "lookbackDays"
        static let syncLogs = "syncLogs"
        static let tirLow  = "tirLow"
        static let tirHigh = "tirHigh"
        static let workoutLogs            = "workoutLogs"
        static let pumpEventLogs          = "pumpEventLogs"
        static let importedDailySummaries = "importedDailySummaries"
        static let journalEntries = "journalEntries"
        static let hiddenJournalItems  = "hiddenJournalItems"   // [String] — JournalItemKey rawValues
        static let customJournalItems  = "customJournalItems"   // [CustomJournalItem]
        static let kiloAPIKey          = "kiloAPIKey"
        static let kiloModel           = "kiloModel"
        static let foodEntries         = "foodEntries"
        static let dexcomUsername = "dexcomUsername"
        static let dexcomPassword = "dexcomPassword"
        static let dexcomRegion = "dexcomRegion"
        static let dexcomEnabled = "dexcomEnabled"
        static let glucoseNotificationsEnabled = "glucoseNotificationsEnabled"
        static let glucoseAlertHigh = "glucoseAlertHigh"
        static let glucoseAlertLow = "glucoseAlertLow"
        static let liveActivityDeeplinkURL = "liveActivityDeeplinkURL"
        static let liveActivityShortcutURLs = "liveActivityShortcutURLs"
        static let dexcomBuffer = "dexcomBuffer"
        static let syncedOuraDays = "syncedOuraDays"
    }
    
    private init() {}
    
    var nightscoutURL: String? {
        get { defaults.string(forKey: Keys.nightscoutURL) }
        set { defaults.set(newValue, forKey: Keys.nightscoutURL) }
    }
    
    var nightscoutAPISecret: String? {
        get { defaults.string(forKey: Keys.nightscoutAPISecret) }
        set { defaults.set(newValue, forKey: Keys.nightscoutAPISecret) }
    }
    
    var lastSyncDate: Date? {
        get { defaults.object(forKey: Keys.lastSyncDate) as? Date }
        set { defaults.set(newValue, forKey: Keys.lastSyncDate) }
    }
    
    var syncedTreatmentIDs: Set<String> {
        get { Set(defaults.stringArray(forKey: Keys.syncedTreatmentIDs) ?? []) }
        set { defaults.set(Array(newValue), forKey: Keys.syncedTreatmentIDs) }
    }
    
    var syncedGlucoseIDs: Set<String> {
        get { Set(defaults.stringArray(forKey: Keys.syncedGlucoseIDs) ?? []) }
        set { defaults.set(Array(newValue), forKey: Keys.syncedGlucoseIDs) }
    }
    
    var glucoseUnit: GlucoseUnit {
        get {
            let raw = defaults.string(forKey: Keys.glucoseUnit) ?? "mgdl"
            return GlucoseUnit(rawValue: raw) ?? .mgdl
        }
        set { defaults.set(newValue.rawValue, forKey: Keys.glucoseUnit) }
    }
    
    var autoSyncEnabled: Bool {
        get { defaults.bool(forKey: Keys.autoSyncEnabled) }
        set { defaults.set(newValue, forKey: Keys.autoSyncEnabled) }
    }

    var syncCarbs: Bool {
        get { defaults.object(forKey: Keys.syncCarbs) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Keys.syncCarbs) }
    }

    var syncInsulin: Bool {
        get { defaults.object(forKey: Keys.syncInsulin) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Keys.syncInsulin) }
    }

    var syncGlucose: Bool {
        get { defaults.object(forKey: Keys.syncGlucose) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Keys.syncGlucose) }
    }

    /// How many days back to fetch from Nightscout and compare against HealthKit
    var lookbackDays: Int {
        get { defaults.object(forKey: Keys.lookbackDays) as? Int ?? 30 }
        set { defaults.set(newValue, forKey: Keys.lookbackDays) }
    }

    /// How often to sync in minutes (e.g. 15, 30, 60)
    var backgroundSyncInterval: Int {
        get { defaults.object(forKey: Keys.backgroundSyncInterval) as? Int ?? 15 }
        set { defaults.set(newValue, forKey: Keys.backgroundSyncInterval) }
    }
    
    func addSyncedTreatmentID(_ id: String) {
        var ids = syncedTreatmentIDs
        ids.insert(id)
        syncedTreatmentIDs = ids
    }
    
    func addSyncedGlucoseID(_ id: String) {
        var ids = syncedGlucoseIDs
        ids.insert(id)
        syncedGlucoseIDs = ids
    }
    
    func isTreatmentSynced(_ id: String) -> Bool {
        syncedTreatmentIDs.contains(id)
    }
    
    func isGlucoseSynced(_ id: String) -> Bool {
        syncedGlucoseIDs.contains(id)
    }

    func setNightscoutURL(_ url: String) {
        nightscoutURL = url.isEmpty ? nil : url
    }

    func setNightscoutAPISecret(_ secret: String) {
        nightscoutAPISecret = secret.isEmpty ? nil : secret
    }

    func setGlucoseUnit(_ unit: GlucoseUnit) {
        glucoseUnit = unit
    }

    func setAutoSyncEnabled(_ enabled: Bool) {
        autoSyncEnabled = enabled
    }

    func setSyncCarbs(_ value: Bool) { syncCarbs = value }
    func setSyncInsulin(_ value: Bool) { syncInsulin = value }
    func setSyncGlucose(_ value: Bool) { syncGlucose = value }
    func setBackgroundSyncInterval(_ minutes: Int) { backgroundSyncInterval = minutes }
    func setLookbackDays(_ days: Int) { lookbackDays = days }

    func setLastSyncDate(_ date: Date?) {
        lastSyncDate = date
    }

    var syncLogs: [SyncLog] {
        get {
            guard let data = defaults.data(forKey: Keys.syncLogs),
                  let logs = try? JSONDecoder().decode([SyncLog].self, from: data) else { return [] }
            return logs
        }
        set {
            let kept = Array(newValue.suffix(100)) // keep last 100
            if let data = try? JSONEncoder().encode(kept) {
                defaults.set(data, forKey: Keys.syncLogs)
            }
        }
    }

    func appendSyncLog(_ log: SyncLog) {
        var logs = syncLogs
        logs.append(log)
        syncLogs = logs
    }

    // MARK: - Time in Range

    var tirLow: Int {
        get { defaults.object(forKey: Keys.tirLow) as? Int ?? 70 }
        set { defaults.set(newValue, forKey: Keys.tirLow) }
    }

    var tirHigh: Int {
        get { defaults.object(forKey: Keys.tirHigh) as? Int ?? 200 }
        set { defaults.set(newValue, forKey: Keys.tirHigh) }
    }

    func setTirLow(_ v: Int)  { tirLow  = v }
    func setTirHigh(_ v: Int) { tirHigh = v }

    // MARK: - Workout logs

    var workoutLogs: [WorkoutEntry] {
        get {
            guard let data = defaults.data(forKey: Keys.workoutLogs),
                  let logs = try? JSONDecoder().decode([WorkoutEntry].self, from: data) else { return [] }
            return logs
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                defaults.set(data, forKey: Keys.workoutLogs)
            }
        }
    }

    func appendWorkout(_ entry: WorkoutEntry) {
        var logs = workoutLogs
        logs.insert(entry, at: 0)
        workoutLogs = logs
    }

    func deleteWorkout(id: UUID) {
        workoutLogs = workoutLogs.filter { $0.id != id }
    }

    // MARK: - Pump event logs

    var pumpEventLogs: [PumpEventEntry] {
        get {
            guard let data = defaults.data(forKey: Keys.pumpEventLogs),
                  let logs = try? JSONDecoder().decode([PumpEventEntry].self, from: data) else { return [] }
            return logs
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                defaults.set(data, forKey: Keys.pumpEventLogs)
            }
        }
    }

    func appendPumpEvent(_ entry: PumpEventEntry) {
        var logs = pumpEventLogs
        logs.insert(entry, at: 0)
        pumpEventLogs = logs
    }

    func deletePumpEvent(id: UUID) {
        pumpEventLogs = pumpEventLogs.filter { $0.id != id }
    }

    // MARK: - Imported Oura daily summaries (from CSV export)

    var importedDailySummaries: [OuraDailySummary] {
        get {
            guard let data = defaults.data(forKey: Keys.importedDailySummaries),
                  let decoded = try? JSONDecoder().decode([OuraDailySummary].self, from: data)
            else { return [] }
            return decoded
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                defaults.set(data, forKey: Keys.importedDailySummaries)
            }
        }
    }

    func setImportedDailySummaries(_ summaries: [OuraDailySummary]) {
        importedDailySummaries = summaries
    }

    func clearImportedDailySummaries() {
        defaults.removeObject(forKey: Keys.importedDailySummaries)
    }

    // MARK: - Journal entries

    var journalEntries: [JournalDayEntry] {
        get {
            guard let data = defaults.data(forKey: Keys.journalEntries),
                  let decoded = try? JSONDecoder().decode([JournalDayEntry].self, from: data)
            else { return [] }
            return decoded
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                defaults.set(data, forKey: Keys.journalEntries)
            }
        }
    }

    func upsertJournalEntry(_ entry: JournalDayEntry) {
        var entries = journalEntries
        if let idx = entries.firstIndex(where: { $0.day == entry.day }) {
            entries[idx] = entry
        } else {
            entries.insert(entry, at: 0)
        }
        journalEntries = entries
    }

    // MARK: - Journal configuration

    var hiddenJournalItems: Set<String> {
        get {
            let arr = defaults.stringArray(forKey: Keys.hiddenJournalItems) ?? []
            return Set(arr)
        }
        set { defaults.set(Array(newValue), forKey: Keys.hiddenJournalItems) }
    }

    func setHiddenJournalItems(_ items: Set<String>) { hiddenJournalItems = items }

    var customJournalItems: [CustomJournalItem] {
        get {
            guard let data = defaults.data(forKey: Keys.customJournalItems),
                  let decoded = try? JSONDecoder().decode([CustomJournalItem].self, from: data)
            else { return [] }
            return decoded
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                defaults.set(data, forKey: Keys.customJournalItems)
            }
        }
    }

    func upsertCustomJournalItem(_ item: CustomJournalItem) {
        var items = customJournalItems
        if let idx = items.firstIndex(where: { $0.id == item.id }) {
            items[idx] = item
        } else {
            items.append(item)
        }
        customJournalItems = items
    }

    func deleteCustomJournalItem(id: UUID) {
        customJournalItems = customJournalItems.filter { $0.id != id }
    }

    // MARK: - Kilo Gateway

    var kiloAPIKey: String {
        get { defaults.string(forKey: Keys.kiloAPIKey) ?? "" }
        set { defaults.set(newValue, forKey: Keys.kiloAPIKey) }
    }
    func setKiloAPIKey(_ v: String) { kiloAPIKey = v }

    var kiloModel: String {
        get { defaults.string(forKey: Keys.kiloModel) ?? "anthropic/claude-sonnet-4-6" }
        set { defaults.set(newValue, forKey: Keys.kiloModel) }
    }
    func setKiloModel(_ v: String) { kiloModel = v }

    // MARK: - Food log

    var foodEntries: [FoodEntry] {
        get {
            guard let data = defaults.data(forKey: Keys.foodEntries),
                  let entries = try? JSONDecoder().decode([FoodEntry].self, from: data)
            else { return [] }
            return entries
        }
        set {
            guard let data = try? JSONEncoder().encode(Array(newValue.suffix(500))) else { return }
            defaults.set(data, forKey: Keys.foodEntries)
        }
    }

    func upsertFoodEntry(_ entry: FoodEntry) {
        var entries = foodEntries
        if let i = entries.firstIndex(where: { $0.id == entry.id }) {
            entries[i] = entry
        } else {
            entries.append(entry)
        }
        foodEntries = entries.sorted { $0.date > $1.date }
    }

    func deleteFoodEntry(id: UUID) {
        foodEntries = foodEntries.filter { $0.id != id }
    }

    // MARK: - Dexcom

    var dexcomUsername: String {
        get { defaults.string(forKey: Keys.dexcomUsername) ?? "" }
        set { defaults.set(newValue, forKey: Keys.dexcomUsername) }
    }
    func setDexcomUsername(_ v: String) { dexcomUsername = v }

    var dexcomPassword: String {
        get { defaults.string(forKey: Keys.dexcomPassword) ?? "" }
        set { defaults.set(newValue, forKey: Keys.dexcomPassword) }
    }
    func setDexcomPassword(_ v: String) { dexcomPassword = v }

    var dexcomRegion: DexcomRegion {
        get {
            let raw = defaults.string(forKey: Keys.dexcomRegion) ?? "us"
            return DexcomRegion(rawValue: raw) ?? .us
        }
        set { defaults.set(newValue.rawValue, forKey: Keys.dexcomRegion) }
    }
    func setDexcomRegion(_ v: DexcomRegion) { dexcomRegion = v }

    var dexcomEnabled: Bool {
        get { defaults.bool(forKey: Keys.dexcomEnabled) }
        set { defaults.set(newValue, forKey: Keys.dexcomEnabled) }
    }
    func setDexcomEnabled(_ v: Bool) { dexcomEnabled = v }

    var glucoseNotificationsEnabled: Bool {
        get { defaults.bool(forKey: Keys.glucoseNotificationsEnabled) }
        set { defaults.set(newValue, forKey: Keys.glucoseNotificationsEnabled) }
    }
    func setGlucoseNotificationsEnabled(_ v: Bool) { glucoseNotificationsEnabled = v }

    var glucoseAlertHigh: Int {
        get { defaults.object(forKey: Keys.glucoseAlertHigh) as? Int ?? 250 }
        set { defaults.set(newValue, forKey: Keys.glucoseAlertHigh) }
    }
    func setGlucoseAlertHigh(_ v: Int) { glucoseAlertHigh = v }

    var glucoseAlertLow: Int {
        get { defaults.object(forKey: Keys.glucoseAlertLow) as? Int ?? 70 }
        set { defaults.set(newValue, forKey: Keys.glucoseAlertLow) }
    }
    func setGlucoseAlertLow(_ v: Int) { glucoseAlertLow = v }

    // MARK: - Live Activity

    var liveActivityDeeplinkURL: String {
        get { defaults.string(forKey: Keys.liveActivityDeeplinkURL) ?? "healthsync://glucose" }
        set { defaults.set(newValue, forKey: Keys.liveActivityDeeplinkURL) }
    }
    func setLiveActivityDeeplinkURL(_ v: String) { liveActivityDeeplinkURL = v }

    var liveActivityShortcutURLs: [String] {
        get { defaults.stringArray(forKey: Keys.liveActivityShortcutURLs) ?? [] }
        set { defaults.set(newValue, forKey: Keys.liveActivityShortcutURLs) }
    }
    func setLiveActivityShortcutURLs(_ v: [String]) { liveActivityShortcutURLs = v }

    // MARK: - Dexcom reading buffer (persisted across sessions)

    var dexcomBuffer: [GlucosePoint] {
        get {
            guard let data = defaults.data(forKey: Keys.dexcomBuffer),
                  let pts = try? JSONDecoder().decode([GlucosePoint].self, from: data)
            else { return [] }
            return pts
        }
        set {
            if let data = try? JSONEncoder().encode(Array(newValue.suffix(288))) {
                defaults.set(data, forKey: Keys.dexcomBuffer)
            }
        }
    }
    func setDexcomBuffer(_ pts: [GlucosePoint]) { dexcomBuffer = pts }

    // MARK: - Oura day dedup

    var syncedOuraDays: Set<String> {
        get { Set(defaults.stringArray(forKey: Keys.syncedOuraDays) ?? []) }
        set { defaults.set(Array(newValue), forKey: Keys.syncedOuraDays) }
    }

    func addSyncedOuraDay(_ day: String) {
        var days = syncedOuraDays
        days.insert(day)
        syncedOuraDays = days
    }

    func isOuraDaySynced(_ day: String) -> Bool {
        syncedOuraDays.contains(day)
    }
}

enum GlucoseUnit: String {
    case mgdl = "mgdl"
    case mmol = "mmol"
    
    var displayName: String {
        switch self {
        case .mgdl: return "mg/dL"
        case .mmol: return "mmol/L"
        }
    }
}
