//
//  TaskView.swift
//  fitness-app
//
//  Created by Dominic Kish on 1/25/26.
//

import SwiftUI
import GRDB

struct WorkoutView: View {
    @ObservedObject var coordinator: AppShellCoordinator
    @EnvironmentObject var authCoordinator: AuthCoordinator
    @EnvironmentObject var themeManager: ThemeManager

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
    @State private var showLimitPopover: Bool = false
    @State private var showPremium: Bool = false

    private enum TopSegment: Hashable { case routines, exercises }
    @State private var topSegmentSelection: TopSegment = .routines

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
                themeManager.currentTheme.background
                    .ignoresSafeArea()
                
                VStack(spacing: 15) {
                    // Top segmented navigation between Routines and Exercises (custom segmented control)
                    HStack(spacing: 6) {
                        let isRoutines = (topSegmentSelection == .routines)
                        Button {
                            topSegmentSelection = .routines
                            coordinator.currentStep = .workout
                        } label: {
                            Text("Routines")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(isRoutines ? themeManager.currentTheme.background : themeManager.currentTheme.textDefault)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(isRoutines ? themeManager.currentTheme.primary : themeManager.currentTheme.surface)
                                )
                        }

                        Button {
                            topSegmentSelection = .exercises
                            coordinator.currentStep = .exercise
                        } label: {
                            Text("Exercises")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(!isRoutines ? themeManager.currentTheme.background : themeManager.currentTheme.textDefault)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(!isRoutines ? themeManager.currentTheme.primary : themeManager.currentTheme.surface)
                                )
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 15)
                    .onAppear {
                        // Initialize from coordinator on first appear
                        topSegmentSelection = (coordinator.currentStep == .exercise) ? .exercises : .routines
                    }
                    
