import SwiftUI

// MARK: - Root (entry point — replaces ContentView tab shell)

struct RootView: View {
    @EnvironmentObject var vm: SyncViewModel
    @AppStorage("ui_density") private var density: DS.Density = .compact
    @State private var tab = 0
    @Environment(\.openURL) private var openURL

    var body: some View {
        ZStack(alignment: .bottom) {
            DS.bg.ignoresSafeArea()

            // Main content
            Group {
                switch tab {
                case 0: NavigationStack { VitalsTabView() }
                case 1: NavigationStack { TrendsTabView()  }
                case 2: NavigationStack { JournalView()   }
                case 3: NavigationStack { FoodLogView()   }
                default: NavigationStack { SettingsTabView() }
                }
            }
            .environment(\.dsDensity, density)
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Floating tab bar
            DSCustomTabBar(tab: $tab)
        }
        .preferredColorScheme(.dark)
        .ignoresSafeArea(edges: .bottom)
        .onOpenURL { url in
            if url.scheme == "daatlas" {
                switch url.host ?? url.path {
                case "glucose", "vitals": tab = 0
                case "trends":            tab = 1
                case "journal":           tab = 2
                case "food":              tab = 3
                case "settings":          tab = 4
                default:                  tab = 0
                }
            } else {
                // External deeplink (Loop, Dexcom, Nightscout, etc.) — hand off to the system
                openURL(url)
            }
        }
        .task {
            await vm.loadSettings()
            async let a: () = vm.loadTodayData()
            async let b: () = vm.loadDashboard()
            _ = await (a, b)
        }
    }
}

// MARK: - Custom tab bar

struct DSCustomTabBar: View {
    @Binding var tab: Int

    private let items: [(String, String, String)] = [
        ("waveform.path.ecg",         "Vitals",   "waveform.path.ecg"),
        ("chart.xyaxis.line",         "Trends",   "chart.xyaxis.line"),
        ("note.text",                 "Journal",  "note.text"),
        ("fork.knife",                "Food",     "fork.knife"),
        ("gearshape",                 "Settings", "gearshape.fill"),
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.offset) { i, item in
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) { tab = i }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab == i ? item.2 : item.0)
                            .font(.system(size: 20, weight: .light))
                            .foregroundStyle(tab == i ? DS.accent : DS.fg3)
                            .frame(height: 24)
                        Text(item.1.uppercased())
                            .font(.dsMonoXs)
                            .tracking(0.8)
                            .foregroundStyle(tab == i ? DS.accent : DS.fg3)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .background(
            ZStack {
                DS.bg2.opacity(0.92)
                Color.white.opacity(0.03)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: DS.r))
        .overlay(RoundedRectangle(cornerRadius: DS.r).stroke(DS.line, lineWidth: 1))
        .padding(.horizontal, 12)
        .padding(.bottom, 28)
        .shadow(color: .black.opacity(0.4), radius: 24, y: 8)
    }
}
