//
//  SessionExerciseMigration.swift
//  fitness-app
//
//  Created by Dominic Kish on 2/1/26.
//
import GRDB

extension DatabaseMigrator {

    mutating func registerSessionExerciseMigrations() {

        registerMigration("create_session_exercises") { db in
            try db.create(table: "session_exercises") { t in
                t.autoIncrementedPrimaryKey("id")

                t.column("session_block_id", .integer).notNull().indexed()
                t.foreignKey(["session_block_id"], references: "session_blocks", onDelete: .cascade)

                t.column("exercise_id", .integer).notNull().indexed()
                t.foreignKey(["exercise_id"], references: "exercises", onDelete: .cascade)

                t.column("exercise_name", .text).notNull()
                t.column("note", .text)

                t.column("order", .integer) // exercise order in workout
                t.column("duration", .integer).notNull().defaults(to: 0)

                t.softDeletes()
                t.timestamps()
            }
        }
    }
}
