//
//  ExerciseTagPivotMigration.swift
//  SimplyFitness
//
//  Created by Dominic Kish on 1/26/26.
//
import GRDB

extension DatabaseMigrator {

    mutating func registerExerciseTagPivotMigrations() {

        registerMigration("create_exercise_tag_pivots") { db in
            try db.create(table: "exercise_tag_pivots") { t in
                t.autoIncrementedPrimaryKey("id")
                t.foreignId("exercise_id", references: "exercises")
                t.foreignId("exercise_tag_id", references: "exercise_tags")
                t.timestamps()
            }
        }
    }
}
