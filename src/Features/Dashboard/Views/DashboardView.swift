//
//  DashboardView.swift
//  fitness-app
//
//  Created by Dominic Kish on 1/25/26.
//
import SwiftUI
import Combine
import GRDB
import Charts

struct DashboardView: View {
    @ObservedObject var coordinator: AppShellCoordinator
    @EnvironmentObject var authCoordinator: AuthCoordinator
    @EnvironmentObject var themeManager: ThemeManager

    @StateObject var viewModel: DashboardViewModel
    
    @State private var completedExercises: [ExerciseOption] = []
    @State private var selectedExerciseId: Int64? = nil
    @State private var prPoints: [SetsChartView.SetChartPoint] = []
    @State private var isLoadingExerciseLog = false
    @State private var exerciseLogError: String? = nil

    init(coordinator: AppShellCoordinator, userId: Int64? = nil, viewModel: DashboardViewModel? = nil) {
        self.coordinator = coordinator
        if let vm = viewModel {
            _viewModel = StateObject(wrappedValue: vm)
        } else {
            let uid = userId ?? 0
            let repo = SessionRepository(dbQueue: DatabaseQueueProvider.shared.dbQueue)
            _viewModel = StateObject(wrappedValue: DashboardViewModel(sessionRepository: repo, userId: uid))
        }
    }
    
    private struct ExerciseOption: Identifiable, Hashable {
        let id: Int64
        let name: String
    }

    private var currentUserName: String { authCoordinator.currentUser?.name ?? "" }
    private var isImperial: Bool { authCoordinator.currentUser?.isImperial ?? true }

    private var currentDateRange: (start: Date, end: Date)? {
        switch viewModel.dateSelection {
        case .lifetime:
            return nil
        case let .custom(start, end):
            return (start, end)
        }
    }
    
    // MARK: - Loading Exercise Log
    
    private func loadExerciseLog() async {
        await MainActor.run {
            isLoadingExerciseLog = true
            exerciseLogError = nil
        }

        guard let userId = authCoordinator.currentUser?.id else {
            await MainActor.run {
                isLoadingExerciseLog = false
                completedExercises = []
                selectedExerciseId = nil
                prPoints = []
            }
            return
        }

        let id64 = Int64(userId)
        let range = currentDateRange
        let dbQueue = DatabaseQueueProvider.shared.dbQueue
        let exRepo = SessionExerciseRepository(dbQueue: dbQueue)
        let blockRepo = SessionBlockRepository(dbQueue: dbQueue)

        // Build unique completed exercises within date window for this user
         do {
            let exercises: [ExerciseOption] = try await withCheckedThrowingContinuation { cont in
                dbQueue.asyncRead { dbResult in
                    do {
                        let db = try dbResult.get()
                        // SQL: distinct exercise id+name for completed exercises with at least one completed set, scoped to user and date window
                        var sql = """
                            SELECT DISTINCT se.exercise_id AS id, se.exercise_name AS name
                            FROM session_exercises se
                            JOIN session_blocks sb ON sb.id = se.session_block_id AND sb.deleted_at IS NULL
                            JOIN sessions s ON s.id = sb.session_id AND s.deleted_at IS NULL
                            JOIN session_sets ss ON ss.session_exercise_id = se.id AND ss.deleted_at IS NULL AND ss.completed = 1
                            WHERE se.deleted_at IS NULL
                              AND se.completed = 1
                              AND s.user_id = ?
                        """
                        var args = StatementArguments()
                        args += [id64]
                        if let start = range?.start {
                            sql += " AND (COALESCE(s.completed_at, s.created_at) >= ?)"
                            args += [start]
                        }
                        if let end = range?.end {
                            sql += " AND (COALESCE(s.completed_at, s.created_at) <= ?)"
                            args += [end]
                        }
                        sql += " ORDER BY name COLLATE NOCASE ASC"
                        struct RowMap: FetchableRecord, Decodable { let id: Int64; let name: String }
                        let rows = try RowMap.fetchAll(db, sql: sql, arguments: args)
                        let opts = rows.map { ExerciseOption(id: $0.id, name: $0.name) }
                        cont.resume(returning: opts)
                    } catch {
                        cont.resume(throwing: error)
                    }
                }
            }

            await MainActor.run {
                self.completedExercises = exercises
                // Prefer user's stored log if it matches an available exercise; else fallback to first
                if let storedLog = authCoordinator.currentUser?.log,
                   let match = exercises.first(where: { Int($0.id) == storedLog }) {
                    self.selectedExerciseId = match.id
                } else {
                    self.selectedExerciseId = exercises.first?.id
                }
            }

            if let sel = await MainActor.run(body: { self.selectedExerciseId }) {
                await buildPRPoints(for: sel)
            } else {
                await MainActor.run { prPoints = [] }
            }

            await MainActor.run { isLoadingExerciseLog = false }
         } catch {
            await MainActor.run {
                exerciseLogError = "Failed to load exercise log.\n\(error.localizedDescription)"
                isLoadingExerciseLog = false
                completedExercises = []
                selectedExerciseId = nil
                prPoints = []
            }
         }
    }
    
