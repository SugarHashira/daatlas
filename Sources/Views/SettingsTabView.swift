import SwiftUI

// MARK: - Settings Tab (SettingsA design)

struct SettingsTabView: View {
    @EnvironmentObject var vm: SyncViewModel
    @Environment(\.dsDensity) private var density
    @AppStorage("ui_density") private var densitySetting: DS.Density = .compact

    @State private var isTesting = false
    @State private var testResult: Bool? = nil
    @State private var isSaving = false

    // Dexcom section state
    @State private var dexcomEnabled: Bool = false
    @State private var dexcomUsername: String = ""

    // Oura direct picker
    @State private var showOuraPicker = false

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // ── Data Sources ─────────────────────────────
                groupHeader("Data Sources")
                VStack(spacing: DS.gap(density)) {
                    connectionSection
                    dexcomSection
                }

                // ── Sync ──────────────────────────────────────
                groupHeader("Sync")
                VStack(spacing: DS.gap(density)) {
                    syncSection
                    glucoseUnitSection
                    appleHealthSection
                    backgroundSyncSection
                    lookbackSection
                    syncLogsSection
                }

                // ── Integrations ──────────────────────────────
                groupHeader("Integrations")
                VStack(spacing: DS.gap(density)) {
                    ouraSection
                    kiloSection
                    claudeExportSection
                }

                // ── App ───────────────────────────────────────
                groupHeader("App")
                VStack(spacing: DS.gap(density)) {
                    journalSection
                    appearanceSection
                    aboutSection
                }

