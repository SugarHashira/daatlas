import SwiftUI

// MARK: - Main view

struct JournalView: View {
    @EnvironmentObject var viewModel: SyncViewModel
    @State private var editKey: JournalItemKey? = nil
    @State private var numericInput: String = ""
    @State private var selectedDay: String = JournalView.todayStr()
    @State private var showLogWorkout  = false
    @State private var showConfigure   = false
    @State private var editCustomItem: CustomJournalItem? = nil

    static func todayStr() -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f.string(from: Date())
    }

    private var entry: JournalDayEntry {
        viewModel.journalEntries.first { $0.day == selectedDay } ?? JournalDayEntry(day: selectedDay)
    }

    var body: some View {
        ZStack {
            Color.surfaceBg.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    header
                    weekStrip
                        .padding(.top, 16)
                    itemSections
                        .padding(.top, 20)
                    workoutsSection
                        .padding(.top, 20)
                    pumpEventsSection
                        .padding(.top, 20)
                    Spacer().frame(height: 32)
                }
            }
        }
        .navigationTitle("")
        .sheet(isPresented: $showLogWorkout) {
            LogWorkoutSheet { entry in
                Task { await viewModel.logWorkout(entry) }
            }
        }
        .sheet(item: $editKey) { key in
            switch key.inputType {
            case .numeric(let unit):
                NumericEntrySheet(key: key, unit: unit, current: entry.numericValue(for: key)) { val in
                    var e = entry
                    e.set(number: val, for: key)
                    Task { await viewModel.upsertJournalEntry(e) }
                }
            case .scale:
                ScalePickerSheet(key: key, current: entry.scaleValue(for: key)) { val in
                    var e = entry
                    e.set(scale: val, for: key)
                    Task { await viewModel.upsertJournalEntry(e) }
                }
            case .boolean:
                EmptyView()
            }
        }
        .sheet(isPresented: $showConfigure) {
            ConfigureJournalSheet()
        }
        .sheet(item: $editCustomItem) { item in
            let cid = item.id.uuidString
            switch item.type {
            case .numeric:
                NumericEntrySheet(
                    key: .mood,
                    unit: item.unit,
                    current: entry.numbers[cid],
                    titleOverride: item.name,
                    emojiOverride: item.emoji
                ) { val in
                    var e = entry
                    e.set(number: val, customID: cid)
                    Task { await viewModel.upsertJournalEntry(e) }
                }
            case .scale:
                ScalePickerSheet(key: .mood, current: entry.scales[cid]) { val in
                    var e = entry
                    e.set(scale: val, customID: cid)
                    Task { await viewModel.upsertJournalEntry(e) }
                }
            case .boolean:
                EmptyView()
            }
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Journal")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(.white)
                Text(monthYearStr())
                    .font(.system(size: 15))
                    .foregroundStyle(Color(white: 0.5))
            }
            Spacer()
            Button { showConfigure = true } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Color(white: 0.55))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    private func monthYearStr() -> String {
        let f = DateFormatter(); f.dateFormat = "MMM yyyy"; return f.string(from: Date())
    }

    // MARK: Week strip

    private var weekStrip: some View {
        let days = lastSevenDays()
        return VStack(spacing: 8) {
            HStack(spacing: 0) {
                ForEach(days, id: \.self) { d in
                    weekDayCell(dayStr: d)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func weekDayCell(dayStr: String) -> some View {
        let isSelected = dayStr == selectedDay
        let isToday = dayStr == JournalView.todayStr()
        let complete = viewModel.journalEntries.first(where: { $0.day == dayStr })?.isComplete ?? false
        let raw = String(dayStr.suffix(2))
        let dayNum = raw.hasPrefix("0") ? String(raw.dropFirst()) : raw
        let weekday = shortWeekday(for: dayStr)
        return Button { selectedDay = dayStr } label: {
            VStack(spacing: 4) {
                Text(weekday)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color(white: 0.4))
                ZStack {
                    Circle()
                        .fill(isSelected ? Color(white: 0.20) : Color.clear)
                        .frame(width: 34, height: 34)
                    if isToday && !isSelected {
                        Circle()
                            .strokeBorder(Color(white: 0.3), lineWidth: 1)
                            .frame(width: 34, height: 34)
                    }
                    if complete {
                        ZStack {
                            Circle()
                                .fill(Color(red: 0.82, green: 0.67, blue: 0.20))
                                .frame(width: 34, height: 34)
                            Image(systemName: "checkmark")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(.black)
                        }
                    } else {
                        Text(dayNum)
                            .font(.system(size: 15, weight: isToday ? .bold : .regular))
                            .foregroundStyle(isSelected ? .white : Color(white: 0.65))
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func lastSevenDays() -> [String] {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        var days: [String] = []
        for i in stride(from: -6, through: 0, by: 1) {
            let d = Calendar.current.date(byAdding: .day, value: i, to: Date()) ?? Date()
            days.append(f.string(from: d))
        }
        return days
    }

    private func shortWeekday(for dayStr: String) -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        guard let d = f.date(from: dayStr) else { return "" }
        let w = DateFormatter(); w.dateFormat = "EEE"
        return w.string(from: d).uppercased()
    }

    // MARK: Item sections

    private var itemSections: some View {
        VStack(spacing: 20) {
            let isToday = selectedDay == JournalView.todayStr()
            Text(isToday ? "Today's Entries" : entriesLabel())
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)

            ForEach(JournalCategory.allCases, id: \.self) { cat in
                categorySection(cat)
            }
        }
    }

    private func entriesLabel() -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        let d = DateFormatter(); d.dateStyle = .medium; d.timeStyle = .none
        guard let date = f.date(from: selectedDay) else { return "Entries" }
        return d.string(from: date)
    }

    private func categorySection(_ cat: JournalCategory) -> some View {
        let predefined = JournalItemKey.allCases.filter {
            $0.category == cat && !viewModel.hiddenJournalItems.contains($0.rawValue)
        }
        let custom = viewModel.customJournalItems.filter { $0.category == cat }
        guard !predefined.isEmpty || !custom.isEmpty else { return AnyView(EmptyView()) }

        return AnyView(VStack(spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: cat.icon)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color(white: 0.4))
                Text(cat.rawValue.uppercased())
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color(white: 0.4))
                    .tracking(1.2)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 8)

            VStack(spacing: 1) {
                ForEach(predefined, id: \.self) { key in
                    JournalItemRow(key: key, entry: entry) { updated in
                        Task { await viewModel.upsertJournalEntry(updated) }
                    } onTapNumeric: {
                        editKey = key
                    }
                }
                ForEach(custom) { item in
                    CustomJournalItemRow(item: item, entry: entry) { updated in
                        Task { await viewModel.upsertJournalEntry(updated) }
                    } onTapNumeric: {
                        editCustomItem = item
                    }
                }
            }
            .background(Color(white: 0.10), in: RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, 16)
        })
    }

    // MARK: Workouts section

    private var workoutsSection: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "figure.run")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color(white: 0.4))
                Text("WORKOUTS")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color(white: 0.4))
                    .tracking(1.2)
                Spacer()
                Button { showLogWorkout = true } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(Color(red: 0.50, green: 0.30, blue: 0.90))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 8)

            if viewModel.workoutLogs.isEmpty {
                emptyState(icon: "figure.run", text: "No workouts logged yet")
            } else {
                VStack(spacing: 1) {
                    ForEach(viewModel.workoutLogs.prefix(5)) { entry in
                        workoutRow(entry)
                    }
                }
                .background(Color(white: 0.10), in: RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 16)
            }
        }
    }

    private func workoutRow(_ entry: WorkoutEntry) -> some View {
        HStack(spacing: 12) {
            Text(entry.feeling.emoji)
                .font(.system(size: 22))
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.activityType)
                    .font(.system(size: 15))
                    .foregroundStyle(.white)
                if !entry.notes.isEmpty {
                    Text(entry.notes)
                        .font(.system(size: 12))
                        .foregroundStyle(Color(white: 0.45))
                        .lineLimit(1)
                }
            }
            Spacer()
            Text(timeStr(entry.date))
                .font(.system(size: 12))
                .foregroundStyle(Color(white: 0.35))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: Pump events section (boolean per day)

    private var pumpEventsSection: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "cross.vial.fill")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color(white: 0.4))
                Text("PUMP EVENTS")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color(white: 0.4))
                    .tracking(1.2)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 8)

            VStack(spacing: 1) {
                ForEach(PumpEventType.allCases, id: \.self) { eventType in
                    pumpEventBoolRow(eventType)
                }
            }
            .background(Color(white: 0.10), in: RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, 16)
        }
    }

    private func pumpEventBoolRow(_ eventType: PumpEventType) -> some View {
        let key = "pump.\(eventType.rawValue)"
        let current = entry.booleans[key]
        return HStack(spacing: 12) {
            Image(systemName: eventType.icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(eventType.color)
                .frame(width: 32)
            Text(eventType.rawValue)
                .font(.system(size: 15))
                .foregroundStyle(.white)
            Spacer()
            HStack(spacing: 4) {
                pumpBoolBtn(symbol: "xmark", isActive: current == false, activeColor: .red) {
                    var e = entry; e.set(boolean: current == false ? nil : false, customID: key)
                    Task { await viewModel.upsertJournalEntry(e) }
                }
                pumpBoolBtn(symbol: "minus", isActive: current == nil, activeColor: Color(white: 0.4)) {
                    var e = entry; e.set(boolean: nil, customID: key)
                    Task { await viewModel.upsertJournalEntry(e) }
                }
                pumpBoolBtn(symbol: "checkmark", isActive: current == true, activeColor: .ouraActivity) {
                    var e = entry; e.set(boolean: current == true ? nil : true, customID: key)
                    Task { await viewModel.upsertJournalEntry(e) }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }

    private func pumpBoolBtn(symbol: String, isActive: Bool, activeColor: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(isActive ? activeColor : Color(white: 0.3))
                .frame(width: 30, height: 30)
                .background(isActive ? activeColor.opacity(0.15) : Color(white: 0.13), in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    // MARK: Helpers

    private func timeStr(_ date: Date) -> String {
        let f = DateFormatter()
        let cal = Calendar.current
        if cal.isDateInToday(date) {
            f.dateFormat = "HH:mm"
        } else if cal.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            f.dateStyle = .short; f.timeStyle = .none
        }
        return f.string(from: date)
    }

    private func emptyState(icon: String, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(Color(white: 0.25))
            Text(text)
                .font(.system(size: 14))
                .foregroundStyle(Color(white: 0.35))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(Color(white: 0.10), in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 16)
    }
}

// MARK: - Item row

struct JournalItemRow: View {
    let key: JournalItemKey
    let entry: JournalDayEntry
    let onUpdate: (JournalDayEntry) -> Void
    let onTapNumeric: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text(key.emoji)
                .font(.system(size: 22))
                .frame(width: 32)
            Text(key.displayName)
                .font(.system(size: 15))
                .foregroundStyle(.white)
            Spacer()
            trailingContent
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .contentShape(Rectangle())
    }

    @ViewBuilder private var trailingContent: some View {
        switch key.inputType {
        case .boolean:
            booleanButtons
        case .numeric(let unit):
            Button { onTapNumeric() } label: {
                HStack(spacing: 4) {
                    if let v = entry.numericValue(for: key) {
                        Text(v == v.rounded() ? "\(Int(v))" : String(format: "%.1f", v))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white)
                        Text(unit)
                            .font(.system(size: 12))
                            .foregroundStyle(Color(white: 0.45))
                    } else {
                        Text("- \(unit)")
                            .font(.system(size: 13))
                            .foregroundStyle(Color(white: 0.35))
                    }
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color(white: 0.3))
                }
            }
            .buttonStyle(.plain)
        case .scale:
            Button { onTapNumeric() } label: {
                HStack(spacing: 4) {
                    if let v = entry.scaleValue(for: key) {
                        Text(moodEmoji(v))
                            .font(.system(size: 18))
                    } else {
                        Text("-")
                            .font(.system(size: 14))
                            .foregroundStyle(Color(white: 0.35))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color(white: 0.3))
                    }
                }
            }
            .buttonStyle(.plain)
        }
    }

    private var booleanButtons: some View {
        let current = entry.booleans[key.rawValue]
        return HStack(spacing: 4) {
            boolBtn(symbol: "xmark", isActive: current == false, activeColor: .red) {
                var e = entry; e.set(boolean: current == false ? nil : false, for: key)
                onUpdate(e)
            }
            boolBtn(symbol: "minus", isActive: current == nil, activeColor: Color(white: 0.4)) {
                var e = entry; e.set(boolean: nil, for: key); onUpdate(e)
            }
            boolBtn(symbol: "checkmark", isActive: current == true, activeColor: .ouraActivity) {
                var e = entry; e.set(boolean: current == true ? nil : true, for: key)
                onUpdate(e)
            }
        }
    }

    private func boolBtn(symbol: String, isActive: Bool, activeColor: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(isActive ? activeColor : Color(white: 0.3))
                .frame(width: 30, height: 30)
                .background(isActive ? activeColor.opacity(0.15) : Color(white: 0.13), in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    private func moodEmoji(_ v: Int) -> String {
        ["😫","😕","😐","😊","😄"][max(0, min(4, v - 1))]
    }
}

// MARK: - Numeric entry sheet

struct NumericEntrySheet: View {
    let key: JournalItemKey
    let unit: String
    let current: Double?
    let onSave: (Double?) -> Void
    var titleOverride: String? = nil
    var emojiOverride: String? = nil
    @Environment(\.dismiss) private var dismiss
    @State private var text: String

    init(key: JournalItemKey, unit: String, current: Double?,
         titleOverride: String? = nil, emojiOverride: String? = nil,
         onSave: @escaping (Double?) -> Void) {
        self.key = key; self.unit = unit; self.current = current
        self.titleOverride = titleOverride; self.emojiOverride = emojiOverride
        self.onSave = onSave
        _text = State(initialValue: current.map { v in
            v == v.rounded() ? "\(Int(v))" : String(format: "%.1f", v)
        } ?? "")
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.surfaceBg.ignoresSafeArea()
                VStack(spacing: 32) {
                    Text(emojiOverride ?? key.emoji).font(.system(size: 52))
                    VStack(spacing: 8) {
                        Text(titleOverride ?? key.displayName)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.white)
                        HStack(alignment: .lastTextBaseline, spacing: 4) {
                            TextField("0", text: $text)
                                .keyboardType(.decimalPad)
                                .font(.system(size: 48, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: 200)
                            Text(unit)
                                .font(.system(size: 20))
                                .foregroundStyle(Color(white: 0.5))
                        }
                    }
                    HStack(spacing: 12) {
                        Button("Clear") {
                            onSave(nil); dismiss()
                        }
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color(white: 0.45))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color(white: 0.12), in: RoundedRectangle(cornerRadius: 14))

                        Button("Save") {
                            onSave(Double(text)); dismiss()
                        }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color(red: 0.50, green: 0.30, blue: 0.90), in: RoundedRectangle(cornerRadius: 14))
                    }
                    .padding(.horizontal, 24)
                }
                .padding(.top, 40)
            }
            .navigationTitle(key.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }.foregroundStyle(.white)
                }
            }
            .toolbarBackground(Color.surfaceBg, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Scale picker sheet

struct ScalePickerSheet: View {
    let key: JournalItemKey
    let current: Int?
    let onSave: (Int?) -> Void
    @Environment(\.dismiss) private var dismiss

    private let options: [(Int, String, String)] = [
        (1, "😫", "Terrible"),
        (2, "😕", "Bad"),
        (3, "😐", "Okay"),
        (4, "😊", "Good"),
        (5, "😄", "Great")
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.surfaceBg.ignoresSafeArea()
                VStack(spacing: 24) {
                    Text("How's your mood?")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                    HStack(spacing: 12) {
                        ForEach(options, id: \.0) { val, emoji, label in
                            Button {
                                onSave(current == val ? nil : val)
                                dismiss()
                            } label: {
                                VStack(spacing: 6) {
                                    Text(emoji).font(.system(size: 36))
                                    Text(label)
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(current == val ? .white : Color(white: 0.45))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(current == val ? Color(red: 0.50, green: 0.30, blue: 0.90).opacity(0.25) : Color(white: 0.10), in: RoundedRectangle(cornerRadius: 14))
                                .overlay(current == val ? RoundedRectangle(cornerRadius: 14).strokeBorder(Color(red: 0.72, green: 0.55, blue: 0.98), lineWidth: 1.5) : nil)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    Button("Clear") { onSave(nil); dismiss() }
                        .font(.system(size: 14))
                        .foregroundStyle(Color(white: 0.4))
                }
                .padding(.top, 32)
            }
            .navigationTitle("Daily Mood")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }.foregroundStyle(.white)
                }
            }
            .toolbarBackground(Color.surfaceBg, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Insight card

struct JournalInsight: Identifiable {
    var id: String { key }
    let key: String
    let emoji: String
    let name: String
    let withAvg: Double
    let withoutAvg: Double
    let metric: String

    var isBetterWithout: Bool { withoutAvg > withAvg }
    var diff: Double { abs(withAvg - withoutAvg) }
}

struct InsightCard: View {
    let insight: JournalInsight

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Text(insight.emoji).font(.system(size: 20))
                Text(insight.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
            }
            Text(insight.metric)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Color(white: 0.4))
                .tracking(1)

            HStack(spacing: 16) {
                statBit(label: "With", value: insight.withAvg, highlight: !insight.isBetterWithout)
                statBit(label: "Without", value: insight.withoutAvg, highlight: insight.isBetterWithout)
            }

            Text(insight.isBetterWithout ? "Better without" : "Better with")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(insight.isBetterWithout ? Color.red.opacity(0.9) : Color.ouraActivity)
        }
        .padding(14)
        .frame(width: 170)
        .background(Color(white: 0.10), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color(white: 0.15), lineWidth: 1))
    }

    private func statBit(label: String, value: Double, highlight: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(Color(white: 0.4))
            Text(String(format: "%.0f", value))
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(highlight ? .white : Color(white: 0.55))
        }
    }
}

