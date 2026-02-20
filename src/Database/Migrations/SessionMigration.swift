//
//  WorkoutSession.swift
//  SimplyFitness
//
//  Created by Dominic Kish on 2/1/26.
//
import GRDB

extension DatabaseMigrator {

    mutating func registerSessionMigrations() {

        registerMigration("create_sessions") { db in
            try db.create(table: "sessions") { t in
                t.autoIncrementedPrimaryKey("id")

                t.column("user_id", .integer).notNull().indexed()
                t.foreignKey(["user_id"], references: "users", onDelete: .cascade)

                t.column("workout_id", .integer).notNull().indexed()
                t.foreignKey(["workout_id"], references: "workouts", onDelete: .cascade)

                t.column("calendar_workout_id", .integer).notNull().indexed()
                t.foreignKey(["calendar_workout_id"], references: "calendar_workouts", onDelete: .cascade)

                t.column("workout_name", .text).notNull()
                t.column("description", .text)
                t.column("total_duration", .integer).notNull().defaults(to: 0)
                t.column("started_at", .datetime)
                t.column("completed_at", .datetime)

                t.softDeletes()
                t.timestamps()

                t.uniqueKey(["calendar_workout_id", "started_at"], onConflict: nil)
            }
        }
    }
}
