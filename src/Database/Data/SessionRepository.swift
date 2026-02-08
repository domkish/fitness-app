//
//  SessionRepository.swift
//  fitness-app
//
//  Created by Dominic Kish on 2/1/26.
//
import Foundation
import GRDB

struct SessionRepository {
    let dbQueue: DatabaseQueue

    // Fetch a session by unique key (calendar_workout_id + started_at)
    func find(calendarWorkoutId: Int64, startedAt: Date) throws -> SessionRecord? {
        let started: Date = startedAt
        return try dbQueue.read { db in
            try SessionRecord
                .filter(SessionRecord.Columns.calendarWorkoutId == calendarWorkoutId)
                .filter(SessionRecord.Columns.startedAt == started)
                .filter(SessionRecord.Columns.deletedAt == nil)
                .fetchOne(db)
        }
    }

    // Create a new session snapshot
    func createSession(userId: Int64, workoutId: Int64, calendarWorkoutId: Int64, workoutName: String, startedAt: Date, createdAt: Date = Date()) throws -> Int64 {
        let rec = SessionRecord(
            id: nil,
            userId: userId,
            workoutId: workoutId,
            calendarWorkoutId: calendarWorkoutId,
            workoutName: workoutName,
            totalDuration: 0,
            startedAt: startedAt,
            completedAt: nil,
            deletedAt: nil,
            createdAt: createdAt,
            updatedAt: Date()
        )
        return try dbQueue.write { db in
            try rec.insert(db)
            return rec.id ?? Int64(db.lastInsertedRowID)
        }
    }

    // Ensure a session exists (idempotent) and return it
    func ensureSession(userId: Int64, workoutId: Int64, calendarWorkoutId: Int64, workoutName: String, startedAt: Date) throws -> SessionRecord {
        if let existing = try find(calendarWorkoutId: calendarWorkoutId, startedAt: startedAt) {
            return existing
        }
        let _ = try createSession(userId: userId, workoutId: workoutId, calendarWorkoutId: calendarWorkoutId, workoutName: workoutName, startedAt: startedAt)
        return try find(calendarWorkoutId: calendarWorkoutId, startedAt: startedAt)!
    }

    // Seed a newly created session with exercises/sets from the current workout definition
    func ensureSessionWithSeed(
        userId: Int64,
        workoutId: Int64,
        calendarWorkoutId: Int64,
        workoutName: String,
        startedAt: Date,
        createdAt: Date = Date(),
        workoutRepo: WorkoutRepository
    ) throws -> SessionRecord {
        if let existing = try find(calendarWorkoutId: calendarWorkoutId, startedAt: startedAt) {
            return existing
        }
        // Create session first
        let sessionId = try createSession(userId: userId, workoutId: workoutId, calendarWorkoutId: calendarWorkoutId, workoutName: workoutName, startedAt: startedAt, createdAt: createdAt)
        // Load workout blocks and exercises
        let blocks = try workoutRepo.fetchBlocks(forWorkoutId: workoutId).filter { $0.deletedAt == nil }
        let blockRepo = SessionBlockRepository(dbQueue: dbQueue)
        let exRepo = SessionExerciseRepository(dbQueue: dbQueue)
        let setRepo = SessionSetRepository(dbQueue: dbQueue)

        // For each block, create session blocks, session exercises, and default sets (1 set each by default)
        for block in blocks.sorted(by: { $0.sortOrder < $1.sortOrder }) {
            // Create a session block row
            var sBlock = SessionBlockRecord(
                id: nil,
                sessionId: sessionId,
                workoutBlockId: block.id ?? -1,
                duration: 0,
                deletedAt: nil,
                createdAt: Date(),
                updatedAt: Date()
            )
            let sessionBlockId = try blockRepo.create(&sBlock)

            // Fetch exercises for this block
            let exRows = try workoutRepo.fetchExercisesByBlock(forWorkoutId: workoutId)[block.id ?? -1] ?? []
            var orderCounter = 1
            for ex in exRows.sorted(by: { $0.sortOrder < $1.sortOrder }) {
                var sEx = SessionExerciseRecord(
                    id: nil,
                    sessionBlockId: sessionBlockId,
                    exerciseId: ex.exerciseId,
                    exerciseName: ex.name,
                    note: nil,
                    unit: ex.unit,
                    order: orderCounter,
                    duration: 0,
                    deletedAt: nil,
                    createdAt: Date(),
                    updatedAt: Date()
                )
                let sessionExerciseId = try exRepo.create(&sEx)
                // Seed a single default set
                let unitLower = (ex.unit ?? "").lowercased()
                let initialCompleted = (unitLower == "none") ? 1 : 0
                var sSet = SessionSetRecord(
                    id: nil,
                    sessionExerciseId: sessionExerciseId,
                    setNumber: 1,
                    completedReps: nil,
                    value: nil,
                    unit: ex.unit,
                    completed: initialCompleted,
                    deletedAt: nil,
                    createdAt: Date(),
                    updatedAt: Date()
                )
                _ = try setRepo.create(&sSet)
                orderCounter += 1
            }
        }

        // Return the created session
        return try find(calendarWorkoutId: calendarWorkoutId, startedAt: startedAt)!
    }

