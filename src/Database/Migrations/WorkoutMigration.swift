import GRDB

extension DatabaseMigrator {

    mutating func registerWorkoutMigrations() {

        registerMigration("create_workouts") { db in
            try db.create(table: "workouts") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("user_id", .integer).notNull().indexed()
                t.foreignKey(["user_id"], references: "users", onDelete: .cascade)
                t.column("name", .text).notNull()
                t.column("color", .text).notNull().defaults(to: "primary")
                t.column("description", .text)
                t.softDeletes()
                t.timestamps()
            }
        }
    }
}

