import UIKit
import BackgroundTasks
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate {

    // BGAppRefreshTask  — quick "wake up" every X minutes (iOS may defer, but will eventually fire)
    static let refreshTaskID    = "com.daatlas.app.refresh"
    // BGProcessingTask  — longer-running sync with network, fires when device is idle / charging
    static let processingTaskID = "com.daatlas.app.processing"

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        registerBackgroundTasks()
        UNUserNotificationCenter.current().delegate = self

        // Schedule immediately on every launch so a task is always queued
        Task { await scheduleIfEnabled() }

        // Start Dexcom polling + Live Activity if enabled
        Task {
            let enabled = await UserSettings.shared.dexcomEnabled
            if enabled {
                await GlucoseMonitor.shared.startPolling()
            }
        }

        return true
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        Task { await scheduleIfEnabled() }
    }

    // MARK: - Registration

    private func registerBackgroundTasks() {
        // Quick refresh task (BGAppRefreshTask)
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.refreshTaskID,
            using: nil
        ) { [weak self] task in
            self?.handleRefreshTask(task as! BGAppRefreshTask)
        }

        // Processing task (BGProcessingTask) — runs with network, more CPU budget
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.processingTaskID,
            using: nil
        ) { [weak self] task in
            self?.handleProcessingTask(task as! BGProcessingTask)
        }
    }

    // MARK: - Scheduling

    /// Schedule (or cancel) both task types based on current settings.
    func scheduleIfEnabled() async {
        let settings = UserSettings.shared
        let enabled  = await settings.autoSyncEnabled

        guard enabled else {
            BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: Self.refreshTaskID)
            BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: Self.processingTaskID)
            return
        }

        let intervalMinutes = await settings.backgroundSyncInterval
        let delay = TimeInterval(intervalMinutes * 60)

        // 1. BGAppRefreshTask — quick wake-up
        let refreshRequest = BGAppRefreshTaskRequest(identifier: Self.refreshTaskID)
        refreshRequest.earliestBeginDate = Date(timeIntervalSinceNow: delay)
        submitTask(refreshRequest)

        // 2. BGProcessingTask — full sync with network access
        let processingRequest = BGProcessingTaskRequest(identifier: Self.processingTaskID)
        processingRequest.requiresNetworkConnectivity = true
        processingRequest.requiresExternalPower = false
        processingRequest.earliestBeginDate = Date(timeIntervalSinceNow: delay)
        submitTask(processingRequest)
    }

    private func submitTask(_ request: BGTaskRequest) {
        do {
            try BGTaskScheduler.shared.submit(request)
            print("[BG] Scheduled \(request.identifier) in \(Int((request.earliestBeginDate?.timeIntervalSinceNow ?? 0) / 60))min")
        } catch BGTaskScheduler.Error.unavailable {
            print("[BG] Task unavailable (simulator or background refresh disabled in Settings)")
        } catch BGTaskScheduler.Error.tooManyPendingTaskRequests {
            print("[BG] Too many pending requests for \(request.identifier) — already scheduled")
        } catch {
            print("[BG] Failed to schedule \(request.identifier): \(error)")
        }
    }

    // MARK: - Handlers

    private func handleRefreshTask(_ task: BGAppRefreshTask) {
        // Reschedule next run first
        Task { await scheduleIfEnabled() }

        let work = Task {
            await runSync()
            task.setTaskCompleted(success: true)
        }

        task.expirationHandler = {
            print("[BG] Refresh task expired")
            work.cancel()
            task.setTaskCompleted(success: false)
        }
    }

    private func handleProcessingTask(_ task: BGProcessingTask) {
        // Reschedule next run first
        Task { await scheduleIfEnabled() }

        let work = Task {
            await runSync()
            task.setTaskCompleted(success: true)
        }

        task.expirationHandler = {
            print("[BG] Processing task expired")
            work.cancel()
            task.setTaskCompleted(success: false)
        }
    }

    // MARK: - Actual sync work

    private func runSync() async {
        print("[BG] Starting sync at \(Date())")

        // Nightscout sync
        do {
            let result = try await SyncService.shared.syncAll()
            print("[BG] Nightscout sync done — glucose: \(result.glucoseSynced), insulin: \(result.insulinSynced), carbs: \(result.carbsSynced)")
        } catch {
            print("[BG] Nightscout sync failed: \(error.localizedDescription)")
        }

        // Dexcom polling (fire-and-forget — GlucoseMonitor owns its own timer when foregrounded,
        // but background tasks only fire when the timer can't run, so we trigger a manual poll)
        let dexcomEnabled = await UserSettings.shared.dexcomEnabled
        if dexcomEnabled {
            await GlucoseMonitor.shared.pollOnce()
        }

        print("[BG] Sync complete at \(Date())")
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension AppDelegate: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show banners + play sound even while app is foregrounded
        completionHandler([.banner, .sound, .badge])
    }
}
