//
//  ExerciseMigration.swift
//  fitness-app
//
//  Created by Dominic Kish on 1/26/26.
//
import GRDB

extension DatabaseMigrator {

    mutating func registerExerciseMigrations() {

        registerMigration("create_exercises") { db in
            try db.create(table: "exercises") { t in
                t.autoIncrementedPrimaryKey("id")
                t.foreignId("user_id", references: "users")
                t.column("name", .text).notNull()
                t.column("locked", .boolean).notNull().defaults(to: false)
                t.softDeletes()
                t.timestamps()
            }
        }
    }
}