    // Fetch full session tree: session with blocks, exercises and sets
    func fetchSessionTree(calendarWorkoutId: Int64, startedAt: Date) throws -> [(block: SessionBlockRecord, exercises: [(exercise: SessionExerciseRecord, sets: [SessionSetRecord])])] {
        // First, find the session
        guard let session = try find(calendarWorkoutId: calendarWorkoutId, startedAt: startedAt) else {
            return [] // or throw an error
        }

        let blockRepo = SessionBlockRepository(dbQueue: dbQueue)
        let exRepo = SessionExerciseRepository(dbQueue: dbQueue)
        let setRepo = SessionSetRepository(dbQueue: dbQueue)

        // Fetch full tree using session.id
        let blocksTree = try blockRepo.fetchTree(sessionId: session.id ?? -1, exRepo: exRepo, setRepo: setRepo)

        return blocksTree
    }

    /// Fetch the most recent set for a session exercise that occurred before a given date
    func fetchPreviousSet(for sessionExerciseId: Int64, before date: Date) throws -> SessionSetRecord? {
        return try dbQueue.read { db in
            try SessionSetRecord
                .filter(SessionSetRecord.Columns.sessionExerciseId == sessionExerciseId)
                .filter(SessionSetRecord.Columns.deletedAt == nil)
                .filter(SessionSetRecord.Columns.createdAt < date)
                .order(SessionSetRecord.Columns.createdAt.desc)
                .fetchOne(db)
        }
    }
    
    /// Soft-delete a single session (and its blocks/exercises/sets) for a calendar workout on a specific day
    func deleteSessionTree(calendarWorkoutId: Int64, on date: Date) throws {
        let day = Calendar.current.startOfDay(for: date)
        try dbQueue.write { db in
            // Find the session for that day
            if var session = try SessionRecord
                .filter(SessionRecord.Columns.calendarWorkoutId == calendarWorkoutId)
                .filter(SessionRecord.Columns.startedAt == day)
                .filter(SessionRecord.Columns.deletedAt == nil)
                .fetchOne(db) {

                let blockRepo = SessionBlockRepository(dbQueue: dbQueue)
                let exRepo = SessionExerciseRepository(dbQueue: dbQueue)
                let setRepo = SessionSetRepository(dbQueue: dbQueue)
                // Delete sets, exercises, and blocks
                let blocks = try blockRepo.bySession(session.id ?? -1)
                for b in blocks {
                    let exercises = try exRepo.bySessionBlock(b.id ?? -1)
                    for e in exercises {
                        // Soft delete sets
                        var sets = try setRepo.bySessionExercise(e.id ?? -1)
                        for i in 0..<sets.count {
                            sets[i].deletedAt = Date()
                            sets[i].updatedAt = Date()
                            try sets[i].update(db)
                        }
                        // Soft delete exercise
                        var ex = e
                        ex.deletedAt = Date()
                        ex.updatedAt = Date()
                        try ex.update(db)
                    }
                    // Soft delete block
                    var blk = b
                    blk.deletedAt = Date()
                    blk.updatedAt = Date()
                    try blk.update(db)
                }

                // Soft delete session
                session.deletedAt = Date()
                session.updatedAt = Date()
                try session.update(db)
            }
        }
    }

