//
//  DayCalendarView.swift
//  SimplyFitness
//
//  Created by Assistant on 1/30/26.
//
import SwiftUI
import PhotosUI
import GRDB

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

    @State private var showNonPremiumAlert = false
    @State private var nonPremiumAlertMessage: String = ""

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
            ZStack {
                themeManager.currentTheme.background
                    .ignoresSafeArea()
                VStack(spacing: 30) {
                    VStack(spacing: 0) {
                        ScrollView {
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
                                        Button(action: {
                                            let isPremium = authCoordinator.currentUser?.isPremium ?? false
                                            if !isPremium {
                                                // Enforce only 1 workout per day for non-premium
                                                if workouts.count >= 1 {
                                                    nonPremiumAlertMessage = "Free members can add one workout per day. Upgrade to Premium to schedule more."
                                                    showNonPremiumAlert = true
                                                    return
                                                }
                                            }
                                            showingRoutinePicker = true
                                        }) {
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
                                                
                                                // Use cachedExercises method and new loadExercisesForWorkout(row:) method
                                                if let cached = cachedExercises(for: w), !cached.isEmpty {
                                                    Task { @MainActor in
                                                        self.selectedWorkoutRow = w
                                                        self.selectedWorkoutExercises = cached
                                                        self.showingWorkoutPopover = true
                                                    }
                                                    // Optionally refresh cache in background without affecting UI
                                                    self.exerciseLoadTask = Task {
                                                        await loadExercisesForWorkout(row: w)
                                                        await MainActor.run { self.exerciseLoadTask = nil }
                                                    }
                                                } else {
                                                    // No cache yet: fetch first, then present
                                                    self.exerciseLoadTask = Task {
                                                        await loadExercisesForWorkout(row: w)
                                                        await MainActor.run {
                                                            self.selectedWorkoutRow = w
                                                            self.selectedWorkoutExercises = cachedExercises(for: w) ?? []
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
                                } else {
                                    VStack(alignment: .center, spacing: 8) {
                                        Image(systemName: "calendar.badge.exclamationmark")
                                            .font(.system(size: 40))
                                            .foregroundColor(themeManager.currentTheme.textDefault)
                                        Text("No workout routines assigned for this day")
                                            .font(.headline)
                                            .foregroundColor(themeManager.currentTheme.textDefault)
                                        Text("To add a session, use the + Workout button above.")
                                            .font(.callout)
                                            .foregroundColor(themeManager.currentTheme.muted)
                                            .multilineTextAlignment(.center)
                                            .padding(.horizontal)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
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
                                                        .foregroundColor(isTodayOrPast ? themeManager.currentTheme.textDefault : themeManager.currentTheme.textDefault.opacity(0.5))
                                                    Spacer()
                                                    Image(systemName: t.isComplete ? "checkmark.square.fill" : "square")
                                                        .font(.system(size: 22, weight: .semibold))
                                                        .foregroundColor(isTodayOrPast ? (t.isComplete ? themeManager.currentTheme.primary : themeManager.currentTheme.muted) : themeManager.currentTheme.muted.opacity(0.5))
                                                        .contentShape(Rectangle())
                                                }
                                            }
                                            .padding()
                                            .background(themeManager.currentTheme.surface)
                                            .cornerRadius(16)
                                            .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
                                            .disabled(!isTodayOrPast)
                                        }
                                        
                                        // Scheduled tasks without daily instances
                                        let pending = scheduledTasks.filter { hasDailyInstance(for: $0.id) == nil }
                                        ForEach(Array(pending.enumerated()), id: \.element.id) { _, s in
                                            Button {
                                                Task { await toggleTask(taskId: s.id) }
                                            } label: {
                                                HStack(spacing: 10) {
                                                    Text(s.name)
                                                        .foregroundColor(isTodayOrPast ? themeManager.currentTheme.textDefault : themeManager.currentTheme.textDefault.opacity(0.5))
                                                    Spacer()
                                                    Image(systemName: "square")
                                                        .font(.system(size: 22, weight: .semibold))
                                                        .foregroundColor(isTodayOrPast ? themeManager.currentTheme.muted : themeManager.currentTheme.muted.opacity(0.5))
                                                        .contentShape(Rectangle())
                                                }
                                            }
                                            .padding()
                                            .background(themeManager.currentTheme.surface)
                                            .cornerRadius(16)
                                            .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
                                            .disabled(!isTodayOrPast)
                                        }
                                    }
                                }
                                
                                Spacer()
                                
                                // Removed the two hidden NavigationLinks from here
                            }
                            .padding()
                            .alert("Premium Feature", isPresented: $showNonPremiumAlert) {
                                Button("OK", role: .cancel) { }
                            } message: {
                                Text(nonPremiumAlertMessage)
                            }
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
                                FrequencyPickerSheet(disableRepeatingOptions: !(authCoordinator.currentUser?.isPremium ?? false)) { freq in
                                    let isPremium = authCoordinator.currentUser?.isPremium ?? false
                                    if !isPremium {
                                        // Non-premium: only allow one-time (Just selected date)
                                        showingFrequencyPicker = false
                                        pendingFrequency = nil
                                        Task { await createOneTimeCalendarWorkout() }
                                        return
                                    }
                                    
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
                                .overlay(
                                    Group {
                                        let isPremium = authCoordinator.currentUser?.isPremium ?? false
                                        if !isPremium {
                                            VStack {
                                                Spacer()
                                                Text("Setting workout frequency is available for Premium members only.")
                                                    .font(.footnote)
                                                    .foregroundColor(themeManager.currentTheme.muted)
                                                    .padding(.horizontal)
                                                    .padding(.bottom, 12)
                                            }
                                        }
                                    }
                                )
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
                                        onDeleteSingle: {
                                            Task {
                                                await MainActor.run {
                                                    self.showingWorkoutPopover = false
                                                    self.selectedWorkoutRow = nil
                                                }
                                                await deleteSingleOccurrence(row)
                                            }
                                        },
                                        onDeleteThisAndFuture: {
                                            Task {
                                                await MainActor.run {
                                                    self.showingWorkoutPopover = false
                                                    self.selectedWorkoutRow = nil
                                                }
                                                await deleteThisAndFuture(row)
                                            }
                                        }
                                    )
                                    .environmentObject(authCoordinator)
                                }
                            }
                        }
                    }
                    
                    Spacer()
                }

                // Persistent hidden navigation links (outside ScrollView content)
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
        }
    }

    @ViewBuilder
    private var sessionDestinationView: some View {
        if let session = activeSession {
            SessionView(coordinator: coordinator, session: session, sessionRepo: sessionRepository, onCompleted: { completed in
                Task { @MainActor in
                    // Pop back to DayCalendarView
                    self.navigateToSession = false
                    // Present summary
                    self.summarySession = completed
                    self.navigateToSessionSummary = true
                }
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
            let rows = try workoutRepository.workoutsWithDetails(on: selectedDate, userId: id64)
            
            let sessionRepo = SessionRepository(dbQueue: DatabaseQueueProvider.shared.dbQueue)
            let day = Calendar.current.startOfDay(for: selectedDate)
            let dbQueue = DatabaseQueueProvider.shared.dbQueue
            let daySessions: [SessionRecord] = try await dbQueue.read { db in
                try SessionRecord
                    .filter(SessionRecord.Columns.deletedAt == nil)
                    .filter(SessionRecord.Columns.userId == id64)
                    .filter(SessionRecord.Columns.startedAt == day)
                    .fetchAll(db)
            }
            
            let exceptionRepo = CalendarWorkoutExceptionRepository(dbQueue: DatabaseQueueProvider.shared.dbQueue)
            let filteredWorkouts = rows.filter { row in
                CalendarWorkoutRepository.matches(row, on: selectedDate) && (try? !exceptionRepo.exists(calendarWorkoutId: row.id, on: selectedDate)) ?? true
            }
            
            var mergedWorkouts = filteredWorkouts
            let existingIds = Set(filteredWorkouts.map { $0.id })
            for sess in daySessions {
                if !existingIds.contains(sess.calendarWorkoutId) {
                    // Create a minimal synthetic row so the session appears even if the workout was deleted
                    let weekday = Calendar.current.component(.weekday, from: day)
                    let startsStr = CalendarWorkout.dbString(from: day)
                    let synthetic = CalendarWorkoutRepository.ScheduledWorkoutRow(
                        id: sess.calendarWorkoutId,
                        workoutId: sess.workoutId,
                        workoutName: sess.workoutName,
                        workoutColor: nil,
                        startsOn: startsStr,
                        endsOn: startsStr,
                        frequency: nil,
                        mon: weekday == 2,
                        tues: weekday == 3,
                        wed: weekday == 4,
                        thurs: weekday == 5,
                        fri: weekday == 6,
                        sat: weekday == 7,
                        sun: weekday == 1
                    )
                    mergedWorkouts.append(synthetic)
                }
            }
            
            let fetchedDailyTasks = try taskRepository.tasks(on: selectedDate, userId: id64)
            let fetchedScheduledTasks = try workoutRepo.activeTasks(on: selectedDate, userId: id64)

            await MainActor.run {
                self.entry = try? repository.entry(for: id64, on: selectedDate)
                self.priorEntry = try? repository.mostRecentPriorEntry(before: selectedDate, userId: id64)
                self.workouts = mergedWorkouts
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
                createdAt: day,
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

    private func deleteSingleOccurrence(_ row: CalendarWorkoutRepository.ScheduledWorkoutRow) async {
        do {
            let dbQueue = DatabaseQueueProvider.shared.dbQueue
            let day = Calendar.current.startOfDay(for: selectedDate)
            try await dbQueue.write { db in
                // 1) Insert exception
                var exception = CalendarWorkoutExceptionRecord(
                    id: nil,
                    calendarWorkoutId: row.id,
                    date: CalendarWorkout.dbString(from: day),
                    deletedAt: nil,
                    createdAt: Date(),
                    updatedAt: Date()
                )
                try exception.insert(db)

                // 2) Soft-delete session tree for that day
                if var session = try SessionRecord
                    .filter(SessionRecord.Columns.calendarWorkoutId == row.id)
                    .filter(SessionRecord.Columns.startedAt == day)
                    .filter(SessionRecord.Columns.deletedAt == nil)
                    .fetchOne(db) {
                    // Delete sets
                    let blocks = try SessionBlockRecord
                        .filter(SessionBlockRecord.Columns.sessionId == session.id)
                        .filter(SessionBlockRecord.Columns.deletedAt == nil)
                        .fetchAll(db)
                    for var b in blocks {
                        let exercises = try SessionExerciseRecord
                            .filter(SessionExerciseRecord.Columns.sessionBlockId == b.id)
                            .filter(SessionExerciseRecord.Columns.deletedAt == nil)
                            .fetchAll(db)
                        for var e in exercises {
                            var sets = try SessionSetRecord
                                .filter(SessionSetRecord.Columns.sessionExerciseId == e.id)
                                .filter(SessionSetRecord.Columns.deletedAt == nil)
                                .fetchAll(db)
                            for i in 0..<sets.count {
                                sets[i].deletedAt = Date()
                                sets[i].updatedAt = Date()
                                try sets[i].update(db)
                            }
                            e.deletedAt = Date()
                            e.updatedAt = Date()
                            try e.update(db)
                        }
                        b.deletedAt = Date()
                        b.updatedAt = Date()
                        try b.update(db)
                    }
                    session.deletedAt = Date()
                    session.updatedAt = Date()
                    try session.update(db)
                }
            }
            await loadData()
        } catch {
            print("[DayCalendarView] deleteSingleOccurrence error: \(error)")
        }
    }

    private func deleteThisAndFuture(_ row: CalendarWorkoutRepository.ScheduledWorkoutRow) async {
        do {
            let dbQueue = DatabaseQueueProvider.shared.dbQueue
            let day = Calendar.current.startOfDay(for: selectedDate)
            let previousDay = Calendar.current.date(byAdding: .day, value: -1, to: day) ?? day
            try await dbQueue.write { db in
                // 1) Truncate recurrence
                if var rec = try CalendarWorkoutRecord.fetchOne(db, key: row.id) {
                    rec.endsOn = CalendarWorkout.dbString(from: previousDay)
                    rec.updatedAt = Date()
                    try rec.update(db)
                }
                // 2) Soft-delete sessions on or after selected day
                let sessions = try SessionRecord
                    .filter(SessionRecord.Columns.calendarWorkoutId == row.id)
                    .filter(SessionRecord.Columns.startedAt >= day)
                    .filter(SessionRecord.Columns.deletedAt == nil)
                    .fetchAll(db)
                for var session in sessions {
                    let blocks = try SessionBlockRecord
                        .filter(SessionBlockRecord.Columns.sessionId == session.id)
                        .filter(SessionBlockRecord.Columns.deletedAt == nil)
                        .fetchAll(db)
                    for var b in blocks {
                        let exercises = try SessionExerciseRecord
                            .filter(SessionExerciseRecord.Columns.sessionBlockId == b.id)
                            .filter(SessionExerciseRecord.Columns.deletedAt == nil)
                            .fetchAll(db)
                        for var e in exercises {
                            var sets = try SessionSetRecord
                                .filter(SessionSetRecord.Columns.sessionExerciseId == e.id)
                                .filter(SessionSetRecord.Columns.deletedAt == nil)
                                .fetchAll(db)
                            for i in 0..<sets.count {
                                sets[i].deletedAt = Date()
                                sets[i].updatedAt = Date()
                                try sets[i].update(db)
                            }
                            e.deletedAt = Date()
                            e.updatedAt = Date()
                            try e.update(db)
                        }
                        b.deletedAt = Date()
                        b.updatedAt = Date()
                        try b.update(db)
                    }
                    session.deletedAt = Date()
                    session.updatedAt = Date()
                    try session.update(db)
                }
            }
            await loadData()
        } catch {
            print("[DayCalendarView] deleteThisAndFuture error: \(error)")
        }
    }

    private func loadExercisesForWorkout(row: CalendarWorkoutRepository.ScheduledWorkoutRow) async {
        await MainActor.run { self.exerciseLoadError = nil }
        let day = Calendar.current.startOfDay(for: selectedDate)
        do {
            try Task.checkCancellation()
            let sessionRepo = SessionRepository(dbQueue: DatabaseQueueProvider.shared.dbQueue)
            if let existingSession = try sessionRepo.find(calendarWorkoutId: row.id, startedAt: day) {
                // Load exercises from session_exercises tree
                let blockRepo = SessionBlockRepository(dbQueue: DatabaseQueueProvider.shared.dbQueue)
                let exRepo = SessionExerciseRepository(dbQueue: DatabaseQueueProvider.shared.dbQueue)
                let blocks = try blockRepo.bySession(existingSession.id ?? -1)
                var names: [String] = []
                for b in blocks.sorted(by: { ($0.id ?? 0) < ($1.id ?? 0) }) {
                    let ses = try exRepo.bySessionBlock(b.id ?? -1)
                    for e in ses.sorted(by: { (lhs, rhs) in
                        (lhs.order) ?? Int.max < (rhs.order) ?? Int.max
                    }) {
                        names.append(e.exerciseName)
                    }
                }
                try Task.checkCancellation()
                await MainActor.run {
                    // cache by calendar workout id + date to distinguish session-based cache
                    self.exerciseCache[row.id] = names
                    self.selectedWorkoutExercises = names
                    self.lastLoadedWorkoutId = row.workoutId
                }
            } else {
                // Fall back to workout definition exercises
                let grouped = try workoutRepo.fetchExercisesByBlock(forWorkoutId: row.workoutId)
                try Task.checkCancellation()
                let orderedBlockIds = grouped.keys.sorted()
                var names: [String] = []
                for bid in orderedBlockIds {
                    let rows = grouped[bid] ?? []
                    for r in rows { names.append(r.name) }
                }
                try Task.checkCancellation()
                await MainActor.run {
                    self.exerciseCache[row.workoutId] = names
                    self.selectedWorkoutExercises = names
                    self.lastLoadedWorkoutId = row.workoutId
                }
            }
        } catch is CancellationError {
            // ignore
        } catch {
            await MainActor.run { self.exerciseLoadError = error.localizedDescription }
        }
    }
    
    private func cachedExercises(for row: CalendarWorkoutRepository.ScheduledWorkoutRow) -> [String]? {
        // Prefer session cache keyed by calendar workout id; fall back to workout definition cache
        if let names = exerciseCache[row.id], !names.isEmpty { return names }
        if let names = exerciseCache[row.workoutId], !names.isEmpty { return names }
        return nil
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

