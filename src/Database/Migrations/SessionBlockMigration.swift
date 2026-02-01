//
//  SessionBlockMigration.swift
//  fitness-app
//
//  Created by Dominic Kish on 2/1/26.
//
import GRDB

extension DatabaseMigrator {

    mutating func registerSessionBlockMigrations() {

        registerMigration("create_session_blocks") { db in
            try db.create(table: "session_blocks") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("session_id", .integer).notNull().indexed()
                t.foreignKey(["session_id"], references: "sessions", onDelete: .cascade)
                t.column("workout_block_id", .integer).notNull().indexed()
                t.foreignKey(["workout_block_id"], references: "workout_blocks", onDelete: .cascade)
                t.column("duration", .integer).notNull().defaults(to: 0)
                t.softDeletes()
                t.timestamps()
            }
        }
    }
}
