//
//  TaskMigration.swift
//  fitness-app
//
//  Created by Dominic Kish on 1/28/26.
//
import GRDB

extension DatabaseMigrator {

    mutating func registerTaskMigrations() {

        registerMigration("create_tasks") { db in
            try db.create(table: "tasks") { t in
                t.autoIncrementedPrimaryKey("id")
                t.foreignId("user_id", references: "users")
                t.column("name", .text)
                    .notNull()
                t.column("sunday", .boolean).notNull().defaults(to: false)
                t.column("monday", .boolean).notNull().defaults(to: false)
                t.column("tuesday", .boolean).notNull().defaults(to: false)
                t.column("wednesday", .boolean).notNull().defaults(to: false)
                t.column("thursday", .boolean).notNull().defaults(to: false)
                t.column("friday", .boolean).notNull().defaults(to: false)
                t.column("saturday", .boolean).notNull().defaults(to: false)
                t.column("started_at", .datetime)
                t.column("ends_at", .datetime)
                t.softDeletes()
                t.timestamps()
            }
        }
    }
}
