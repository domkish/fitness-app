//
//  CalendarEntry.swift
//  fitness-app
//
//  Created by Dominic Kish on 1/30/26.
//
import GRDB

extension DatabaseMigrator {

    mutating func registerCalendarEntryMigrations() {

        registerMigration("create_calendar_entries") { db in
            try db.create(table: "calendar_entries") { t in
                // Primary key
                t.autoIncrementedPrimaryKey("id")

                // Foreign key to users(id) with cascade on delete
                t.column("user_id", .integer).notNull().indexed()
                    .references("users", onDelete: .cascade)
                t.column("date", .text).notNull()
                t.column("weight", .double)
                t.column("body_fat", .double)
                t.column("progress_photo", .text)
                t.softDeletes()
                t.timestamps()
            }

            // Helpful composite index for frequent queries per user/date
            try db.create(index: "idx_calendar_entries_user_date", on: "calendar_entries", columns: ["user_id", "date"]) 
        }
    }
}
