//
//  DayCalendarView.swift
//  fitness-app
//
//  Created by Assistant on 1/30/26.
//

import SwiftUI
import PhotosUI

struct DayCalendarView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var authCoordinator: AuthCoordinator

    let repository: CalendarEntryRepository
    let workoutRepository = CalendarWorkoutRepository(dbQueue: DatabaseQueueProvider.shared.dbQueue)
    let taskRepository = CalendarTaskRepository(dbQueue: DatabaseQueueProvider.shared.dbQueue)
    let workoutRepo = WorkoutRepository(dbQueue: DatabaseQueueProvider.shared.dbQueue)
    let sessionRepository = SessionRepository(dbQueue: DatabaseQueueProvider.shared.dbQueue)

    @Binding var selectedDate: Date
    @State private var entry: CalendarEntryRecord?
    @State private var priorEntry: CalendarEntryRecord?
    @State private var showingCheckin = false
    @State private var workouts: [CalendarWorkoutRepository.ScheduledWorkoutRow] = []
    @State private var dailyTasks: [CalendarTaskRecord] = []
    @State private var scheduledTasks: [WorkoutRepository.TaskScheduleRow] = []

    @State private var showingRoutinePicker = false
    @State private var pendingWorkoutId: Int64?
    @State private var pendingFrequency: Int?
    @State private var showingFrequencyPicker = false
    @State private var showingWeekdayPicker = false

    private var isTodayOrPast: Bool {
        let today = Calendar.current.startOfDay(for: Date())
        return selectedDate <= today
    }

    private var isTodayOrFuture: Bool {
        let today = Calendar.current.startOfDay(for: Date())
        return selectedDate >= today
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack() {
                Button(action: { shiftDay(-1) }) { Image(systemName: "chevron.left") }
                Spacer()
                Text(selectedDate.formatted(date: .abbreviated, time: .omitted))
                    .font(.headline)
                    .foregroundColor(themeManager.currentTheme.textDefault)
                Spacer()
                Button(action: { shiftDay(1) }) { Image(systemName: "chevron.right") }
            }
            .padding(.bottom, 8)

            ZStack {
                // Center: Today button always centered
                Button("Go to Today") { selectedDate = Calendar.current.startOfDay(for: Date()) }
                    .foregroundColor(themeManager.currentTheme.primary)

                // Leading: Check-in button (today or past)
                HStack {
                    if isTodayOrPast {
                        Button(action: { showingCheckin = true }) {
                            HStack(spacing: 6) {
                                Image(systemName: entry != nil ? "checkmark.seal.fill" : "pencil.and.list.clipboard")
                            }
                            .padding(.horizontal, 12)
                            .foregroundColor(entry != nil ? themeManager.currentTheme.primary : themeManager.currentTheme.muted)
                            .clipShape(Capsule())
                        }
                    }
                    Spacer()
                }

                // Trailing: + Workout button (today or future)
                HStack {
                    Spacer()
                    if isTodayOrFuture {
                        Button(action: { showingRoutinePicker = true }) {
                            HStack(spacing: 6) {
                                Image(systemName: "plus")
                                Text("Workout")
                            }
                        }
                    }
                }
            }
            .padding(.bottom, 16)

            if !workouts.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Scheduled Workouts")
                        .bold()
                        .foregroundColor(themeManager.currentTheme.textDefault)
                        .padding(.bottom, 8)
                    ForEach(workouts, id: \.id) { w in
                        let c = colorForKey(w.workoutColor)
                        Button {
                            Task {
                                await ensureSessionForWorkoutRow(w)
                            }
                        } label: {
                            HStack(spacing: 10) {
                                Circle()
                                    .fill(c)
                                    .frame(width: 14, height: 14)
                                Text(w.workoutName)
                                    .font(.headline)
                                    .foregroundColor(c)
                                Spacer()
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(c.opacity(0.1))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.bottom, 16)
            }

            if !dailyTasks.isEmpty || !scheduledTasks.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Tasks")
                        .bold()
                        .foregroundColor(themeManager.currentTheme.textDefault)
                        .padding(.bottom, 8)

                    // Daily instances first (in creation order)
                    ForEach(Array(dailyTasks.enumerated()), id: \.element.id) { index, t in
                        VStack(spacing: 0) {
                            Button {
                                Task { await toggleTask(taskId: t.taskId) }
                            } label: {
                                HStack(spacing: 10) {
                                    Text(taskName(for: t.taskId))
                                        .foregroundColor(themeManager.currentTheme.textDefault)
                                    Spacer()
                                    Image(systemName: t.isComplete ? "checkmark.square.fill" : "square")
                                        .font(.system(size: 22, weight: .semibold))  // bigger checkbox
                                        .foregroundColor(t.isComplete ? themeManager.currentTheme.primary : themeManager.currentTheme.muted)
                                        .contentShape(Rectangle())
                                }
                            }
                            .buttonStyle(.plain)
                        }
                        .padding()
                        .background(themeManager.currentTheme.surface)
                        .cornerRadius(16)
                        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
                    }

                    // Scheduled tasks that do not yet have a daily instance
                    let pending = scheduledTasks.filter { hasDailyInstance(for: $0.id) == nil }
                    ForEach(Array(pending.enumerated()), id: \.element.id) { index, s in
                        VStack(spacing: 0) {
                            Button {
                                Task { await toggleTask(taskId: s.id) }
                            } label: {
                                HStack(spacing: 10) {
                                    Text(s.name)
                                        .foregroundColor(themeManager.currentTheme.textDefault)
                                    Spacer()
                                    Image(systemName: "square")
                                        .font(.system(size: 22, weight: .semibold))  // bigger checkbox
                                        .foregroundColor(themeManager.currentTheme.muted)
                                        .contentShape(Rectangle())
                                }
                            }
                            .padding()
                            .background(themeManager.currentTheme.surface)
                            .cornerRadius(16)
                            .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
                        }
                    }
                }
            }

            Spacer()
        }
        .padding()
        .task(id: selectedDate) {
            await loadData()
        }
        .sheet(isPresented: $showingCheckin) {
            DailyCheckinSheet(
                date: selectedDate,
                existing: entry,
                prior: priorEntry,
                repository: repository
            ) { saved in
                showingCheckin = false
                Task { await loadData() }
            }
            .environmentObject(themeManager)
            .environmentObject(authCoordinator)
        }
        .sheet(isPresented: $showingRoutinePicker) {
            RoutinePickerSheet { pickedId in
                if pickedId <= 0 { showingRoutinePicker = false; return }
                pendingWorkoutId = pickedId
                showingRoutinePicker = false
                // Next: frequency
                showingFrequencyPicker = true
            }
            .environmentObject(themeManager)
            .environmentObject(authCoordinator)
        }
        .sheet(isPresented: $showingFrequencyPicker) {
            FrequencyPickerSheet { freq in
                if let f = freq, f == -1 { showingFrequencyPicker = false; return }
                pendingFrequency = (freq == -1 ? nil : freq) // normalize cancel
                showingFrequencyPicker = false
                if pendingFrequency == nil {
                    Task { await createOneTimeCalendarWorkout() }
                } else {
                    showingWeekdayPicker = true
                }
            }
            .environmentObject(themeManager)
        }
        .sheet(isPresented: $showingWeekdayPicker) {
            let weekday = Calendar.current.component(.weekday, from: selectedDate)
            WeekdayPickerSheet(initialSelectedWeekday: weekday) { days in
                showingWeekdayPicker = false
                Task { await createRepeatingCalendarWorkout(days: days) }
            }
            .environmentObject(themeManager)
        }
    }

    private var checkinBackground: some View {
        let hasEntry = (entry != nil)
        return (hasEntry ? themeManager.currentTheme.important : themeManager.currentTheme.muted)
    }

    private func colorForKey(_ key: String?) -> Color {
        switch key ?? "primary" {
        case "primary": return themeManager.currentTheme.primary
        case "secondary": return themeManager.currentTheme.secondary
        case "success": return AppColors.success
        case "warning": return AppColors.warning
        case "error": return themeManager.currentTheme.error
        case "important": return themeManager.currentTheme.important
        default: return themeManager.currentTheme.primary
        }
    }

    private func shiftDay(_ delta: Int) {
        if let d = Calendar.current.date(byAdding: .day, value: delta, to: selectedDate) {
            selectedDate = Calendar.current.startOfDay(for: d)
        }
    }

    private func loadData() async {
        guard let userId = authCoordinator.currentUser?.id else { return }
        do {
            let id64 = Int64(userId)
            entry = try repository.entry(for: id64, on: selectedDate)
            priorEntry = try repository.mostRecentPriorEntry(before: selectedDate, userId: id64)
            workouts = try workoutRepository.workoutsWithDetails(on: selectedDate, userId: id64)
            dailyTasks = try taskRepository.tasks(on: selectedDate, userId: id64)
            scheduledTasks = try workoutRepo.activeTasks(on: selectedDate, userId: id64)
        } catch {
            print("[DayCalendarView] loadData error: \(error)")
        }
    }

    private func createOneTimeCalendarWorkout() async {
        guard let userId = authCoordinator.currentUser?.id, let wid = pendingWorkoutId else { return }
        let id64 = Int64(userId)
        let day = Calendar.current.startOfDay(for: selectedDate)
        let now = Date()
        let domain = CalendarWorkout(
            id: nil,
            userId: id64,
            workoutId: wid,
            startsOn: day,
            endsOn: day,
            frequency: nil,
            mon: false, tues: false, wed: false, thurs: false, fri: false, sat: false, sun: false,
            createdAt: now,
            updatedAt: now,
            deletedAt: nil
        )
        do {
            try workoutRepository.create(domain)
            await loadData()
        } catch {
            print("[DayCalendarView] createOneTimeCalendarWorkout error: \(error)")
        }
        pendingWorkoutId = nil
        pendingFrequency = nil
    }

    private func createRepeatingCalendarWorkout(days: (mon: Bool, tues: Bool, wed: Bool, thurs: Bool, fri: Bool, sat: Bool, sun: Bool)) async {
        guard let userId = authCoordinator.currentUser?.id, let wid = pendingWorkoutId, let freq = pendingFrequency else { return }
        let id64 = Int64(userId)
        let day = Calendar.current.startOfDay(for: selectedDate)
        let now = Date()
        let domain = CalendarWorkout(
            id: nil,
            userId: id64,
            workoutId: wid,
            startsOn: day,
            endsOn: nil,
            frequency: freq,
            mon: days.mon, tues: days.tues, wed: days.wed, thurs: days.thurs, fri: days.fri, sat: days.sat, sun: days.sun,
            createdAt: now,
            updatedAt: now,
            deletedAt: nil
        )
        do {
            try workoutRepository.create(domain)
            await loadData()
        } catch {
            print("[DayCalendarView] createRepeatingCalendarWorkout error: \(error)")
        }
        pendingWorkoutId = nil
        pendingFrequency = nil
    }

    private func hasDailyInstance(for taskId: Int64) -> CalendarTaskRecord? {
        return dailyTasks.first { $0.taskId == taskId }
    }

    private func toggleTask(taskId: Int64) async {
        guard let userId = authCoordinator.currentUser?.id else { return }
        do {
            _ = try taskRepository.toggleComplete(userId: Int64(userId), taskId: taskId, date: selectedDate)
            await loadData()
        } catch {
            print("[DayCalendarView] toggleTask error: \(error)")
        }
    }

    private func taskName(for taskId: Int64) -> String {
        if let s = scheduledTasks.first(where: { $0.id == taskId }) { return s.name }
        return "Task #\(taskId)"
    }

    private func ensureSessionForWorkoutRow(_ w: CalendarWorkoutRepository.ScheduledWorkoutRow) async {
        guard let userId = authCoordinator.currentUser?.id else { return }
        let id64 = Int64(userId)
        let day = Calendar.current.startOfDay(for: selectedDate)
        do {
            let sessionRepo = SessionRepository(dbQueue: DatabaseQueueProvider.shared.dbQueue)
            let workoutRepo = WorkoutRepository(dbQueue: DatabaseQueueProvider.shared.dbQueue)
            _ = try sessionRepo.ensureSessionWithSeed(
                userId: id64,
                workoutId: w.workoutId,
                calendarWorkoutId: w.id,
                workoutName: w.workoutName,
                startedAt: day,
                workoutRepo: workoutRepo
            )
        } catch {
            print("[DayCalendarView] ensureSessionWithSeed error: \(error)")
        }
    }
}

