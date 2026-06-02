import Foundation

struct SyncLog: Codable, Identifiable {
    let id: UUID
    let date: Date
    // How many were on Nightscout and not yet in HealthKit
    let pendingGlucose: Int
    let pendingInsulin: Int
    let pendingCarbs: Int
    // How many were actually written to HealthKit in this run
    let glucoseSynced: Int
    let insulinSynced: Int
    let carbsSynced: Int
    let errors: [String]

    init(date: Date,
         pendingGlucose: Int, pendingInsulin: Int, pendingCarbs: Int,
         glucoseSynced: Int, insulinSynced: Int, carbsSynced: Int,
         errors: [String]) {
        self.id = UUID()
        self.date = date
        self.pendingGlucose = pendingGlucose
        self.pendingInsulin = pendingInsulin
        self.pendingCarbs = pendingCarbs
        self.glucoseSynced = glucoseSynced
        self.insulinSynced = insulinSynced
        self.carbsSynced = carbsSynced
        self.errors = errors
    }

    var totalSynced: Int { glucoseSynced + insulinSynced + carbsSynced }
    var totalPending: Int { pendingGlucose + pendingInsulin + pendingCarbs }
    var hasErrors: Bool { !errors.isEmpty }
}
