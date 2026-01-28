//
//  ExerciseRepository.swift
//  fitness-app
//
//  Created by Dominic Kish on 1/26/26.
//
import GRDB
import Foundation

final class ExerciseRepository {

    private let dbQueue: DatabaseQueue

    init(dbQueue: DatabaseQueue) {
        self.dbQueue = dbQueue
    }

    func fetchAll(for userId: Int64) throws -> [ExerciseDomain] {
        try dbQueue.read { db in
            // 1) Fetch exercises for user or system (userId = 0)
            let records = try ExerciseRecord
                .filter([userId, 0].contains(ExerciseRecord.Columns.userId))
                .filter(ExerciseRecord.Columns.deletedAt == nil)
                .order(ExerciseRecord.Columns.name.asc)
                .fetchAll(db)

            // 2) Map to domain with empty tags
            var domains = records.map { ExerciseDomain(from: $0) }

            // Build index lookup by exercise id
            var indexById: [Int64: Int] = [:]
            for (i, rec) in records.enumerated() {
                if let id = rec.id { indexById[id] = i }
            }

            // 3) If no ids, return early
            let exerciseIDs = records.compactMap { $0.id }
            guard !exerciseIDs.isEmpty else { return domains }

            // 4) Fetch tags joined via pivot for these exercises
            let sql = """
            SELECT t.id AS t_id, t.name AS t_name, t.type AS t_type, t.created_at AS t_created, t.updated_at AS t_updated, p.exercise_id AS p_exercise_id
            FROM exercise_tags t
            JOIN exercise_tag_pivots p ON p.exercise_tag_id = t.id
            WHERE p.exercise_id IN (\(exerciseIDs.map { _ in "?" }.joined(separator: ",")))
            """
            let rows = try Row.fetchAll(db, sql: sql, arguments: StatementArguments(exerciseIDs))

            for row in rows {
                let exId: Int64 = row["p_exercise_id"]
                let tag = ExerciseTagDomain(
                    id: row["t_id"],
                    name: row["t_name"],
                    type: row["t_type"],
                    createdAt: row["t_created"],
                    updatedAt: row["t_updated"]
                )
                if let idx = indexById[exId] {
                    domains[idx].tags.append(tag)
                }
            }

            return domains
        }
    }

    func createOrUpdate(_ exercise: ExerciseDomain) throws {
        try dbQueue.write { db in
            var record = ExerciseRecord(from: exercise) // Domain → Record
            try record.insert(db, onConflict: .replace)
        }
    }

    func delete(_ exercise: ExerciseDomain) throws {
        try dbQueue.write { db in
            if let id = exercise.id {
                _ = try ExerciseRecord.deleteOne(db, key: id)
            }
        }
    }

    func delete(id: Int64) throws {
        try dbQueue.write { db in
            _ = try ExerciseRecord.deleteOne(db, key: id)
        }
    }

    func softDelete(id: Int64) throws {
        try dbQueue.write { db in
            // Load the record, set deletedAt, and save
            if var record = try ExerciseRecord.fetchOne(db, key: id) {
                record.deletedAt = Date()
                try record.update(db)
            }
        }
    }

    struct ExerciseIdNameRow: FetchableRecord, Decodable { let id: Int64; let name: String }
    func fetchAllIdName() throws -> [ExerciseIdNameRow] {
        try dbQueue.read { db in
            let sql = "SELECT id, name FROM exercises WHERE deleted_at IS NULL ORDER BY name ASC"
            return try ExerciseIdNameRow.fetchAll(db, sql: sql)
        }
    }
}