// MARK: - Custom journal item row

struct CustomJournalItemRow: View {
    let item: CustomJournalItem
    let entry: JournalDayEntry
    let onUpdate: (JournalDayEntry) -> Void
    let onTapNumeric: () -> Void
    private var cid: String { item.id.uuidString }

    var body: some View {
        HStack(spacing: 12) {
            Text(item.emoji)
                .font(.system(size: 22))
                .frame(width: 32)
            Text(item.name)
                .font(.system(size: 15))
                .foregroundStyle(.white)
            Spacer()
            trailingContent
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .contentShape(Rectangle())
    }

    @ViewBuilder private var trailingContent: some View {
        switch item.type {
        case .boolean:
            booleanButtons
        case .numeric:
            Button { onTapNumeric() } label: {
                HStack(spacing: 4) {
                    if let v = entry.numbers[cid] {
                        Text(v == v.rounded() ? "\(Int(v))" : String(format: "%.1f", v))
                            .font(.system(size: 14, weight: .medium)).foregroundStyle(.white)
                        Text(item.unit)
                            .font(.system(size: 12)).foregroundStyle(Color(white: 0.45))
                    } else {
                        Text(item.unit.isEmpty ? "-" : "- \(item.unit)")
                            .font(.system(size: 13)).foregroundStyle(Color(white: 0.35))
                    }
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold)).foregroundStyle(Color(white: 0.3))
                }
            }.buttonStyle(.plain)
        case .scale:
            Button { onTapNumeric() } label: {
                if let v = entry.scales[cid] {
                    Text(["😫","😕","😐","😊","😄"][max(0,min(4,v-1))]).font(.system(size: 18))
                } else {
                    HStack(spacing: 4) {
                        Text("-").font(.system(size: 14)).foregroundStyle(Color(white: 0.35))
                        Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold)).foregroundStyle(Color(white: 0.3))
                    }
                }
            }.buttonStyle(.plain)
        }
    }

    private var booleanButtons: some View {
        let current = entry.booleans[cid]
        return HStack(spacing: 4) {
            boolBtn(symbol: "xmark",     isActive: current == false, activeColor: .red)       { var e = entry; e.set(boolean: current == false ? nil : false, customID: cid); onUpdate(e) }
            boolBtn(symbol: "minus",     isActive: current == nil,   activeColor: Color(white:0.4)) { var e = entry; e.set(boolean: nil, customID: cid); onUpdate(e) }
            boolBtn(symbol: "checkmark", isActive: current == true,  activeColor: .ouraActivity) { var e = entry; e.set(boolean: current == true ? nil : true, customID: cid); onUpdate(e) }
        }
    }

    private func boolBtn(symbol: String, isActive: Bool, activeColor: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(isActive ? activeColor : Color(white: 0.3))
                .frame(width: 30, height: 30)
                .background(isActive ? activeColor.opacity(0.15) : Color(white: 0.13), in: RoundedRectangle(cornerRadius: 8))
        }.buttonStyle(.plain)
    }
}

