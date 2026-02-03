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
    func createSession(userId: Int64, workoutId: Int64, calendarWorkoutId: Int64, workoutName: String, startedAt: Date) throws -> Int64 {
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
            createdAt: Date(),
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
        workoutRepo: WorkoutRepository
    ) throws -> SessionRecord {
        if let existing = try find(calendarWorkoutId: calendarWorkoutId, startedAt: startedAt) {
            return existing
        }
        // Create session first
        let sessionId = try createSession(userId: userId, workoutId: workoutId, calendarWorkoutId: calendarWorkoutId, workoutName: workoutName, startedAt: startedAt)
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
                var sSet = SessionSetRecord(
                    id: nil,
                    sessionExerciseId: sessionExerciseId,
                    setNumber: 1,
                    completedReps: nil,
                    value: nil,
                    unit: ex.unit,
                    completed: 0,
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
}

