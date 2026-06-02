import SwiftUI
import UniformTypeIdentifiers

// MARK: - ZIP Document Picker wrapper

struct ZIPDocumentPicker: UIViewControllerRepresentable {
    let onPick: (URL) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let types: [UTType] = [
            UTType(filenameExtension: "zip") ?? .data,
            .data
        ]
        let vc = UIDocumentPickerViewController(forOpeningContentTypes: types, asCopy: true)
        vc.delegate = context.coordinator
        vc.allowsMultipleSelection = false
        return vc
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (URL) -> Void
        init(onPick: @escaping (URL) -> Void) { self.onPick = onPick }

        func documentPicker(_ controller: UIDocumentPickerViewController,
                            didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            onPick(url)
        }
    }
}

// MARK: - Oura Export Import View

struct OuraImportView: View {
    @EnvironmentObject var viewModel: SyncViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showPicker      = false
    @State private var showWebLogin    = false
    @State private var showClearAlert  = false

    var body: some View {
        ZStack {
            Color.surfaceBg.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    // Hero
                    importHero

                    // Result card (post-import)
                    if let result = viewModel.importResult {
                        importResultCard(result)
                    }

                    // Error card
                    if let err = viewModel.importError {
                        errorCard(err)
                    }

                    // Primary: sign in via web
                    webLoginButton

                    // Divider
                    HStack {
                        Rectangle().fill(Color(white: 0.18)).frame(height: 1)
                        Text("or").font(.system(size: 12)).foregroundStyle(Color(white: 0.35))
                            .padding(.horizontal, 8)
                        Rectangle().fill(Color(white: 0.18)).frame(height: 1)
                    }

                    // Fallback: manual ZIP
                    manualImportButton

                    // Clear imported data
                    if viewModel.importResult != nil {
                        clearButton
                    }

                    Spacer().frame(height: 20)
                }
                .padding(.horizontal)
                .padding(.top, 8)
            }
        }
        .navigationTitle("Import Oura Data")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $showWebLogin) {
            OuraWebExportView()
                .preferredColorScheme(.dark)
        }
        .sheet(isPresented: $showPicker) {
            ZIPDocumentPicker { url in
                Task { await viewModel.importOuraExport(from: url) }
            }
        }
        .alert("Clear imported data?", isPresented: $showClearAlert) {
            Button("Clear", role: .destructive) {
                Task { await viewModel.clearImportedData() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes all CSV-imported Oura history. API-synced data is unaffected.")
        }
    }

    // MARK: - Hero

    private var importHero: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color(red: 0.20, green: 0.12, blue: 0.35))
                    .frame(width: 72, height: 72)
                Image(systemName: "archivebox.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(Color(red: 0.72, green: 0.55, blue: 0.98))
            }
            Text("Oura Data Export")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)
            Text("Import your full Oura history from the official data export. Gets all metrics regardless of API subscription — resilience, cardiovascular age, detailed sleep stages and more.")
                .font(.system(size: 14))
                .foregroundStyle(Color(white: 0.55))
                .multilineTextAlignment(.center)
                .lineSpacing(3)
        }
        .padding(.top, 8)
    }

    // MARK: - Steps

    private var stepsCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("HOW TO GET YOUR EXPORT")
            VStack(alignment: .leading, spacing: 12) {
                stepRow(n: "1", text: "Open **ouraring.com** → Log in")
                stepRow(n: "2", text: "Go to **Account → Data Export**")
                stepRow(n: "3", text: "Tap **Request data export**")
                stepRow(n: "4", text: "Wait for the email, download the ZIP")
                stepRow(n: "5", text: "Share the ZIP to this app below")
            }
            .padding(.top, 12)
        }
        .padding(18)
        .background(Color.cardBg, in: RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - Result

    private func importResultCard(_ result: OuraExportResult) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.ouraActivity)
                Text("Import successful")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
            }

            HStack(spacing: 0) {
                statCell(value: "\(result.daysImported)", label: "DAYS")
                Divider().frame(height: 40).background(Color.cardBg2)
                statCell(value: "\(result.workouts.count)", label: "WORKOUTS")
            }
            .background(Color(white: 0.07), in: RoundedRectangle(cornerRadius: 12))
        }
        .padding(16)
        .background(Color.ouraActivity.opacity(0.08), in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Color.ouraActivity.opacity(0.25), lineWidth: 1))
    }

    // MARK: - Error

    private func errorCard(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 4) {
                Text("Import failed")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                Text(message)
                    .font(.system(size: 13))
                    .foregroundStyle(Color(white: 0.55))
            }
        }
        .padding(16)
        .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.red.opacity(0.25), lineWidth: 1))
    }

    // MARK: - Buttons

    private var webLoginButton: some View {
        Button { showWebLogin = true } label: {
            HStack(spacing: 10) {
                Image(systemName: "globe")
                    .font(.system(size: 16, weight: .semibold))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Sign in to Oura")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Automatic — no manual download")
                        .font(.system(size: 12))
                        .opacity(0.75)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .opacity(0.6)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .background(Color(red: 0.50, green: 0.30, blue: 0.90), in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }

    private var manualImportButton: some View {
        Button {
            showPicker = true
        } label: {
            HStack(spacing: 10) {
                if viewModel.isImportingExport {
                    ProgressView().tint(Color(white: 0.6)).scaleEffect(0.85)
                    Text("Parsing…")
                } else {
                    Image(systemName: "square.and.arrow.down")
                    Text("Import ZIP manually")
                }
            }
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(Color(white: 0.55))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color(white: 0.10), in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color(white: 0.20), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isImportingExport)
    }

    private var clearButton: some View {
        Button {
            showClearAlert = true
        } label: {
            Text("Clear imported data")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color(white: 0.40))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.secondary)
            .tracking(1.5)
    }

    private func stepRow(n: String, text: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(n)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(Color(red: 0.72, green: 0.55, blue: 0.98))
                .frame(width: 22, height: 22)
                .background(Color(red: 0.20, green: 0.12, blue: 0.35), in: Circle())
            Text(text)
                .font(.system(size: 14))
                .foregroundStyle(Color(white: 0.75))
                .lineSpacing(2)
            Spacer()
        }
    }

    private func statCell(value: String, label: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.secondary)
                .tracking(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
    }
}