// MARK: - Configure journal sheet

struct ConfigureJournalSheet: View {
    @EnvironmentObject var viewModel: SyncViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showAddItem = false
    @State private var hidden: Set<String> = []

    var body: some View {
        NavigationStack {
            ZStack {
                Color.surfaceBg.ignoresSafeArea()
                List {
                    ForEach(JournalCategory.allCases, id: \.self) { cat in
                        Section(cat.rawValue) {
                            ForEach(JournalItemKey.allCases.filter { $0.category == cat }, id: \.self) { key in
                                Toggle(isOn: Binding(
                                    get: { !hidden.contains(key.rawValue) },
                                    set: { enabled in
                                        if enabled { hidden.remove(key.rawValue) }
                                        else       { hidden.insert(key.rawValue) }
                                    }
                                )) {
                                    HStack(spacing: 10) {
                                        Text(key.emoji)
                                        Text(key.displayName)
                                    }
                                }
                                .tint(Color(red: 0.50, green: 0.30, blue: 0.90))
                            }
                        }
                        .listRowBackground(Color.cardBg)
                    }

                    if !viewModel.customJournalItems.isEmpty {
                        Section("Custom Items") {
                            ForEach(viewModel.customJournalItems) { item in
                                HStack(spacing: 10) {
                                    Text(item.emoji)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.name).foregroundStyle(.white)
                                        Text(item.category.rawValue + " · " + item.type.rawValue)
                                            .font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                }
                            }
                            .onDelete { indexSet in
                                for i in indexSet {
                                    let id = viewModel.customJournalItems[i].id
                                    Task { await viewModel.deleteCustomJournalItem(id: id) }
                                }
                            }
                        }
                        .listRowBackground(Color.cardBg)
                    }

                    Section {
                        Button { showAddItem = true } label: {
                            Label("Add Custom Item", systemImage: "plus.circle.fill")
                                .foregroundStyle(Color(red: 0.72, green: 0.55, blue: 0.98))
                        }
                    }
                    .listRowBackground(Color.cardBg)
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Configure Journal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }.foregroundStyle(.white)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        Task { await viewModel.setHiddenJournalItems(hidden) }
                        dismiss()
                    }
                    .fontWeight(.semibold).foregroundStyle(.white)
                }
            }
            .toolbarBackground(Color.surfaceBg, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .sheet(isPresented: $showAddItem) { AddCustomItemSheet() }
        }
        .preferredColorScheme(.dark)
        .onAppear { hidden = viewModel.hiddenJournalItems }
    }
}

