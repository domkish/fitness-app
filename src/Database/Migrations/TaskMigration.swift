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
                t.column("user_id", .integer).notNull().indexed()
                    .references("users", onDelete: .cascade)
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

        registerMigration("create_calendar_tasks") { db in
            try db.create(table: "calendar_tasks") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("user_id", .integer).notNull().indexed()
                    .references("users", onDelete: .cascade)
                t.column("task_id", .integer).notNull().indexed()
                    .references("tasks", onDelete: .cascade)
                t.column("date", .text).notNull() // ISO8601 YYYY-MM-DD
                t.column("is_complete", .boolean).notNull().defaults(to: false)
                t.softDeletes()
                t.timestamps()
            }
            try db.create(index: "idx_calendar_tasks_user_date", on: "calendar_tasks", columns: ["user_id", "date"])
            try db.create(index: "idx_calendar_tasks_user_task_date", on: "calendar_tasks", columns: ["user_id", "task_id", "date"])
        }
    }
}
