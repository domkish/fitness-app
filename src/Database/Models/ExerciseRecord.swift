//
//  ExerciseRecord.swift
//  SimplyFitness
//
//  Created by Dominic Kish on 1/26/26.
//
import GRDB
import Foundation

struct ExerciseRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "exercises"
    
    var id: Int64?
    var userId: Int64
    var name: String
    var locked: Bool
    var deletedAt: Date?
    var createdAt: Date
    var updatedAt: Date
    
    init(
        id: Int64? = nil,
        userId: Int64,
        name: String,
        locked: Bool,
        deletedAt: Date? = nil,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.userId = userId
        self.name = name
        self.locked = locked
        self.deletedAt = deletedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name
        case locked
        case deletedAt = "deleted_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    // Domain → Record initializer
    init(from domain: ExerciseDomain) {
        self.id = domain.id
        self.userId = Int64(domain.userId)
        self.name = domain.name
        self.locked = domain.locked
        self.deletedAt = domain.deletedAt
        self.createdAt = domain.createdAt
        self.updatedAt = domain.updatedAt
    }

    // Columns enum for GRDB queries
    enum Columns {
        static let id = Column("id")
        static let userId = Column("user_id")
        static let name = Column("name")
        static let locked = Column("locked")
        static let deletedAt = Column("deleted_at")
        static let createdAt = Column("created_at")
        static let updatedAt = Column("updated_at")
    }
}

// MARK: - Many-to-Many Helpers

extension ExerciseRecord {

    private enum ExerciseRecordError: Error {
        case missingID
    }

    func tags(_ db: Database) throws -> [ExerciseTagRecord] {
        let exerciseID = try id ?? { throw ExerciseRecordError.missingID }()
        return try ExerciseTagRecord
            .joining(
                required: ExerciseTagRecord
                    .belongsTo(
                        ExerciseTagPivotRecord.self,
                        using: ForeignKey([ExerciseTagPivotRecord.Columns.exerciseTagId], to: [ExerciseTagRecord.Columns.id])
                    )
                    .filter(ExerciseTagPivotRecord.Columns.exerciseId == exerciseID)
            )
            .fetchAll(db)
    }

    func attachTag(_ tag: ExerciseTagRecord, db: Database) throws {
        let exerciseID = try id ?? { throw ExerciseRecordError.missingID }()
        guard let tagID = tag.id else { throw DatabaseError(message: "Tag must be persisted before attaching.") }

        let pivot = ExerciseTagPivotRecord(
            id: nil,
            exerciseId: exerciseID,
            exerciseTagId: tagID,
            createdAt: Date(),
            updatedAt: Date()
        )
        try pivot.insert(db)
    }

    func detachTag(_ tag: ExerciseTagRecord, db: Database) throws {
        let exerciseID = try id ?? { throw ExerciseRecordError.missingID }()
        guard let tagID = tag.id else { return } // Silently ignore or throw, your call

        try ExerciseTagPivotRecord
            .filter(ExerciseTagPivotRecord.Columns.exerciseId == exerciseID)
            .filter(ExerciseTagPivotRecord.Columns.exerciseTagId == tagID)
            .deleteAll(db)
    }
}

