import Foundation
import UserNotifications
import CryptoKit
#if os(iOS)
import ActivityKit
#endif

@MainActor
class GlucoseMonitor: ObservableObject {
    static let shared = GlucoseMonitor()

    @Published var latestReading: DexcomReading?
    @Published var isPolling = false
    @Published var lastError: Error?

    private var timer: Timer?
    private var lastNotifiedTimestamp: Date?
    private var currentActivity: Any? // Activity<GlucoseActivityAttributes> — typed below
    private var readingBuffer: [DexcomReading] = []
    @Published var latestIOB: Double?
    @Published var latestCOB: Double?

    private init() {
        Task {
            let pts = await UserSettings.shared.dexcomBuffer
            if !pts.isEmpty {
                let readings = pts.map { DexcomReading(value: $0.value, timestamp: $0.timestamp) }
                mergeReadings(readings)
            }
        }
    }

    func startPolling() {
        guard !isPolling else { return }
        isPolling = true
        Task { await poll() }
        timer = Timer.scheduledTimer(withTimeInterval: 5 * 60, repeats: true) { [weak self] _ in
            Task { await self?.poll() }
        }
    }

    func stopPolling() {
        isPolling = false
        timer?.invalidate()
        timer = nil
        endLiveActivity()
    }

    /// One-shot poll — called from BGTask when the in-process timer isn't running.
    func pollOnce() async {
        await poll()
    }

    private func poll() async {
        do {
            let readings = try await DexcomService.shared.fetchLatestReadings(count: 36)
            lastError = nil

            mergeReadings(readings)

            guard let reading = readingBuffer.last else { return }

            let isNew = lastNotifiedTimestamp.map { reading.timestamp > $0 } ?? true

            latestReading = reading

            // Fetch IOB + COB from Nightscout (best-effort)
            await fetchDeviceStatus()

            updateLiveActivity(reading: reading)

            if isNew {
                lastNotifiedTimestamp = reading.timestamp
                await sendNotificationsIfNeeded(reading: reading)
            }
        } catch {
            lastError = error
        }
    }

    /// Merge new readings into the rolling buffer (dedup, sorted, capped at 288 / 24h).
    private func mergeReadings(_ new: [DexcomReading]) {
        var seen = Set(readingBuffer.map { $0.timestamp })
        for reading in new where !seen.contains(reading.timestamp) {
            readingBuffer.append(reading)
            seen.insert(reading.timestamp)
        }
        readingBuffer.sort { $0.timestamp < $1.timestamp }
        if readingBuffer.count > 288 {
            readingBuffer = Array(readingBuffer.suffix(288))
        }
        let pts = readingBuffer.map { GlucosePoint(value: $0.value, timestamp: $0.timestamp) }
        Task { await UserSettings.shared.setDexcomBuffer(pts) }
    }

    // MARK: - IOB / COB

    private func fetchDeviceStatus() async {
        guard let urlString = await UserSettings.shared.nightscoutURL,
              let secret = await UserSettings.shared.nightscoutAPISecret,
              let url = URL(string: "\(urlString)/api/v1/devicestatus.json?count=1") else { return }
        var req = URLRequest(url: url)
        req.setValue(secret.sha1Hash(), forHTTPHeaderField: "api-secret")
        guard let (data, _) = try? await URLSession.shared.data(for: req),
              let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
              let first = json.first else { return }
        if let iobDict = first["iob"] as? [String: Any], let iob = iobDict["iob"] as? Double {
            latestIOB = iob
        }
        if let cobDict = first["cob"] as? [String: Any], let cob = cobDict["cob"] as? Double {
            latestCOB = cob
        }
    }

    // MARK: - Live Activity

