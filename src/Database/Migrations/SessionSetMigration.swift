//
//  SessionSetMigration.swift
//  SimplyFitness
//
//  Created by Dominic Kish on 2/1/26.
//
import GRDB

extension DatabaseMigrator {

    mutating func registerSessionSetMigrations() {

        registerMigration("create_session_sets") { db in
            try db.create(table: "session_sets") { t in
                t.autoIncrementedPrimaryKey("id")

                t.column("session_exercise_id", .integer).notNull().indexed()
                t.foreignKey(["session_exercise_id"], references: "session_exercises", onDelete: .cascade)

                t.column("set_number", .integer).notNull()

                // user performance
                t.column("completed_reps", .integer)
                t.column("value", .double) // decimal(10,2) approximated as double in SQLite/GRDB
                t.column("unit", .text)
                t.column("completed", .integer).notNull().defaults(to: 0)

                t.softDeletes()
                t.timestamps()
            }
        }
    }
}

