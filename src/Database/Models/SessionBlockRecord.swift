//
//  SessionBlockRecord.swift
//  fitness-app
//
//  Created by Dominic Kish on 2/1/26.
//
import Foundation
import GRDB

struct SessionBlockRecord: Codable, FetchableRecord, PersistableRecord, Identifiable {
    var id: Int64?
    var sessionId: Int64
    var workoutBlockId: Int64
    var duration: Int
    var deletedAt: Date?
    var createdAt: Date
    var updatedAt: Date

    static let databaseTableName = "session_blocks"
    
    enum CodingKeys: String, CodingKey {
        case id
        case sessionId = "session_id"
        case workoutBlockId = "workout_block_id"
        case duration
        case deletedAt = "deleted_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    // Columns enum for GRDB queries
    enum Columns {
        static let id = Column("id")
        static let sessionId = Column("session_id")
        static let workoutBlockId = Column("workout_block_id")
        static let duration = Column("duration")
        static let deletedAt = Column("deleted_at")
        static let createdAt = Column("created_at")
        static let updatedAt = Column("updated_at")
    }

    init(
        id: Int64? = nil,
        sessionId: Int64,
        workoutBlockId: Int64,
        duration: Int = 0,
        deletedAt: Date? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.sessionId = sessionId
        self.workoutBlockId = workoutBlockId
        self.duration = duration
        self.deletedAt = deletedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    init(from domain: SessionBlockDomain) {
        self.id = domain.id
        self.sessionId = domain.sessionId
        self.workoutBlockId = domain.workoutBlockId
        self.duration = domain.duration
        self.deletedAt = domain.deletedAt
        self.createdAt = domain.createdAt
        self.updatedAt = domain.updatedAt
    }

    func toDomain() -> SessionBlockDomain {
        SessionBlockDomain(
            id: id,
            sessionId: sessionId,
            workoutBlockId: workoutBlockId,
            duration: duration,
            deletedAt: deletedAt,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