// MARK: - Daily Check-in Sheet
struct DailyCheckinSheet: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var authCoordinator: AuthCoordinator

    let date: Date
    let existing: CalendarEntryRecord?
    let prior: CalendarEntryRecord?
    let repository: CalendarEntryRepository
    var onSaved: (Bool) -> Void

    @State private var weightText: String = ""
    @State private var bodyFatText: String = ""
    @State private var pickedPhoto: PhotosPickerItem?
    @State private var localPhotoPath: String?

    private var weightUnit: String {
        authCoordinator.currentUser?.isImperial == true ? "lbs" : "kg"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Metrics") {
                    InputWithSuffixDecimal(
                        title: "Body Weight",
                        digits: $weightText,
                        suffix: weightUnit,
                        maxValue: 999.9,
                        theme: themeManager
                    )
                    InputWithSuffixDecimal(
                        title: "Body Fat %",
                        digits: $bodyFatText,
                        suffix: "%",
                        maxValue: 99.9,
                        theme: themeManager
                    )
                }
                Section("Progress Photo") {
                    PhotosPicker(selection: $pickedPhoto, matching: .images) {
                        HStack {
                            Image(systemName: "photo")
                            Text(localPhotoPath == nil ? "Select Photo" : "Replace Photo")
                        }
                    }
                }
            }
            .onAppear(perform: prefill)
            .onChange(of: existing?.id) { _, _ in
                prefill()
            }
            .onChange(of: prior?.id) { _, _ in
                // Only prefill remaining empty fields so we don't overwrite user edits.
                prefill()
            }
            .navigationTitle("Daily Check‑in")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onSaved(false) }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await save() } }
                        .disabled(!canSave)
                }
            }
        }
    }

    private var canSave: Bool {
        // At least one field should be present
        return !(weightText.isEmpty && bodyFatText.isEmpty && localPhotoPath == nil)
    }

    private func prefill() {
        // Existing entry
        if let e = existing {
            if weightText.isEmpty, let w = e.weight { weightText = String(Int((w * 10.0).rounded())) }
            if bodyFatText.isEmpty, let bf = e.bodyFat { bodyFatText = String(Int((bf * 10.0).rounded())) }
            if localPhotoPath == nil { localPhotoPath = e.progressPhoto }
            return
        }
        // Prefill from prior if empty
        if let p = prior {
            if weightText.isEmpty, let w = p.weight { weightText = String(Int((w * 10.0).rounded())) }
            if bodyFatText.isEmpty, let bf = p.bodyFat { bodyFatText = String(Int((bf * 10.0).rounded())) }
        }
    }

    private func savePickedPhoto(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        do {
            if let data = try await item.loadTransferable(type: Data.self) {
                localPhotoPath = try saveProgressPhotoData(data)
            }
        } catch {
            print("[DailyCheckinSheet] photo pick error: \(error)")
        }
    }

    private func saveProgressPhotoData(_ data: Data) throws -> String {
        let fm = FileManager.default
        let docs = try fm.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let folder = docs.appendingPathComponent("progress_photos", isDirectory: true)
        try fm.createDirectory(at: folder, withIntermediateDirectories: true)
        let filename = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-").replacingOccurrences(of: ".", with: "-") + ".jpg"
        let url = folder.appendingPathComponent(filename)
        try data.write(to: url, options: .atomic)
        return "progress_photos/\(filename)"
    }

    private func save() async {
        guard let user = authCoordinator.currentUser else { return }
        let id64 = Int64(user.id)

        // Parse numeric fields
        let weight = Double(weightText).map { $0 / 10.0 }
        let bodyFat = Double(bodyFatText).map { $0 / 10.0 }

        // Build domain and persist
        let domain = CalendarEntry(
            id: existing?.id,
            userId: id64,
            date: CalendarEntry.date(from: CalendarEntry.dbString(from: date)) ?? date,
            weight: weight,
            bodyFat: bodyFat,
            progressPhoto: localPhotoPath,
            createdAt: existing?.createdAt ?? Date(),
            updatedAt: Date(),
            deletedAt: existing?.deletedAt
        )

        do {
            try repository.upsert(domain)
            onSaved(true)
        } catch {
            print("[DailyCheckinSheet] save error: \(error)")
        }
    }
}

