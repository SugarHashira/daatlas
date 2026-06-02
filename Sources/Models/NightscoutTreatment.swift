import Foundation

struct NightscoutTreatment: Codable, Identifiable {
    let id: String?
    let eventType: String?
    let insulin: Double?
    let carbs: Double?
    let protein: Double?
    let fat: Double?
    let glucose: Double?
    let createdAt: String
    let notes: String?
    let appSecret: String?
    
    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case eventType = "eventType"
        case insulin
        case carbs
        case protein
        case fat
        case glucose
        case createdAt = "created_at"
        case notes
        case appSecret = "appSecret"
    }
    
    var isValid: Bool {
        return insulin != nil || carbs != nil || glucose != nil
    }
    
    var treatmentDate: Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        if let date = formatter.date(from: createdAt) {
            return date
        }
        
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: createdAt)
    }
}

extension NightscoutTreatment {
    static var sample: NightscoutTreatment {
        NightscoutTreatment(
            id: "abc123",
            eventType: "Meal Bolus",
            insulin: 5.5,
            carbs: 45,
            protein: nil,
            fat: nil,
            glucose: nil,
            createdAt: "2024-01-15T12:30:00.000Z",
            notes: "Lunch",
            appSecret: nil
        )
    }
}