    private func buildPRPoints(for exerciseId: Int64) async {
        let range = currentDateRange
        let dbQueue = DatabaseQueueProvider.shared.dbQueue

        // For now, compute a simple series of points per set ordered by created_at for the selected exercise across the date window.
         do {
            let points: [SetsChartView.SetChartPoint] = try await withCheckedThrowingContinuation { cont in
                dbQueue.asyncRead { dbResult in
                    do {
                        let db = try dbResult.get()
                        // Fetch completed sets for the given exerciseId across sessions in window
                        var sql = """
                            SELECT ss.set_number AS setIndex,
                                   COALESCE(ss.value, 0) AS value,
                                   COALESCE(ss.completed_reps, 0) AS reps,
                                   COALESCE(ss.unit, se.unit) AS unit,
                                   ss.created_at AS createdAt
                            FROM session_sets ss
                            JOIN session_exercises se ON se.id = ss.session_exercise_id AND se.deleted_at IS NULL AND se.completed = 1
                            JOIN session_blocks sb ON sb.id = se.session_block_id AND sb.deleted_at IS NULL
                            JOIN sessions s ON s.id = sb.session_id AND s.deleted_at IS NULL
                            WHERE ss.deleted_at IS NULL
                              AND ss.completed = 1
                              AND se.exercise_id = ?
                        """
                        var args = StatementArguments()
                        args += [exerciseId]
                        if let start = range?.start {
                            sql += " AND (COALESCE(s.completed_at, s.created_at) >= ?)"
                            args += [start]
                        }
                        if let end = range?.end {
                            sql += " AND (COALESCE(s.completed_at, s.created_at) <= ?)"
                            args += [end]
                        }
                        sql += " ORDER BY createdAt ASC, setIndex ASC"
                        struct RowMap: FetchableRecord, Decodable { let setIndex: Int; let value: Double?; let reps: Int?; let unit: String? }
                        let rows = try RowMap.fetchAll(db, sql: sql, arguments: args)
                        let pts = rows.enumerated().map { idx, r in
                            SetsChartView.SetChartPoint(setIndex: idx, value: r.value ?? 0, reps: r.reps ?? 0, unit: r.unit ?? "", isPrevious: false)
                        }
                        cont.resume(returning: pts)
                    } catch {
                        cont.resume(throwing: error)
                    }
                }
            }
            await MainActor.run { self.prPoints = points }
         } catch {
            await MainActor.run { self.prPoints = [] }
         }
    }

