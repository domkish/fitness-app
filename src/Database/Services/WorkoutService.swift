//
//  WorkoutService.swift
//  fitness-app
//
//  Created by Dominic Kish on 1/27/26.
//
import Foundation
import GRDB

final class WorkoutService {
    private let dbQueue: DatabaseQueue
    private let workoutRepo: WorkoutRepository
    private let blockRepo: WorkoutBlockRepository
    private let userRepo: UserRepository

    init(dbQueue: DatabaseQueue) {
        self.dbQueue = dbQueue
        self.workoutRepo = WorkoutRepository(dbQueue: dbQueue)
        self.blockRepo = WorkoutBlockRepository(dbQueue: dbQueue)
        self.userRepo = UserRepository(dbQueue: dbQueue)
    }

    /// Creates a workout for the current user and a default first block ("Block 1" with sort_order = 1).
    /// - Parameter name: The workout name.
    /// - Returns: The created workout id.
    @discardableResult
    func createWorkoutWithDefaultBlock(name: String) async throws -> Int64 {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        precondition(!trimmed.isEmpty, "Workout name must not be empty")

        guard let user = try await userRepo.fetchUser() else {
            throw NSError(domain: "WorkoutService", code: 1, userInfo: [NSLocalizedDescriptionKey: "No current user."])
        }
        let now = Date()

        let availableColors = ["primary", "secondary", "success", "warning", "error", "important"]
        let randomColor = availableColors.randomElement() ?? "primary"

        // Create workout
        let workout = WorkoutDomain(
            id: nil,
            userId: user.id,
            name: trimmed,
            color: randomColor,
            description: nil,
            deletedAt: nil,
            createdAt: now,
            updatedAt: now
        )
        let workoutId = try workoutRepo.createOrUpdateReturningId(workout)

        // Create default block (sortOrder 1, name "Block 1")
        let block = WorkoutBlockDomain(
            id: nil,
            userId: Int64(user.id),
            workoutId: workoutId,
            name: "Block 1",
            description: nil,
            difficulty: nil,
            sortOrder: 1,
            deletedAt: nil,
            createdAt: now,
            updatedAt: now
        )
        _ = try blockRepo.createOrUpdate(block)

        return workoutId
    }
}

