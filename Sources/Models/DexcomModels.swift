import Foundation

enum DexcomRegion: String, Codable, CaseIterable {
    case us = "us"
    case nonUS = "nonUS"

    var baseURL: String {
        switch self {
        case .us: return "https://share2.dexcom.com"
        case .nonUS: return "https://shareous1.dexcom.com"
        }
    }

    var displayName: String {
        switch self {
        case .us: return "United States"
        case .nonUS: return "Outside US"
        }
    }
}

enum DexcomTrend: String, Codable {
    case doubleUp = "DoubleUp"
    case singleUp = "SingleUp"
    case fortyFiveUp = "FortyFiveUp"
    case flat = "Flat"
    case fortyFiveDown = "FortyFiveDown"
    case singleDown = "SingleDown"
    case doubleDown = "DoubleDown"
    case none = "None"
    case notComputable = "NotComputable"
    case rateOutOfRange = "RateOutOfRange"

    // Dexcom Share API returns integer trends in most responses
    static func fromInt(_ value: Int) -> DexcomTrend {
        switch value {
        case 1: return .doubleUp
        case 2: return .singleUp
        case 3: return .fortyFiveUp
        case 4: return .flat
        case 5: return .fortyFiveDown
        case 6: return .singleDown
        case 7: return .doubleDown
        default: return .none
        }
    }

    var arrow: String {
        switch self {
        case .doubleUp: return "↑↑"
        case .singleUp: return "↑"
        case .fortyFiveUp: return "↗"
        case .flat: return "→"
        case .fortyFiveDown: return "↘"
        case .singleDown: return "↓"
        case .doubleDown: return "↓↓"
        default: return "-"
        }
    }

    var sfSymbol: String {
        switch self {
        case .doubleUp: return "arrow.up.to.line"
        case .singleUp: return "arrow.up"
        case .fortyFiveUp: return "arrow.up.right"
        case .flat: return "arrow.right"
        case .fortyFiveDown: return "arrow.down.right"
        case .singleDown: return "arrow.down"
        case .doubleDown: return "arrow.down.to.line"
        default: return "minus"
        }
    }
}

struct DexcomReading: Decodable {
    let value: Int         // mg/dL
    let trend: DexcomTrend
    let timestamp: Date

    // Raw API response fields
    private enum CodingKeys: String, CodingKey {
        case value = "Value"
        case trendString = "Trend"
        case wt = "WT"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        value = try c.decode(Int.self, forKey: .value)
        // API returns integer trend (most versions) or string (some versions)
        if let trendInt = try? c.decode(Int.self, forKey: .trendString) {
            trend = DexcomTrend.fromInt(trendInt)
        } else if let trendStr = try? c.decode(String.self, forKey: .trendString) {
            trend = DexcomTrend(rawValue: trendStr) ?? .none
        } else {
            trend = .none
        }
        let wt = try c.decode(String.self, forKey: .wt)
        // Parse /Date(milliseconds)/ or /Date(milliseconds+offset)/ format
        let ms = wt.components(separatedBy: CharacterSet.decimalDigits.inverted)
            .compactMap(Double.init).first ?? 0
        timestamp = Date(timeIntervalSince1970: ms / 1000)
    }

    var mmolValue: Double { Double(value) / 18.0182 }

    init(value: Int, trend: DexcomTrend = .none, timestamp: Date) {
        self.value = value
        self.trend = trend
        self.timestamp = timestamp
    }
}
