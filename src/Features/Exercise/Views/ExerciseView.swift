//
//  ExerciseView.swift
//  fitness-app
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
                    await viewModel.refresh(search: newValue)
                }
            }
            .task {
                await viewModel.refresh(search: searchText)
            }
        }
    }

    // MARK: - Search Bar View
    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(themeManager.currentTheme.secondary)

            TextField("Search exercises", text: $searchText)
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
                                await viewModel.loadMore(search: searchText)
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

    func refresh(search: String) async {
        isLoadingInitial = true
        currentPage = 0
        canLoadMore = true
        exercises = []
        defer { isLoadingInitial = false }
        await loadMore(search: search)
    }

    func loadMore(search: String) async {
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

            let mapped: [ExerciseRow] = all.map { ex in
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