    var body: some View {
        ZStack {
            themeManager.currentTheme.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .trailing, spacing: 16) {
                    Text("Welcome back, \(currentUserName)")
                        .bold()
                        .foregroundStyle(themeManager.currentTheme.textDefault)
                        .padding(.horizontal)
                        .padding(.top, 4)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
                VStack(alignment: .center, spacing: 16) {
                    Button {
                        viewModel.showingDatePicker = true
                    } label: {
                        HStack(spacing: 4) {
                            Text(viewModel.dateRangeLabel)
                                .fontWeight(.semibold)
                            Image(systemName: "chevron.down")
                                .font(.footnote.weight(.semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .foregroundColor(themeManager.currentTheme.primary)
                        .background(themeManager.currentTheme.primary.opacity(0.1))
                        .cornerRadius(8)
                    }
                    .padding(.horizontal)
                    .sheet(isPresented: $viewModel.showingDatePicker) {
                        NavigationStack {
                            DateRangePickerView(
                                initialSelection: viewModel.dateSelection,
                                onDone: { newSelection in
                                    self.viewModel.dateSelection = newSelection
                                    viewModel.showingDatePicker = false
                                },
                                onCancel: {
                                    viewModel.showingDatePicker = false
                                }
                            )
                        }
                    }

                    HStack(spacing: 16) {
                        let weight = viewModel.formattedWeight(isImperial: isImperial)
                        MetricTile(title: "Weight", icon: "scalemass", value: weight.value, unit: weight.unit)

                        let distance = viewModel.formattedDistance(isImperial: isImperial)
                        MetricTile(title: "Distance", icon: "figure.walk.motion", value: distance.value, unit: distance.unit)
                    }
                    .padding(.horizontal)
                    
                    HStack(spacing: 16) {
                        let freq = viewModel.formattedWorkoutFrequency()
                        MetricTile(title: "Avg Workouts", icon: "calendar", value: freq.value, unit: freq.unit)
                        
                        MetricTile(title: "Duration", icon: "clock", value: viewModel.formattedDuration(), unit: nil)
                    }
                    .padding(.horizontal)
                    
                    if !completedExercises.isEmpty {
                        HStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Exercise Log")
                                        .font(.headline)
                                        .foregroundStyle(themeManager.currentTheme.textDefault)
                                    Spacer()
                                    if isLoadingExerciseLog { ProgressView().tint(themeManager.currentTheme.primary) }
                                }
                                if let error = exerciseLogError {
                                    Text(error)
                                        .font(.caption)
                                        .foregroundStyle(themeManager.currentTheme.error)
                                }
                                Picker("Exercise", selection: Binding<Int64?>(
                                    get: { selectedExerciseId ?? completedExercises.first?.id },
                                    set: { newValue in
                                        selectedExerciseId = newValue
                                        if let id = newValue {
                                            // Persist selection to user->log
                                            Task {
                                                await buildPRPoints(for: id)
                                                await MainActor.run {
                                                    if var user = authCoordinator.currentUser {
                                                        // Create a new User value with updated log
                                                        let updated = User(
                                                            id: user.id,
                                                            name: user.name,
                                                            email: user.email,
                                                            isPremium: user.isPremium,
                                                            isImperial: user.isImperial,
                                                            weight: user.weight,
                                                            fat: user.fat,
                                                            log: Int(id),
                                                            theme: user.theme,
                                                            emailVerifiedAt: user.emailVerifiedAt,
                                                            createdAt: user.createdAt,
                                                            updatedAt: Date()
                                                        )
                                                        authCoordinator.currentUser = updated
                                                        do { try authCoordinator.userRepository.createOrUpdate(updated) } catch { print("[DashboardView] Failed to persist user log:", error) }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                )) {
                                    ForEach(completedExercises) { opt in
                                        Text(opt.name).tag(Optional(opt.id))
                                    }
                                }
                                .pickerStyle(.menu)
                                .tint(themeManager.currentTheme.primary)

                                SetsChartView(points: prPoints)
                                    .environmentObject(themeManager)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .task {
                await viewModel.loadDashboardData()
                await loadExerciseLog()
            }
            .onChange(of: viewModel.dateSelection) { _ in
                Task {
                    await viewModel.loadDashboardData()
                    await loadExerciseLog()
                }
            }
            .onReceive(authCoordinator.$currentUser) { user in
                if let id = user?.id {
                    Task { @MainActor in
                        self.viewModel.updateUser(id: Int64(id))
                        await self.viewModel.loadDashboardData()
                        await self.loadExerciseLog()
                    }
                }
            }
                
        }
    }

    struct MetricTile: View {
        @EnvironmentObject var themeManager: ThemeManager
        
        let title: String
        let icon: String
        let value: String
        let unit: String?

        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(title)
                        .font(.callout)
                        .bold()
                        .foregroundStyle(themeManager.currentTheme.textDefault)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Image(systemName: icon)
                        .font(.callout)
                        .foregroundStyle(themeManager.currentTheme.textDefault)
                        .lineLimit(1)
                    Text(value)
                        .font(.callout)
                        .foregroundStyle(themeManager.currentTheme.textDefault)
                        .lineLimit(1)
                    if let unit = unit {
                        Text(unit)
                            .font(.callout)
                            .foregroundStyle(themeManager.currentTheme.textDefault)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding()
            .background(themeManager.currentTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    struct DateRangePickerView: View {
        @Environment(\.dismiss) private var dismiss

        @State private var customStart: Date
        @State private var customEnd: Date

        var initialSelection: DashboardViewModel.DateRangeSelection
        var onDone: (DashboardViewModel.DateRangeSelection) -> Void
        var onCancel: () -> Void

        init(initialSelection: DashboardViewModel.DateRangeSelection,
             onDone: @escaping (DashboardViewModel.DateRangeSelection) -> Void,
             onCancel: @escaping () -> Void)
        {
            self.initialSelection = initialSelection
            self.onDone = onDone
            self.onCancel = onCancel

            switch initialSelection {
            case .lifetime:
                let now = Date()
                _customEnd = State(initialValue: now)
                _customStart = State(initialValue: Calendar.current.date(byAdding: .day, value: -30, to: now) ?? now)
            case let .custom(start, end):
                _customStart = State(initialValue: start)
                _customEnd = State(initialValue: end)
            }
        }

        var body: some View {
            Form {
                Section {
                    Button("Select Lifetime") {
                        onDone(.lifetime)
                        dismiss()
                    }
                }

                Section("Custom Range") {
                    DatePicker("Start Date", selection: $customStart, displayedComponents: [.date])
                        .datePickerStyle(.graphical)
                    DatePicker("End Date", selection: $customEnd, in: customStart..., displayedComponents: [.date])
                        .datePickerStyle(.graphical)
                }
            }
            .navigationTitle("Select Date Range")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        onDone(.custom(customStart.startOfDay, customEnd.endOfDay))
                        dismiss()
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                        dismiss()
                    }
                }
            }
        }
    }
}
private extension Date {
    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }
    var endOfDay: Date {
        let start = startOfDay
        return Calendar.current.date(byAdding: DateComponents(day: 1, second: -1), to: start) ?? self
    }
}

#Preview {
    let coordinator = AppShellCoordinator()
    let themeManager = ThemeManager()
    let userRepo = UserRepository(dbQueue: DatabaseQueueProvider.shared.dbQueue)
    let authCoordinator = AuthCoordinator(authService: AuthService(userRepository: userRepo), userRepository: userRepo)
    return DashboardView(coordinator: coordinator)
        .environmentObject(authCoordinator)
        .environmentObject(themeManager)
}