private struct LiveDecimalTextField: UIViewRepresentable {
    @Binding var displayText: String
    @Binding var digits: String
    let maxValue: Double

    func makeUIView(context: Context) -> UITextField {
        let tf = UITextField(frame: .zero)
        tf.keyboardType = .decimalPad
        tf.delegate = context.coordinator
        tf.text = displayText
        tf.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return tf
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        if uiView.text != displayText { uiView.text = displayText }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UITextFieldDelegate {
        let parent: LiveDecimalTextField
        init(_ parent: LiveDecimalTextField) { self.parent = parent }

        func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
            let current = textField.text ?? ""
            guard let r = Range(range, in: current) else { return true }
            let proposed = current.replacingCharacters(in: r, with: string)

            // Build digits-only from proposed
            let rawDigits = proposed.filter { $0.isNumber }
            if rawDigits.isEmpty {
                parent.displayText = ""
                parent.digits = ""
                return true
            }

            // Clamp implicit one-decimal value
            var clamped = String(rawDigits)
            while !clamped.isEmpty {
                let v = (Double(clamped) ?? 0) / 10.0
                if v <= parent.maxValue { break }
                clamped.removeLast()
            }

            parent.digits = clamped
            let value = (Double(clamped) ?? 0) / 10.0
            parent.displayText = String(format: "%.1f", value)

            // Update the text field text immediately
            textField.text = parent.displayText
            // Place cursor at end
            let end = textField.endOfDocument
            textField.selectedTextRange = textField.textRange(from: end, to: end)
            return false
        }
    }
}

private struct InputWithSuffixDecimal: View {
    let title: String
    @Binding var digits: String // raw digits only, implicit 1 decimal place
    let suffix: String
    let maxValue: Double
    @ObservedObject var theme: ThemeManager
    @State private var displayText: String = ""

    var body: some View {
        HStack(spacing: 8) {
            LiveDecimalTextField(displayText: $displayText, digits: $digits, maxValue: maxValue)
                .foregroundColor(theme.currentTheme.textDefault)
                .onAppear {
                    if digits.isEmpty {
                        displayText = ""
                    } else {
                        displayText = formatted(from: digits)
                    }
                }

            Text(suffix)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(theme.currentTheme.muted)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(theme.currentTheme.surface)
                .clipShape(Capsule())
        }
    }

    private func formatted(from digits: String) -> String {
        guard !digits.isEmpty else { return "" }
        let value = (Double(digits) ?? 0) / 10.0
        return String(format: "%.1f", value)
    }
}