                Spacer().frame(height: 100)
            }
            .padding(.top, DS.pad(density))
        }
        .background(DS.bg)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                DSAppBar(title: "Settings", status: .live,
                         right: AnyView(DSBadge(text: "v1.4")))
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbarBackground(DS.bg, for: .navigationBar)
        .onAppear { Task { await loadDexcomStatus() } }
        .sheet(isPresented: $showOuraPicker) {
            ZIPDocumentPicker { url in
                Task { await vm.importOuraExport(from: url) }
            }
        }
    }

    private func loadDexcomStatus() async {
        let s = UserSettings.shared
        dexcomEnabled = await s.dexcomEnabled
        dexcomUsername = await s.dexcomUsername
    }

    // MARK: - Dexcom (CGM)

    private var dexcomSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            DSSectionHeader(text: "CGM · Dexcom")
                .padding(.horizontal, DS.pad(density))

            DSCard {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(dexcomEnabled ? DS.accent : DS.fg4)
                            .frame(width: 8, height: 8)
                            .shadow(color: dexcomEnabled ? DS.accent : .clear, radius: 4)
                        Text(dexcomEnabled
                             ? (dexcomUsername.isEmpty ? "enabled · no credentials" : "enabled · polling Dexcom Share")
                             : "disabled")
                            .font(.system(size: 13))
                            .foregroundStyle(DS.fg2)
                    }
                    .padding(.bottom, 10)

                    DSKVRow(key: "Username",
                            value: dexcomUsername.isEmpty ? "—" : maskUsername(dexcomUsername))
                    DSKVRow(key: "Polling",
                            value: dexcomEnabled ? "every 5 min" : "off",
                            showDivider: false)

                    NavigationLink(destination: DexcomSettingsView()
                        .onDisappear { Task { await loadDexcomStatus() } }) {
                        HStack(spacing: 8) {
                            Text("Configure")
                                .font(.dsMonoSm)
                                .foregroundStyle(DS.fg2)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(DS.fg4)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(DS.bg3, in: RoundedRectangle(cornerRadius: DS.rSm))
                    }
                    .padding(.top, 8)

                    NavigationLink(destination: LiveActivitySettingsView()) {
                        HStack(spacing: 8) {
                            Text("Live Activity")
                                .font(.dsMonoSm)
                                .foregroundStyle(DS.fg2)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(DS.fg4)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(DS.bg3, in: RoundedRectangle(cornerRadius: DS.rSm))
                    }
                    .padding(.top, 6)
                }
            }
            .padding(.horizontal, DS.pad(density))
        }
    }

    private func maskUsername(_ s: String) -> String {
        guard s.count > 2 else { return "●●" }
        let first = s.prefix(2)
        return "\(first)●●●●"
    }

    // MARK: - Connection

    private var connectionSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            DSSectionHeader(text: "Connection")
                .padding(.horizontal, DS.pad(density))

            DSCard {
                VStack(alignment: .leading, spacing: 0) {
                    // Status pill
                    HStack(spacing: 8) {
                        Circle()
                            .fill(vm.isConfigured ? DS.accent : DS.fg4)
                            .frame(width: 8, height: 8)
                            .shadow(color: vm.isConfigured ? DS.accent : .clear, radius: 4)
                        Text(vm.isConfigured
                             ? "nightscout · responding"
                             : "not configured")
                            .font(.system(size: 13))
                            .foregroundStyle(DS.fg2)
                    }
                    .padding(.bottom, 10)

                    DSKVRow(key: "URL",
                            value: vm.nightscoutURL.isEmpty ? "—" : shortenURL(vm.nightscoutURL))
                    DSKVRow(key: "API secret",
                            value: vm.nightscoutSecret.isEmpty ? "—" : "●●●●●●●●")
                    if let last = vm.lastSyncDate {
                        DSKVRow(key: "Last test",
                                value: "\(relativeTime(last)) · OK",
                                showDivider: false)
                    } else {
                        DSKVRow(key: "Last sync", value: "never", showDivider: false)
                    }

                    HStack(spacing: 8) {
                        NavigationLink(destination: ConnectionEditView()) {
                            Text("Edit")
                                .font(.dsMonoSm)
                                .foregroundStyle(DS.fg2)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(DS.bg3, in: RoundedRectangle(cornerRadius: DS.rSm))
                        }
                        Button {
                            Task {
                                isTesting = true
                                testResult = await vm.testConnection()
                                isTesting = false
                            }
                        } label: {
                            HStack(spacing: 6) {
                                if isTesting {
                                    ProgressView()
                                        .tint(DS.accentInk)
                                        .scaleEffect(0.7)
                                }
                                Text(isTesting ? "Testing…" : testResult == true ? "Connected" : "Test connection")
                                    .font(.dsMonoSm)
                                    .foregroundStyle(DS.accentInk)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(testResult == false ? DS.hi : DS.accent,
                                        in: RoundedRectangle(cornerRadius: DS.rSm))
                        }
                        .disabled(isTesting)
                    }
                    .padding(.top, 8)
                }
            }
            .padding(.horizontal, DS.pad(density))
        }
    }

    // MARK: - What to sync

    private var syncSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            DSSectionHeader(text: "What to sync")
                .padding(.horizontal, DS.pad(density))

            DSCard {
                VStack(spacing: 0) {
                    DSToggleRow(label: "Glucose readings",
                                sub: "CGM data → Apple Health",
                                isOn: $vm.syncGlucose)
                    DS.line.frame(height: 1)
                    DSToggleRow(label: "Insulin deliveries",
                                sub: "Bolus + basal segments",
                                isOn: $vm.syncInsulin)
                    DS.line.frame(height: 1)
                    DSToggleRow(label: "Carbohydrates",
                                sub: "From meal entries",
                                isOn: $vm.syncCarbs)
                }
            }
            .padding(.horizontal, DS.pad(density))
        }
    }

    // MARK: - Glucose unit

    private var glucoseUnitSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            DSSectionHeader(text: "Glucose unit")
                .padding(.horizontal, DS.pad(density))

            DSCard {
                HStack(spacing: 0) {
                    ForEach([GlucoseUnit.mgdl, GlucoseUnit.mmol], id: \.rawValue) { unit in
                        Button {
                            vm.selectedGlucoseUnit = unit
                            Task { await vm.saveSettings() }
                        } label: {
                            Text(unit == .mgdl ? "mg/dL" : "mmol/L")
                                .font(.dsMonoSm)
                                .foregroundStyle(vm.selectedGlucoseUnit == unit ? DS.accentInk : DS.fg2)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(
                                    vm.selectedGlucoseUnit == unit
                                        ? DS.accent
                                        : DS.bg3,
                                    in: RoundedRectangle(cornerRadius: DS.rXs)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(4)
                .background(DS.bg2, in: RoundedRectangle(cornerRadius: DS.rSm))
            }
            .padding(.horizontal, DS.pad(density))
        }
    }

    // MARK: - Background sync

    private var backgroundSyncSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            DSSectionHeader(text: "Background sync")
                .padding(.horizontal, DS.pad(density))

            DSCard {
                VStack(alignment: .leading, spacing: 0) {
                    DSToggleRow(label: "Auto-sync",
                                sub: "Periodic background fetch",
                                isOn: $vm.autoSyncEnabled)

                    if vm.autoSyncEnabled {
                        DS.line.frame(height: 1).padding(.vertical, 4)

                        HStack {
                            Text("Sync every".uppercased())
                                .font(.dsMonoXs)
                                .tracking(1.0)
                                .foregroundStyle(DS.fg3)
                            Spacer()
                            Text("\(vm.backgroundSyncInterval) min")
                                .font(.dsMonoSm)
                                .foregroundStyle(DS.fg)
                        }
                        .padding(.top, 4)

                        HStack(spacing: 0) {
                            ForEach([5, 15, 30, 60, 120], id: \.self) { v in
                                Button {
                                    vm.backgroundSyncInterval = v
                                    Task { await vm.saveSettings() }
                                } label: {
                                    Text(v < 60 ? "\(v)m" : "\(v/60)h")
                                        .font(.dsMonoXs)
                                        .foregroundStyle(vm.backgroundSyncInterval == v ? DS.accentInk : DS.fg2)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 7)
                                        .background(
                                            vm.backgroundSyncInterval == v
                                                ? DS.accent
                                                : DS.bg3,
                                            in: RoundedRectangle(cornerRadius: DS.rXs)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(4)
                        .background(DS.bg2, in: RoundedRectangle(cornerRadius: DS.rSm))
                        .padding(.top, 8)
                    }
                }
            }
            .padding(.horizontal, DS.pad(density))
        }
    }

    // MARK: - Look back

    private var lookbackSection: some View {
        let options = [7, 14, 30, 60, 90, 180, 365]
        return VStack(alignment: .leading, spacing: 6) {
            DSSectionHeader(text: "Look back")
                .padding(.horizontal, DS.pad(density))

            DSCard {
                VStack(alignment: .leading, spacing: 8) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 4) {
                            ForEach(options, id: \.self) { d in
                                Button {
                                    vm.lookbackDays = d
                                    Task { await vm.saveSettings() }
                                } label: {
                                    Text(d < 365 ? "\(d)d" : "1y")
                                        .font(.dsMonoXs)
                                        .foregroundStyle(vm.lookbackDays == d ? DS.accentInk : DS.fg2)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 7)
                                        .background(
                                            vm.lookbackDays == d
                                                ? DS.accent
                                                : DS.bg3,
                                            in: RoundedRectangle(cornerRadius: DS.rXs)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    DSKVRow(key: "Records considered",
                            value: "~\(approxRecords(vm.lookbackDays))",
                            showDivider: false)
                }
            }
            .padding(.horizontal, DS.pad(density))
        }
    }

    // MARK: - Apple Health

    private var appleHealthSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            DSSectionHeader(text: "Apple Health")
                .padding(.horizontal, DS.pad(density))

            DSCard {
                VStack(spacing: 0) {
                    // Status row
                    HStack(spacing: 8) {
                        Circle()
                            .fill(vm.isConfigured ? DS.accent : DS.fg4)
                            .frame(width: 8, height: 8)
                            .shadow(color: vm.isConfigured ? DS.accent : .clear, radius: 4)
                        Text(vm.isConfigured
                             ? "Connected · \(shortenURL(vm.nightscoutURL))"
                             : "Nightscout not configured")
                            .font(.system(size: 13))
                            .foregroundStyle(DS.fg2)
                            .lineLimit(1)
                    }
                    .padding(.bottom, 10)

                    DSKVRow(key: "Last sync",
                            value: vm.lastSyncDate.map { relativeTime($0) } ?? "never")
                    DSKVRow(key: "Glucose today",
                            value: "\(vm.todayGlucoseReadings.count) readings")
                    DSKVRow(key: "Insulin today",
                            value: "\(vm.todayInsulinDoses.count) bolus")
                    DSKVRow(key: "Authorization",
                            value: "Granted · 4 types",
                            valueColor: DS.accent,
                            showDivider: false)

                    HStack(spacing: 8) {
                        Button {
                            Task { await vm.requestHealthKitAuthorization() }
                        } label: {
                            Text("Re-authorize")
                                .font(.dsMonoSm)
                                .foregroundStyle(DS.fg2)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(DS.bg3, in: RoundedRectangle(cornerRadius: DS.rSm))
                        }
                        .buttonStyle(.plain)

                        Button {
                            Task { await vm.syncNow() }
                        } label: {
                            HStack(spacing: 6) {
                                if vm.isSyncing {
                                    ProgressView()
                                        .tint(DS.accentInk)
                                        .scaleEffect(0.7)
                                } else {
                                    Text("↻").font(.system(size: 14))
                                }
                                Text(vm.isSyncing ? "Syncing…" : "Sync now")
                                    .font(.dsMonoSm)
                                    .foregroundStyle(DS.accentInk)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(DS.accent, in: RoundedRectangle(cornerRadius: DS.rSm))
                        }
                        .buttonStyle(.plain)
                        .disabled(vm.isSyncing)
                    }
                    .padding(.top, 8)
                }
            }
            .padding(.horizontal, DS.pad(density))
        }
    }

    // MARK: - Oura CSV

    private var ouraSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            DSSectionHeader(text: "Oura · CSV import")
                .padding(.horizontal, DS.pad(density))

            DSCard {
                VStack(alignment: .leading, spacing: 0) {
                    if vm.importResult != nil {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(DS.accent)
                                .frame(width: 8, height: 8)
                                .shadow(color: DS.accent, radius: 4)
                            Text("oura_export.csv · imported today")
                                .font(.system(size: 13))
                                .foregroundStyle(DS.fg2)
                        }
                        .padding(.bottom, 10)

                        DSKVRow(key: "Nights imported",
                                value: "\(vm.dailySummaries.count)")
                        DSKVRow(key: "Sleep score",   value: "parsed")
                        DSKVRow(key: "Readiness",     value: "parsed")
                        DSKVRow(key: "HRV (avg)",     value: "parsed")
                        DSKVRow(key: "Activity score", value: "parsed",
                                showDivider: false)
                    } else {
                        Text("No CSV imported yet.")
                            .font(.system(size: 14))
                            .foregroundStyle(DS.fg3)
                            .padding(.bottom, 8)
                    }

                    HStack(spacing: 8) {
                        Button {
                            showOuraPicker = true
                        } label: {
                            HStack(spacing: 6) {
                                if vm.isImportingExport {
                                    ProgressView().tint(DS.accentInk).scaleEffect(0.7)
                                }
                                Text(vm.isImportingExport ? "Parsing…" : vm.importResult != nil ? "Re-import ZIP" : "Import ZIP")
                                    .font(.dsMonoSm)
                                    .foregroundStyle(DS.accentInk)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(DS.accent, in: RoundedRectangle(cornerRadius: DS.rSm))
                        }
                        .buttonStyle(.plain)
                        .disabled(vm.isImportingExport)

                        NavigationLink(destination: OuraImportView()) {
                            Text("More options")
                                .font(.dsMonoSm)
                                .foregroundStyle(DS.fg2)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(DS.bg3, in: RoundedRectangle(cornerRadius: DS.rSm))
                        }
                    }
                    .padding(.top, vm.importResult != nil ? 8 : 0)
                }
            }
            .padding(.horizontal, DS.pad(density))
        }
    }

    // MARK: - Sync logs (summary)

    private var syncLogsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            DSSectionHeader(text: "Sync logs")
                .padding(.horizontal, DS.pad(density))

            DSCard {
                VStack(alignment: .leading, spacing: 0) {
                    // Summary strip
                    let ok = vm.syncLogs.filter { !$0.hasErrors }.count
                    let errors = vm.syncLogs.filter { $0.hasErrors }.count
                    let totalRecords = vm.syncLogs.reduce(0) { $0 + $1.totalSynced }

                    DSStatStrip(cells: [
                        .init(label: "Runs · 24h", value: "\(vm.syncLogs.count)",
                              delta: "\(ok) OK", deltaUp: true),
                        .init(label: "Records", value: "\(totalRecords)",
                              delta: "written"),
                        .init(label: "Errors",
                              value: "\(errors)",
                              delta: errors > 0 ? "timeout" : "none",
                              valueColor: errors > 0 ? DS.hi : DS.fg),
                    ])
                    .padding(.bottom, 10)

                    // Recent rows
                    ForEach(vm.syncLogs.prefix(4)) { log in
                        SyncLogRow(log: log)
                    }
                }
            }
            .padding(.horizontal, DS.pad(density))
        }
    }

    // MARK: - Kilo Gateway

    private var kiloSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            DSSectionHeader(text: "Kilo Gateway · AI")
                .padding(.horizontal, DS.pad(density))

            DSCard {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(vm.kiloAPIKey.isEmpty ? DS.fg4 : DS.accent)
                            .frame(width: 8, height: 8)
                            .shadow(color: vm.kiloAPIKey.isEmpty ? .clear : DS.accent, radius: 4)
                        Text(vm.kiloAPIKey.isEmpty ? "not configured" : "configured · food carb estimation active")
                            .font(.system(size: 13))
                            .foregroundStyle(DS.fg2)
                    }
                    .padding(.bottom, 10)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("API KEY".uppercased())
                            .font(.dsMonoXs).tracking(1).foregroundStyle(DS.fg3)
                        SecureField("kilo-…", text: $vm.kiloAPIKey)
                            .font(.dsMonoSm).foregroundStyle(DS.fg)
                            .autocapitalization(.none)
                            .autocorrectionDisabled()
                            .onSubmit { Task { await vm.saveSettings() } }
                    }
                    .padding(.vertical, 8)

                    DS.line.frame(height: 1)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("MODEL".uppercased())
                            .font(.dsMonoXs).tracking(1).foregroundStyle(DS.fg3)
                        TextField("anthropic/claude-sonnet-4-6", text: $vm.kiloModel)
                            .font(.dsMonoSm).foregroundStyle(DS.fg)
                            .autocapitalization(.none)
                            .autocorrectionDisabled()
                            .onSubmit { Task { await vm.saveSettings() } }
                    }
                    .padding(.vertical, 8)

                    DS.line.frame(height: 1).padding(.bottom, 8)

                    Button {
                        Task { await vm.saveSettings() }
                    } label: {
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

    // MARK: - Journal

    private var journalSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            DSSectionHeader(text: "Journal")
                .padding(.horizontal, DS.pad(density))

            DSCard {
                VStack(spacing: 0) {
                    DSKVRow(key: "Built-in items",
                            value: "\(JournalItemKey.allCases.count - vm.hiddenJournalItems.count) visible")
                    DSKVRow(key: "Custom items",
                            value: "\(vm.customJournalItems.count)",
                            showDivider: false)

                    NavigationLink(destination: ConfigureJournalSheet()) {
                        HStack(spacing: 8) {
                            Text("Manage journal items")
                                .font(.dsMonoSm)
                                .foregroundStyle(DS.fg2)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(DS.fg4)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(DS.bg3, in: RoundedRectangle(cornerRadius: DS.rSm))
                    }
                    .padding(.top, 8)
                }
            }
            .padding(.horizontal, DS.pad(density))
        }
    }

    // MARK: - Claude export

    private var claudeExportSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            DSSectionHeader(text: "Claude AI · Export")
                .padding(.horizontal, DS.pad(density))

            DSCard {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Text("✦")
                            .font(.system(size: 16))
                            .foregroundStyle(DS.accent)
                        Text("Export health data for AI analysis")
                            .font(.system(size: 13))
                            .foregroundStyle(DS.fg)
                    }
                    Text("Select a date range, generate a structured summary of glucose, insulin, and Oura vitals, then send it to Claude for pattern insights.")
                        .font(.dsMonoXs)
                        .foregroundStyle(DS.fg3)
                        .lineSpacing(3)

                    NavigationLink(destination: ClaudeExportView()) {
                        Text("Open export →")
                            .font(.dsMonoSm)
                            .foregroundStyle(DS.accentInk)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(DS.accent, in: RoundedRectangle(cornerRadius: DS.rSm))
                    }
                }
            }
            .padding(.horizontal, DS.pad(density))
        }
    }

    // MARK: - Appearance

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            DSSectionHeader(text: "Appearance")
                .padding(.horizontal, DS.pad(density))

            DSCard {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Density")
                            .font(.system(size: 14))
                            .foregroundStyle(DS.fg)
                        Spacer()
                    }
                    HStack(spacing: 0) {
                        ForEach(DS.Density.allCases, id: \.rawValue) { d in
                            Button {
                                densitySetting = d
                            } label: {
                                Text(d.rawValue.capitalized)
                                    .font(.dsMonoXs)
                                    .foregroundStyle(densitySetting == d ? DS.accentInk : DS.fg2)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(
                                        densitySetting == d
                                            ? DS.accent
                                            : DS.bg3,
                                        in: RoundedRectangle(cornerRadius: DS.rXs)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(4)
                    .background(DS.bg2, in: RoundedRectangle(cornerRadius: DS.rSm))
                }
            }
            .padding(.horizontal, DS.pad(density))
        }
    }

    // MARK: - About

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            DSSectionHeader(text: "About")
                .padding(.horizontal, DS.pad(density))

            DSCard {
                VStack(spacing: 0) {
                    DSKVRow(key: "Version",     value: "1.4.0 (build 142)")
                    DSKVRow(key: "iOS minimum", value: "16.0")
                    DSKVRow(key: "License",     value: "MIT", showDivider: false)
                }
            }
            .padding(.horizontal, DS.pad(density))
        }
    }

    // MARK: - Helpers

    private func groupHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(DS.fg3)
            .tracking(0.5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, DS.pad(density))
            .padding(.top, 28)
            .padding(.bottom, DS.gap(density))
    }

    private func shortenURL(_ url: String) -> String {
        url.replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "http://", with: "")
    }

    private func relativeTime(_ date: Date) -> String {
        let diff = Int(-date.timeIntervalSinceNow / 60)
        if diff < 1 { return "just now" }
        if diff < 60 { return "\(diff)m ago" }
        return "\(diff / 60)h ago"
    }

    private func approxRecords(_ days: Int) -> String {
        let n = days * 288 // 5-min CGM
        if n >= 1000 { return "\(n / 1000),\(String(format: "%03d", n % 1000))" }
        return "\(n)"
    }
}

