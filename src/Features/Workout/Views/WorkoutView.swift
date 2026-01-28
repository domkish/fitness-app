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
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var isShowingAddPopup = false
    @State private var newWorkoutName: String = ""
    @State private var navigateToWorkoutId: Int64?
    @State private var shouldNavigateToDetail = false
    @State private var isPremiumUser: Bool = false

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
                        Text("Workout Routines")
                            .font(.title)
                            .bold()
                        Spacer()
                        Button {
                            let maxWorkouts = isPremiumUser ? 20 : 4
                            if workouts.count >= maxWorkouts {
                                // Provide lightweight feedback; you can replace with an alert if preferred
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            } else {
                                newWorkoutName = ""
                                isShowingAddPopup = true
                            }
                        } label: {
                            Image(systemName: "plus")
                                .font(.headline)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 12)
                                .background(AppColors.surface)
                                .cornerRadius(8)
                        }
                        .accessibilityLabel("Add Workout Routine")
                        .disabled(workouts.count >= (isPremiumUser ? 20 : 4))
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
                        } else if workouts.isEmpty {
                            VStack(spacing: 8) {
                                Image(systemName: "dumbbell.fill")
                                    .font(.system(size: 44))
                                    .foregroundColor(.secondary)
                                Text("No Workout Routines Yet")
                                    .font(.title3).bold()
                                Text("Tap + to add your first routine.")
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                        } else {
                            ScrollView {
                                VStack(spacing: 10) {
                                    ForEach(workouts, id: \._id) { workout in
                                        let c = colorForKey(workout.color)
                                        NavigationLink {
                                            WorkoutInfoView(workoutId: workout.id)
                                        } label: {
                                            VStack(alignment: .leading, spacing: 8) {
                                                HStack(spacing: 10) {
                                                    Circle()
                                                        .fill(c)
                                                        .frame(width: 14, height: 14)
                                                    Text(workout.name)
                                                        .font(.headline)
                                                        .foregroundColor(c)
                                                    Spacer()
                                                    Image(systemName: "chevron.right")
                                                        .foregroundColor(c)
                                                        .font(.headline)
                                                }
                                            }
                                            .padding(12)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .background(
                                                RoundedRectangle(cornerRadius: 0)
                                                    .fill(c.opacity(0.1))
                                            )
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 0)
                                                    .stroke(c.opacity(0.6), lineWidth: 1)
                                            )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.horizontal)
                                .padding(.vertical, 8)
                            }
                        }
                    }

                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                // Add Workout popup overlay
                if isShowingAddPopup {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .onTapGesture { withAnimation { isShowingAddPopup = false } }

                    VStack(spacing: 16) {
                        Text("New Workout Routine").font(.headline)
                        TextField("Routine name", text: $newWorkoutName)
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
            }
            .ignoresSafeArea(.keyboard, edges: .bottom)
            .task { await loadCurrentUserPremium(); await loadWorkouts() }
        }
    }

    // MARK: - Helpers

    private func colorForKey(_ key: String?) -> Color {
        switch key ?? "primary" {
        case "primary": return AppColors.primary
        case "secondary": return AppColors.secondary
        case "success": return AppColors.success
        case "warning": return AppColors.warning
        case "error": return AppColors.error
        case "important": return AppColors.important
        default: return AppColors.primary
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

    private func loadCurrentUserPremium() async {
        do {
            if let user = try await userRepo.fetchUser() {
                await MainActor.run { self.isPremiumUser = user.isPremium }
            }
        } catch {
            print("[WorkoutView] Failed to load current user premium: \(error)")
        }
    }
}


// Provide a stable id for ForEach
private extension WorkoutDomain {
    var _id: Int64 { id ?? -1 }
}