    /// Soft-delete all sessions (and their trees) for a calendar workout on or after a given day
    func deleteSessionsOnOrAfter(calendarWorkoutId: Int64, from date: Date) throws {
        let startDay = Calendar.current.startOfDay(for: date)
        try dbQueue.write { db in
            let sessions = try SessionRecord
                .filter(SessionRecord.Columns.calendarWorkoutId == calendarWorkoutId)
                .filter(SessionRecord.Columns.startedAt >= startDay)
                .filter(SessionRecord.Columns.deletedAt == nil)
                .fetchAll(db)

            let blockRepo = SessionBlockRepository(dbQueue: dbQueue)
            let exRepo = SessionExerciseRepository(dbQueue: dbQueue)
            let setRepo = SessionSetRepository(dbQueue: dbQueue)

            for var session in sessions {
                let blocks = try blockRepo.bySession(session.id ?? -1)
                for b in blocks {
                    let exercises = try exRepo.bySessionBlock(b.id ?? -1)
                    for e in exercises {
                        var sets = try setRepo.bySessionExercise(e.id ?? -1)
                        for i in 0..<sets.count {
                            sets[i].deletedAt = Date()
                            sets[i].updatedAt = Date()
                            try sets[i].update(db)
                        }
                        var ex = e
                        ex.deletedAt = Date()
                        ex.updatedAt = Date()
                        try ex.update(db)
                    }
                    var blk = b
                    blk.deletedAt = Date()
                    blk.updatedAt = Date()
                    try blk.update(db)
                }
                session.deletedAt = Date()
                session.updatedAt = Date()
                try session.update(db)
            }
        }
    }

    // MARK: - Dashboard Aggregates
    /// Computes aggregates for weight (lbs), distance (miles), and duration (seconds) over an optional date range, scoped to a user.
    func loadAggregates(userId: Int64, start: Date?, end: Date?) throws -> (weightLbs: Double, distanceMiles: Double, durationSec: Double) {
        try dbQueue.read { db in
            // Build dynamic date window predicates and arguments
            var dateWhere = ""
            var dateArgs = StatementArguments()
            if let start = start {
                dateWhere += " AND (COALESCE(sessions.started_at, sessions.started_at) >= ?)"
                dateArgs += [start]
            }
            if let end = end {
                dateWhere += " AND (COALESCE(sessions.started_at, sessions.started_at) <= ?)"
                dateArgs += [end]
            }

            // Weight (lbs)
            let weightSQL = """
                SELECT COALESCE(SUM(
                    CASE LOWER(session_exercises.unit)
                        WHEN 'lbs' THEN (CASE WHEN session_sets.completed_reps IS NULL OR session_sets.completed_reps < 2 THEN 1 ELSE session_sets.completed_reps END) * session_sets.value
                        WHEN 'kg' THEN (CASE WHEN session_sets.completed_reps IS NULL OR session_sets.completed_reps < 2 THEN 1 ELSE session_sets.completed_reps END) * session_sets.value * 2.2046226218
                        ELSE 0
                    END
                ), 0)
                FROM session_sets
                JOIN session_exercises ON session_exercises.id = session_sets.session_exercise_id AND session_exercises.deleted_at IS NULL
                JOIN session_blocks ON session_blocks.id = session_exercises.session_block_id AND session_blocks.deleted_at IS NULL
                JOIN sessions ON sessions.id = session_blocks.session_id AND sessions.deleted_at IS NULL
                WHERE sessions.user_id = ?
                  AND session_sets.deleted_at IS NULL
                  AND session_sets.completed = 1
                  AND session_exercises.completed = 1
                  AND (sessions.completed_at IS NOT NULL OR session_sets.created_at IS NOT NULL)
            """ + dateWhere
            var weightArgs = StatementArguments()
            weightArgs += [userId]
            weightArgs += dateArgs
            let weight = try Double.fetchOne(db, sql: weightSQL, arguments: weightArgs) ?? 0

            // Distance (miles)
            let distanceSQL = """
                SELECT COALESCE(SUM(
                    CASE LOWER(session_exercises.unit)
                        WHEN 'mi' THEN (CASE WHEN session_sets.completed_reps IS NULL OR session_sets.completed_reps < 2 THEN 1 ELSE session_sets.completed_reps END) * session_sets.value
                        WHEN 'yd' THEN ((CASE WHEN session_sets.completed_reps IS NULL OR session_sets.completed_reps < 2 THEN 1 ELSE session_sets.completed_reps END) * session_sets.value) / 1760.0
                        WHEN 'm' THEN ((CASE WHEN session_sets.completed_reps IS NULL OR session_sets.completed_reps < 2 THEN 1 ELSE session_sets.completed_reps END) * session_sets.value) / 1609.344
                        WHEN 'km' THEN ((CASE WHEN session_sets.completed_reps IS NULL OR session_sets.completed_reps < 2 THEN 1 ELSE session_sets.completed_reps END) * session_sets.value) / 1.609344
                        ELSE 0
                    END
                ), 0)
                FROM session_sets
                JOIN session_exercises ON session_exercises.id = session_sets.session_exercise_id AND session_exercises.deleted_at IS NULL
                JOIN session_blocks ON session_blocks.id = session_exercises.session_block_id AND session_blocks.deleted_at IS NULL
                JOIN sessions ON sessions.id = session_blocks.session_id AND sessions.deleted_at IS NULL
                WHERE sessions.user_id = ?
                  AND session_sets.deleted_at IS NULL
                  AND session_sets.completed = 1
                  AND session_exercises.completed = 1
                  AND (sessions.completed_at IS NOT NULL OR session_sets.created_at IS NOT NULL)
            """ + dateWhere
            var distanceArgs = StatementArguments()
            distanceArgs += [userId]
            distanceArgs += dateArgs
            let distance = try Double.fetchOne(db, sql: distanceSQL, arguments: distanceArgs) ?? 0

            // Duration (seconds)
            let durationSQL = """
                SELECT COALESCE(SUM(COALESCE(sessions.total_duration, 0)), 0)
                FROM sessions
                WHERE sessions.deleted_at IS NULL
                  AND sessions.user_id = ?
                  AND (sessions.completed_at IS NOT NULL OR sessions.created_at IS NOT NULL)
            """ + dateWhere
            var durationArgs = StatementArguments()
            durationArgs += [userId]
            durationArgs += dateArgs
            let duration = try Double.fetchOne(db, sql: durationSQL, arguments: durationArgs) ?? 0

            return (weight, distance, duration)
        }
    }
    
