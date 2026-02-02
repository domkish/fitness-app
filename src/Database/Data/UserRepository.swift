//
//  UserRepository.swift
//  fitness-app
//
//  Created by Dominic Kish on 1/26/26.
//
import GRDB
import Foundation

public struct UserRepository {

    private let dbQueue: DatabaseQueue
    private let currentUserKey = "current_user_id"
    
    public init(dbQueue: DatabaseQueue) {
        self.dbQueue = dbQueue
    }

    /// Fetches the signed-in user using a persisted current user id
    func fetchUser() async throws -> User? {
        // Read persisted id from UserDefaults (adjust if you use Keychain/session table)
        let stored = UserDefaults.standard.object(forKey: currentUserKey)
        let userId: Int? = {
            if let n = stored as? Int { return n }
            if let s = stored as? String, let n = Int(s) { return n }
            return nil
        }()
        guard let id = userId, id != 0 else { return nil }

        return try await dbQueue.read { db in
            guard let record = try UserRecord.fetchOne(db, key: id) else { return nil }
            return User(
                id: record.id,
                name: record.name,
                email: record.email,
                isPremium: record.isPremium,
                theme: record.theme,
                emailVerifiedAt: record.emailVerifiedAt,
                createdAt: record.createdAt,
                updatedAt: record.updatedAt
            )
        }
    }

    /// Persist the current user id after sign-in
    func setCurrentUserId(_ id: Int?) {
        if let id = id {
            UserDefaults.standard.set(id, forKey: currentUserKey)
        } else {
            UserDefaults.standard.removeObject(forKey: currentUserKey)
        }
    }

    /// Create or update user without using REPLACE to avoid ON DELETE CASCADE effects
    func createOrUpdate(_ user: User) throws {
        try dbQueue.write { db in
            let record = UserRecord(from: user)
            if try UserRecord.fetchOne(db, key: record.id) != nil {
                try record.update(db) // UPDATE existing row
            } else {
                try record.insert(db) // INSERT new row
            }
        }
    }

    /// Deletes all users (logout)
    func deleteUser() throws {
        try dbQueue.write { db in
            _ = try UserRecord.deleteAll(db)
        }
    }

    // MARK: - Diagnostics
    func diagnosticsLog(_ tag: String = "UserRepository") {
        do {
            try dbQueue.read { db in
                let usersTableCount = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name='users'") ?? 0
                let _hasUsersTable = (usersTableCount > 0)
                let _schemaVersion: Int = try Int.fetchOne(db, sql: "PRAGMA user_version") ?? 0
            }
        } catch {
        }
    }
}

