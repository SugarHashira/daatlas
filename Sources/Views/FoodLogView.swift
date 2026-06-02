import SwiftUI
import Charts
import PhotosUI

// MARK: - Food Log Tab

struct FoodLogView: View {
    @EnvironmentObject var vm: SyncViewModel
    @Environment(\.dsDensity) private var density

    @State private var showAddSheet = false
    @State private var editEntry: FoodEntry? = nil

    private var todayEntries: [FoodEntry] {
        let today = Calendar.current.startOfDay(for: Date())
        return vm.foodEntries.filter { Calendar.current.startOfDay(for: $0.date) == today }
    }

    private var olderEntries: [FoodEntry] {
        let today = Calendar.current.startOfDay(for: Date())
        return vm.foodEntries.filter { Calendar.current.startOfDay(for: $0.date) < today }
    }

    private var totalCarbsToday: Double {
        todayEntries.compactMap(\.carbs).reduce(0, +)
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            DS.bg.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: DS.gap(density)) {
                    if !todayEntries.isEmpty { summaryCard }
                    if todayEntries.isEmpty && olderEntries.isEmpty {
                        emptyState
                    } else {
                        if !todayEntries.isEmpty {
                            entriesSection(title: "Today", entries: todayEntries)
                        }
                        if !olderEntries.isEmpty {
                            entriesSection(title: "Earlier", entries: Array(olderEntries.prefix(20)))
                        }
                    }
                    Spacer().frame(height: 120)
                }
                .padding(.horizontal, 16)
                .padding(.top, DS.gap(density))
            }

            // FAB
            Button { showAddSheet = true } label: {
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(DS.accentInk)
                    .frame(width: 56, height: 56)
                    .background(DS.accent, in: Circle())
                    .shadow(color: DS.accent.opacity(0.4), radius: 12, y: 4)
            }
            .buttonStyle(.plain)
            .padding(.trailing, 20)
            .padding(.bottom, 110)
        }
        .navigationBarHidden(true)
        .safeAreaInset(edge: .top) {
            DSAppBar(title: "Food Log", status: .live,
                     right: AnyView(DSBadge(text: vm.kiloAPIKey.isEmpty ? "NO KEY" : "AI ON",
                                            accent: !vm.kiloAPIKey.isEmpty)))
        }
        .sheet(isPresented: $showAddSheet) {
            AddFoodSheet()
        }
        .sheet(item: $editEntry) { entry in
            AddFoodSheet(editing: entry)
        }
    }

    // MARK: Summary card

    private var summaryCard: some View {
        DSCard {
            HStack(spacing: 0) {
                summaryCell(label: "Meals today", value: "\(todayEntries.count)")
                Divider().frame(height: 40).background(DS.line)
                summaryCell(label: "Total carbs", value: "\(Int(totalCarbsToday))g")
                Divider().frame(height: 40).background(DS.line)
                summaryCell(label: "Avg per meal",
                            value: todayEntries.isEmpty ? "–" : "\(Int(totalCarbsToday / Double(todayEntries.count)))g")
            }
        }
    }

    private func summaryCell(label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.dsMono).foregroundStyle(DS.fg).monospacedDigit()
            Text(label).font(.dsMonoXs).foregroundStyle(DS.fg3)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Entry list section

    private func entriesSection(title: String, entries: [FoodEntry]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            DSSectionHeader(text: title).padding(.horizontal, 0)
            ForEach(entries) { entry in
                FoodEntryCard(entry: entry)
                    .onTapGesture { editEntry = entry }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            Task { await vm.deleteFoodEntry(id: entry.id) }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
            }
        }
    }

    // MARK: Empty state

    private var emptyState: some View {
        VStack(spacing: 14) {
            Spacer().frame(height: 60)
            Image(systemName: "fork.knife.circle")
                .font(.system(size: 52, weight: .thin))
                .foregroundStyle(DS.fg4)
            Text("No meals logged")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(DS.fg2)
            Text("Tap + to log a meal and estimate carbs with AI")
                .font(.dsMonoXs).foregroundStyle(DS.fg3)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

// MARK: - Food Entry Card

struct FoodEntryCard: View {
    @EnvironmentObject var vm: SyncViewModel
    let entry: FoodEntry

    private var timeFmt: DateFormatter {
        let f = DateFormatter(); f.dateFormat = "HH:mm"; return f
    }

    private var impactReadings: [ChartGlucosePoint] { vm.postMealGlucose(after: entry) }

    private var glucoseDelta: Int? {
        guard impactReadings.count >= 2 else { return nil }
        return Int((impactReadings.max(by: { $0.value < $1.value })?.value ?? 0) - (impactReadings.first?.value ?? 0))
    }

    var body: some View {
        DSCard {
            VStack(alignment: .leading, spacing: 8) {
                // Header row
                HStack(alignment: .top, spacing: 10) {
                    if let data = entry.imageData, let img = UIImage(data: data) {
                        Image(uiImage: img)
                            .resizable().scaledToFill()
                            .frame(width: 48, height: 48)
                            .clipShape(RoundedRectangle(cornerRadius: DS.rSm))
                    } else {
                        ZStack {
                            RoundedRectangle(cornerRadius: DS.rSm).fill(DS.bg3)
                            Image(systemName: "fork.knife")
                                .font(.system(size: 18, weight: .light))
                                .foregroundStyle(DS.fg4)
                        }
                        .frame(width: 48, height: 48)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text(entry.description)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(DS.fg)
                            .lineLimit(2)
                        HStack(spacing: 8) {
                            Text(timeFmt.string(from: entry.date))
                                .font(.dsMonoXs).foregroundStyle(DS.fg3)
                            if let c = entry.carbs {
                                Text("·").foregroundStyle(DS.fg4)
                                Text("\(Int(c))g carbs")
                                    .font(.dsMonoXs).foregroundStyle(DS.accent)
                            }
                            if let conf = entry.confidence {
                                Text("·").foregroundStyle(DS.fg4)
                                confidenceBadge(conf)
                            }
                        }
                    }
                    Spacer()
                    if let c = entry.carbs {
                        Text("\(Int(c))g")
                            .font(.system(size: 22, weight: .medium, design: .monospaced))
                            .foregroundStyle(DS.fg)
                            .monospacedDigit()
                    }
                }

                // AI notes
                if let notes = entry.aiNotes, !notes.isEmpty {
                    Text(notes)
                        .font(.dsMonoXs).foregroundStyle(DS.fg3)
                        .lineLimit(2)
                }

                // Post-meal glucose impact
                if !impactReadings.isEmpty {
                    Divider().background(DS.line)
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("POST-MEAL · 3H")
                                .font(.dsMonoXs).tracking(0.8).foregroundStyle(DS.fg3)
                            if let delta = glucoseDelta {
                                Text(delta > 0 ? "+\(delta) mg/dL peak" : "\(delta) mg/dL")
                                    .font(.dsMonoSm)
                                    .foregroundStyle(delta > 60 ? DS.hi : delta > 30 ? DS.lo : DS.accent)
                            }
                        }
                        Spacer()
                        PostMealSparkline(readings: impactReadings)
                            .frame(width: 120, height: 36)
                    }
                }
            }
        }
    }

    private func confidenceBadge(_ conf: String) -> some View {
        let color: Color = conf == "high" ? DS.accent : conf == "medium" ? DS.lo : DS.hi
        return Text(conf)
            .font(.dsMonoXs).foregroundStyle(color)
            .padding(.horizontal, 5).padding(.vertical, 2)
            .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 4))
    }
}

