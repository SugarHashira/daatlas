#if os(iOS)
import ActivityKit
import Foundation

public struct GlucosePoint: Codable, Hashable {
    public var value: Int
    public var timestamp: Date
    public init(value: Int, timestamp: Date) {
        self.value = value
        self.timestamp = timestamp
    }
}

@available(iOS 16.1, *)
struct GlucoseActivityAttributes: ActivityAttributes {
    public typealias ContentState = GlucoseContentState

    // Static — set once at activity start
    var deeplinkURL: String = "healthsync://glucose"
    var shortcutURLs: [String] = []

    public struct GlucoseContentState: Codable, Hashable {
        var value: Int
        var trendArrow: String
        var trendSymbol: String
        var timestamp: Date
        var unit: String
        var recentReadings: [GlucosePoint] = []
        var iob: Double? = nil
        var targetLow: Int = 70
        var targetHigh: Int = 180

        var displayValue: String {
            if unit == "mmol/L" {
                return String(format: "%.1f", Double(value) / 18.0182)
            }
            return "\(value)"
        }

        var minutesAgo: Int {
            Int(Date().timeIntervalSince(timestamp) / 60)
        }
    }
}
#endif
