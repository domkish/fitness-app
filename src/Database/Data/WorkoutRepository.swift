//
//  WorkoutRepository.swift
//  fitness-app
//
//  Created by Dominic Kish on 1/27/26.
//
import GRDB
import Foundation

final class WorkoutRepository {

    private let dbQueue: DatabaseQueue

    init(dbQueue: DatabaseQueue) {
        self.dbQueue = dbQueue
    }

    func fetchAll(for userId: Int64) throws -> [WorkoutDomain] {
        try dbQueue.read { db in
            // 1) Fetch workouts for user or system (userId = 0)
            let records = try WorkoutRecord
                .filter([userId, 0].contains(WorkoutRecord.Columns.userId))
                .filter(WorkoutRecord.Columns.deletedAt == nil)
                .order(WorkoutRecord.Columns.name.asc)
                .fetchAll(db)

            // 2) Map to domain (without tags by default)
            var domains = records.map { WorkoutDomain(from: $0) }

            // Build index lookup by workout id
            var indexById: [Int64: Int] = [:]
            for (i, rec) in records.enumerated() {
                if let id = rec.id { indexById[id] = i }
            }

            // 3) If no ids, return early
            let workoutIDs = records.compactMap { $0.id }
            guard !workoutIDs.isEmpty else { return domains }

            // 4) Optional: Fetch tags joined via pivot for these workouts
            // If your schema includes workout tags, adapt the SQL below to your actual table/column names
            // and uncomment to enrich `domains` with tags.
            /*
            let sql = """
            SELECT t.id AS t_id, t.name AS t_name, t.type AS t_type, t.created_at AS t_created, t.updated_at AS t_updated, p.workout_id AS p_workout_id
            FROM workout_tags t
            JOIN workout_tag_pivots p ON p.workout_tag_id = t.id
            WHERE p.workout_id IN (\(workoutIDs.map { _ in "?" }.joined(separator: ",")))
            """
            let rows = try Row.fetchAll(db, sql: sql, arguments: StatementArguments(workoutIDs))

            for row in rows {
                let wId: Int64 = row["p_workout_id"]
                let tag = WorkoutTagDomain(
                    id: row["t_id"],
                    name: row["t_name"],
                    type: row["t_type"],
                    createdAt: row["t_created"],
                    updatedAt: row["t_updated"]
                )
                if let idx = indexById[wId] {
                    domains[idx].tags.append(tag)
                }
            }
            */

            return domains
        }
    }

    func createOrUpdate(_ workout: WorkoutDomain) throws {
        try dbQueue.write { db in
            var record = WorkoutRecord(from: workout) // Domain → Record
            try record.insert(db, onConflict: .replace)
        }
    }

    @discardableResult
    func createOrUpdateReturningId(_ workout: WorkoutDomain) throws -> Int64 {
        try dbQueue.write { db in
            var record = WorkoutRecord(from: workout)
            try record.insert(db, onConflict: .replace)
            return record.id ?? Int64(db.lastInsertedRowID)
        }
    }

    func delete(_ workout: WorkoutDomain) throws {
        try dbQueue.write { db in
            if let id = workout.id {
                _ = try WorkoutRecord.deleteOne(db, key: id)
            }
        }
    }

    func delete(id: Int64) throws {
        try dbQueue.write { db in
            _ = try WorkoutRecord.deleteOne(db, key: id)
        }
    }

    func softDelete(id: Int64) throws {
        try dbQueue.write { db in
            // Load the record, set deletedAt, and save
            if var record = try WorkoutRecord.fetchOne(db, key: id) {
                record.deletedAt = Date()
                try record.update(db)
            }
        }
    }

    /// Fetch a workout and its blocks together
    /// Returns nil if the workout is not found
    func fetchWorkoutWithBlocks(id: Int64) throws -> (workout: WorkoutDomain, blocks: [WorkoutBlockDomain]) {
        try dbQueue.read { db in
            guard let workoutRecord = try WorkoutRecord.fetchOne(db, key: id) else {
                throw DatabaseError(message: "Workout not found")
            }
            let blocks = try WorkoutBlockRecord
                .filter(WorkoutBlockRecord.Columns.workoutId == id)
                .order(WorkoutBlockRecord.Columns.sortOrder.asc)
                .fetchAll(db)
                .map { WorkoutBlockDomain(from: $0) }
            return (WorkoutDomain(from: workoutRecord), blocks)
        }
    }

    /// Fetch all exercises attached to a workout block (many-to-many via workout_exercises)
    func fetchExercises(forBlockId blockId: Int64) throws -> [ExerciseDomain] {
        try dbQueue.read { db in
            // Join exercises through workout_exercises pivot and order by sort_order (NULLS LAST behavior approximated)
            let exerciseRecords = try ExerciseRecord
                .joining(required: ExerciseRecord
                    .belongsTo(WorkoutExerciseRecord.self,
                               using: ForeignKey([WorkoutExerciseRecord.Columns.exerciseId], to: [ExerciseRecord.Columns.id]))
                    .filter(WorkoutExerciseRecord.Columns.workoutBlockId == blockId)
                )
                .order(sql: "COALESCE(workout_exercises.sort_order, 2147483647) ASC")
                .order(ExerciseRecord.Columns.name.asc)
                .fetchAll(db)
            return exerciseRecords.map { ExerciseDomain(from: $0) }
        }
    }
}
