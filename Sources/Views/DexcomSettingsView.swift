import SwiftUI

// MARK: - Dexcom Settings

struct DexcomSettingsView: View {
    @Environment(\.dsDensity) private var density
    @Environment(\.dismiss) private var dismiss

    @State private var username: String = ""
    @State private var password: String = ""
    @State private var region: DexcomRegion = .us
    @State private var dexcomEnabled: Bool = false
    @State private var notificationsEnabled: Bool = false
    @State private var alertHigh: Int = 250
    @State private var alertLow: Int = 70

    @State private var targetLow: Int = 70
    @State private var targetHigh: Int = 180
    @State private var isTesting = false
    @State private var testMessage: String? = nil
    @State private var testSucceeded: Bool? = nil
    @State private var notificationStatus: String? = nil

    var body: some View {
        ScrollView {
            VStack(spacing: DS.gap(density)) {
                credentialsSection
                pollingSection
                notificationsSection
                targetRangeSection
                thresholdsSection
                testSection
            }
            .padding(.top, DS.pad(density))
            .padding(.bottom, 100)
        }
        .background(DS.bg)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                DSAppBar(title: "Dexcom",
                         status: dexcomEnabled ? .live : .off,
                         right: AnyView(DSBadge(text: "CGM")))
            }
        }
        .toolbarBackground(DS.bg, for: .navigationBar)
        .preferredColorScheme(.dark)
        .onAppear { Task { await load() } }
    }

    // MARK: - Credentials

    private var credentialsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            DSSectionHeader(text: "Credentials")
                .padding(.horizontal, DS.pad(density))

            DSCard {
                VStack(alignment: .leading, spacing: 0) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("USERNAME")
                            .font(.dsMonoXs).tracking(1).foregroundStyle(DS.fg3)
                        TextField("dexcom username", text: $username)
                            .font(.dsMonoSm).foregroundStyle(DS.fg)
                            .autocapitalization(.none)
                            .autocorrectionDisabled()
                            .onSubmit { Task { await save() } }
                    }
                    .padding(.vertical, 8)

                    DS.line.frame(height: 1)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("PASSWORD")
                            .font(.dsMonoXs).tracking(1).foregroundStyle(DS.fg3)
                        SecureField("dexcom password", text: $password)
                            .font(.dsMonoSm).foregroundStyle(DS.fg)
                            .autocapitalization(.none)
                            .autocorrectionDisabled()
                            .onSubmit { Task { await save() } }
                    }
                    .padding(.vertical, 8)

                    DS.line.frame(height: 1)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("REGION")
                            .font(.dsMonoXs).tracking(1).foregroundStyle(DS.fg3)
                        HStack(spacing: 0) {
                            ForEach(DexcomRegion.allCases, id: \.rawValue) { r in
                                Button {
                                    region = r
                                    Task { await save() }
                                } label: {
                                    Text(r.displayName)
                                        .font(.dsMonoXs)
                                        .foregroundStyle(region == r ? DS.accentInk : DS.fg2)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 8)
                                        .background(
                                            region == r ? DS.accent : DS.bg3,
                                            in: RoundedRectangle(cornerRadius: DS.rXs)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(4)
                        .background(DS.bg2, in: RoundedRectangle(cornerRadius: DS.rSm))
                    }
                    .padding(.vertical, 8)

                    DS.line.frame(height: 1).padding(.bottom, 8)

                    Button {
                        Task { await save() }
                    } label: {
                        Text("Save credentials")
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

    // MARK: - Polling

    private var pollingSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            DSSectionHeader(text: "Polling")
                .padding(.horizontal, DS.pad(density))

            DSCard {
                DSToggleRow(label: "Enable Dexcom polling",
                            sub: "Fetch new readings every 5 minutes",
                            isOn: Binding(
                                get: { dexcomEnabled },
                                set: { newVal in
                                    dexcomEnabled = newVal
                                    Task {
                                        await save()
                                        if newVal {
                                            await GlucoseMonitor.shared.startPolling()
                                        } else {
                                            await GlucoseMonitor.shared.stopPolling()
                                        }
                                    }
                                }))
            }
            .padding(.horizontal, DS.pad(density))
        }
    }

    // MARK: - Notifications

    private var notificationsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            DSSectionHeader(text: "Notifications")
                .padding(.horizontal, DS.pad(density))

            DSCard {
                VStack(alignment: .leading, spacing: 0) {
                    DSToggleRow(label: "New reading notifications",
                                sub: "Notify on each new Dexcom reading",
                                isOn: Binding(
                                    get: { notificationsEnabled },
                                    set: { newVal in
                                        notificationsEnabled = newVal
                                        Task { await save() }
                                    }))

                    DS.line.frame(height: 1).padding(.vertical, 8)

                    Button {
                        Task {
                            let granted = await GlucoseMonitor.shared.requestNotificationPermission()
                            notificationStatus = granted ? "Granted" : "Denied"
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Text("Request notification permission")
                                .font(.dsMonoSm)
                                .foregroundStyle(DS.fg2)
                            if let s = notificationStatus {
                                Spacer()
                                Text(s.uppercased())
                                    .font(.dsMonoXs).tracking(1)
                                    .foregroundStyle(s == "Granted" ? DS.accent : DS.hi)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(DS.bg3, in: RoundedRectangle(cornerRadius: DS.rSm))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, DS.pad(density))
        }
    }

    // MARK: - Target Range

    private var targetRangeSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            DSSectionHeader(text: "Target range (mg/dL)")
                .padding(.horizontal, DS.pad(density))

            DSCard {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text("Low")
                            .font(.system(size: 14))
                            .foregroundStyle(DS.fg)
                        Spacer()
                        Stepper(value: $targetLow, in: 40...targetHigh - 5, step: 5) {
                            EmptyView()
                        }
                        .labelsHidden()
                        Text("\(targetLow)")
                            .font(.dsMonoSm)
                            .foregroundStyle(DS.lo)
                            .monospacedDigit()
                            .frame(width: 44, alignment: .trailing)
                    }
                    .padding(.vertical, 12)
                    .onChange(of: targetLow) { _ in Task { await save() } }

                    DS.line.frame(height: 1)

                    HStack {
                        Text("High")
                            .font(.system(size: 14))
                            .foregroundStyle(DS.fg)
                        Spacer()
                        Stepper(value: $targetHigh, in: targetLow + 5...400, step: 5) {
                            EmptyView()
                        }
                        .labelsHidden()
                        Text("\(targetHigh)")
                            .font(.dsMonoSm)
                            .foregroundStyle(DS.hi)
                            .monospacedDigit()
                            .frame(width: 44, alignment: .trailing)
                    }
                    .padding(.vertical, 12)
                    .onChange(of: targetHigh) { _ in Task { await save() } }

                    DS.line.frame(height: 1).padding(.top, 4)

                    Text("Sets the green band on the Live Activity graph and the color thresholds (green / orange / red).")
                        .font(.dsMonoXs)
                        .foregroundStyle(DS.fg3)
                        .lineSpacing(3)
                        .padding(.top, 8)
                }
            }
            .padding(.horizontal, DS.pad(density))
        }
    }

    // MARK: - Thresholds

    private var thresholdsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            DSSectionHeader(text: "Alert thresholds (mg/dL)")
                .padding(.horizontal, DS.pad(density))

            DSCard {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text("High alert")
                            .font(.system(size: 14))
                            .foregroundStyle(DS.fg)
                        Spacer()
                        Stepper(value: $alertHigh, in: 120...400, step: 5) {
                            Text("\(alertHigh)")
                                .font(.dsMonoSm)
                                .foregroundStyle(DS.hi)
                                .monospacedDigit()
                        }
                        .labelsHidden()
                        Text("\(alertHigh)")
                            .font(.dsMonoSm)
                            .foregroundStyle(DS.hi)
                            .monospacedDigit()
                            .frame(width: 44, alignment: .trailing)
                    }
                    .padding(.vertical, 12)
                    .onChange(of: alertHigh) { _ in Task { await save() } }

                    DS.line.frame(height: 1)

                    HStack {
                        Text("Low alert")
                            .font(.system(size: 14))
                            .foregroundStyle(DS.fg)
                        Spacer()
                        Stepper(value: $alertLow, in: 40...120, step: 5) {
                            Text("\(alertLow)")
                                .font(.dsMonoSm)
                                .foregroundStyle(DS.lo)
                                .monospacedDigit()
                        }
                        .labelsHidden()
                        Text("\(alertLow)")
                            .font(.dsMonoSm)
                            .foregroundStyle(DS.lo)
                            .monospacedDigit()
                            .frame(width: 44, alignment: .trailing)
                    }
                    .padding(.vertical, 12)
                    .onChange(of: alertLow) { _ in Task { await save() } }
                }
            }
            .padding(.horizontal, DS.pad(density))
        }
    }

    // MARK: - Test connection

    private var testSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            DSSectionHeader(text: "Test")
                .padding(.horizontal, DS.pad(density))

            DSCard {
                VStack(alignment: .leading, spacing: 0) {
                    if let msg = testMessage {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(testSucceeded == true ? DS.accent : DS.hi)
                                .frame(width: 8, height: 8)
                                .shadow(color: testSucceeded == true ? DS.accent : DS.hi, radius: 4)
                            Text(msg)
                                .font(.system(size: 13))
                                .foregroundStyle(DS.fg2)
                        }
                        .padding(.bottom, 10)
                    }

                    Button {
                        Task { await testConnection() }
                    } label: {
                        HStack(spacing: 6) {
                            if isTesting {
                                ProgressView()
                                    .tint(DS.accentInk)
                                    .scaleEffect(0.7)
                            }
                            Text(isTesting ? "Testing…" : "Test connection")
                                .font(.dsMonoSm)
                                .foregroundStyle(DS.accentInk)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(DS.accent, in: RoundedRectangle(cornerRadius: DS.rSm))
                    }
                    .buttonStyle(.plain)
                    .disabled(isTesting)
                }
            }
            .padding(.horizontal, DS.pad(density))
        }
    }

    // MARK: - Actions

    private func load() async {
        let s = UserSettings.shared
        username = await s.dexcomUsername
        password = await s.dexcomPassword
        region = await s.dexcomRegion
        dexcomEnabled = await s.dexcomEnabled
        notificationsEnabled = await s.glucoseNotificationsEnabled
        alertHigh = await s.glucoseAlertHigh
        alertLow = await s.glucoseAlertLow
        targetLow = await s.tirLow
        targetHigh = await s.tirHigh
    }

    private func save() async {
        let s = UserSettings.shared
        await s.setDexcomUsername(username)
        await s.setDexcomPassword(password)
        await s.setDexcomRegion(region)
        await s.setDexcomEnabled(dexcomEnabled)
        await s.setGlucoseNotificationsEnabled(notificationsEnabled)
        await s.setGlucoseAlertHigh(alertHigh)
        await s.setGlucoseAlertLow(alertLow)
        await s.setTirLow(targetLow)
        await s.setTirHigh(targetHigh)
    }

    private func testConnection() async {
        isTesting = true
        testMessage = nil
        testSucceeded = nil
        await save()
        do {
            let reading = try await DexcomService.shared.testConnection()
            testSucceeded = true
            testMessage = "OK · \(reading.value) mg/dL \(reading.trend.arrow)"
        } catch {
            testSucceeded = false
            testMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
        isTesting = false
    }
}
