//
//  ExerciseTagPivotRecord.swift
//  fitness-app
//
//  Created by Dominic Kish on 1/26/26.
//
import GRDB
import Foundation

struct ExerciseTagPivotRecord: Codable, FetchableRecord, PersistableRecord {
    var id: Int64?
    var exerciseId: Int64
    var exerciseTagId: Int64
    var createdAt: Date
    var updatedAt: Date

    // Domain initializer
    init(from domain: ExerciseTagPivotDomain) {
        self.id = domain.id
        self.exerciseId = Int64(domain.exerciseId)
        self.exerciseTagId = Int64(domain.exerciseTagId)
        self.createdAt = domain.createdAt
        self.updatedAt = domain.updatedAt
    }

    // Memberwise initializer for inserts
    init(id: Int64? = nil, exerciseId: Int64, exerciseTagId: Int64, createdAt: Date, updatedAt: Date) {
        self.id = id
        self.exerciseId = exerciseId
        self.exerciseTagId = exerciseTagId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    // ⚡ GRDB Columns enum
    enum Columns {
        static let id = Column("id")
        static let exerciseId = Column("exercise_id")
        static let exerciseTagId = Column("exercise_tag_id")
        static let createdAt = Column("created_at")
        static let updatedAt = Column("updated_at")
    }
}



