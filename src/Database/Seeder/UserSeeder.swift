//
//  UserSeeder.swift
//  fitness-app
//
//  Created by Dominic Kish on 1/26/26.
//
import GRDB
import Foundation

struct UserSeeder {

    static func seed(db: Database) throws {
        // Only seed if table is empty
        let count = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM users") ?? 0
        guard count == 0 else { return }

        // Dummy user
        let users: [[String: Any]] = [
            [
                "id": 0,
                "name": "System",
                "email": "system@vsvault.io",
                "is_premium": false,
                "is_imperial": true,
                "theme": "classic",
                "email_verified_at": Date(),
                "token": UUID().uuidString
            ]
        ]

        // Insert user
        for user in users {
            try db.execute(
                sql: """
                INSERT INTO users
                (id, name, email, is_premium, is_imperial, theme, email_verified_at, token, created_at, updated_at)
                VALUES
                (:id, :name, :email, :is_premium, :is_imperial, :theme, :email_verified_at, :token, :created_at, :updated_at)
                """,
                arguments: [
                    "id": user["id"] as! Int,
                    "name": user["name"] as! String,
                    "email": user["email"] as! String,
                    "is_premium": user["is_premium"] as! Bool,
                    "is_imperial": user["is_imperial"] as! Bool,
                    "theme": user["theme"] as! String,
                    "email_verified_at": user["email_verified_at"] as! Date,
                    "token": user["token"] as! String,
                    "created_at": Date(),
                    "updated_at": Date()
                ]
            )
        }

        print("📝 Seeded users table with \(users.count) record(s).")
    }
}

