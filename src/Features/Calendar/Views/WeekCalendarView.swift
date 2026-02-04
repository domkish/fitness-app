//
//  WeekCalendarView.swift
//  fitness-app
//
//  Created by Assistant on 1/30/26.
//

import SwiftUI

struct WeekCalendarView: View {
    var onSelectDate: ((Date) -> Void)? = nil
    
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var authCoordinator: AuthCoordinator

    @State private var startOfWeek: Date = {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let weekday = cal.component(.weekday, from: today)
        let diff = (weekday - cal.firstWeekday + 7) % 7
        return cal.date(byAdding: .day, value: -diff, to: today) ?? today
    }()
    
    @State private var showingCheckin = false
    @State private var selectedDateForSheet: Date = Date()
    @State private var currentEntry: CalendarEntryRecord?
    @State private var priorEntry: CalendarEntryRecord?
    
    // Session navigation state
    @State private var activeSession: SessionRecord? = nil
    @State private var navigateToSession = false
    @State private var summarySession: SessionRecord? = nil
    @State private var navigateToSessionSummary = false

    // Quick actions popover state (mirror DayCalendarView)
    @State private var showingWorkoutPopover = false
    @State private var selectedWorkoutRow: CalendarWorkoutRepository.ScheduledWorkoutRow? = nil
    @State private var selectedWorkoutExercises: [String] = []
    @State private var exerciseLoadTask: Task<Void, Never>? = nil
    @State private var exerciseLoadError: String? = nil
    @State private var lastLoadedWorkoutId: Int64? = nil
    @State private var exerciseCache: [Int64: [String]] = [:]
    @State private var selectedWorkoutDate: Date? = nil

    struct CheckinContext: Identifiable {
        let id = UUID()
        let date: Date
        let existing: CalendarEntryRecord?
        let prior: CalendarEntryRecord?
    }

    @State private var checkinContext: CheckinContext?

    private let workoutRepository = CalendarWorkoutRepository(dbQueue: DatabaseQueueProvider.shared.dbQueue)
    private let entryRepository = CalendarEntryRepository(dbQueue: DatabaseQueueProvider.shared.dbQueue)

    @State private var weekWorkouts: [Int: [CalendarWorkoutRepository.ScheduledWorkoutRow]] = [:] // key: 0..6 offset
    @State private var weekEntries: [Int: Bool] = [:]

    // Repositories needed for session creation/navigation
    private let sessionRepository = SessionRepository(dbQueue: DatabaseQueueProvider.shared.dbQueue)
    private let workoutRepo = WorkoutRepository(dbQueue: DatabaseQueueProvider.shared.dbQueue)

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

    private func isTodayOrPast(_ date: Date) -> Bool {
        let today = Calendar.current.startOfDay(for: Date())
        let compareDate = Calendar.current.startOfDay(for: date)
        return compareDate <= today
    }
    
