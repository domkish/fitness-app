//
//  SessionComplete.swift
//  fitness-app
//
//  Created by Dominic Kish on 2/2/26.
//
import SwiftUI

struct SessionSummaryView: View {
    @ObservedObject var coordinator: AppShellCoordinator
    @EnvironmentObject var authCoordinator: AuthCoordinator
    @EnvironmentObject var themeManager: ThemeManager

    let session: SessionRecord
    let sessionRepo = SessionRepository(dbQueue: DatabaseQueueProvider.shared.dbQueue)

    @State private var sessionTree: [SessionBlockItem] = []
    @State private var isLoading = true

    var body: some View {
        ZStack {
            themeManager.currentTheme.background
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {

                    // Header
                    VStack(spacing: 8) {
                        Text(session.workoutName)
                            .font(.title)
                            .bold()
                            .foregroundColor(themeManager.currentTheme.textDefault)

                        if !isLoading {
                            Text("Total time: \(formattedTime(totalDuration))")
                                .font(.subheadline)
                                .foregroundColor(themeManager.currentTheme.secondary)
                        }
                    }
                    .foregroundColor(themeManager.currentTheme.textDefault)
                    .padding(.horizontal)

                    if isLoading {
                        ProgressView()
                            .padding()
                    } else {
                        ForEach(sessionTree) { block in
                            SummaryBlockCardView(
                                block: block
                            )
                            .padding(.horizontal)
                        }
                    }
                }
                .padding(.vertical)
            }
        }
        .onAppear(perform: loadSessionTree)
    }

    // MARK: - Helpers

    private var totalDuration: Int {
        sessionTree.reduce(0) { acc, block in
            acc + block.exercises.reduce(0) { $0 + $1.exercise.duration }
        }
    }

    private func formattedTime(_ seconds: Int) -> String {
        let hrs = seconds / 3600
        let mins = (seconds % 3600) / 60
        let secs = seconds % 60
        return String(format: "%02d:%02d:%02d", hrs, mins, secs)
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
                print("Failed to load summary tree: \(error)")
                DispatchQueue.main.async {
                    self.isLoading = false
                }
            }
        }
    }
}

