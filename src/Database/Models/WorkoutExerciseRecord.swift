//
//  WorkoutExerciseRecord.swift
//  SimplyFitness
//
//  Created by Assistant on 1/27/26.
//
import GRDB
import Foundation

struct WorkoutExerciseRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "workout_exercises"

    var id: Int64?
    var workoutId: Int64
    var workoutBlockId: Int64
    var exerciseId: Int64
    var userId: Int64
    var unit: String?
    var sortOrder: Int?
    var deletedAt: Date?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: Int64? = nil,
        workoutId: Int64,
        workoutBlockId: Int64,
        exerciseId: Int64,
        userId: Int64,
        unit: String? = nil,
        sortOrder: Int? = nil,
        deletedAt: Date? = nil,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.workoutId = workoutId
        self.workoutBlockId = workoutBlockId
        self.exerciseId = exerciseId
        self.userId = userId
        self.unit = unit
        self.sortOrder = sortOrder
        self.deletedAt = deletedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    init(from domain: WorkoutExerciseDomain) {
        self.id = domain.id
        self.workoutId = domain.workoutId
        self.workoutBlockId = domain.workoutBlockId
        self.exerciseId = domain.exerciseId
        self.userId = domain.userId
        self.unit = domain.unit
        self.sortOrder = domain.sortOrder
        self.deletedAt = domain.deletedAt
        self.createdAt = domain.createdAt
        self.updatedAt = domain.updatedAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case workoutId = "workout_id"
        case workoutBlockId = "workout_block_id"
        case exerciseId = "exercise_id"
        case userId = "user_id"
        case unit
        case sortOrder = "sort_order"
        case deletedAt = "deleted_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    enum Columns {
        static let id = Column("id")
        static let workoutId = Column("workout_id")
        static let workoutBlockId = Column("workout_block_id")
        static let exerciseId = Column("exercise_id")
        static let userId = Column("user_id")
        static let unit = Column("unit")
        static let sortOrder = Column("sort_order")
        static let deletedAt = Column("deleted_at")
        static let createdAt = Column("created_at")
        static let updatedAt = Column("updated_at")
    }
}