    private func isToday(_ date: Date) -> Bool {
        Calendar.current.isDateInToday(date)
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

    private func isWorkoutRowCompleted(_ w: CalendarWorkoutRepository.ScheduledWorkoutRow, on date: Date) -> Bool {
        let day = Calendar.current.startOfDay(for: date)
        do {
            let sessionRepo = SessionRepository(dbQueue: DatabaseQueueProvider.shared.dbQueue)
            if let existing = try sessionRepo.find(calendarWorkoutId: w.id, startedAt: day) {
                return sessionIsCompleted(existing)
            }
        } catch {
            // Ignore errors for indicator
        }
        return false
    }
    
    var body: some View {
        VStack(spacing: 0) {
            header
            List {
                ForEach(0..<7, id: \.self) { offset in
                    let date = Calendar.current.date(byAdding: .day, value: offset, to: startOfWeek)!
                    let isTodayCell = isToday(date)

                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(date.formatted(.dateTime.weekday(.wide)))
                                .font(.subheadline)
                                .fontWeight(isTodayCell ? .bold : .regular)
                                .foregroundColor(isTodayCell ? themeManager.currentTheme.primary : themeManager.currentTheme.textDefault)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    onSelectDate?(date)
                                }
                            Text(date.formatted(date: .abbreviated, time: .omitted))
                                .font(.caption)
                                .foregroundColor(isTodayCell ? themeManager.currentTheme.primary : themeManager.currentTheme.textDefault.opacity(0.8))
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    onSelectDate?(date)
                                }
                        }
                        Spacer()

                        let canCheckin = isTodayOrPast(date)
                        let hasEntry = weekEntries[offset] ?? false
                        if canCheckin {
                            Button {
                                let day = Calendar.current.startOfDay(for: date)
                                Task {
                                    // Load context first
                                    let context = await fetchEntryContext(for: day)
                                    await MainActor.run {
                                        self.selectedDateForSheet = day
                                        self.currentEntry = context.existing
                                        self.priorEntry = context.prior
                                        self.checkinContext = context // triggers sheet presentation
                                    }
                                }
                            } label: {
                                Image(systemName: hasEntry ? "checkmark.seal.fill" : "pencil.and.list.clipboard")
                                    .foregroundColor(hasEntry ? themeManager.currentTheme.primary : themeManager.currentTheme.muted)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .listRowBackground(themeManager.currentTheme.surface)

                    if let workouts = weekWorkouts[offset], !workouts.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(workouts, id: \.id) { w in
                                let c = colorForKey(w.workoutColor)
                                Button {
                                    self.exerciseLoadTask?.cancel()
                                    self.exerciseLoadTask = nil
                                    self.exerciseLoadError = nil
                                    self.selectedWorkoutRow = nil
                                    self.selectedWorkoutExercises = []

                                    self.selectedWorkoutDate = Calendar.current.startOfDay(for: date)

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
                                        if isWorkoutRowCompleted(w, on: date) {
                                            Spacer()
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(c)
                                        }
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
                        .listRowBackground(themeManager.currentTheme.surface)
                        .padding(.top, 6)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(themeManager.currentTheme.background)

            // Hidden NavigationLinks for session navigation
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
            
            .task(id: startOfWeek) {
                await loadWeekData()
            }
            .sheet(item: $checkinContext) { context in
                DailyCheckinSheet(
                    date: context.date,
                    existing: context.existing,
                    prior: context.prior,
                    repository: entryRepository
                ) { _ in
                    checkinContext = nil
                    Task { await loadWeekData() }
                }
                .id(sheetIdentity)
                .environmentObject(themeManager)
                .environmentObject(authCoordinator)
            }
            .popover(isPresented: Binding(get: { showingWorkoutPopover && selectedWorkoutRow != nil }, set: { showingWorkoutPopover = $0 }), arrowEdge: .top) {
                if let row = selectedWorkoutRow {
                    let canEnter = selectedWorkoutDate.map { isTodayOrPast($0) } ?? false
                    WorkoutQuickActionsPopover(
                        themeManager: themeManager,
                        workoutRow: row,
                        exercises: selectedWorkoutExercises,
                        canEnterSession: canEnter,
                        error: exerciseLoadError,
                        onEnterSession: {
                            self.exerciseLoadTask?.cancel()
                            self.exerciseLoadTask = nil
                            self.showingWorkoutPopover = false
                            Task { await ensureSessionForWorkoutRow(row, on: selectedWorkoutDate ?? Date()) }
                        },
                        onDelete: {
                            // Deletion from week view should refresh the week data
                            Task {
                                await MainActor.run {
                                    self.exerciseLoadTask?.cancel()
                                    self.exerciseLoadTask = nil
                                    self.showingWorkoutPopover = false
                                    self.selectedWorkoutRow = nil
                                }
                                await loadWeekData()
                            }
                        }
                    )
                    .environmentObject(authCoordinator)
                }
            }
        }
        .padding(.top, 8)
    }

    private var header: some View {
        HStack {
            Button { shiftWeek(-1) } label: { Image(systemName: "chevron.left") }
            Spacer()
            Text(weekLabel)
                .font(.headline)
                .foregroundColor(themeManager.currentTheme.textDefault)
            Spacer()
            Button { shiftWeek(1) } label: { Image(systemName: "chevron.right") }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(themeManager.currentTheme.background)
    }

    private var weekLabel: String {
        let end = Calendar.current.date(byAdding: .day, value: 6, to: startOfWeek) ?? startOfWeek
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return "\(f.string(from: startOfWeek)) - \(f.string(from: end))"
    }
    
    private var sheetIdentity: String {
        let d = CalendarEntry.dbString(from: checkinContext?.date ?? selectedDateForSheet)
        let existingId = checkinContext?.existing?.id.map(String.init) ?? currentEntry?.id.map(String.init) ?? "none"
        return "\(d)-\(existingId)"
    }

    private func shiftWeek(_ delta: Int) {
        if let d = Calendar.current.date(byAdding: .day, value: delta * 7, to: startOfWeek) {
            startOfWeek = d
        }
    }

    private func loadWeekData() async {
        guard let userId = authCoordinator.currentUser?.id else { return }
        let id64 = Int64(userId)
        var map: [Int: [CalendarWorkoutRepository.ScheduledWorkoutRow]] = [:]
        var entriesMap: [Int: Bool] = [:]
        for offset in 0..<7 {
            if let date = Calendar.current.date(byAdding: .day, value: offset, to: startOfWeek) {
                let day = Calendar.current.startOfDay(for: date)
                do {
                    let rows = try workoutRepository.workoutsWithDetails(on: day, userId: id64)
                    map[offset] = rows.filter { CalendarWorkoutRepository.matches($0, on: day) }
                    let has = (try? entryRepository.entry(for: id64, on: day)) != nil
                    entriesMap[offset] = has
                } catch {
                    print("[WeekCalendarView] loadWeekData error: \(error)")
                    map[offset] = []
                    entriesMap[offset] = false
                }
            }
        }
        await MainActor.run {
            self.weekWorkouts = map
            self.weekEntries = entriesMap
        }
    }
    
    private func loadEntryContext(for date: Date) async {
        guard let userId = authCoordinator.currentUser?.id else { return }
        let id64 = Int64(userId)
        let day = Calendar.current.startOfDay(for: date)
        var fetchedCurrent: CalendarEntryRecord?
        var fetchedPrior: CalendarEntryRecord?
        do {
            fetchedCurrent = try entryRepository.entry(for: id64, on: day)
        } catch {
            fetchedCurrent = nil
        }
        do {
            fetchedPrior = try entryRepository.mostRecentPriorEntry(before: day, userId: id64)
        } catch {
            fetchedPrior = nil
        }
        await MainActor.run {
            self.currentEntry = fetchedCurrent
            self.priorEntry = fetchedPrior
        }
    }
    
    private func fetchEntryContext(for date: Date) async -> CheckinContext {
        let day = Calendar.current.startOfDay(for: date)
        await loadEntryContext(for: day)
        return CheckinContext(date: day, existing: self.currentEntry, prior: self.priorEntry)
    }

    private func ensureSessionForWorkoutRow(_ w: CalendarWorkoutRepository.ScheduledWorkoutRow, on date: Date) async {
        guard let userId = authCoordinator.currentUser?.id else { return }
        let id64 = Int64(userId)
        let day = Calendar.current.startOfDay(for: date)
        do {
            let session = try sessionRepository.ensureSessionWithSeed(
                userId: id64,
                workoutId: w.workoutId,
                calendarWorkoutId: w.id,
                workoutName: w.workoutName,
                startedAt: day,
                workoutRepo: workoutRepo
            )
            let isCompleted = sessionIsCompleted(session)
            await MainActor.run {
                if isCompleted {
                    self.summarySession = session
                    self.navigateToSessionSummary = true
                    self.activeSession = nil
                    self.navigateToSession = false
                } else {
                    self.activeSession = session
                    self.navigateToSession = true
                }
            }
        } catch {
            print("[WeekCalendarView] ensureSessionWithSeed error: \(error)")
        }
    }

    private func loadExercisesForWorkout(workoutId: Int64) async {
        await MainActor.run {
            self.exerciseLoadError = nil
        }
        print("[WeekCalendarView] loadExercisesForWorkout start id=\(workoutId)")
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
            print("[WeekCalendarView] loadExercisesForWorkout fetched names=\(names.count)")
            await MainActor.run {
                self.exerciseCache[workoutId] = names
                self.selectedWorkoutExercises = names
                self.lastLoadedWorkoutId = workoutId
            }
        } catch is CancellationError {
            print("[WeekCalendarView] loadExercisesForWorkout cancelled")
        } catch {
            print("[WeekCalendarView] loadExercisesForWorkout error: \(error)")
            await MainActor.run { self.exerciseLoadError = error.localizedDescription }
        }
        print("[WeekCalendarView] loadExercisesForWorkout end id=\(workoutId)")
    }

    @ViewBuilder
    private var sessionDestinationView: some View {
        if let session = activeSession {
            SessionView(coordinator: AppShellCoordinator(), session: session, sessionRepo: sessionRepository, onCompleted: { completed in
                // Pop back to WeekCalendarView by turning off navigation
                self.navigateToSession = false
                // Push summary
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
            SessionSummaryView(coordinator: AppShellCoordinator(), session: s)
                .environmentObject(themeManager)
                .environmentObject(authCoordinator)
        } else {
            EmptyView()
        }
    }
}

