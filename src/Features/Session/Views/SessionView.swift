//
//  SessionView.swift
//  fitness-app
//
//  Created by Dominic Kish on 1/25/26.
//
import SwiftUI
import GRDB

struct SessionView: View {
    @ObservedObject var coordinator: AppShellCoordinator
    @EnvironmentObject var authCoordinator: AuthCoordinator
    @EnvironmentObject var themeManager: ThemeManager

    let session: SessionRecord
    let sessionRepo: SessionRepository

    @State private var sessionTree: [SessionBlockItem] = []
    @State private var isLoading = true
    @State private var showingCompleteAlert = false
    @State private var navigateToSummary = false

    var body: some View {
        ZStack {
            themeManager.currentTheme.background
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    HStack {
                        Text(session.workoutName)
                            .font(.title)
                            .bold()
                            .foregroundColor(themeManager.currentTheme.textDefault)
                        Spacer()
                        Button(action: { showingCompleteAlert = true }) {
                            HStack(spacing: 6) {
                                Image(systemName: "flag.checkered")
                                Text("Complete Workout").bold()
                            }
                            .padding(.vertical, 6)
                            .padding(.horizontal, 10)
                            .background(themeManager.currentTheme.primary)
                            .foregroundColor(themeManager.currentTheme.background)
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal)

                    Group {
                        if isLoading {
                            VStack {
                                ProgressView()
                            }
                            .frame(maxWidth: .infinity)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(themeManager.currentTheme.surface)
                            .cornerRadius(16)
                            .shadow(color: Color.black.opacity(0.05), radius: 10, y: 5)
                            .padding(.horizontal)
                        } else {
                            ForEach(sessionTree) { block in
                                BlockCardView(blockItem: block)
                                    .environmentObject(themeManager)
                                    .padding(.horizontal)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }
                .padding(.vertical)
            }

            NavigationLink(isActive: $navigateToSummary) {
                SessionSummaryView(coordinator: coordinator, session: session)
                    .environmentObject(themeManager)
                    .environmentObject(authCoordinator)
            } label: { EmptyView() }
            .hidden()
        }
        .onAppear(perform: loadSessionTree)
        .alert("Complete Workout?", isPresented: $showingCompleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Complete", role: .destructive) {
                Task { await completeWorkout() }
            }
        } message: {
            Text("Are you sure you want to complete this workout? You can review the summary afterward.")
        }
    }

    private func loadSessionTree() {
        isLoading = true
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let tree = try sessionRepo.fetchSessionTree(
                    calendarWorkoutId: session.calendarWorkoutId,
                    startedAt: session.startedAt ?? Date()
                )

                let mapped = tree.map { blockTuple in
                    SessionBlockItem(
                        block: blockTuple.block,
                        exercises: blockTuple.exercises.map { exTuple in
                            SessionExerciseItem(
                                exercise: exTuple.exercise,
                                sets: exTuple.sets.map { set in
                                    let prevSet = try? sessionRepo.fetchPreviousSet(
                                        for: set.sessionExerciseId,
                                        before: session.startedAt ?? Date()
                                    )
                                    return SessionSetItem(set: set, previousSet: prevSet)
                                }
                            )
                        }
                    )
                }

                DispatchQueue.main.async {
                    self.sessionTree = mapped
                    self.isLoading = false
                }
            } catch {
                print("Failed to load session tree: \(error)")
                DispatchQueue.main.async {
                    self.isLoading = false
                }
            }
        }
    }

    private func completeWorkout() async {
        do {
            // Compute total duration by summing all session exercise durations
            let exRepo = SessionExerciseRepository(dbQueue: DatabaseQueueProvider.shared.dbQueue)
            let blockRepo = SessionBlockRepository(dbQueue: DatabaseQueueProvider.shared.dbQueue)
            let sessRepo = sessionRepo

            // Fetch blocks and exercises tree
            let blocks = try blockRepo.bySession(session.id ?? -1)
            var total: Int = 0
            for b in blocks {
                // For each block, sum its exercise durations
                let exercises = try exRepo.bySessionBlock(b.id ?? -1)
                let sumForBlock = exercises.reduce(0) { $0 + ($1.duration) }
                total += sumForBlock
                // Update block duration to sum of its exercises
                try updateBlockDuration(blockId: b.id ?? -1, to: sumForBlock)
            }
            // Update session total duration and completedAt
            try updateSessionCompletion(totalDuration: total)

            // Navigate to summary
            await MainActor.run { navigateToSummary = true }
        } catch {
            print("[SessionView] completeWorkout error: \(error)")
        }
    }

    private func updateSessionCompletion(totalDuration: Int) throws {
        try sessionRepo.dbQueue.write { db in
            if var rec = try SessionRecord.fetchOne(db, key: session.id) {
                rec.totalDuration = totalDuration
                rec.completedAt = Date()
                rec.updatedAt = Date()
                try rec.update(db)
            }
        }
    }

    private func updateBlockDuration(blockId: Int64, to duration: Int) throws {
        try sessionRepo.dbQueue.write { db in
            if var rec = try SessionBlockRecord.fetchOne(db, key: blockId) {
                rec.duration = duration
                rec.updatedAt = Date()
                try rec.update(db)
            }
        }
    }
}

