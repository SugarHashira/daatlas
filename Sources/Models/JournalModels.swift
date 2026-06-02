import Foundation
import SwiftUI

enum JournalItemKey: String, Codable, CaseIterable {
    case addedSugar, caffeine, hydration, ketoDiet, lowCarbs, alcohol
    case mood, morningLight, naps
    case strength, zone2, mindfulness

    var emoji: String {
        switch self {
        case .addedSugar:   return "🍬"
        case .caffeine:     return "☕️"
        case .hydration:    return "💧"
        case .ketoDiet:     return "🥑"
        case .lowCarbs:     return "🍞"
        case .alcohol:      return "🍷"
        case .mood:         return "😊"
        case .morningLight: return "🌞"
        case .naps:         return "😴"
        case .strength:     return "🏋️"
        case .zone2:        return "🟠"
        case .mindfulness:  return "🧘"
        }
    }

    var displayName: String {
        switch self {
        case .addedSugar:   return "Added sugar"
        case .caffeine:     return "Caffeine"
        case .hydration:    return "Hydration"
        case .ketoDiet:     return "Keto diet"
        case .lowCarbs:     return "Low carbs"
        case .alcohol:      return "Alcohol"
        case .mood:         return "Daily mood"
        case .morningLight: return "Morning sunlight"
        case .naps:         return "Naps"
        case .strength:     return "Strength training"
        case .zone2:        return "Zone 2 cardio"
        case .mindfulness:  return "Mindfulness"
        }
    }

    var inputType: JournalInputType {
        switch self {
        case .caffeine:    return .numeric(unit: "mg")
        case .hydration:   return .numeric(unit: "ml")
        case .strength:    return .numeric(unit: "mins")
        case .zone2:       return .numeric(unit: "mins")
        case .mindfulness: return .numeric(unit: "mins")
        case .mood:        return .scale
        default:           return .boolean
        }
    }

    var category: JournalCategory {
        switch self {
        case .addedSugar, .caffeine, .hydration, .ketoDiet, .lowCarbs, .alcohol: return .nutrition
        case .mood, .morningLight, .naps:                                          return .wellness
        case .strength, .zone2, .mindfulness:                                      return .fitness
        }
    }
}

enum JournalInputType: Equatable {
    case boolean
    case numeric(unit: String)
    case scale
}

enum JournalCategory: String, Codable, CaseIterable {
    case nutrition = "Nutrition"
    case wellness  = "Wellness"
    case fitness   = "Fitness"
    var icon: String {
        switch self {
        case .nutrition: return "fork.knife"
        case .wellness:  return "sparkles"
        case .fitness:   return "figure.run"
        }
    }
}

struct JournalDayEntry: Codable {
    let day: String                   // "YYYY-MM-DD"
    var booleans: [String: Bool]   = [:]
    var numbers:  [String: Double] = [:]
    var scales:   [String: Int]    = [:]  // 1–5 for mood

    init(day: String) { self.day = day }

    var isComplete: Bool { !booleans.isEmpty || !numbers.isEmpty || !scales.isEmpty }

    func boolValue(for key: JournalItemKey) -> Bool?   { booleans[key.rawValue] }
    func numericValue(for key: JournalItemKey) -> Double? { numbers[key.rawValue] }
    func scaleValue(for key: JournalItemKey) -> Int?   { scales[key.rawValue] }

    mutating func set(boolean: Bool?, for key: JournalItemKey) {
        if let v = boolean { booleans[key.rawValue] = v } else { booleans.removeValue(forKey: key.rawValue) }
    }
    mutating func set(number: Double?, for key: JournalItemKey) {
        if let v = number { numbers[key.rawValue] = v } else { numbers.removeValue(forKey: key.rawValue) }
    }
    mutating func set(scale: Int?, for key: JournalItemKey) {
        if let v = scale { scales[key.rawValue] = v } else { scales.removeValue(forKey: key.rawValue) }
    }

    // Custom item access (key = item.id.uuidString)
    func boolValue(customID: String) -> Bool?   { booleans[customID] }
    func numericValue(customID: String) -> Double? { numbers[customID] }
    func scaleValue(customID: String) -> Int?   { scales[customID] }

    mutating func set(boolean: Bool?, customID: String) {
        if let v = boolean { booleans[customID] = v } else { booleans.removeValue(forKey: customID) }
    }
    mutating func set(number: Double?, customID: String) {
        if let v = number { numbers[customID] = v } else { numbers.removeValue(forKey: customID) }
    }
    mutating func set(scale: Int?, customID: String) {
        if let v = scale { scales[customID] = v } else { scales.removeValue(forKey: customID) }
    }
}

// MARK: - Custom journal items

enum CustomItemType: String, Codable, CaseIterable {
    case boolean = "Yes / No"
    case numeric = "Number"
    case scale   = "1–5 Scale"
}

struct CustomJournalItem: Codable, Identifiable {
    let id: UUID
    var name: String
    var emoji: String
    var type: CustomItemType
    var unit: String          // for numeric only (e.g. "ml", "mg")
    var category: JournalCategory

    init(id: UUID = UUID(), name: String, emoji: String,
         type: CustomItemType, unit: String = "",
         category: JournalCategory = .wellness) {
        self.id = id; self.name = name; self.emoji = emoji
        self.type = type; self.unit = unit; self.category = category
    }
}
