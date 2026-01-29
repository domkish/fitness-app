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

    var body: some View {
        NavigationStack {
            ZStack {
                themeManager.currentTheme.background
                    .ignoresSafeArea()

                VStack(spacing: 30) {
                     Spacer().frame(height: 100) // Removed as per instructions
                    // Header with Add button (constrained to same horizontal padding as table)
                    HStack {
                        Text("Exercise Library")
                            .font(.title)
                            .bold()
                            .foregroundColor(themeManager.currentTheme.textDefault)
                        Spacer()
                        NavigationLink {
                            ExerciseAddView()
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

                    // Table container styled like ProfileView cards
                    VStack(spacing: 0) {
                        tableBody
                        .background(themeManager.currentTheme.surface)
                    }
                    .background(themeManager.currentTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
                    .padding([.horizontal, .bottom])
                    .padding(.bottom, 100)
                }

                VStack {
                    Spacer()
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(themeManager.currentTheme.secondary)

                        TextField("Search exercises", text: $searchText)
                            .textFieldStyle(.roundedBorder)
                            .foregroundColor(themeManager.currentTheme.textDefault)
                            .background(themeManager.currentTheme.formDefault)

                        if !searchText.isEmpty {
                            Button {
                                searchText = ""
                                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(themeManager.currentTheme.secondary)
                                    .imageScale(.medium)
                                    .accessibilityLabel("Clear search")
                                    .foregroundColor(themeManager.currentTheme.textDefault)
                            }
                        }
                    }
                    .padding()
                    .background(themeManager.currentTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
                    .padding(.horizontal)
                    .padding(.bottom, 34)
                }
            }
            .ignoresSafeArea(.keyboard, edges: .bottom)
            .onChange(of: searchText) { newValue in
                Task {
                    // Debounce ~250ms
                    try? await Task.sleep(nanoseconds: 250_000_000)
                    // If the user kept typing, abort this run
                    guard newValue == searchText else { return }
                    await viewModel.refresh(search: newValue)
                }
            }
            .task { await viewModel.refresh(search: searchText) }
        }
    }


    // MARK: - Table Body
    private var tableBody: some View {
        List {
            Section() {
                ForEach(viewModel.exercises) { exercise in
                    let row = HStack(alignment: .center, spacing: 12) {
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
                    .background(themeManager.currentTheme.surface)
                    .padding(.vertical, 4)

                    let destination = ExerciseInfoView(exerciseId: exercise.exerciseId, locked: exercise.locked)

                    if exercise.locked {
                        NavigationLink(destination: destination) { row }
                    } else {
                        NavigationLink(destination: destination) { row }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    Task { await viewModel.deleteRow(with: exercise.exerciseId) }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                }

                if viewModel.canLoadMore {
                    HStack { Spacer(); ProgressView(); Spacer() }
                        .onAppear {
                            Task { await viewModel.loadMore(search: searchText) }
                        }
                }

                if viewModel.isLoadingInitial {
                    HStack { Spacer(); ProgressView(); Spacer() }
                } else if viewModel.exercises.isEmpty {
                    VStack(spacing: 8) {
                        Text("No exercises found").bold()
                        Text("If you expect data, verify the current user is set and the app is using the correct database file.")
                            .font(.footnote)
                            .foregroundColor(themeManager.currentTheme.textDefault)
                            .multilineTextAlignment(.center)
                    }
                }
            }
        }
        .listStyle(.plain)
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

    // Data dependencies
    private let exerciseRepo: ExerciseRepository
    private let userRepo: UserRepository

    init() {
        // Access the shared DatabaseQueue from the global provider
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
        print("[ExerciseList] loadMore start — page: \(currentPage), search: \(search)")
        defer { isLoadingPage = false }

        // Fetch all user exercises, then filter and paginate locally for now.
        // If needed, optimize with SQL LIMIT/OFFSET in repository later.
        do {
            guard let user = try await userRepo.fetchUser() else {
                print("[ExerciseList] No current user found — cannot scope exercises. Showing empty list.")
                self.exercises = []
                self.canLoadMore = false
                return
            }
            print("[ExerciseList] Current user id: \(user.id)")
            let all = try await exerciseRepo.fetchAll(for: Int64(user.id))
            print("[ExerciseList] Repository returned total exercises for user: \(all.count)")

            // Map to ExerciseRow using tag info if present on domain
            let mapped: [ExerciseRow] = all.map { ex in
                let groupNames: [String] = ex.tags.filter { $0.kind == .group }.map { $0.name }
                let categoryNames: [String] = ex.tags.filter { $0.kind == .category }.map { $0.name }
                return ExerciseRow(id: UUID(), exerciseId: ex.id ?? -1, name: ex.name, groupNames: groupNames, categoryNames: categoryNames, locked: ex.locked)
            }
            print("[ExerciseList] Mapped rows: \(mapped.count)")

            // Apply search
            let filtered: [ExerciseRow]
            if search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                filtered = mapped
            } else {
                let q = search.lowercased()
                filtered = mapped.filter { row in
                    if row.name.lowercased().contains(q) { return true }
                    if row.groupNames.joined(separator: ", ").lowercased().contains(q) { return true }
                    if row.categoryNames.joined(separator: ", ").lowercased().contains(q) { return true }
                    return false
                }
            }
            print("[ExerciseList] Filtered rows: \(filtered.count)")

            // Paginate
            let start = currentPage * pageSize
            let end = min(start + pageSize, filtered.count)
            print("[ExerciseList] Pagination — start: \(start), end: \(end), pageSize: \(pageSize)")
            if start >= end {
                canLoadMore = false
                return
            }
            let nextSlice = Array(filtered[start..<end])
            exercises.append(contentsOf: nextSlice)
            currentPage += 1
            canLoadMore = end < filtered.count
        } catch {
            let message = String(describing: error)
            print("[ExerciseList] Error during loadMore: \(message)")
            canLoadMore = false
        }
    }

    func deleteRow(with exerciseId: Int64) async {
        do {
            try exerciseRepo.softDelete(id: exerciseId)
            await MainActor.run {
                exercises.removeAll { $0.exerciseId == exerciseId }
            }
        } catch {
            print("[ExerciseList] Failed to delete exercise id: \(exerciseId), error: \(error)")
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
    // This should be set during app startup.
    var dbQueue: DatabaseQueue = try! DatabaseQueue() // in-memory fallback; will be replaced at runtime
}

