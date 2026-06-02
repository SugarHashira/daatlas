import SwiftUI
import BackgroundTasks

@main
struct HealthSyncApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var syncViewModel = SyncViewModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(syncViewModel)
                .onAppear {
                    syncViewModel.appDelegate = appDelegate
                }
        }
    }
}
