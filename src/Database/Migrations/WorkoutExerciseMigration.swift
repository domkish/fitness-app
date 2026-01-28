//
//  WorkoutExerciseMigration.swift
//  fitness-app
//
//  Created by Assistant on 1/27/26.
//
import GRDB

extension DatabaseMigrator {

    mutating func registerWorkoutExerciseMigrations() {
        registerMigration("create_workout_exercises") { db in
            try db.create(table: "workout_exercises") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("user_id", .integer).notNull().indexed()
                t.foreignKey(["user_id"], references: "users", onDelete: .cascade)
                t.column("workout_block_id", .integer).notNull().indexed()
                t.foreignKey(["workout_block_id"], references: "workout_blocks", onDelete: .cascade)
                t.column("workout_id", .integer).notNull().indexed()
                t.foreignKey(["workout_id"], references: "workouts", onDelete: .cascade)
                t.column("exercise_id", .integer).notNull().indexed()
                t.foreignKey(["exercise_id"], references: "exercises", onDelete: .cascade)
                t.column("unit", .text)
                t.column("sort_order", .integer)
                t.softDeletes()
                t.timestamps()
            }
        }
    }
}
