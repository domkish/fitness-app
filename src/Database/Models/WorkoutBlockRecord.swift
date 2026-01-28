//
//  WorkoutBlockRecord.swift
//  fitness-app
//
//  Created by Dominic Kish on 1/27/26.
//
import GRDB
import Foundation

struct WorkoutBlockRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "workout_blocks"

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

    init(
        id: Int64? = nil,
        userId: Int64,
        workoutId: Int64,
        name: String,
        description: String? = nil,
        difficulty: String? = nil,
        sortOrder: Int = 0,
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

    init(from domain: WorkoutBlockDomain) {
        self.id = domain.id
        self.userId = domain.userId
        self.workoutId = domain.workoutId
        self.name = domain.name
        self.description = domain.description
        self.difficulty = domain.difficulty
        self.sortOrder = domain.sortOrder
        self.deletedAt = domain.deletedAt
        self.createdAt = domain.createdAt
        self.updatedAt = domain.updatedAt
    }

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

    // Columns enum for GRDB queries
    enum Columns {
        static let id = Column("id")
        static let userId = Column("user_id")
        static let workoutId = Column("workout_id")
        static let name = Column("name")
        static let description = Column("description")
        static let difficulty = Column("difficulty")
        static let sortOrder = Column("sort_order")
        static let deletedAt = Column("deleted_at")
        static let createdAt = Column("created_at")
        static let updatedAt = Column("updated_at")
    }
}