// MARK: - Post-meal sparkline

struct PostMealSparkline: View {
    let readings: [ChartGlucosePoint]

    var body: some View {
        if readings.isEmpty { return AnyView(EmptyView()) }
        let lo = readings.map(\.value).min() ?? 70
        let hi = max((readings.map(\.value).max() ?? 180), lo + 20)
        return AnyView(
            Chart {
                ForEach(readings) { pt in
                    LineMark(x: .value("T", pt.date), y: .value("G", pt.value))
                        .foregroundStyle(DS.accent)
                        .lineStyle(StrokeStyle(lineWidth: 1.5))
                        .interpolationMethod(.catmullRom)
                }
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .chartYScale(domain: (lo - 10)...(hi + 10))
            .clipped()
        )
    }
}

// MARK: - Add / Edit Food Sheet

struct AddFoodSheet: View {
    @EnvironmentObject var vm: SyncViewModel
    @Environment(\.dismiss) private var dismiss

    var editing: FoodEntry? = nil

    @State private var description: String = ""
    @State private var confirmedCarbs: String = ""
    @State private var selectedPhoto: PhotosPickerItem? = nil
    @State private var capturedImage: UIImage? = nil
    @State private var showCamera = false
    @State private var estimate: CarbEstimate? = nil
    @State private var isEstimating = false
    @State private var estimateError: String? = nil
    @State private var date: Date = Date()

