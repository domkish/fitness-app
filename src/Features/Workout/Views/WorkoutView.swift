//  WorkoutView.swift
//  fitness-app
//
//  Created by Dominic Kish on 1/25/26.
//
import SwiftUI
import GRDB

struct WorkoutView: View {
    @ObservedObject var coordinator: AppShellCoordinator

    // Dependencies
    private let dbQueue = DatabaseQueueProvider.shared.dbQueue
    private let workoutRepo: WorkoutRepository
    private let userRepo: UserRepository
    private let workoutService: WorkoutService

    // State
    @State private var workouts: [WorkoutDomain] = []
    @State private var searchText: String = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var isShowingAddPopup = false
    @State private var newWorkoutName: String = ""
    @State private var navigateToWorkoutId: Int64?
    @State private var shouldNavigateToDetail = false

    init(coordinator: AppShellCoordinator) {
        self.coordinator = coordinator
        let db = DatabaseQueueProvider.shared.dbQueue
        self.workoutRepo = WorkoutRepository(dbQueue: db)
        self.userRepo = UserRepository(dbQueue: db)
        self.workoutService = WorkoutService(dbQueue: db)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.background
                    .ignoresSafeArea()

                VStack(spacing: 30) {
                    Spacer().frame(height: 100)

                    // Header with Add button (constrained to same horizontal padding as table)
                    HStack {
                        Text("Workouts")
                            .font(.title)
                            .bold()
                        Spacer()
                        Button {
                            newWorkoutName = ""
                            isShowingAddPopup = true
                        } label: {
                            Image(systemName: "plus")
                                .font(.headline)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 12)
                                .background(AppColors.surface)
                                .cornerRadius(8)
                        }
                        .accessibilityLabel("Add Workout")
                    }
                    .padding(.horizontal)

                    // Hidden navigation link to push detail after creation
                    NavigationLink(
                        isActive: $shouldNavigateToDetail,
                        destination: {
                            if let id = navigateToWorkoutId {
                                WorkoutInfoView(workoutId: id)
                            } else {
                                // Return a concrete placeholder view to satisfy ViewBuilder
                                Text("Loading…").hidden()
                            }
                        },
                        label: { EmptyView() }
                    )
                    .hidden()

                    // Table container styled like ExerciseView
                    VStack(spacing: 0) {
                        // Content body matching ExerciseView’s List presentation
                        if isLoading {
                            HStack { Spacer(); ProgressView(); Spacer() }
                                .padding()
                        } else if let errorMessage = errorMessage {
                            VStack(spacing: 12) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                    .imageScale(.large)
                                Text(errorMessage)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                                Button("Retry") { Task { await loadWorkouts() } }
                                    .buttonStyle(.bordered)
                            }
                            .padding()
                        } else if filteredWorkouts.isEmpty {
                            VStack(spacing: 8) {
                                Image(systemName: "dumbbell.fill")
                                    .font(.system(size: 44))
                                    .foregroundColor(.secondary)
                                Text(searchText.isEmpty ? "No Workouts Yet" : "No Results")
                                    .font(.title3).bold()
                                Text(searchText.isEmpty
                                     ? "Tap + to add your first workout."
                                     : "Try a different search.")
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                        } else {
                            List {
                                Section() {
                                    ForEach(filteredWorkouts, id: \._id) { workout in
                                        let row = HStack(alignment: .center, spacing: 12) {
                                            Text(workout.name)
                                                .foregroundColor(.primary)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                        }
                                        .padding(.vertical, 4)

                                        NavigationLink {
                                            WorkoutInfoView(workoutId: workout.id)
                                        } label: { row }
                                    }
                                }
                            }
                            .listStyle(.plain)
                        }
                    }
                    .background(AppColors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
                    .padding([.horizontal, .bottom])
                    .padding(.bottom, 100)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                // Add Workout popup overlay
                if isShowingAddPopup {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .onTapGesture { withAnimation { isShowingAddPopup = false } }

                    VStack(spacing: 16) {
                        Text("New Workout").font(.headline)
                        TextField("Workout name", text: $newWorkoutName)
                            .textFieldStyle(.roundedBorder)
                            .padding(.horizontal)
                        HStack {
                            Button("Cancel") { withAnimation { isShowingAddPopup = false } }
                            Spacer()
                            Button("Create") { Task { await createWorkoutAndDefaultBlock() } }
                                .disabled(newWorkoutName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                    }
                    .padding(.vertical, 20)
                    .frame(maxWidth: 360)
                    .background(AppColors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: Color.black.opacity(0.15), radius: 20, x: 0, y: 10)
                }

                // Floating bottom search bar to mirror ExerciseView
                VStack {
                    Spacer()
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        TextField("Search workouts", text: $searchText)
                            .textFieldStyle(.roundedBorder)
                        if !searchText.isEmpty {
                            Button {
                                searchText = ""
                                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                                    .imageScale(.medium)
                                    .accessibilityLabel("Clear search")
                            }
                        }
                    }
                    .padding()
                    .background(AppColors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
                    .padding(.horizontal)
                    .padding(.bottom, 34)
                }
            }
            .ignoresSafeArea(.keyboard, edges: .bottom)
            .onChange(of: searchText) { newValue in
                Task {
                    try? await Task.sleep(nanoseconds: 250_000_000)
                    guard newValue == searchText else { return }
                    await loadWorkouts()
                }
            }
            .task { await loadWorkouts() }
        }
    }

    // MARK: - Derived

    private var filteredWorkouts: [WorkoutDomain] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return workouts }
        let lower = trimmed.lowercased()
        return workouts.filter { workout in
            workout.name.lowercased().contains(lower) ||
            (workout.description?.lowercased().contains(lower) ?? false)
        }
    }

    // MARK: - Data

    @MainActor
    private func loadWorkouts() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            guard let user = try await userRepo.fetchUser() else {
                self.workouts = []
                self.errorMessage = "No current user."
                return
            }
            let result = try workoutRepo.fetchAll(for: Int64(user.id))
            self.workouts = result
        } catch {
            self.errorMessage = "Failed to load workouts: \(error.localizedDescription)"
        }
    }

    private func createWorkoutAndDefaultBlock() async {
        let trimmed = newWorkoutName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        do {
            let workoutId = try await workoutService.createWorkoutWithDefaultBlock(name: trimmed)
            await MainActor.run {
                isShowingAddPopup = false
                newWorkoutName = ""
                navigateToWorkoutId = workoutId
                shouldNavigateToDetail = true
            }
            // Refresh workouts to ensure the newly created one is present
            await loadWorkouts()
        } catch {
            print("[WorkoutView] Failed to create workout and default block: \(error)")
        }
    }
}


// Provide a stable id for ForEach
private extension WorkoutDomain {
    var _id: Int64 { id ?? -1 }
}