// MARK: - Add custom item sheet

struct AddCustomItemSheet: View {
    @EnvironmentObject var viewModel: SyncViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var emoji: String = "⭐️"
    @State private var type: CustomItemType = .boolean
    @State private var unit: String = ""
    @State private var category: JournalCategory = .wellness

    var body: some View {
        NavigationStack {
            ZStack {
                Color.surfaceBg.ignoresSafeArea()
                List {
                    Section("Item") {
                        HStack(spacing: 12) {
                            TextField("Emoji", text: $emoji)
                                .frame(width: 44)
                                .multilineTextAlignment(.center)
                                .font(.system(size: 24))
                            TextField("Name (e.g. Cold shower)", text: $name)
                                .foregroundStyle(.white)
                        }
                    }
                    .listRowBackground(Color.cardBg)

                    Section("Type") {
                        Picker("Type", selection: $type) {
                            ForEach(CustomItemType.allCases, id: \.self) { t in
                                Text(t.rawValue).tag(t)
                            }
                        }
                        .pickerStyle(.segmented)
                        if type == .numeric {
                            TextField("Unit (e.g. ml, steps)", text: $unit)
                                .foregroundStyle(.white)
                        }
                    }
                    .listRowBackground(Color.cardBg)

                    Section("Category") {
                        Picker("Category", selection: $category) {
                            ForEach(JournalCategory.allCases, id: \.self) { c in
                                Text(c.rawValue).tag(c)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    .listRowBackground(Color.cardBg)
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("New Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }.foregroundStyle(.white)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        guard !name.isEmpty else { return }
                        let item = CustomJournalItem(
                            name: name,
                            emoji: emoji.isEmpty ? "⭐️" : String(emoji.prefix(2)),
                            type: type,
                            unit: unit,
                            category: category
                        )
                        Task { await viewModel.upsertCustomJournalItem(item) }
                        dismiss()
                    }
                    .fontWeight(.semibold).foregroundStyle(.white)
                    .disabled(name.isEmpty)
                }
            }
            .toolbarBackground(Color.surfaceBg, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - JournalItemKey + Identifiable for sheet(item:)

extension JournalItemKey: Identifiable {
    var id: String { rawValue }
}
