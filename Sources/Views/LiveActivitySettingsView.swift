import SwiftUI
import ActivityKit

struct LiveActivitySettingsView: View {
    @Environment(\.dsDensity) private var density
    @ObservedObject private var monitor = GlucoseMonitor.shared

    @State private var shortcutURLs: [String] = []
    @State private var newURL: String = ""

    var body: some View {
        ScrollView {
            VStack(spacing: DS.gap(density)) {
                statusSection
                shortcutsSection
            }
            .padding(.top, DS.pad(density))
            .padding(.bottom, 100)
        }
        .background(DS.bg)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                DSAppBar(title: "Live Activity",
                         status: .live,
                         right: AnyView(DSBadge(text: "CGM")))
            }
        }
        .toolbarBackground(DS.bg, for: .navigationBar)
        .preferredColorScheme(.dark)
        .onAppear { Task { await load() } }
    }

    // MARK: - Status

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            DSSectionHeader(text: "Status")
                .padding(.horizontal, DS.pad(density))

            DSCard {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        let isActive: Bool = {
                            if #available(iOS 16.2, *) {
                                return Activity<GlucoseActivityAttributes>.activities.contains { $0.activityState == .active }
                            }
                            return false
                        }()
                        Circle()
                            .fill(isActive ? DS.accent : DS.fg3)
                            .frame(width: 8, height: 8)
                            .shadow(color: isActive ? DS.accent : .clear, radius: 4)
                        Text(isActive ? "Live Activity running" : "Live Activity not running")
                            .font(.dsMonoSm)
                            .foregroundStyle(isActive ? DS.fg : DS.fg3)
                        Spacer()
                        if monitor.latestReading != nil {
                            Text("CGM active")
                                .font(.dsMonoXs).tracking(1)
                                .foregroundStyle(DS.accent)
                                .padding(.horizontal, 5).padding(.vertical, 2)
                                .background(DS.accent.opacity(0.15), in: RoundedRectangle(cornerRadius: 4))
                        }
                    }

                    if let err = monitor.lastError {
                        Text(err.localizedDescription)
                            .font(.dsMonoXs)
                            .foregroundStyle(DS.hi)
                            .lineSpacing(3)
                    }

                    DS.line.frame(height: 1)

                    Button {
                        Task { await GlucoseMonitor.shared.restartLiveActivity() }
                    } label: {
                        Text("Restart Live Activity")
                            .font(.dsMonoSm).foregroundStyle(DS.accentInk)
                            .frame(maxWidth: .infinity).padding(.vertical, 10)
                            .background(DS.accent, in: RoundedRectangle(cornerRadius: DS.rSm))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, DS.pad(density))
        }
    }

    // MARK: - Shortcuts

    private var shortcutsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            DSSectionHeader(text: "Shortcut buttons")
                .padding(.horizontal, DS.pad(density))

            DSCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Up to 3 buttons appear on the right of the Live Activity. Tap to open another app.")
                        .font(.dsMonoXs)
                        .foregroundStyle(DS.fg3)
                        .lineSpacing(3)

                    if !shortcutURLs.isEmpty {
                        DS.line.frame(height: 1)
                        ForEach(shortcutURLs.indices, id: \.self) { i in
                            HStack(spacing: 8) {
                                TextField("URL scheme", text: $shortcutURLs[i])
                                    .font(.dsMonoSm).foregroundStyle(DS.fg)
                                    .autocapitalization(.none)
                                    .autocorrectionDisabled()
                                    .keyboardType(.URL)
                                Button {
                                    shortcutURLs.remove(at: i)
                                    Task { await save() }
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundStyle(DS.hi)
                                        .font(.system(size: 16))
                                }
                                .buttonStyle(.plain)
                            }
                            if i < shortcutURLs.count - 1 {
                                DS.line.frame(height: 1)
                            }
                        }
                    }

                    if shortcutURLs.count < 3 {
                        DS.line.frame(height: 1)
                        HStack(spacing: 8) {
                            TextField("Add URL (e.g. loopkit://)", text: $newURL)
                                .font(.dsMonoSm).foregroundStyle(DS.fg)
                                .autocapitalization(.none)
                                .autocorrectionDisabled()
                                .keyboardType(.URL)
                                .onSubmit { addURL() }
                            Button { addURL() } label: {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundStyle(DS.accent)
                                    .font(.system(size: 16))
                            }
                            .buttonStyle(.plain)
                        }

                        DS.line.frame(height: 1)

                        HStack(spacing: 8) {
                            quickAdd("Nightscout", "nightscout://")
                            quickAdd("Dexcom", "dexcom://")
                            quickAdd("Loop", "loopkit://")
                        }
                    }

                    DS.line.frame(height: 1).padding(.top, 4)

                    Button { Task { await save() } } label: {
                        Text("Save")
                            .font(.dsMonoSm).foregroundStyle(DS.accentInk)
                            .frame(maxWidth: .infinity).padding(.vertical, 10)
                            .background(DS.accent, in: RoundedRectangle(cornerRadius: DS.rSm))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, DS.pad(density))
        }
    }

    private func quickAdd(_ label: String, _ url: String) -> some View {
        Button {
            guard shortcutURLs.count < 3, !shortcutURLs.contains(url) else { return }
            shortcutURLs.append(url)
            Task { await save() }
        } label: {
            Text(label)
                .font(.dsMonoXs)
                .foregroundStyle(DS.fg2)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .background(DS.bg3, in: RoundedRectangle(cornerRadius: DS.rXs))
        }
        .buttonStyle(.plain)
    }

    private func addURL() {
        let trimmed = newURL.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, shortcutURLs.count < 3 else { return }
        shortcutURLs.append(trimmed)
        newURL = ""
        Task { await save() }
    }

    // MARK: - Load / Save

    private func load() async {
        shortcutURLs = await UserSettings.shared.liveActivityShortcutURLs
    }

    private func save() async {
        await UserSettings.shared.setLiveActivityShortcutURLs(shortcutURLs)
        await GlucoseMonitor.shared.restartLiveActivity()
    }
}
