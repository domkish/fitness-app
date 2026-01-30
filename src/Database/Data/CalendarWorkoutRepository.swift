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
}
