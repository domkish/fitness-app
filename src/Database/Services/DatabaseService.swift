//
//  DatabaseManager.swift
//  SimplyFitness
//
//  Created by Dominic Kish on 1/25/26.
//
import Foundation
import GRDB

final class DatabaseService {
    // MARK: - Properties
    private let path: String
    var dbQueue: DatabaseQueue

    // MARK: - Initialization
    init(path: String) throws {
        self.path = path
        print("📂 SQLite database path: \(path)") // ✅ Keep this
        dbQueue = try DatabaseQueue(path: path)
    }

    // MARK: - Public Setup for Production
    func setupDatabaseIfNeeded() throws {
        let fileExists = FileManager.default.fileExists(atPath: path)

        var migrator = DatabaseMigrator()
        registerAllMigrations(on: &migrator)

        // Always run migrations; they're idempotent and apply only what's needed.
        try migrator.migrate(dbQueue)

        if !fileExists {
            try seedIfNeeded()
            print("✅ Database created and seeded on first run.")
        } else {
            // Still guard seeding to be resilient if a prior run didn't finish.
            try seedIfNeeded()
            print("✅ Database migrated (no first-run seed).")
        }
    }

    // MARK: - Development Setup (Debug Only Reset Option)
    func setupDatabase(resetFirst: Bool = false) throws {
        #if DEBUG
        if resetFirst {
            try resetDatabaseFile()
            dbQueue = try DatabaseQueue(path: path)
        }
        #endif

        var migrator = DatabaseMigrator()
        registerAllMigrations(on: &migrator)

        // Run migrations
        try migrator.migrate(dbQueue)

        // Post-migration diagnostics
        try dbQueue.read { db in
            let usersTableCount = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name='users'") ?? 0
            let _hasUsersTable = (usersTableCount > 0)
            let _userCols = try Row.fetchAll(db, sql: "PRAGMA table_info(users)")
            let _schemaVersion: Int = try Int.fetchOne(db, sql: "PRAGMA user_version") ?? 0
            _ = _hasUsersTable
            _ = _userCols
            _ = _schemaVersion
        }

        // Seed data (guarded to run only once)
        try seedIfNeeded()

        print("✅ Database migrated and seeded!")
    }

    // MARK: - Register Migrations
    private func registerAllMigrations(on migrator: inout DatabaseMigrator) {
        // migrator.eraseDatabaseOnSchemaChange = true
        migrator.registerUserMigrations()
        migrator.registerExerciseMigrations()
        migrator.registerExerciseTagMigrations()
        migrator.registerExerciseTagPivotMigrations()
        migrator.registerUnitMigrations()
        migrator.registerExerciseUnitPivotMigrations()
        migrator.registerWorkoutMigrations()
        migrator.registerWorkoutBlockMigrations()
        migrator.registerWorkoutExerciseMigrations()
        migrator.registerTaskMigrations()
        migrator.registerCalendarEntryMigrations()
        migrator.registerCalendarWorkoutMigrations()
        migrator.registerCalendarWorkoutExceptionMigrations()
        migrator.registerSessionMigrations()
        migrator.registerSessionBlockMigrations()
        migrator.registerSessionExerciseMigrations()
        migrator.registerSessionSetMigrations()
    }

    // MARK: - Seed
    private func seedIfNeeded() throws {
        let seedKey = "dbSeeded"
        if UserDefaults.standard.bool(forKey: seedKey) {
            return
        }

        try dbQueue.write { db in
            try UserSeeder.seed(db: db)
            try ExerciseSeeder.seed(db: db)
            try ExerciseTagSeeder.seed(db: db)
            try ExerciseTagPivotSeeder.seed(db: db)
            try UnitSeeder.seed(db: db)
            try ExerciseUnitPivotSeeder.seed(db: db)
        }

        UserDefaults.standard.set(true, forKey: seedKey)
    }

    // MARK: - Reset Database File
    private func resetDatabaseFile() throws {
        let fileManager = FileManager.default
        let walPath = path + "-wal"
        let shmPath = path + "-shm"

        for filePath in [path, walPath, shmPath] {
            if fileManager.fileExists(atPath: filePath) {
                try fileManager.removeItem(atPath: filePath)
            }
        }

        print("🗑️ Database file and associated WAL/SHM files removed at path: \(path)")
    }

    // MARK: - Reset Database In Place
    func resetDatabaseInPlace() throws {
        try dbQueue.write { db in
            try db.execute(sql: "PRAGMA foreign_keys = OFF")

            // Drop views
            let views = try Row.fetchAll(db, sql: "SELECT name FROM sqlite_master WHERE type = 'view'")
            for view in views {
                if let name: String = view["name"] {
                    try db.execute(sql: "DROP VIEW IF EXISTS \"\(name)\"")
                }
            }

            // Drop triggers
            let triggers = try Row.fetchAll(db, sql: "SELECT name FROM sqlite_master WHERE type = 'trigger'")
            for trigger in triggers {
                if let name: String = trigger["name"] {
                    try db.execute(sql: "DROP TRIGGER IF EXISTS \"\(name)\"")
                }
            }

            // Drop indexes
            let indexes = try Row.fetchAll(db, sql: "SELECT name FROM sqlite_master WHERE type = 'index'")
            for index in indexes {
                if let name: String = index["name"], name != "sqlite_autoindex" {
                    try db.execute(sql: "DROP INDEX IF EXISTS \"\(name)\"")
                }
            }

            // Drop tables
            let tables = try Row.fetchAll(db, sql: "SELECT name FROM sqlite_master WHERE type = 'table'")
            for table in tables {
                if let name: String = table["name"], name != "sqlite_sequence" {
                    try db.execute(sql: "DROP TABLE IF EXISTS \"\(name)\"")
                }
            }

            try db.execute(sql: "PRAGMA foreign_keys = ON")
        }
    }
}