    var body: some View {
        NavigationStack {
            ZStack {
                DS.bg.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 16) {
                        // Photo area
                        photoSection

                        // Description
                        DSCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("MEAL DESCRIPTION".uppercased())
                                    .font(.dsMonoXs).tracking(1).foregroundStyle(DS.fg3)
                                TextField("e.g. chicken rice bowl with vegetables", text: $description, axis: .vertical)
                                    .font(.system(size: 14))
                                    .foregroundStyle(DS.fg)
                                    .lineLimit(3)
                            }
                        }
                        .padding(.horizontal, 16)

                        // Estimate button
                        if !description.isEmpty || capturedImage != nil {
                            estimateButton
                        }

                        // Estimate result
                        if let est = estimate {
                            estimateResultCard(est)
                        }

                        // Error
                        if let err = estimateError {
                            DSCard {
                                Text(err).font(.dsMonoXs).foregroundStyle(DS.hi)
                            }
                            .padding(.horizontal, 16)
                        }

                        // Manual carbs override
                        DSCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("CONFIRMED CARBS (G) — OPTIONAL".uppercased())
                                    .font(.dsMonoXs).tracking(1).foregroundStyle(DS.fg3)
                                TextField(estimate.map { "\(Int($0.carbsG))" } ?? "override AI estimate", text: $confirmedCarbs)
                                    .font(.dsMono)
                                    .foregroundStyle(DS.fg)
                                    .keyboardType(.decimalPad)
                            }
                        }
                        .padding(.horizontal, 16)

                        // Date/time
                        DSCard {
                            HStack {
                                Text("TIME".uppercased())
                                    .font(.dsMonoXs).tracking(1).foregroundStyle(DS.fg3)
                                Spacer()
                                DatePicker("", selection: $date, displayedComponents: [.date, .hourAndMinute])
                                    .labelsHidden()
                                    .colorScheme(.dark)
                                    .tint(DS.accent)
                            }
                        }
                        .padding(.horizontal, 16)

