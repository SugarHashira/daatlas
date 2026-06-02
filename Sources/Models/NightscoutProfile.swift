import Foundation

struct NightscoutProfile: Codable {
    let id: String?
    let name: String?
    let defaultProfile: String?
    let units: ProfileUnits?
    let bgTarget: [BGTarget]?
    
    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case name
        case defaultProfile = "defaultProfile"
        case units
        case bgTarget = "bgTarget"
    }
}

struct ProfileUnits: Codable {
    let bg: String?
    let carb: String?
}

struct BGTarget: Codable {
    let low: Double?
    let high: Double?
    let target: Double?
}

extension NightscoutProfile {
    var isMmol: Bool {
        units?.bg?.lowercased() == "mmol"
    }
}
