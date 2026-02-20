//
//  TaskRepository.swift
//  SimplyFitness
//
//  Created by Dominic Kish on 1/29/26.
//

import Foundation
import GRDB

final class TaskRepository {
    private let dbQueue: DatabaseQueue
    private var cachedHasUserId: Bool?
    
    init(dbQueue: DatabaseQueue) {
        self.dbQueue = dbQueue
    }
    
    func fetchAll(for userId: Int64) throws -> [TaskDomain] {
        try dbQueue.read { db in
            let hasUserId = try self.hasUserIdColumn(db)
            let sql: String
            let arguments: StatementArguments
            
            if hasUserId {
                // Filter tasks where user_id IN (userId, 0) and deleted_at IS NULL, order by name asc
                sql = """
                SELECT * FROM tasks
                WHERE (user_id = ? OR user_id = 0)
                  AND deleted_at IS NULL
                ORDER BY name ASC
                """
                arguments = [userId]
            } else {
                // No user_id column: fetch tasks where deleted_at IS NULL ordered by name
                sql = """
                SELECT * FROM tasks
                WHERE deleted_at IS NULL
                ORDER BY name ASC
                """
                arguments = []
            }
            
            // Diagnostics: print schema and sample rows before decoding
            do {
                let rows = try RowModel.fetchAll(db, sql: sql, arguments: arguments)
                return rows.map { $0.toDomain() }
            } catch {
                throw error
            }
        }
    }
    
    func create(name: String, userId: Int64) throws -> Int64 {
        try dbQueue.write { db in
            let now = Date()
            let hasUserId = try self.hasUserIdColumn(db)
            
            if hasUserId {
                let sql = """
                INSERT INTO tasks (name, user_id, created_at, updated_at)
                VALUES (?, ?, ?, ?)
                """
                try db.execute(sql: sql, arguments: [name, userId, now, now])
            } else {
                let sql = """
                INSERT INTO tasks (name, created_at, updated_at)
                VALUES (?, ?, ?)
                """
                try db.execute(sql: sql, arguments: [name, now, now])
            }
            
            return db.lastInsertedRowID
        }
    }
    
    func softDelete(id: Int64) throws {
        try dbQueue.write { db in
            let now = Date()
            let sql = """
            UPDATE tasks
            SET deleted_at = ?
            WHERE id = ?
            """
            try db.execute(sql: sql, arguments: [now, id])
        }
    }
    
    func delete(id: Int64) throws {
        try dbQueue.write { db in
            try db.execute(sql: "DELETE FROM tasks WHERE id = ?", arguments: [id])
        }
    }
    
    func fetchOne(id: Int64) throws -> TaskDomain? {
        try dbQueue.read { db in
            let hasUserId = try self.hasUserIdColumn(db)
            let sql: String
            let arguments: StatementArguments
            
            if hasUserId {
                // No user_id filter on fetchOne - just not deleted and id match
                sql = """
                SELECT * FROM tasks
                WHERE id = ? AND deleted_at IS NULL
                LIMIT 1
                """
                arguments = [id]
            } else {
                sql = """
                SELECT * FROM tasks
                WHERE id = ? AND deleted_at IS NULL
                LIMIT 1
                """
                arguments = [id]
            }
            
            guard let row = try RowModel.fetchOne(db, sql: sql, arguments: arguments) else {
                return nil
            }
            return row.toDomain()
        }
    }
    
    func updateName(id: Int64, to newName: String) throws {
        try dbQueue.write { db in
            let now = Date()
            let sql = """
            UPDATE tasks
            SET name = ?, updated_at = ?
            WHERE id = ?
            """
            try db.execute(sql: sql, arguments: [newName, now, id])
        }
    }
    
    func updateSchedule(
        id: Int64,
        sunday: Bool,
        monday: Bool,
        tuesday: Bool,
        wednesday: Bool,
        thursday: Bool,
        friday: Bool,
        saturday: Bool,
        startedAt: Date?,
        endsAt: Date?
    ) throws {
        try dbQueue.write { db in
            let now = Date()
            let sql = """
            UPDATE tasks
            SET sunday = ?, monday = ?, tuesday = ?, wednesday = ?, thursday = ?, friday = ?, saturday = ?,
                started_at = ?, ends_at = ?, updated_at = ?
            WHERE id = ?
            """
            try db.execute(sql: sql, arguments: [sunday, monday, tuesday, wednesday, thursday, friday, saturday, startedAt, endsAt, now, id])
        }
    }
    
    // MARK: - Helpers
    
    private func hasUserIdColumn(_ db: Database) throws -> Bool {
        if let cached = cachedHasUserId {
            return cached
        }
        let rows = try Row.fetchAll(db, sql: "PRAGMA table_info(tasks)")
        for row in rows {
            if let name: String = row["name"], name == "user_id" {
                cachedHasUserId = true
                return true
            }
        }
        cachedHasUserId = false
        return false
    }
    
    // MARK: - RowModel
    
    private struct RowModel: FetchableRecord, Decodable {
        let id: Int64
        let userId: Int64?
        let name: String
        let sunday: Bool?
        let monday: Bool?
        let tuesday: Bool?
        let wednesday: Bool?
        let thursday: Bool?
        let friday: Bool?
        let saturday: Bool?
        let startedAt: Date?
        let endsAt: Date?
        let deletedAt: Date?
        let createdAt: Date
        let updatedAt: Date
        
        enum Columns: String, CodingKey {
            case id
            case userId = "user_id"
            case name, sunday, monday, tuesday, wednesday, thursday, friday, saturday
            case startedAt = "started_at"
            case endsAt = "ends_at"
            case deletedAt = "deleted_at"
            case createdAt = "created_at"
            case updatedAt = "updated_at"
        }
        typealias CodingKeys = Columns
        
        func toDomain() -> TaskDomain {
            TaskDomain(
                id: id,
                userId: userId,
                name: name,
                sunday: sunday ?? false,
                monday: monday ?? false,
                tuesday: tuesday ?? false,
                wednesday: wednesday ?? false,
                thursday: thursday ?? false,
                friday: friday ?? false,
                saturday: saturday ?? false,
                startedAt: startedAt,
                endsAt: endsAt,
                deletedAt: deletedAt,
                createdAt: createdAt,
                updatedAt: updatedAt
            )
        }
    }
}


