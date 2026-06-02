import SwiftUI

struct OuraSettingsView: View {
    @EnvironmentObject var viewModel: SyncViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.surfaceBg.ignoresSafeArea()
            List {
                Section {
                    NavigationLink(destination: OuraImportView()) {
                        HStack(spacing: 12) {
                            Image(systemName: "archivebox.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Color(red: 0.72, green: 0.55, blue: 0.98))
                                .frame(width: 28)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Import Data Export")
                                    .font(.system(size: 15))
                                    .foregroundStyle(.white)
                                Text("Full history · no subscription needed")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                } header: {
                    Text("Data Import")
                } footer: {
                    Text("Sign in to Oura or import your export ZIP to get resilience, cardiovascular age, and complete history.")
                        .font(.caption)
                }
                .listRowBackground(Color.cardBg)
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Oura Ring")
    }
}
