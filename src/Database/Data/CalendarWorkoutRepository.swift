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

    static func matches(_ row: ScheduledWorkoutRow, on date: Date) -> Bool {
        let cal = Calendar.current
        let day = cal.startOfDay(for: date)

        // Robust parser for YYYY-MM-DD stored strings
        func parse(_ s: String?) -> Date? {
            guard let s else { return nil }
            if let d = CalendarWorkout.date(from: s) { return cal.startOfDay(for: d) }
            // Fallback: yyyy-MM-dd
            let df = DateFormatter()
            df.calendar = cal
            df.locale = Locale(identifier: "en_US_POSIX")
            df.timeZone = TimeZone(secondsFromGMT: 0)
            df.dateFormat = "yyyy-MM-dd"
            if let d = df.date(from: s) { return cal.startOfDay(for: d) }
            return nil
        }

        guard let startsDay = parse(row.startsOn) else { return true }
        if day < startsDay { return false }
        if let endsDay = parse(row.endsOn), day > endsDay { return false }

        // One-time (no frequency): only on the startsDay
        if row.frequency == nil {
            return cal.isDate(day, inSameDayAs: startsDay)
        }

        // Repeating: must match selected weekday and cadence
        let weekday = cal.component(.weekday, from: day)
        let weekdayAllowed: Bool = {
            switch weekday {
            case 1: return row.sun
            case 2: return row.mon
            case 3: return row.tues
            case 4: return row.wed
            case 5: return row.thurs
            case 6: return row.fri
            case 7: return row.sat
            default: return false
            }
        }()
        guard weekdayAllowed else { return false }

        let freq = row.frequency ?? 1
        // Compute the number of full weeks between startsDay and day
        guard let weeks = cal.dateComponents([.weekOfYear], from: startsDay, to: day).weekOfYear else { return false }
        return weeks % freq == 0
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
            let rec = CalendarWorkoutRecord(from: domain)
            try rec.insert(db)
        }
    }
}

