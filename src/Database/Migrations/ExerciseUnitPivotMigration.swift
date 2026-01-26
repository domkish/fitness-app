//
//  ExerciseUnitPivotMigration.swift
//  fitness-app
//
//  Created by Dominic Kish on 1/26/26.
//
import GRDB

extension DatabaseMigrator {

    mutating func registerExerciseUnitPivotMigrations() {

        registerMigration("create_exercise_unit_pivots") { db in
            try db.create(table: "exercise_unit_pivots") { t in
                t.autoIncrementedPrimaryKey("id")
                t.foreignId("exercise_id", references: "exercises")
                t.foreignId("unit_id", references: "units")
                t.timestamps()
            }
        }
    }
}
