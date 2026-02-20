//
//  CalendarWorkoutExceptionMigration.swift
//  SimplyFitness
//
//  Created by Dominic Kish on 2/4/26.
//
import GRDB

extension DatabaseMigrator {

    mutating func registerCalendarWorkoutExceptionMigrations() {

        registerMigration("create_calendar_workout_exceptions") { db in
            try db.create(table: "calendar_workout_exceptions") { t in
                // Primary key
                t.autoIncrementedPrimaryKey("id")

                // Foreign key to calendar_workouts(id) with cascade on delete
                t.column("calendar_workout_id", .integer).notNull().indexed()
                    .references("calendar_workouts", onDelete: .cascade)

                // Normalized day string for the date
                t.column("date", .text).notNull().indexed()

                // Timestamps
                t.softDeletes()
                t.timestamps()

                // Unique key on (calendar_workout_id, date)
                t.uniqueKey(["calendar_workout_id", "date"])
            }

        }
    }
}