    /// Counts completed sessions for a user within an optional date range.
    func countCompletedSessions(userId: Int64, start: Date?, end: Date?) throws -> Int {
        try dbQueue.read { db in
            var dateWhere = ""
            var dateArgs = StatementArguments()
            if let start = start {
                dateWhere += " AND (COALESCE(sessions.started_at, sessions.started_at) >= ?)"
                dateArgs += [start]
            }
            if let end = end {
                dateWhere += " AND (COALESCE(sessions.started_at, sessions.started_at) <= ?)"
                dateArgs += [end]
            }
            let sql = """
                SELECT COUNT(*)
                FROM sessions
                WHERE sessions.deleted_at IS NULL
                  AND sessions.user_id = ?
                  AND sessions.completed_at IS NOT NULL
            """ + dateWhere
            var args = StatementArguments()
            args += [userId]
            args += dateArgs
            return try Int.fetchOne(db, sql: sql, arguments: args) ?? 0
        }
    }

    /// Returns the earliest completed_at date for the given user, or nil if none.
    func earliestCompletedSessionDate(userId: Int64) throws -> Date? {
        try dbQueue.read { db in
            let sql = """
                SELECT MIN(completed_at)
                FROM sessions
                WHERE deleted_at IS NULL
                  AND user_id = ?
                  AND completed_at IS NOT NULL
            """
            return try Date.fetchOne(db, sql: sql, arguments: [userId])
        }
    }
    
    /// Returns the latest completed_at date for the given user, or nil if none.
    func latestCompletedSessionDate(userId: Int64) throws -> Date? {
        try dbQueue.read { db in
            let sql = """
                SELECT MAX(completed_at)
                FROM sessions
                WHERE deleted_at IS NULL
                  AND user_id = ?
                  AND completed_at IS NOT NULL
            """
            return try Date.fetchOne(db, sql: sql, arguments: [userId])
        }
    }
    