    @available(iOS 16.2, *)
    private func startOrUpdateLiveActivity(reading: DexcomReading) async {
        let settings = UserSettings.shared
        let unit = await settings.glucoseUnit == .mmol ? "mmol/L" : "mg/dL"
        // Cap at 36 readings (3h) — ActivityKit 4 KB payload limit
        let points = readingBuffer.suffix(36).map { GlucosePoint(value: $0.value, timestamp: $0.timestamp) }
        let state = GlucoseActivityAttributes.GlucoseContentState(
            value: reading.value,
            trendArrow: reading.trend.arrow,
            trendSymbol: reading.trend.sfSymbol,
            timestamp: reading.timestamp,
            unit: unit,
            recentReadings: points,
            iob: latestIOB,
            targetLow: await settings.tirLow,
            targetHigh: await settings.tirHigh
        )
        // Reconnect to an active activity that survived an app restart
        if currentActivity == nil {
            currentActivity = Activity<GlucoseActivityAttributes>.activities.first(where: {
                $0.activityState == .active
            })
        }
        if let existing = currentActivity as? Activity<GlucoseActivityAttributes> {
            await existing.update(using: state)
        } else {
            guard ActivityAuthorizationInfo().areActivitiesEnabled else {
                lastError = NSError(
                    domain: "LiveActivity", code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Live Activities disabled — enable in Settings → HealthSync → Live Activities"]
                )
                return
            }
            do {
                let deeplinkURL = await UserSettings.shared.liveActivityDeeplinkURL
                let shortcutURLs = await UserSettings.shared.liveActivityShortcutURLs
                let activity = try Activity.request(
                    attributes: GlucoseActivityAttributes(
                        deeplinkURL: deeplinkURL,
                        shortcutURLs: shortcutURLs
                    ),
                    contentState: state,
                    pushType: nil
                )
                currentActivity = activity
                lastError = nil
            } catch {
                lastError = error
            }
        }
    }

    private func updateLiveActivity(reading: DexcomReading) {
        if #available(iOS 16.2, *) {
            Task { await startOrUpdateLiveActivity(reading: reading) }
        }
    }

    /// End the current activity and immediately start a fresh one with updated static attributes.
    /// Call this after saving wallpaper or deeplink settings.
    func restartLiveActivity() async {
        if #available(iOS 16.2, *) {
            if let activity = currentActivity as? Activity<GlucoseActivityAttributes> {
                await activity.end(dismissalPolicy: .immediate)
            }
            currentActivity = nil
            if let reading = latestReading {
                await startOrUpdateLiveActivity(reading: reading)
            } else {
                // No cached reading — poll now, which will start the activity after fetch
                await poll()
            }
        }
    }

    private func endLiveActivity() {
        if #available(iOS 16.2, *) {
            Task { [weak self] in
                guard let self else { return }
                if let activity = self.currentActivity as? Activity<GlucoseActivityAttributes> {
                    await activity.end(dismissalPolicy: .immediate)
                    self.currentActivity = nil
                }
            }
        }
    }

    // MARK: - Notifications

    private func sendNotificationsIfNeeded(reading: DexcomReading) async {
        let settings = UserSettings.shared
        let notifEnabled = await settings.glucoseNotificationsEnabled
        let alertHigh = await settings.glucoseAlertHigh
        let alertLow = await settings.glucoseAlertLow
        let unit = await settings.glucoseUnit

        let center = UNUserNotificationCenter.current()

        if notifEnabled {
            let displayVal = unit == .mmol
                ? String(format: "%.1f mmol/L", reading.mmolValue)
                : "\(reading.value) mg/dL"

            let content = UNMutableNotificationContent()
            content.title = "Glucose Reading"
            content.body = "\(displayVal) \(reading.trend.arrow)"
            content.sound = .default
            let req = UNNotificationRequest(identifier: "glucose-reading-\(reading.timestamp.timeIntervalSince1970)", content: content, trigger: nil)
            try? await center.add(req)
        }

        if reading.value > alertHigh {
            let content = UNMutableNotificationContent()
            content.title = "High Glucose Alert"
            content.body = "Glucose is \(reading.value) mg/dL \(reading.trend.arrow) — above your \(alertHigh) mg/dL threshold"
            content.sound = .defaultCritical
            let req = UNNotificationRequest(identifier: "glucose-high-\(reading.timestamp.timeIntervalSince1970)", content: content, trigger: nil)
            try? await center.add(req)
        }

        if reading.value < alertLow {
            let content = UNMutableNotificationContent()
            content.title = "Low Glucose Alert"
            content.body = "Glucose is \(reading.value) mg/dL \(reading.trend.arrow) — below your \(alertLow) mg/dL threshold"
            content.sound = .defaultCritical
            let req = UNNotificationRequest(identifier: "glucose-low-\(reading.timestamp.timeIntervalSince1970)", content: content, trigger: nil)
            try? await center.add(req)
        }
    }

    func requestNotificationPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let granted = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
        return granted ?? false
    }
}

private extension String {
    func sha1Hash() -> String {
        let data = Data(self.utf8)
        let hash = Insecure.SHA1.hash(data: data)
        return hash.map { String(format: "%02x", $0) }.joined()
    }
}
