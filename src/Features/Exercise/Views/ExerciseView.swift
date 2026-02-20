//
//  ExerciseView.swift
//  SimplyFitness
//
//  Created by Dominic Kish on 1/25/26.
//

import SwiftUI
import Combine
import GRDB

struct ExerciseView: View {
    @ObservedObject var coordinator: AppShellCoordinator
    @EnvironmentObject var authCoordinator: AuthCoordinator
    @EnvironmentObject var themeManager: ThemeManager

    @StateObject private var viewModel = ExerciseListViewModel()
    @State private var searchText: String = ""

    // Tag filter state
    @State private var groupTags: [(id: Int64, name: String)] = []
    @State private var categoryTags: [(id: Int64, name: String)] = []
    @State private var workoutTags: [(id: Int64, name: String)] = []
    @State private var selectedGroupTagId: Int64? = nil
    @State private var selectedCategoryTagId: Int64? = nil
    @State private var selectedWorkoutTagId: Int64? = nil
    @State private var showAdvancedFilters: Bool = false

    private enum TopSegment: Hashable { case routines, exercises }
    @State private var topSegmentSelection: TopSegment = .exercises

    var body: some View {
        NavigationStack {
            ZStack {
                themeManager.currentTheme.background
                    .ignoresSafeArea()

                VStack(spacing: 30) {

                    // MARK: - Top Segmented Control
                    HStack(spacing: 6) {
                        let isRoutines = (topSegmentSelection == .routines)

                        Button {
                            topSegmentSelection = .routines
                            coordinator.currentStep = .workout
                        } label: {
                            Text("Routines")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(
                                    isRoutines
                                    ? themeManager.currentTheme.background
                                    : themeManager.currentTheme.textDefault
                                )
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(
                                            isRoutines
                                            ? themeManager.currentTheme.primary
                                            : themeManager.currentTheme.surface
                                        )
                                )
                        }

                        Button {
                            topSegmentSelection = .exercises
                            coordinator.currentStep = .exercise
                        } label: {
                            Text("Exercises")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(
                                    !isRoutines
                                    ? themeManager.currentTheme.background
                                    : themeManager.currentTheme.textDefault
                                )
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(
                                            !isRoutines
                                            ? themeManager.currentTheme.primary
                                            : themeManager.currentTheme.surface
                                        )
                                )
                        }
                    }
                    .padding(.horizontal)
                    .onAppear {
                        topSegmentSelection =
                            (coordinator.currentStep == .exercise)
                            ? .exercises
                            : .routines
                    }

                    // MARK: - Header
                    HStack {
                        Text("Exercise Library")
                            .font(.title)
                            .bold()
                            .foregroundColor(themeManager.currentTheme.textDefault)

                        Spacer()

                        NavigationLink {
                            ExerciseAddView()
                                .environmentObject(themeManager)
                        } label: {
                            Image(systemName: "plus")
                                .font(.headline)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 12)
                                .background(themeManager.currentTheme.surface)
                                .cornerRadius(8)
                        }
                    }
                    .padding(.horizontal)

                    // MARK: - Search Bar (MOVED ABOVE LIST)
                    searchBar

                    // MARK: - Advanced Filters Toggle
                    Button(action: { withAnimation(.easeInOut) { showAdvancedFilters.toggle() } }) {
                        HStack(spacing: 6) {
                            Text("Advanced Filters")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(themeManager.currentTheme.textDefault)
                            Spacer()
                            Image(systemName: showAdvancedFilters ? "chevron.up" : "chevron.down")
                                .foregroundColor(themeManager.currentTheme.muted)
                        }
                        .padding(.horizontal)
                    }

                    if showAdvancedFilters {
                        VStack(spacing: 12) {
                            // Card content
                            VStack(spacing: 12) {
                                HStack {
                                    Text("Muscle Group").foregroundColor(themeManager.currentTheme.textDefault)
                                    Spacer()
                                    Picker("Muscle Group", selection: Binding<Int64?>(
                                        get: { selectedGroupTagId },
                                        set: { selectedGroupTagId = $0 }
                                    )) {
                                        Text("Any").tag(Int64?.none)
                                        ForEach(groupTags, id: \.id) { item in
                                            Text(item.name).tag(Int64?.some(item.id))
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    .labelsHidden()
                                }
                                HStack {
                                    Text("Category").foregroundColor(themeManager.currentTheme.textDefault)
                                    Spacer()
                                    Picker("Category", selection: Binding<Int64?>(
                                        get: { selectedCategoryTagId },
                                        set: { selectedCategoryTagId = $0 }
                                    )) {
                                        Text("Any").tag(Int64?.none)
                                        ForEach(categoryTags, id: \.id) { item in
                                            Text(item.name).tag(Int64?.some(item.id))
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    .labelsHidden()
                                }
                                HStack {
                                    Text("Workout").foregroundColor(themeManager.currentTheme.textDefault)
                                    Spacer()
                                    Picker("Workout", selection: Binding<Int64?>(
                                        get: { selectedWorkoutTagId },
                                        set: { selectedWorkoutTagId = $0 }
                                    )) {
                                        Text("Any").tag(Int64?.none)
                                        ForEach(workoutTags, id: \.id) { item in
                                            Text(item.name).tag(Int64?.some(item.id))
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    .labelsHidden()
                                }
                            }
                            .padding()
                            .background(themeManager.currentTheme.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
                            .padding(.horizontal)
                        }
                    }

                    // MARK: - Table Container
                    VStack(spacing: 0) {
                        tableBody
                            .background(themeManager.currentTheme.surface)
                    }
                    .frame(maxHeight: .infinity)
                    .background(themeManager.currentTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
                    .padding([.horizontal, .bottom])
                }
            }
            .background(themeManager.currentTheme.surface)
            .ignoresSafeArea(.keyboard, edges: .bottom)
            .onChange(of: searchText) { newValue in
                Task {
                    try? await Task.sleep(nanoseconds: 250_000_000)
                    guard newValue == searchText else { return }
                    await viewModel.refresh(
                        search: newValue,
                        groupTagId: selectedGroupTagId,
                        categoryTagId: selectedCategoryTagId,
                        workoutTagId: selectedWorkoutTagId
                    )
                }
            }
            .onChange(of: selectedGroupTagId) { _ in
                Task { await viewModel.refresh(search: searchText, groupTagId: selectedGroupTagId, categoryTagId: selectedCategoryTagId, workoutTagId: selectedWorkoutTagId) }
            }
            .onChange(of: selectedCategoryTagId) { _ in
                Task { await viewModel.refresh(search: searchText, groupTagId: selectedGroupTagId, categoryTagId: selectedCategoryTagId, workoutTagId: selectedWorkoutTagId) }
            }
            .onChange(of: selectedWorkoutTagId) { _ in
                Task { await viewModel.refresh(search: searchText, groupTagId: selectedGroupTagId, categoryTagId: selectedCategoryTagId, workoutTagId: selectedWorkoutTagId) }
            }
            .task {
                await loadFilterTags()
                await viewModel.refresh(search: searchText, groupTagId: selectedGroupTagId, categoryTagId: selectedCategoryTagId, workoutTagId: selectedWorkoutTagId)
            }
        }
    }

    // MARK: - Search Bar View
    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(themeManager.currentTheme.secondary)

            TextField("", text: $searchText)
                .themedPlaceholder("Search exercises", when: searchText.isEmpty, color: themeManager.currentTheme.muted)
                .foregroundColor(themeManager.currentTheme.textDefault)
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(themeManager.currentTheme.formDefault)
                .cornerRadius(10)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                    UIApplication.shared.sendAction(
                        #selector(UIResponder.resignFirstResponder),
                        to: nil,
                        from: nil,
                        for: nil
                    )
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(themeManager.currentTheme.secondary)
                        .imageScale(.medium)
                        .accessibilityLabel("Clear search")
                }
            }
        }
        .padding()
        .background(themeManager.currentTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
        .padding(.horizontal)
    }

    private func loadFilterTags() async {
        do {
            try await DatabaseQueueProvider.shared.dbQueue.read { db in
                let groups = try ExerciseTagRecord
                    .filter(ExerciseTagRecord.Columns.type == "Group")
                    .order(ExerciseTagRecord.Columns.name.asc)
                    .fetchAll(db)
                    .compactMap { rec -> (Int64, String)? in
                        guard let id = rec.id else { return nil }
                        return (id, rec.name)
                    }
                let categories = try ExerciseTagRecord
                    .filter(ExerciseTagRecord.Columns.type == "Category")
                    .order(ExerciseTagRecord.Columns.name.asc)
                    .fetchAll(db)
                    .compactMap { rec -> (Int64, String)? in
                        guard let id = rec.id else { return nil }
                        return (id, rec.name)
                    }
                let workouts = try ExerciseTagRecord
                    .filter(ExerciseTagRecord.Columns.type == "Workout")
                    .order(ExerciseTagRecord.Columns.name.asc)
                    .fetchAll(db)
                    .compactMap { rec -> (Int64, String)? in
                        guard let id = rec.id else { return nil }
                        return (id, rec.name)
                    }
                self.groupTags = groups.map { (id: $0.0, name: $0.1) }
                self.categoryTags = categories.map { (id: $0.0, name: $0.1) }
                self.workoutTags = workouts.map { (id: $0.0, name: $0.1) }
            }
        } catch {
            // ignore for now
        }
    }

    // MARK: - Table Body
    private var tableBody: some View {
        List {
            Section {
                ForEach(viewModel.exercises) { exercise in
                    let row = HStack(spacing: 12) {
                        if !exercise.locked {
                            Image(systemName: "circle.fill")
                                .foregroundColor(themeManager.currentTheme.primary)
                                .imageScale(.small)
                                .accessibilityLabel("Custom exercise")
                        }

                        Text(exercise.name)
                            .foregroundColor(themeManager.currentTheme.textDefault)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.vertical, 4)
                    .listRowBackground(themeManager.currentTheme.surface)

                    let destination = ExerciseInfoView(
                        exerciseId: exercise.exerciseId,
                        locked: exercise.locked
                    )
                    .environmentObject(themeManager)

                    if exercise.locked {
                        NavigationLink(destination: destination) { row }
                    } else {
                        NavigationLink(destination: destination) { row }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    Task {
                                        await viewModel.deleteRow(
                                            with: exercise.exerciseId
                                        )
                                    }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                }

                if viewModel.canLoadMore {
                    HStack { Spacer(); ProgressView(); Spacer() }
                        .listRowBackground(themeManager.currentTheme.surface)
                        .onAppear {
                            Task {
                                await viewModel.loadMore(
                                    search: searchText,
                                    groupTagId: selectedGroupTagId,
                                    categoryTagId: selectedCategoryTagId,
                                    workoutTagId: selectedWorkoutTagId
                                )
                            }
                        }
                }

                if viewModel.isLoadingInitial {
                    HStack { Spacer(); ProgressView(); Spacer() }
                        .listRowBackground(themeManager.currentTheme.surface)
                } else if viewModel.exercises.isEmpty {
                    VStack(spacing: 8) {
                        Text("No exercises found")
                            .bold()
                        Text(
                            "If you expect data, verify the current user is set and the app is using the correct database file."
                        )
                        .font(.footnote)
                        .foregroundColor(themeManager.currentTheme.textDefault)
                        .multilineTextAlignment(.center)
                    }
                    .listRowBackground(themeManager.currentTheme.surface)
                }
            }
            .listRowBackground(themeManager.currentTheme.surface)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(themeManager.currentTheme.surface)
    }
}

// MARK: - ViewModel + Models

@MainActor
final class ExerciseListViewModel: ObservableObject {
    @Published private(set) var exercises: [ExerciseRow] = []
    @Published private(set) var isLoadingInitial = false
    @Published private(set) var isLoadingPage = false
    @Published private(set) var canLoadMore = true

    private var currentPage: Int = 0
    private let pageSize: Int = 25

    private let exerciseRepo: ExerciseRepository
    private let userRepo: UserRepository

    init() {
        let dbQueue = DatabaseQueueProvider.shared.dbQueue
        self.exerciseRepo = ExerciseRepository(dbQueue: dbQueue)
        self.userRepo = UserRepository(dbQueue: dbQueue)
    }

    func refresh(search: String, groupTagId: Int64? = nil, categoryTagId: Int64? = nil, workoutTagId: Int64? = nil) async {
        isLoadingInitial = true
        currentPage = 0
        canLoadMore = true
        exercises = []
        defer { isLoadingInitial = false }
        await loadMore(search: search, groupTagId: groupTagId, categoryTagId: categoryTagId, workoutTagId: workoutTagId)
    }

    func loadMore(
        search: String,
        groupTagId: Int64? = nil,
        categoryTagId: Int64? = nil,
        workoutTagId: Int64? = nil
    ) async {
        guard !isLoadingPage, canLoadMore else { return }
        isLoadingPage = true
        defer { isLoadingPage = false }

        do {
            guard let user = try await userRepo.fetchUser() else {
                exercises = []
                canLoadMore = false
                return
            }

            let all = try await exerciseRepo.fetchAll(for: Int64(user.id))

            let filteredByTags: [ExerciseDomain]
            if groupTagId == nil && categoryTagId == nil && workoutTagId == nil {
                filteredByTags = all
            } else {
                // Build a set of exercise IDs matching ALL selected tags using exercise_tag_pivots
                let matchingIds: Set<Int64> = try await withCheckedThrowingContinuation { cont in
                    Task {
                        do {
                            try await DatabaseQueueProvider.shared.dbQueue.read { db in
                                var selected: [Int64] = []
                                if let g = groupTagId { selected.append(g) }
                                if let c = categoryTagId { selected.append(c) }
                                if let w = workoutTagId { selected.append(w) }
                                if selected.isEmpty {
                                    cont.resume(returning: Set(all.compactMap { $0.id }))
                                    return
                                }
                                struct Row: FetchableRecord, Decodable { let exercise_id: Int64 }
                                let placeholders = Array(repeating: "?", count: selected.count).joined(separator: ",")
                                let rows = try Row.fetchAll(
                                    db,
                                    sql: """
                                    SELECT exercise_id
                                    FROM exercise_tag_pivots
                                    WHERE exercise_tag_id IN (\(placeholders))
                                    GROUP BY exercise_id
                                    HAVING COUNT(DISTINCT exercise_tag_id) = ?
                                    """,
                                    arguments: StatementArguments(Array(selected) + [Int64(selected.count)])
                                )
                                cont.resume(returning: Set(rows.map { $0.exercise_id }))
                            }
                        } catch {
                            cont.resume(throwing: error)
                        }
                    }
                }
                filteredByTags = all.filter { ex in
                    if let id = ex.id { return matchingIds.contains(id) }
                    return false
                }
            }

            let mapped: [ExerciseRow] = filteredByTags.map { ex in
                let groupNames = ex.tags
                    .filter { $0.kind == .group }
                    .map { $0.name }

                let categoryNames = ex.tags
                    .filter { $0.kind == .category }
                    .map { $0.name }

                return ExerciseRow(
                    id: UUID(),
                    exerciseId: ex.id ?? -1,
                    name: ex.name,
                    groupNames: groupNames,
                    categoryNames: categoryNames,
                    locked: ex.locked
                )
            }

            let filtered: [ExerciseRow]
            if search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                filtered = mapped
            } else {
                let q = search.lowercased()
                filtered = mapped.filter {
                    $0.name.lowercased().contains(q) ||
                    $0.groupNames.joined(separator: ", ").lowercased().contains(q) ||
                    $0.categoryNames.joined(separator: ", ").lowercased().contains(q)
                }
            }

            let start = currentPage * pageSize
            let end = min(start + pageSize, filtered.count)

            guard start < end else {
                canLoadMore = false
                return
            }

            exercises.append(contentsOf: filtered[start..<end])
            currentPage += 1
            canLoadMore = end < filtered.count

        } catch {
            canLoadMore = false
        }
    }

    func deleteRow(with exerciseId: Int64) async {
        do {
            try exerciseRepo.softDelete(id: exerciseId)
            exercises.removeAll { $0.exerciseId == exerciseId }
        } catch {
            print("Failed to delete exercise:", error)
        }
    }
}

struct ExerciseRow: Identifiable, Hashable {
    let id: UUID
    let exerciseId: Int64
    let name: String
    let groupNames: [String]
    let categoryNames: [String]
    let locked: Bool
}

final class DatabaseQueueProvider {
    static let shared = DatabaseQueueProvider()
    private init() {}

    var dbQueue: DatabaseQueue = try! DatabaseQueue()
}