    /// Counts all non-deleted sessions for a user (regardless of date range).
    func countAnySessions(userId: Int64) throws -> Int {
        try dbQueue.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM sessions WHERE deleted_at IS NULL AND user_id = ?", arguments: [userId]) ?? 0
        }
    }
}

extension SessionRepository {

    struct ExerciseLogOption {
        let id: Int64
        let name: String
    }

    struct PRSetPoint {
        let date: Date
        let value: Double
        let reps: Int
        let unit: String
        let durationSec: Int
    }

    func fetchCompletedExercises(
        userId: Int64,
        start: Date?,
        end: Date?
    ) throws -> [ExerciseLogOption] {

        try dbQueue.read { db in
            var sql = """
                SELECT DISTINCT se.exercise_id AS id, se.exercise_name AS name
                FROM session_exercises se
                JOIN session_blocks sb ON sb.id = se.session_block_id AND sb.deleted_at IS NULL
                JOIN sessions s ON s.id = sb.session_id AND s.deleted_at IS NULL
                JOIN session_sets ss ON ss.session_exercise_id = se.id
                    AND ss.deleted_at IS NULL
                    AND ss.completed = 1
                WHERE se.deleted_at IS NULL
                  AND se.completed = 1
                  AND s.user_id = ?
            """

            var args = StatementArguments([userId])

            if let start {
                sql += " AND COALESCE(s.started_at, s.started_at) >= ?"
                args += [start]
            }
            if let end {
                sql += " AND COALESCE(s.started_at, s.started_at) <= ?"
                args += [end]
            }

            sql += " ORDER BY name COLLATE NOCASE ASC"

            struct Row: FetchableRecord, Decodable {
                let id: Int64
                let name: String
            }

            return try Row.fetchAll(db, sql: sql, arguments: args)
                .map { ExerciseLogOption(id: $0.id, name: $0.name) }
        }
    }

    func fetchPRPoints(
        userId: Int64,
        exerciseId: Int64,
        start: Date?,
        end: Date?
    ) throws -> [PRSetPoint] {

        try dbQueue.read { db in
            var sql = """
                SELECT
                    s.id AS sessionId,
                    COALESCE(s.started_at, s.started_at) AS sessionDate,
                    ss.set_number AS setIndex,
                    COALESCE(ss.value, 0) AS value,
                    COALESCE(ss.completed_reps, 0) AS reps,
                    COALESCE(ss.unit, se.unit) AS unit,
                    COALESCE(se.duration, 0) AS durationSec
                FROM session_sets ss
                JOIN session_exercises se ON se.id = ss.session_exercise_id
                    AND se.deleted_at IS NULL
                    AND se.completed = 1
                JOIN session_blocks sb ON sb.id = se.session_block_id
                    AND sb.deleted_at IS NULL
                JOIN sessions s ON s.id = sb.session_id
                    AND s.deleted_at IS NULL
                WHERE ss.deleted_at IS NULL
                  AND ss.completed = 1
                  AND s.user_id = ?
                  AND se.exercise_id = ?
            """

            var args = StatementArguments([userId, exerciseId])

            if let start {
                sql += " AND COALESCE(s.started_at, s.started_at) >= ?"
                args += [start]
            }
            if let end {
                sql += " AND COALESCE(s.started_at, s.started_at) <= ?"
                args += [end]
            }

            struct Row: FetchableRecord, Decodable {
                let sessionId: Int64
                let sessionDate: Date
                let setIndex: Int
                let value: Double
                let reps: Int
                let unit: String?
                let durationSec: Int
            }

            let rows = try Row.fetchAll(db, sql: sql, arguments: args)

            var best: [Int64: PRSetPoint] = [:]

            for r in rows {
                let candidate = PRSetPoint(
                    date: r.sessionDate,
                    value: r.value,
                    reps: r.reps,
                    unit: r.unit ?? "",
                    durationSec: r.durationSec
                )

                if let existing = best[r.sessionId] {
                    if candidate.value > existing.value ||
                        (candidate.value == existing.value && candidate.reps > existing.reps) {
                        best[r.sessionId] = candidate
                    }
                } else {
                    best[r.sessionId] = candidate
                }
            }

            return best.values.sorted { $0.date < $1.date }
        }
    }
}

