//
//  CalendarWorkout.swift
//  SimplyFitness
//
//  Created by Dominic Kish on 1/30/26.
//
import GRDB

extension DatabaseMigrator {

    mutating func registerCalendarWorkoutMigrations() {

        registerMigration("create_calendar_workouts") { db in
            try db.create(table: "calendar_workouts") { t in
                // Primary key
                t.autoIncrementedPrimaryKey("id")

                // Foreign keys
                t.column("user_id", .integer).notNull().indexed()
                    .references("users", onDelete: .cascade)
                t.column("workout_id", .integer).notNull().indexed()
                    .references("workouts", onDelete: .cascade)

                // Dates
                t.column("starts_on", .text).notNull() // store as ISO8601 string
                t.column("ends_on", .text) // nullable

                // Frequency and day-of-week flags
                t.column("frequency", .integer) // nullable, default null
                t.column("mon", .boolean).notNull().defaults(to: false)
                t.column("tues", .boolean).notNull().defaults(to: false)
                t.column("wed", .boolean).notNull().defaults(to: false)
                t.column("thurs", .boolean).notNull().defaults(to: false)
                t.column("fri", .boolean).notNull().defaults(to: false)
                t.column("sat", .boolean).notNull().defaults(to: false)
                t.column("sun", .boolean).notNull().defaults(to: false)

                // Soft deletes and timestamps
                t.softDeletes()
                t.timestamps()
            }

            // Indexes to speed up common queries
            try db.create(index: "idx_calendar_workouts_user_starts", on: "calendar_workouts", columns: ["user_id", "starts_on"])
            try db.create(index: "idx_calendar_workouts_user_workout", on: "calendar_workouts", columns: ["user_id", "workout_id"])
        }
    }
}

