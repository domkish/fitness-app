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

    // MARK: - Blocks CRUD
    func fetchBlocks(forWorkoutId workoutId: Int64) throws -> [WorkoutBlockDomain] {
        try dbQueue.read { db in
            try WorkoutBlockRecord
                .filter(WorkoutBlockRecord.Columns.workoutId == workoutId)
                .order(WorkoutBlockRecord.Columns.sortOrder.asc)
                .fetchAll(db)
                .map { WorkoutBlockDomain(from: $0) }
        }
    }

    func createBlock(_ block: WorkoutBlockDomain) throws {
        try dbQueue.write { db in
            var rec = WorkoutBlockRecord(from: block)
            try rec.insert(db)
        }
    }

    func updateBlockName(blockId: Int64, to newName: String) throws {
        try dbQueue.write { db in
            if var rec = try WorkoutBlockRecord.fetchOne(db, key: blockId) {
                rec.name = newName
                rec.updatedAt = Date()
                try rec.update(db)
            }
        }
    }

    func updateBlockDescription(blockId: Int64, to newDescription: String?) throws {
        try dbQueue.write { db in
            if var rec = try WorkoutBlockRecord.fetchOne(db, key: blockId) {
                rec.description = (newDescription?.isEmpty == true) ? nil : newDescription
                rec.updatedAt = Date()
                try rec.update(db)
            }
        }
    }

    /// Deletes a workout block if it has no exercises attached
    func deleteBlockIfEmpty(blockId: Int64) throws -> Bool {
        try dbQueue.write { db in
            // Check for attached exercises
            let count: Int = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM workout_exercises WHERE workout_block_id = ? AND deleted_at IS NULL", arguments: [blockId]) ?? 0
            guard count == 0 else { return false }
            // Safe to delete the block
            _ = try WorkoutBlockRecord.deleteOne(db, key: blockId)
            return true
        }
    }

    // MARK: - Exercises in Blocks
    struct ExerciseInBlockRow: FetchableRecord, Decodable { let id: Int64; let exerciseId: Int64; let name: String; let blockId: Int64; let sortOrder: Int; let unit: String? }

    func fetchExercisesByBlock(forWorkoutId workoutId: Int64) throws -> [Int64: [ExerciseInBlockRow]] {
        try dbQueue.read { db in
            let sql = """
            SELECT we.id AS id,
                   we.exercise_id AS exerciseId,
                   e.name AS name,
                   we.workout_block_id AS blockId,
                   we.sort_order AS sortOrder,
                   we.unit AS unit
            FROM workout_exercises AS we
            JOIN exercises AS e ON e.id = we.exercise_id
            WHERE we.workout_id = ? AND we.deleted_at IS NULL AND e.deleted_at IS NULL
            ORDER BY we.workout_block_id ASC, we.sort_order ASC
            """
            let rows = try ExerciseInBlockRow.fetchAll(db, sql: sql, arguments: [workoutId])
            var grouped: [Int64: [ExerciseInBlockRow]] = [:]
            for r in rows { grouped[r.blockId, default: []].append(r) }
            for (k, var arr) in grouped { arr.sort { $0.sortOrder < $1.sortOrder }; grouped[k] = arr }
            return grouped
        }
    }

    func addExercise(toBlockId blockId: Int64, workoutId: Int64, exerciseId: Int64, userId: Int64) throws {
        try dbQueue.write { db in
            let nextOrder: Int = try Int.fetchOne(db, sql: "SELECT MAX(sort_order) FROM workout_exercises WHERE workout_block_id = ?", arguments: [blockId]) ?? 0
            var rec = WorkoutExerciseRecord(
                id: nil,
                workoutId: workoutId,
                workoutBlockId: blockId,
                exerciseId: exerciseId,
                userId: userId,
                unit: nil,
                sortOrder: nextOrder + 1,
                deletedAt: nil,
                createdAt: Date(),
                updatedAt: Date()
            )
            try rec.insert(db)
        }
    }

    func deleteExercises(ids: [Int64]) throws {
        guard !ids.isEmpty else { return }
        try dbQueue.write { db in
            let now = Date()
            var args = StatementArguments()
            args += [now]
            for id in ids { args += [id] }
            let placeholders = ids.map { _ in "?" }.joined(separator: ",")
            try db.execute(sql: "UPDATE workout_exercises SET deleted_at = ? WHERE id IN (\(placeholders))", arguments: args)
        }
    }

    func updateExerciseOrder(forBlockId blockId: Int64, items: [(order: Int, id: Int64)]) throws {
        try dbQueue.write { db in
            for (order, id) in items {
                try db.execute(sql: "UPDATE workout_exercises SET sort_order = ? WHERE id = ?", arguments: [order, id])
            }
        }
    }

    func updateWorkoutExerciseUnit(id workoutExerciseId: Int64, to unit: String?) throws {
        try dbQueue.write { db in
            try db.execute(sql: "UPDATE workout_exercises SET unit = ?, updated_at = ? WHERE id = ?", arguments: [unit, Date(), workoutExerciseId])
        }
    }

    // MARK: - Units lookup
    struct UnitAbbrevRow: FetchableRecord, Decodable { let exerciseId: Int64; let abbreviation: String }

    func loadUnitsForExercises(_ exerciseIds: [Int64]) throws -> [Int64: [String]] {
        guard !exerciseIds.isEmpty else { return [:] }
        return try dbQueue.read { db in
            let placeholders = exerciseIds.map { _ in "?" }.joined(separator: ",")
            let sql = """
            SELECT eup.exercise_id AS exerciseId,
                   u.abbreviation AS abbreviation
            FROM exercise_unit_pivots AS eup
            JOIN units AS u ON u.id = eup.unit_id
            WHERE eup.exercise_id IN (\(placeholders))
            ORDER BY CASE WHEN (SELECT is_imperial FROM users LIMIT 1) = 1 THEN (u.type = '1') ELSE (u.type = '0') END DESC, u.id ASC
            """
            let rows = try UnitAbbrevRow.fetchAll(db, sql: sql, arguments: StatementArguments(exerciseIds))
            var map: [Int64: [String]] = [:]
            for r in rows { map[r.exerciseId, default: []].append(r.abbreviation) }
            return map
        }
    }

    // MARK: - Workout load/save for Info screen
    func fetchWorkout(id: Int64) throws -> WorkoutRecord? {
        try dbQueue.read { db in
            try WorkoutRecord.fetchOne(db, key: id)
        }
    }

    func saveWorkout(id: Int64?, userId: Int64, name: String, description: String?) throws {
        try dbQueue.write { db in
            let now = Date()
            if let wid = id, var rec = try WorkoutRecord.fetchOne(db, key: wid) {
                rec.name = name
                rec.description = description
                rec.updatedAt = now
                try rec.update(db)
            } else {
                var rec = WorkoutRecord(
                    id: nil,
                    userId: userId,
                    name: name,
                    color: "primary",
                    description: description,
                    deletedAt: nil,
                    createdAt: now,
                    updatedAt: now
                )
                try rec.insert(db)
            }
        }
    }

    /// Clones a workout block and all its exercises into a new block
    func cloneBlock(blockId: Int64) throws {
        try dbQueue.write { db in
            // Load source block
            guard let src = try WorkoutBlockRecord.fetchOne(db, key: blockId) else { return }
            // Compute next sort order within the same workout
            let maxOrder: Int = try Int.fetchOne(db, sql: "SELECT MAX(sort_order) FROM workout_blocks WHERE workout_id = ?", arguments: [src.workoutId]) ?? 0
            let now = Date()
            // Create new block
            var newBlock = WorkoutBlockRecord(
                id: nil,
                userId: src.userId,
                workoutId: src.workoutId,
                name: src.name + " Copy",
                description: src.description,
                difficulty: src.difficulty,
                sortOrder: maxOrder + 1,
                deletedAt: nil,
                createdAt: now,
                updatedAt: now
            )
            try newBlock.insert(db)
            let newBlockId = newBlock.id ?? Int64(db.lastInsertedRowID)
            // Fetch exercises in source block
            struct SrcEx: FetchableRecord, Decodable { let id: Int64; let exerciseId: Int64; let sortOrder: Int; let unit: String? }
            let rows = try SrcEx.fetchAll(db, sql: "SELECT id, exercise_id AS exerciseId, sort_order AS sortOrder, unit FROM workout_exercises WHERE workout_block_id = ? AND deleted_at IS NULL ORDER BY sort_order ASC", arguments: [blockId])
            // Determine next sort order per insertion
            var order = 0
            for r in rows {
                order += 1
                var rec = WorkoutExerciseRecord(
                    id: nil,
                    workoutId: src.workoutId,
                    workoutBlockId: newBlockId,
                    exerciseId: r.exerciseId,
                    userId: src.userId,
                    unit: r.unit,
                    sortOrder: order,
                    deletedAt: nil,
                    createdAt: now,
                    updatedAt: now
                )
                try rec.insert(db)
            }
        }
    }
}

