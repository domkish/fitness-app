//
//  SessionRecord.swift
//  fitness-app
//
//  Created by Dominic Kish on 2/1/26.
//
import Foundation
import GRDB

struct SessionRecord: Codable, FetchableRecord, PersistableRecord, Identifiable {
    var id: Int64?
    var userId: Int64
    var workoutId: Int64
    var calendarWorkoutId: Int64
    var workoutName: String
    var description: String?
    var totalDuration: Int
    var startedAt: Date?
    var completedAt: Date?
    var deletedAt: Date?
    var createdAt: Date
    var updatedAt: Date

    static let databaseTableName = "sessions"
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case workoutId = "workout_id"
        case calendarWorkoutId = "calendar_workout_id"
        case workoutName = "workout_name"
        case description = "description"
        case totalDuration = "total_duration"
        case startedAt = "started_at"
        case completedAt = "completed_at"
        case deletedAt = "deleted_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    // Columns enum for GRDB queries
    enum Columns {
        static let id = Column("id")
        static let userId = Column("user_id")
        static let workoutId = Column("workout_id")
        static let calendarWorkoutId = Column("calendar_workout_id")
        static let workoutName = Column("workout_name")
        static let description = Column("description")
        static let totalDuration = Column("total_duration")
        static let startedAt = Column("started_at")
        static let completedAt = Column("completed_at")
        static let deletedAt = Column("deleted_at")
        static let createdAt = Column("created_at")
        static let updatedAt = Column("updated_at")
    }

    mutating func willInsert(_ db: Database) throws {
        let now = Date()
        createdAt = now
        updatedAt = now
    }

    mutating func willUpdate(_ db: Database, columns: Set<String>) throws {
        updatedAt = Date()
    }

    init(from domain: SessionDomain) {
        self.id = domain.id
        self.userId = domain.userId
        self.workoutId = domain.workoutId
        self.calendarWorkoutId = domain.calendarWorkoutId
        self.workoutName = domain.workoutName
        self.description = domain.description
        self.totalDuration = domain.totalDuration
        self.startedAt = domain.startedAt
        self.completedAt = domain.completedAt
        self.deletedAt = domain.deletedAt
        self.createdAt = domain.createdAt
        self.updatedAt = domain.updatedAt
    }

    func toDomain() -> SessionDomain {
        SessionDomain(
            id: id,
            userId: userId,
            workoutId: workoutId,
            calendarWorkoutId: calendarWorkoutId,
            workoutName: workoutName,
            description: description,
            totalDuration: totalDuration,
            startedAt: startedAt,
            completedAt: completedAt,
            deletedAt: deletedAt,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}
extension SessionRecord {
    init(
        id: Int64? = nil,
        userId: Int64,
        workoutId: Int64,
        calendarWorkoutId: Int64,
        workoutName: String,
        description: String? = nil,
        totalDuration: Int = 0,
        startedAt: Date? = nil,
        completedAt: Date? = nil,
        deletedAt: Date? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.workoutId = workoutId
        self.calendarWorkoutId = calendarWorkoutId
        self.workoutName = workoutName
        self.description = description
        self.totalDuration = totalDuration
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.deletedAt = deletedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

