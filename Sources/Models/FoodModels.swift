import Foundation

struct FoodEntry: Codable, Identifiable {
    let id: UUID
    var date: Date
    var description: String
    var estimatedCarbs: Double?
    var confirmedCarbs: Double?   // user override
    var confidence: String?       // "high" / "medium" / "low"
    var aiNotes: String?
    var imageData: Data?          // JPEG compressed

    init(id: UUID = UUID(), date: Date = Date(), description: String,
         estimatedCarbs: Double? = nil, confirmedCarbs: Double? = nil,
         confidence: String? = nil, aiNotes: String? = nil, imageData: Data? = nil) {
        self.id = id; self.date = date; self.description = description
        self.estimatedCarbs = estimatedCarbs; self.confirmedCarbs = confirmedCarbs
        self.confidence = confidence; self.aiNotes = aiNotes; self.imageData = imageData
    }

    var carbs: Double? { confirmedCarbs ?? estimatedCarbs }

    var confidenceColor: String {
        switch confidence {
        case "high":   return "accent"
        case "medium": return "lo"
        default:       return "hi"
        }
    }
}

struct CarbEstimate: Codable {
    let foodName: String
    let carbsG: Double
    let confidence: String
    let notes: String

    enum CodingKeys: String, CodingKey {
        case foodName = "food_name"
        case carbsG   = "carbs_g"
        case confidence, notes
    }
}
