//
//  CalendarWorkoutRepository.swift
//  fitness-app
//
//  Created by Assistant on 1/30/26.
//

import Foundation
import GRDB

struct CalendarWorkoutRepository {
    let dbQueue: DatabaseQueue

    struct ScheduledWorkoutRow: FetchableRecord, Decodable {
        let id: Int64
        let workoutId: Int64
        let workoutName: String
        let workoutColor: String?
        let startsOn: String
        let endsOn: String?
        let frequency: Int?
        let mon: Bool
        let tues: Bool
        let wed: Bool
        let thurs: Bool
        let fri: Bool
        let sat: Bool
        let sun: Bool
    }

    func workouts(on date: Date, userId: Int64) throws -> [CalendarWorkoutRecord] {
        let day = CalendarWorkout.dbString(from: date)
        return try dbQueue.read { db in
            try CalendarWorkoutRecord
                .filter(CalendarWorkoutRecord.Columns.userId == userId)
                .filter(
                    (CalendarWorkoutRecord.Columns.startsOn <= day) &&
                    (CalendarWorkoutRecord.Columns.endsOn == nil || CalendarWorkoutRecord.Columns.endsOn >= day)
                )
                .filter(CalendarWorkoutRecord.Columns.deletedAt == nil)
                .fetchAll(db)
        }
    }

    func workoutsWithDetails(on date: Date, userId: Int64) throws -> [ScheduledWorkoutRow] {
        let day = CalendarWorkout.dbString(from: date)
        return try dbQueue.read { db in
            let sql = """
            SELECT cw.id AS id,
                   cw.workout_id AS workoutId,
                   w.name AS workoutName,
                   w.color AS workoutColor,
                   cw.starts_on AS startsOn,
                   cw.ends_on AS endsOn,
                   cw.frequency AS frequency,
                   cw.mon AS mon, cw.tues AS tues, cw.wed AS wed, cw.thurs AS thurs,
                   cw.fri AS fri, cw.sat AS sat, cw.sun AS sun
            FROM calendar_workouts cw
            JOIN workouts w ON w.id = cw.workout_id
            WHERE cw.user_id = ?
              AND cw.deleted_at IS NULL
              AND w.deleted_at IS NULL
              AND cw.starts_on <= ?
              AND (cw.ends_on IS NULL OR cw.ends_on >= ?)
            ORDER BY cw.created_at ASC
            """
            return try ScheduledWorkoutRow.fetchAll(db, sql: sql, arguments: [userId, day, day])
        }
    }

    // Create a calendar workout entry
    func create(_ domain: CalendarWorkout) throws {
        try dbQueue.write { db in
            var rec = CalendarWorkoutRecord(from: domain)
            try rec.insert(db)
        }
    }
}

