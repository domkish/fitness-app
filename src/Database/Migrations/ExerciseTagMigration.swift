//
//  ExerciseTagMigration.swift
//  SimplyFitness
//
//  Created by Dominic Kish on 1/26/26.
//
import GRDB

extension DatabaseMigrator {

    mutating func registerExerciseTagMigrations() {

        registerMigration("create_exercise_tags") { db in
            try db.create(table: "exercise_tags") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("name", .text).notNull()
                t.column("type", .text).notNull()
                t.timestamps()
            }
        }
    }
}
