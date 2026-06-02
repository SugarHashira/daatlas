import Foundation

struct GlucoseEntry: Codable, Identifiable {
    let id: String?
    let sgv: Int
    let date: Double
    let dateString: String?
    let device: String?
    let type: String?
    
    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case sgv
        case date
        case dateString = "dateString"
        case device
        case type
    }
    
    var timestamp: Date {
        Date(timeIntervalSince1970: date / 1000)
    }
    
    var isMmol: Bool {
        sgv < 600 / 18
    }
    
    var mgDlValue: Double {
        if isMmol {
            return Double(sgv) * 18.0182
        }
        return Double(sgv)
    }
    
    var mmolValue: Double {
        if isMmol {
            return Double(sgv) / 18.0182
        }
        return Double(sgv) / 18.0182
    }
}

extension GlucoseEntry {
    static var sample: GlucoseEntry {
        GlucoseEntry(
            id: "def456",
            sgv: 120,
            date: Date().timeIntervalSince1970 * 1000,
            dateString: nil,
            device: "iPhone",
            type: "sgv"
        )
    }
}