                    HStack {
                        Text("Workout Routines")
                            .font(.title)
                            .bold()
                            .foregroundColor(themeManager.currentTheme.textDefault)
                        Spacer()
                        Button {
                            let maxWorkouts = isPremiumUser ? 20 : 4
                            if workouts.count >= maxWorkouts {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                showLimitPopover = true
                            } else {
                                newWorkoutName = ""
                                isShowingAddPopup = true
                            }
                        } label: {
                            Image(systemName: "plus")
                                .font(.headline)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 12)
                                .background(themeManager.currentTheme.surface)
                                .foregroundColor(showLimitPopover ? themeManager.currentTheme.muted : themeManager.currentTheme.primary)
                                .cornerRadius(8)
                        }
                        .accessibilityLabel("Add Workout Routine")
                        .popover(isPresented: $showLimitPopover) {
                            VStack(alignment: .leading, spacing: 16) {
                                if isPremiumUser {
                                    Text("You have hit the max number of workout routines allowed. Please clean up your current list to add more.")
                                        .foregroundColor(themeManager.currentTheme.textDefault)
                                        .fixedSize(horizontal: false, vertical: true)
                                } else {
                                    Text("You have hit the max number of workout routines allowed. Sign up for Premium to gain access up to 20 Workouts!.")
                                        .foregroundColor(themeManager.currentTheme.textDefault)
                                        .fixedSize(horizontal: false, vertical: true)
                                    HStack {
                                        Spacer()
                                        Button("View Premium") {
                                            showLimitPopover = false
                                            showPremium = true
                                        }
                                        .buttonStyle(.borderedProminent)
                                    }
                                }
                            }
                            .padding()
                            .frame(maxWidth: 360)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Hidden navigation link to push detail after creation
                    NavigationLink(
                        isActive: $shouldNavigateToDetail,
                        destination: {
                            if let id = navigateToWorkoutId {
                                WorkoutInfoView(workoutId: id)
                                    .environmentObject(themeManager)
                            } else {
                                // Return a concrete placeholder view to satisfy ViewBuilder
                                Text("Loading…").hidden()
                            }
                        },
                        label: { EmptyView() }
                    )
                    .hidden()
                    .background(EmptyView())

                    .navigationDestination(isPresented: $showPremium) {
                        PremiumView(coordinator: coordinator)
                            .environmentObject(authCoordinator)
                    }

                    // Table container styled like ExerciseView
                    ScrollView {
                        VStack() {
                            if isLoading {
                                HStack { Spacer(); ProgressView(); Spacer() }
                                    .padding()
                            } else if let errorMessage = errorMessage {
                                VStack(spacing: 12) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.orange)
                                        .imageScale(.large)
                                    Text(errorMessage)
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal)
                                        .foregroundColor(themeManager.currentTheme.textDefault)
                                    Button("Retry") { Task { await loadWorkouts() } }
                                        .buttonStyle(.bordered)
                                }
                                .padding()
                            } else if workouts.isEmpty {
                                VStack(spacing: 8) {
                                    Image(systemName: "dumbbell.fill")
                                        .font(.system(size: 44))
                                        .foregroundColor(themeManager.currentTheme.textDefault)
                                    Text("No Workout Routines Yet")
                                        .font(.title3).bold()
                                        .foregroundColor(themeManager.currentTheme.textDefault)
                                    Text("Tap + to add your first routine.")
                                        .foregroundColor(themeManager.currentTheme.muted)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                
                                // Dashed separator
                                Capsule()
                                    .stroke(style: StrokeStyle(lineWidth: 4, dash: [6, 4]))
                                    .foregroundColor(themeManager.currentTheme.borderDefault)
                                    .frame(height: 1)
                                    .padding(.horizontal)
                                    .padding(.top, 28)

                                // Info section
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                                        Text("About Workout Routines")
                                            .font(.title3)
                                            .bold()
                                            .foregroundColor(themeManager.currentTheme.textDefault)
                                    }
                            
                                    Text("Workout routines are fully customizable so you can build the perfect plan for your goals. Once you create a routine, it’ll be available to add to your workout calendar whenever you’re ready.")
                                        .font(.callout)
                                        .foregroundColor(themeManager.currentTheme.muted)
                                        .fixedSize(horizontal: false, vertical: true)
                                    
                                    (
                                        Text("Whether you’re setting up a standard workout with ") +
                                        Text("sets and reps ").fontWeight(.heavy) +
                                        Text("or dialing in fast-paced ") +
                                        Text("circuit training").fontWeight(.heavy) +
                                        Text(", we’ve got you covered. Mix and match exercises from our database or create your own to tailor every routine to you.")
                                    )
                                    .font(.callout)
                                    .foregroundColor(themeManager.currentTheme.muted)
                                    .fixedSize(horizontal: false, vertical: true)
                            
                                    HStack(alignment: .center, spacing: 10) {
                                        Image(systemName: "plus.circle.fill")
                                            .foregroundColor(themeManager.currentTheme.primary)
                                        Text("Tap the \"+\" above to create a routine — name it anything you like!")
                                            .font(.callout)
                                            .foregroundColor(themeManager.currentTheme.muted)
                                    }
                                }
                                .padding(16)
                                .padding(.top, 6)
                            } else {
                                VStack(spacing: 10) {
                                    ForEach(workouts, id: \._id) { workout in
                                        let c = colorForKey(workout.color)
                                        NavigationLink {
                                            WorkoutInfoView(workoutId: workout.id)
                                                .environmentObject(themeManager)
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
                                                RoundedRectangle(cornerRadius: 6)
                                                    .fill(c.opacity(0.1))
                                            )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.horizontal)
                                .padding(.vertical, 8)
                                
                                
                                
                                // Dashed separator
                                Capsule()
                                    .stroke(style: StrokeStyle(lineWidth: 4, dash: [6, 4]))
                                    .foregroundColor(themeManager.currentTheme.borderDefault)
                                    .frame(height: 1)
                                    .padding(.horizontal)
                                    .padding(.top, 28)
                                Button {
                                    coordinator.currentStep = .calendar
                                } label: {
                                    HStack {
                                        Text("Go to Calendar")
                                            .foregroundColor(themeManager.currentTheme.textDefault)
                                    }
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 12)
                                    .background(themeManager.currentTheme.surface)
                                    .cornerRadius(8)
                                }
                                .padding(16)
                                .padding(.top, 6)
                                Text("You can add your workout routines to your calendar to track your progress and stay motivated!")
                                    .font(.callout)
                                    .foregroundColor(themeManager.currentTheme.muted)
                                    .fixedSize(horizontal: false, vertical: true)
                            }

                            
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                    }
                    
                    Spacer()
                }
                
                // Add Workout popup overlay
                if isShowingAddPopup {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .onTapGesture { isShowingAddPopup = false }

                    VStack(spacing: 16) {
                        Text("New Routine")
                            .font(.title3)
                            .bold()
                            .foregroundColor(themeManager.currentTheme.textDefault)

                        TextField("", text: $newWorkoutName)
                            .themedPlaceholder("Routine name", when: newWorkoutName.isEmpty, color: themeManager.currentTheme.muted)
                            .padding(12)
                            .background(themeManager.currentTheme.surface)
                            .foregroundColor(themeManager.currentTheme.textDefault)
                            .cornerRadius(8)
                            .submitLabel(.done)
                            .onSubmit {
                                Task { await createWorkoutAndDefaultBlock() }
                            }

                        HStack(spacing: 16) {
                            Button {
                                isShowingAddPopup = false
                                newWorkoutName = ""
                            } label: {
                                Text("Cancel")
                                    .font(.headline)
                                    .foregroundColor(themeManager.currentTheme.primary)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(themeManager.currentTheme.surface)
                                    .cornerRadius(8)
                            }

                            Button {
                                Task { await createWorkoutAndDefaultBlock() }
                            } label: {
                                Text("Create")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .foregroundColor(Color.white)
                                    .background(newWorkoutName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? themeManager.currentTheme.primary.opacity(0.5) : themeManager.currentTheme.primary)
                                    .cornerRadius(8)
                            }
                            .disabled(newWorkoutName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                    .padding(24)
                    .background(themeManager.currentTheme.background)
                    .cornerRadius(16)
                    .padding(.horizontal, 40)
                    .shadow(radius: 20)
                }
            }
            .task {
                await loadWorkouts()
                await loadCurrentUserPremium()
            }
        }
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

