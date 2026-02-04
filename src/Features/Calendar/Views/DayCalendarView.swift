//
//  DayCalendarView.swift
//  fitness-app
//
//  Created by Assistant on 1/30/26.
//

import SwiftUI
import PhotosUI

struct DayCalendarView: View {
    @ObservedObject var coordinator: AppShellCoordinator
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
    @State private var activeSession: SessionRecord? = nil
    @State private var navigateToSession = false

    @State private var navigateToSessionSummary = false
    @State private var summarySession: SessionRecord? = nil

    @State private var showingWorkoutPopover = false
    @State private var selectedWorkoutRow: CalendarWorkoutRepository.ScheduledWorkoutRow? = nil
    @State private var selectedWorkoutExercises: [String] = []
    @State private var exerciseLoadTask: Task<Void, Never>? = nil

    @State private var exerciseLoadError: String? = nil
    @State private var lastLoadedWorkoutId: Int64? = nil
    
    @State private var exerciseCache: [Int64: [String]] = [:]

    private var isTodayOrPast: Bool {
        let today = Calendar.current.startOfDay(for: Date())
        return selectedDate <= today
    }

    private var isTodayOrFuture: Bool {
        let today = Calendar.current.startOfDay(for: Date())
        return selectedDate >= today
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                // MARK: - Header with date navigation
                HStack {
                    Button(action: { shiftDay(-1) }) { Image(systemName: "chevron.left") }
                    Spacer()
                    Text(selectedDate.formatted(date: .abbreviated, time: .omitted))
                        .font(.headline)
                        .foregroundColor(themeManager.currentTheme.textDefault)
                    Spacer()
                    Button(action: { shiftDay(1) }) { Image(systemName: "chevron.right") }
                }
                .padding(.bottom, 8)

                // MARK: - Today button / Check-in / Add Workout
                ZStack {
                    // Center: Go to Today
                    switch relativeDay {
                    case .yesterday:
                        Text("Yesterday")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(themeManager.currentTheme.muted)

                    case .today:
                        Text("Today")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(themeManager.currentTheme.muted)

                    case .tomorrow:
                        Text("Tomorrow")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(themeManager.currentTheme.muted)

                    case .other:
                        Button("Go to Today") {
                            selectedDate = Calendar.current.startOfDay(for: Date())
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(themeManager.currentTheme.muted)
                    }

                    // Leading: Check-in button (today or past)
                    HStack {
                        if isTodayOrPast {
                            Button(action: {
                                // Cancel any in-flight exercise load
                                self.exerciseLoadTask?.cancel()
                                self.exerciseLoadTask = nil
                                self.exerciseLoadError = nil
                                self.selectedWorkoutRow = nil
                                showingCheckin = true
                            }) {
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

                    // Trailing: + Workout button (always shown)
                    HStack {
                        Spacer()
                        Button(action: { showingRoutinePicker = true }) {
                            HStack(spacing: 6) {
                                Image(systemName: "plus")
                                Text("Workout")
                            }
                        }
                    }
                }
                .padding(.bottom, 16)

                // MARK: - Scheduled Workouts
                if !workouts.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Scheduled Workouts")
                            .bold()
                            .foregroundColor(themeManager.currentTheme.textDefault)
                            .padding(.bottom, 8)

                        ForEach(workouts, id: \.id) { w in
                            let c = colorForKey(w.workoutColor)
                            Button {
                                self.exerciseLoadTask?.cancel()
                                self.exerciseLoadTask = nil
                                self.exerciseLoadError = nil
                                self.selectedWorkoutRow = nil
                                self.selectedWorkoutExercises = []

                                let workoutId = w.workoutId

                                // If we have cached exercises, present immediately; otherwise fetch before showing popover
                                if let cached = exerciseCache[workoutId], !cached.isEmpty {
                                    Task { @MainActor in
                                        self.selectedWorkoutRow = w
                                        self.selectedWorkoutExercises = cached
                                        self.showingWorkoutPopover = true
                                    }
                                    // Optionally refresh cache in background without affecting UI
                                    self.exerciseLoadTask = Task {
                                        await loadExercisesForWorkout(workoutId: workoutId)
                                        await MainActor.run { self.exerciseLoadTask = nil }
                                    }
                                } else {
                                    // No cache yet: fetch first, then present
                                    self.exerciseLoadTask = Task {
                                        await loadExercisesForWorkout(workoutId: workoutId)
                                        await MainActor.run {
                                            self.selectedWorkoutRow = w
                                            self.selectedWorkoutExercises = self.exerciseCache[workoutId] ?? []
                                            self.showingWorkoutPopover = true
                                            self.exerciseLoadTask = nil
                                        }
                                    }
                                }
                            } label: {
                                HStack(spacing: 10) {
                                    Circle()
                                        .fill(c)
                                        .frame(width: 14, height: 14)
                                    Text(w.workoutName)
                                        .font(.headline)
                                        .foregroundColor(c)
                                    if isWorkoutRowCompleted(w) {
                                        Spacer()
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(c)
                                    }
                                }
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(RoundedRectangle(cornerRadius: 6).fill(c.opacity(0.1)))
                            }
                            .buttonStyle(.plain)
                            // Removed .allowsHitTesting(isTodayOrPast) to make future workouts tappable
                        }
                    }
                    .padding(.bottom, 16)
                }

                // MARK: - Tasks Section
                if !dailyTasks.isEmpty || !scheduledTasks.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Tasks")
                            .bold()
                            .foregroundColor(themeManager.currentTheme.textDefault)
                            .padding(.bottom, 8)

                        // Daily instances first
                        ForEach(Array(dailyTasks.enumerated()), id: \.element.id) { _, t in
                            Button {
                                Task { await toggleTask(taskId: t.taskId) }
                            } label: {
                                HStack(spacing: 10) {
                                    Text(taskName(for: t.taskId))
                                        .foregroundColor(themeManager.currentTheme.textDefault)
                                    Spacer()
                                    Image(systemName: t.isComplete ? "checkmark.square.fill" : "square")
                                        .font(.system(size: 22, weight: .semibold))
                                        .foregroundColor(t.isComplete ? themeManager.currentTheme.primary : themeManager.currentTheme.muted)
                                        .contentShape(Rectangle())
                                }
                            }
                            .padding()
                            .background(themeManager.currentTheme.surface)
                            .cornerRadius(16)
                            .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
                        }

                        // Scheduled tasks without daily instances
                        let pending = scheduledTasks.filter { hasDailyInstance(for: $0.id) == nil }
                        ForEach(Array(pending.enumerated()), id: \.element.id) { _, s in
                            Button {
                                Task { await toggleTask(taskId: s.id) }
                            } label: {
                                HStack(spacing: 10) {
                                    Text(s.name)
                                        .foregroundColor(themeManager.currentTheme.textDefault)
                                    Spacer()
                                    Image(systemName: "square")
                                        .font(.system(size: 22, weight: .semibold))
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

                Spacer()

                // MARK: - Hidden NavigationLink to SessionView
                NavigationLink(
                    destination: sessionDestinationView,
                    isActive: $navigateToSession,
                    label: { EmptyView() }
                )
                .hidden()

                NavigationLink(
                    destination: summaryDestinationView,
                    isActive: $navigateToSessionSummary,
                    label: { EmptyView() }
                )
                .hidden()
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
                RoutinePickerSheet(coordinator: coordinator) { pickedId in
                    if pickedId <= 0 { showingRoutinePicker = false; return }
                    pendingWorkoutId = pickedId
                    showingRoutinePicker = false
                    showingFrequencyPicker = true
                }
                .environmentObject(themeManager)
                .environmentObject(authCoordinator)
            }
            .sheet(isPresented: $showingFrequencyPicker) {
                FrequencyPickerSheet { freq in
                    if let f = freq, f == -1 { showingFrequencyPicker = false; return }
                    pendingFrequency = (freq == -1 ? nil : freq)
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
            .popover(isPresented: Binding(get: { showingWorkoutPopover && selectedWorkoutRow != nil }, set: { showingWorkoutPopover = $0 }), arrowEdge: .top) {
                if let row = selectedWorkoutRow {
                    WorkoutQuickActionsPopover(
                        themeManager: themeManager,
                        workoutRow: row,
                        exercises: selectedWorkoutExercises,
                        canEnterSession: isTodayOrPast,
                        error: exerciseLoadError,
                        onEnterSession: {
                            self.exerciseLoadTask?.cancel()
                            self.exerciseLoadTask = nil
                            showingWorkoutPopover = false
                            Task { await ensureSessionForWorkoutRow(row) }
                        },
                        onDelete: {
                            Task { await deleteCalendarWorkout(row) }
                        }
                    )
                    .environmentObject(authCoordinator)
                }
            }
        }
    }

    @ViewBuilder
    private var sessionDestinationView: some View {
        if let session = activeSession {
            SessionView(coordinator: coordinator, session: session, sessionRepo: sessionRepository, onCompleted: { completed in
                // Pop back to DayCalendarView
                self.navigateToSession = false
                // Present summary
                self.summarySession = completed
                self.navigateToSessionSummary = true
            })
                .environmentObject(themeManager)
                .environmentObject(authCoordinator)
        } else {
            EmptyView()
        }
    }

    @ViewBuilder
    private var summaryDestinationView: some View {
        if let s = summarySession {
            SessionSummaryView(coordinator: coordinator, session: s)
                .environmentObject(themeManager)
                .environmentObject(authCoordinator)
        } else {
            EmptyView()
        }
    }

    private func sessionIsCompleted(_ session: SessionRecord) -> Bool {
        let mirror = Mirror(reflecting: session)
        for child in mirror.children {
            guard let label = child.label else { continue }
            if label == "isComplete", let flag = child.value as? Bool { return flag }
            if (label == "endedAt" || label == "completedAt") {
                let childMirror = Mirror(reflecting: child.value)
                if childMirror.displayStyle == .optional {
                    if childMirror.children.first != nil { return true }
                } else if child.value is Date { return true }
            }
        }
        return false
    }

    private func isWorkoutRowCompleted(_ w: CalendarWorkoutRepository.ScheduledWorkoutRow) -> Bool {
        guard let userId = authCoordinator.currentUser?.id else { return false }
        let day = Calendar.current.startOfDay(for: selectedDate)
        do {
            let sessionRepo = SessionRepository(dbQueue: DatabaseQueueProvider.shared.dbQueue)
            if let existing = try sessionRepo.find(calendarWorkoutId: w.id, startedAt: day) {
                return sessionIsCompleted(existing)
            }
        } catch {
            // Ignore lookup errors for indicator
        }
        return false
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
            let fetchedEntry = try repository.entry(for: id64, on: selectedDate)
            let fetchedPrior = try repository.mostRecentPriorEntry(before: selectedDate, userId: id64)
            let rows = try workoutRepository.workoutsWithDetails(on: selectedDate, userId: id64)
            let filteredWorkouts = rows.filter { CalendarWorkoutRepository.matches($0, on: selectedDate) }
            let fetchedDailyTasks = try taskRepository.tasks(on: selectedDate, userId: id64)
            let fetchedScheduledTasks = try workoutRepo.activeTasks(on: selectedDate, userId: id64)

            await MainActor.run {
                self.entry = fetchedEntry
                self.priorEntry = fetchedPrior
                self.workouts = filteredWorkouts
                self.dailyTasks = fetchedDailyTasks
                self.scheduledTasks = fetchedScheduledTasks
            }
        } catch {
            print("[DayCalendarView] loadData error: \(error)")
        }
    }

    private func createOneTimeCalendarWorkout() async {
        guard let userId = authCoordinator.currentUser?.id, let wid = pendingWorkoutId else { return }
        let id64 = Int64(userId)
        let selectedStart = Calendar.current.startOfDay(for: selectedDate)
        // Normalize to the exact DB day boundary to avoid timezone mismatches
        let dbDayString = CalendarWorkout.dbString(from: selectedStart)
        let day = CalendarWorkout.date(from: dbDayString) ?? selectedStart
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
        let selectedStart = Calendar.current.startOfDay(for: selectedDate)
        // Normalize to the exact DB day boundary to avoid timezone mismatches
        let dbDayString = CalendarWorkout.dbString(from: selectedStart)
        let day = CalendarWorkout.date(from: dbDayString) ?? selectedStart
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
            let session = try sessionRepo.ensureSessionWithSeed(
                userId: id64,
                workoutId: w.workoutId,
                calendarWorkoutId: w.id,
                workoutName: w.workoutName,
                startedAt: day,
                workoutRepo: workoutRepo
            )

            // If the session already exists and is complete, present the summary instead of navigating into the live session.
            // Prefer a direct property check. We first look for `endedAt` (Date?), then fall back to an `isComplete` Bool if available.
            let isCompleted = sessionIsCompleted(session)

            await MainActor.run {
                if isCompleted {
                    self.summarySession = session
                    self.navigateToSessionSummary = true
                    self.activeSession = nil
                    self.navigateToSession = false
                } else {
                    // Navigate to the active/live SessionView
                    self.activeSession = session
                    self.navigateToSession = true
                }
            }
        } catch {
            print("[DayCalendarView] ensureSessionWithSeed error: \(error)")
        }
    }
    
    private func loadExercisesForWorkout(workoutId: Int64) async {
        await MainActor.run {
            // Do not toggle a loading state; keep any existing exercises shown
            self.exerciseLoadError = nil
        }
        print("[DayCalendarView] loadExercisesForWorkout start id=\(workoutId)")
        do {
            try Task.checkCancellation()
            let grouped = try workoutRepo.fetchExercisesByBlock(forWorkoutId: workoutId)
            try Task.checkCancellation()
            let orderedBlockIds = grouped.keys.sorted()
            var names: [String] = []
            for bid in orderedBlockIds {
                let rows = grouped[bid] ?? []
                for r in rows { names.append(r.name) }
            }
            try Task.checkCancellation()
            print("[DayCalendarView] loadExercisesForWorkout fetched names=\(names.count)")
            await MainActor.run {
                self.exerciseCache[workoutId] = names
                self.selectedWorkoutExercises = names
                self.lastLoadedWorkoutId = workoutId
            }
        } catch is CancellationError {
            print("[DayCalendarView] loadExercisesForWorkout cancelled")
        } catch {
            print("[DayCalendarView] loadExercisesForWorkout error: \(error)")
            await MainActor.run { self.exerciseLoadError = error.localizedDescription }
        }
        print("[DayCalendarView] loadExercisesForWorkout end id=\(workoutId) loading=false")
    }
    
    private func deleteCalendarWorkout(_ row: CalendarWorkoutRepository.ScheduledWorkoutRow) async {
        do {
            // Cancel any in-flight exercise load
            await MainActor.run {
                self.exerciseLoadTask?.cancel()
                self.exerciseLoadTask = nil
                self.showingWorkoutPopover = false
                self.selectedWorkoutRow = nil
            }
            await loadData()
        } catch {
            print("[DayCalendarView] deleteCalendarWorkout error: \(error)")
        }
    }

    private enum RelativeDay {
        case yesterday, today, tomorrow, other
    }

    private var relativeDay: RelativeDay {
        let calendar = Calendar.current
        let selected = calendar.startOfDay(for: selectedDate)
        let today = calendar.startOfDay(for: Date())

        if selected == calendar.date(byAdding: .day, value: -1, to: today) {
            return .yesterday
        } else if selected == today {
            return .today
        } else if selected == calendar.date(byAdding: .day, value: 1, to: today) {
            return .tomorrow
        } else {
            return .other
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

    private enum Field: Hashable { case weight, bodyFat }
    @FocusState private var focusedField: Field?

    private var weightUnit: String {
        authCoordinator.currentUser?.isImperial == true ? "lbs" : "kg"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                themeManager.currentTheme.background
                    .ignoresSafeArea()
                Form {
                    metricsSection
                    Section("Progress Photo") {
                        PhotosPicker(selection: $pickedPhoto, matching: .images) {
                            HStack {
                                Image(systemName: "photo")
                                Text(localPhotoPath == nil ? "Select Photo" : "Replace Photo")
                                    .foregroundColor(themeManager.currentTheme.textDefault)
                            }
                        }
                    }
                    .scrollContentBackground(.hidden)
                    .listRowBackground(themeManager.currentTheme.surface)
                    .foregroundColor(themeManager.currentTheme.muted)
                }
                .scrollContentBackground(.hidden)
                .onAppear(perform: prefill)
                .onChange(of: existing?.id) { _, _ in
                    prefill()
                }
                .onChange(of: prior?.id) { _, _ in
                    // Only prefill remaining empty fields so we don't overwrite user edits.
                    prefill()
                }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { onSaved(false) }
                    }
                    ToolbarItem(placement: .principal) {
                        Text("Daily Check-in")
                            .foregroundColor(themeManager.currentTheme.textDefault)
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") { Task { await save() } }
                            .disabled(!canSave)
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("CustomNumericKeyboardNext"))) { _ in
                switch focusedField {
                case .weight:
                    focusedField = .bodyFat
                default:
                    focusedField = nil
                }
            }
        }
    }

    @ViewBuilder
    private var metricsSection: some View {
        Section("Metrics") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Body Weight")
                InputWithSuffixDecimal(
                    title: "Body Weight",
                    digits: $weightText,
                    suffix: weightUnit,
                    maxValue: 999.9,
                    decimal: true
                )
                .focused($focusedField, equals: .weight)

                Text("Body Fat %")
                InputWithSuffixDecimal(
                    title: "Body Fat %",
                    digits: $bodyFatText,
                    suffix: "%",
                    maxValue: 99.9,
                    decimal: true
                )
                .focused($focusedField, equals: .bodyFat)
            }
            .foregroundColor(themeManager.currentTheme.textDefault)
            .listRowBackground(themeManager.currentTheme.surface)
        }
        .foregroundColor(themeManager.currentTheme.muted)
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

struct WorkoutQuickActionsPopover: View {
    @EnvironmentObject var authCoordinator: AuthCoordinator
    var themeManager: ThemeManager
    let workoutRow: CalendarWorkoutRepository.ScheduledWorkoutRow?
    let exercises: [String]
    let canEnterSession: Bool
    let error: String?
    let onEnterSession: () -> Void
    let onDelete: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let row = workoutRow {
                Text(row.workoutName)
                    .font(.headline)
                    .foregroundColor(themeManager.currentTheme.textDefault)
                if let err = error {
                    Text(err)
                        .foregroundColor(themeManager.currentTheme.error)
                        .font(.footnote)
                } else if exercises.isEmpty {
                    Text("No exercises found")
                        .foregroundColor(themeManager.currentTheme.muted)
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(exercises.prefix(12), id: \.self) { name in
                            HStack {
                                Circle().fill(themeManager.currentTheme.primary.opacity(0.2)).frame(width: 6, height: 6)
                                Text(name)
                                    .foregroundColor(themeManager.currentTheme.textDefault)
                                    .font(.subheadline)
                            }
                        }
                        if exercises.count > 12 {
                            Text("+ \(exercises.count - 12) more")
                                .font(.footnote)
                                .foregroundColor(themeManager.currentTheme.muted)
                        }
                    }
                }
                if !canEnterSession {
                    Text("This session will be available on the scheduled day.")
                        .font(.footnote)
                        .foregroundColor(themeManager.currentTheme.muted)
                }
                HStack {
                    Button(role: .none) { onEnterSession() } label: {
                        HStack { Image(systemName: "play.circle"); Text("Enter Session") }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(themeManager.currentTheme.primary)
                    .disabled(!canEnterSession)
                    .opacity(canEnterSession ? 1.0 : 0.5)
                    Spacer()
                    Button(role: .destructive) { onDelete() } label: {
                        HStack { Image(systemName: "trash"); Text("Delete") }
                    }
                }
            } else {
                Text("No workout selected")
                    .foregroundColor(themeManager.currentTheme.muted)
            }
        }
        .padding()
        .background(themeManager.currentTheme.surface)
    }
}

