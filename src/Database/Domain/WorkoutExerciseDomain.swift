//
//  WorkoutExerciseDomain.swift
//  SimplyFitness
//
//  Created by Assistant on 1/27/26.
//
import Foundation

struct WorkoutExerciseDomain: Identifiable, Codable, Equatable, Sendable {
    var id: Int64?
    var userId: Int64
    var workoutId: Int64
    var workoutBlockId: Int64
    var exerciseId: Int64
    var unit: String?
    var sortOrder: Int?
    var deletedAt: Date?
    var createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case workoutId = "workout_id"
        case workoutBlockId = "workout_block_id"
        case exerciseId = "exercise_id"
        case unit
        case sortOrder = "sort_order"
        case deletedAt = "deleted_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(from record: WorkoutExerciseRecord) {
        self.id = record.id
        self.userId = record.userId
        self.workoutId = record.workoutId
        self.workoutBlockId = record.workoutBlockId
        self.exerciseId = record.exerciseId
        self.unit = record.unit
        self.sortOrder = record.sortOrder
        self.deletedAt = record.deletedAt
        self.createdAt = record.createdAt
        self.updatedAt = record.updatedAt
    }
}