// MARK: - Connection edit placeholder

private struct ConnectionEditView: View {
    @EnvironmentObject var vm: SyncViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    DSCard {
                        VStack(alignment: .leading, spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Nightscout URL".uppercased())
                                    .font(.dsMonoXs).tracking(1.2).foregroundStyle(DS.fg3)
                                TextField("https://…", text: $vm.nightscoutURL)
                                    .font(.dsMonoSm)
                                    .foregroundStyle(DS.fg)
                                    .autocapitalization(.none)
                                    .keyboardType(.URL)
                                DS.line.frame(height: 1)
                            }
                            VStack(alignment: .leading, spacing: 4) {
                                Text("API secret".uppercased())
                                    .font(.dsMonoXs).tracking(1.2).foregroundStyle(DS.fg3)
                                SecureField("secret", text: $vm.nightscoutSecret)
                                    .font(.dsMonoSm)
                                    .foregroundStyle(DS.fg)
                            }
                        }
                    }
                    .padding(.horizontal, 16)

                    Button {
                        Task {
                            await vm.saveSettings()
                            dismiss()
                        }
                    } label: {
                        Text("Save")
                            .font(.dsMonoSm)
                            .foregroundStyle(DS.accentInk)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(DS.accent, in: RoundedRectangle(cornerRadius: DS.rSm))
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.top, 16)
            }
            .background(DS.bg)
            .preferredColorScheme(.dark)
            .navigationTitle("Edit connection")
        }
    }
}

// MARK: - Sync log row

private struct SyncLogRow: View {
    let log: SyncLog

    private var timeStr: String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: log.date)
    }

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(timeStr)
                    .font(.dsMonoSm)
                    .foregroundStyle(DS.fg)
                Text("Today")
                    .font(.dsMonoXs)
                    .foregroundStyle(DS.fg3)
            }
            .frame(width: 44, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                if log.hasErrors {
                    Text(log.errors.first ?? "Error")
                        .font(.system(size: 13))
                        .foregroundStyle(DS.hi)
                } else {
                    Text("Synced \(log.totalSynced) \(log.totalSynced == 1 ? "record" : "records")")
                        .font(.system(size: 13))
                        .foregroundStyle(DS.fg)
                }
                Text("G \(log.glucoseSynced)/\(log.pendingGlucose) · I \(log.insulinSynced)/\(log.pendingInsulin) · C \(log.carbsSynced)/\(log.pendingCarbs)")
                    .font(.dsMonoXs)
                    .foregroundStyle(DS.fg3)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            DSBadge(text: log.hasErrors ? "ERR" : "OK",
                    accent: !log.hasErrors)
        }
        .padding(.vertical, 8)
        .overlay(alignment: .bottom) { DS.line.frame(height: 1) }
    }
}