                        Spacer().frame(height: 20)
                    }
                    .padding(.top, 16)
                }
            }
            .navigationTitle(editing == nil ? "Log Meal" : "Edit Meal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }.foregroundStyle(DS.fg2)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .foregroundStyle(canSave ? DS.accent : DS.fg4)
                        .disabled(!canSave)
                }
            }
            .toolbarBackground(DS.bg, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .sheet(isPresented: $showCamera) {
                CameraPickerView(image: $capturedImage)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear { prefill() }
    }

    // MARK: Photo section

    private var photoSection: some View {
        HStack(spacing: 10) {
            // Camera
            Button { showCamera = true } label: {
                photoButton(icon: "camera.fill", label: "Camera")
            }
            .buttonStyle(.plain)

            // Gallery
            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                photoButton(icon: "photo.on.rectangle", label: "Gallery")
            }
            .buttonStyle(.plain)
            .onChange(of: selectedPhoto) { item in
                Task {
                    if let data = try? await item?.loadTransferable(type: Data.self),
                       let img  = UIImage(data: data) {
                        capturedImage = img
                    }
                }
            }

            // Preview
            if let img = capturedImage {
                Spacer()
                Image(uiImage: img)
                    .resizable().scaledToFill()
                    .frame(width: 72, height: 72)
                    .clipShape(RoundedRectangle(cornerRadius: DS.rSm))
                    .overlay(
                        Button { capturedImage = nil } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.white)
                                .background(Circle().fill(Color.black.opacity(0.5)))
                        }
                        .buttonStyle(.plain)
                        .padding(4),
                        alignment: .topTrailing
                    )
            }
        }
        .padding(.horizontal, 16)
    }

    private func photoButton(icon: String, label: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 14))
            Text(label).font(.dsMonoXs)
        }
        .foregroundStyle(DS.fg2)
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(DS.bg2, in: RoundedRectangle(cornerRadius: DS.rSm))
        .overlay(RoundedRectangle(cornerRadius: DS.rSm).stroke(DS.line, lineWidth: 1))
    }

    // MARK: Estimate button

    private var estimateButton: some View {
        Button {
            Task { await runEstimate() }
        } label: {
            HStack(spacing: 8) {
                if isEstimating {
                    ProgressView().tint(DS.accentInk).scaleEffect(0.8)
                } else {
                    Text("✦").font(.system(size: 13))
                }
                Text(isEstimating ? "Estimating…" : "Estimate carbs with AI")
                    .font(.system(size: 14, weight: .semibold))
            }
            .frame(maxWidth: .infinity).frame(height: 46)
            .background(DS.accent)
            .foregroundStyle(DS.accentInk)
            .clipShape(RoundedRectangle(cornerRadius: DS.rSm))
        }
        .buttonStyle(.plain)
        .disabled(isEstimating || vm.kiloAPIKey.isEmpty)
        .padding(.horizontal, 16)
        .overlay(alignment: .bottom) {
            if vm.kiloAPIKey.isEmpty {
                Text("Add Kilo API key in Settings first")
                    .font(.dsMonoXs).foregroundStyle(DS.hi)
                    .padding(.top, 50)
            }
        }
    }

    // MARK: Estimate result

    private func estimateResultCard(_ est: CarbEstimate) -> some View {
        DSCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("✦ AI ESTIMATE".uppercased())
                        .font(.dsMonoXs).tracking(1).foregroundStyle(DS.accent)
                    Spacer()
                    let color: Color = est.confidence == "high" ? DS.accent : est.confidence == "medium" ? DS.lo : DS.hi
                    Text(est.confidence).font(.dsMonoXs).foregroundStyle(color)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 4))
                }
                HStack(alignment: .lastTextBaseline, spacing: 6) {
                    Text("\(Int(est.carbsG))")
                        .font(.system(size: 36, weight: .medium, design: .monospaced))
                        .foregroundStyle(DS.fg)
                    Text("g carbs").font(.dsMono).foregroundStyle(DS.fg3)
                }
                Text(est.foodName).font(.system(size: 13)).foregroundStyle(DS.fg2)
                if !est.notes.isEmpty {
                    Text(est.notes).font(.dsMonoXs).foregroundStyle(DS.fg3).lineSpacing(3)
                }
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: Helpers

    private var canSave: Bool {
        !description.isEmpty || estimate != nil
    }

    private func prefill() {
        guard let e = editing else { return }
        description    = e.description
        confirmedCarbs = e.confirmedCarbs.map { "\(Int($0))" } ?? ""
        date           = e.date
    }

    private func runEstimate() async {
        estimateError = nil
        isEstimating  = true
        defer { isEstimating = false }
        do {
            if let img = capturedImage {
                estimate = try await vm.estimateCarbs(image: img, hint: description)
            } else {
                estimate = try await vm.estimateCarbs(description: description)
            }
            // Auto-fill description from AI if blank
            if description.isEmpty, let est = estimate {
                description = est.foodName
            }
        } catch {
            estimateError = error.localizedDescription
        }
    }

    private func save() {
        let confirmed = Double(confirmedCarbs)
        let imgData   = capturedImage?.jpegData(compressionQuality: 0.6)

        var entry = FoodEntry(
            id:             editing?.id ?? UUID(),
            date:           date,
            description:    description.isEmpty ? (estimate?.foodName ?? "Meal") : description,
            estimatedCarbs: estimate?.carbsG,
            confirmedCarbs: confirmed,
            confidence:     estimate?.confidence,
            aiNotes:        estimate?.notes,
            imageData:      imgData ?? editing?.imageData
        )
        _ = entry  // suppress warning — already initialised above

        Task {
            await vm.upsertFoodEntry(entry)
            dismiss()
        }
    }
}

// MARK: - Camera picker

struct CameraPickerView: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
        picker.delegate   = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPickerView
        init(_ parent: CameraPickerView) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            parent.image = (info[.editedImage] ?? info[.originalImage]) as? UIImage
            parent.dismiss()
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
