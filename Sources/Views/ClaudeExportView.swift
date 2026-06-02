import SwiftUI

struct ClaudeExportView: View {
    @EnvironmentObject var vm: SyncViewModel
    @Environment(\.dsDensity) private var density

    @State private var startDate: Date = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
    @State private var endDate: Date = Date()
    @State private var isBuilding = false
    @State private var exportText: String = ""
    @State private var copied = false

    var body: some View {
        ScrollView {
            VStack(spacing: DS.gap(density)) {
                dateRangeCard
                if !exportText.isEmpty { previewCard }
                actionCard
            }
            .padding(.top, DS.pad(density))
            .padding(.bottom, 100)
        }
        .background(DS.bg)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                DSAppBar(title: "Claude Export", status: .live, right: AnyView(EmptyView()))
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbarBackground(DS.bg, for: .navigationBar)
    }

    // MARK: - Date range

    private var dateRangeCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            DSSectionHeader(text: "Date range")
                .padding(.horizontal, DS.pad(density))

            DSCard {
                VStack(spacing: 0) {
                    HStack {
                        Text("From".uppercased())
                            .font(.dsMonoXs).tracking(1).foregroundStyle(DS.fg3)
                        Spacer()
                        DatePicker("", selection: $startDate, in: ...endDate, displayedComponents: .date)
                            .labelsHidden()
                            .colorScheme(.dark)
                            .tint(DS.accent)
                    }
                    .padding(.vertical, 4)

                    DS.line.frame(height: 1)

                    HStack {
                        Text("To".uppercased())
                            .font(.dsMonoXs).tracking(1).foregroundStyle(DS.fg3)
                        Spacer()
                        DatePicker("", selection: $endDate, in: startDate...Date(), displayedComponents: .date)
                            .labelsHidden()
                            .colorScheme(.dark)
                            .tint(DS.accent)
                    }
                    .padding(.vertical, 4)

                    DS.line.frame(height: 1).padding(.vertical, 8)

                    // Quick range chips
                    HStack(spacing: 6) {
                        ForEach([7, 14, 30, 90], id: \.self) { days in
                            Button {
                                endDate   = Date()
                                startDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
                                exportText = ""
                            } label: {
                                Text("\(days)d")
                                    .font(.dsMonoXs)
                                    .foregroundStyle(rangeMatchesDays(days) ? DS.accentInk : DS.fg2)
                                    .padding(.horizontal, 10).padding(.vertical, 6)
                                    .background(
                                        rangeMatchesDays(days) ? DS.accent : DS.bg3,
                                        in: RoundedRectangle(cornerRadius: DS.rXs)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                        Spacer()
                        Text("\(dayCount) days selected")
                            .font(.dsMonoXs)
                            .foregroundStyle(DS.fg3)
                    }
                }
            }
            .padding(.horizontal, DS.pad(density))
        }
    }

    // MARK: - Preview

    private var previewCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            DSSectionHeader(text: "Preview")
                .padding(.horizontal, DS.pad(density))

            DSCard {
                ScrollView {
                    Text(exportText)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(DS.fg2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 260)
            }
            .padding(.horizontal, DS.pad(density))
        }
    }

    // MARK: - Actions

    private var actionCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            DSSectionHeader(text: exportText.isEmpty ? "Generate" : "Send to Claude")
                .padding(.horizontal, DS.pad(density))

            DSCard {
                VStack(spacing: 8) {
                    if exportText.isEmpty {
                        Button {
                            Task { await generate() }
                        } label: {
                            HStack(spacing: 8) {
                                if isBuilding {
                                    ProgressView().tint(DS.accentInk).scaleEffect(0.8)
                                } else {
                                    Text("✦").font(.system(size: 14))
                                }
                                Text(isBuilding ? "Building export…" : "Generate export")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(DS.accent)
                            .foregroundStyle(DS.accentInk)
                            .clipShape(RoundedRectangle(cornerRadius: DS.rSm))
                        }
                        .buttonStyle(.plain)
                        .disabled(isBuilding)
                    } else {
                        // Copy button
                        Button {
                            UIPasteboard.general.string = exportText
                            copied = true
                            Task {
                                try? await Task.sleep(for: .seconds(2))
                                copied = false
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                                    .font(.system(size: 14))
                                Text(copied ? "Copied!" : "Copy to clipboard")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(copied ? DS.bg3 : DS.bg2)
                            .foregroundStyle(copied ? DS.accent : DS.fg)
                            .clipShape(RoundedRectangle(cornerRadius: DS.rSm))
                            .overlay(RoundedRectangle(cornerRadius: DS.rSm).stroke(DS.line, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .animation(.easeInOut(duration: 0.2), value: copied)

                        // Open Claude button
                        Button {
                            UIPasteboard.general.string = exportText
                            openClaude()
                        } label: {
                            HStack(spacing: 8) {
                                Text("✦").font(.system(size: 14))
                                Text("Copy & open Claude")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(DS.accent)
                            .foregroundStyle(DS.accentInk)
                            .clipShape(RoundedRectangle(cornerRadius: DS.rSm))
                        }
                        .buttonStyle(.plain)

                        // Regenerate
                        Button {
                            exportText = ""
                        } label: {
                            Text("Change date range")
                                .font(.dsMonoSm)
                                .foregroundStyle(DS.fg3)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, DS.pad(density))
        }
    }

    // MARK: - Helpers

    private var dayCount: Int {
        max(1, Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 0)
    }

    private func rangeMatchesDays(_ days: Int) -> Bool {
        abs(Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 0) == days - 1
    }

    private func generate() async {
        isBuilding = true
        exportText = await vm.buildClaudeExport(from: startDate, to: endDate)
        isBuilding = false
    }

    private func openClaude() {
        // Try Claude app deep link first, fall back to claude.ai in Safari
        if let appURL = URL(string: "claude://"),
           UIApplication.shared.canOpenURL(appURL) {
            UIApplication.shared.open(appURL)
        } else if let webURL = URL(string: "https://claude.ai") {
            UIApplication.shared.open(webURL)
        }
    }
}
