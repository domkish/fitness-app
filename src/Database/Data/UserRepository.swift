//
//  UserRepository.swift
//  fitness-app
//
//  Created by Dominic Kish on 1/26/26.
//
import GRDB

struct UserRepository {

    private let dbQueue: DatabaseQueue

    init(dbQueue: DatabaseQueue) {
        self.dbQueue = dbQueue
    }

    /// Fetches the first user (assuming one logged-in user)
    func fetchUser() throws -> User? {
        try dbQueue.read { db in
            guard let record = try UserRecord.fetchOne(db) else {
                return nil
            }

            return User(
                id: record.id,
                name: record.name,
                email: record.email,
                isPremium: record.isPremium,
                emailVerifiedAt: record.emailVerifiedAt,
                createdAt: record.createdAt,
                updatedAt: record.updatedAt
            )
        }
    }

    /// Create or update user
    func createOrUpdate(_ user: User) throws {
        try dbQueue.write { db in
            try UserRecord(from: user)
                .insert(db, onConflict: .replace)
        }
    }

    /// Deletes all users (logout)
    func deleteUser() throws {
        try dbQueue.write { db in
            _ = try UserRecord.deleteAll(db)
        }
    }
}
