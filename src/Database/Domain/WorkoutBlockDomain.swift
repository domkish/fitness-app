//
//  WorkoutBlockDomain.swift
//  fitness-app
//
//  Created by Dominic Kish on 1/27/26.
//
import Foundation

struct WorkoutBlockDomain: Identifiable, Codable, Equatable, Sendable {
    var id: Int64?
    var userId: Int64
    var workoutId: Int64
    var name: String
    var description: String?
    var difficulty: String?
    var sortOrder: Int
    var deletedAt: Date?
    var createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case workoutId = "workout_id"
        case name
        case description
        case difficulty
        case sortOrder = "sort_order"
        case deletedAt = "deleted_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(from record: WorkoutBlockRecord) {
        self.id = record.id
        self.userId = record.userId
        self.workoutId = record.workoutId
        self.name = record.name
        self.description = record.description
        self.difficulty = record.difficulty
        self.sortOrder = record.sortOrder
        self.deletedAt = record.deletedAt
        self.createdAt = record.createdAt
        self.updatedAt = record.updatedAt
    }
}

extension WorkoutBlockDomain {
    init(
        id: Int64? = nil,
        userId: Int64,
        workoutId: Int64,
        name: String,
        description: String? = nil,
        difficulty: String? = nil,
        sortOrder: Int,
        deletedAt: Date? = nil,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.userId = userId
        self.workoutId = workoutId
        self.name = name
        self.description = description
        self.difficulty = difficulty
        self.sortOrder = sortOrder
        self.deletedAt = deletedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

extension WorkoutBlockDomain { var _id: Int64 { id ?? -1 } }
