//
//  WorkoutBlock.swift
//  fitness-app
//
//  Created by Dominic Kish on 1/27/26.
//
import GRDB

extension DatabaseMigrator {

    mutating func registerWorkoutBlockMigrations() {

        registerMigration("create_workout_blocks") { db in
            try db.create(table: "workout_blocks") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("user_id", .integer).notNull().indexed()
                t.foreignKey(["user_id"], references: "users", onDelete: .cascade)
                t.column("workout_id", .integer).notNull().indexed()
                t.foreignKey(["workout_id"], references: "workouts", onDelete: .cascade)
                t.column("name", .text).notNull()
                t.column("description", .text)
                t.column("difficulty", .text)
                t.column("sort_order", .integer).notNull().defaults(to: 0)
                t.softDeletes()
                t.timestamps()
            }
        }
    }
}
