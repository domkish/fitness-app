//
//  fitness_appApp.swift
//  fitness-app
//
//  Created by Dominic Kish on 1/24/26.
//

import SwiftUI
import GRDB

@main
struct fitness_appApp: App {
    @StateObject private var authCoordinator: AuthCoordinator
    @StateObject private var themeManager = ThemeManager()

    init() {
        // Build DatabaseService and run setup
        let dbQueue: DatabaseQueue
        do {
            let supportURL = try FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            let dbURL = supportURL.appendingPathComponent("fitness.sqlite")
            let dbService = try DatabaseService(path: dbURL.path)
            try dbService.setupDatabase(resetFirst: true) // resetFirst: false
            dbQueue = dbService.dbQueue
            DatabaseQueueProvider.shared.dbQueue = dbQueue
            
            // Verify shared dbQueue is migrated
            do {
                try dbQueue.read { db in
                    let usersTableCount = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name='users'") ?? 0
                    let hasUsersTable = (usersTableCount > 0)
                    let schemaVersion: Int = try Int.fetchOne(db, sql: "PRAGMA user_version") ?? 0
                    print("✅ App init — shared dbQueue set. users exists? \(hasUsersTable), schemaVersion: \(schemaVersion)")
                }
            } catch {
                print("⚠️ App init — shared dbQueue diagnostics failed: \(error)")
            }
        } catch {
            fatalError("Failed to initialize database: \(error)")
        }

        let userRepo = UserRepository(dbQueue: dbQueue)
        let authService = AuthService(userRepository: userRepo)
        _authCoordinator = StateObject(wrappedValue: AuthCoordinator(authService: authService, userRepository: userRepo))
    }
    
    var body: some Scene {
        WindowGroup {
            NavigationStack {
                ContentView()
                    .environmentObject(authCoordinator)
                    .environmentObject(themeManager)
                    .statusBar(hidden: false)
            }
            .onReceive(authCoordinator.$currentUser) { user in
                themeManager.update(for: user?.theme)
            }
            .onReceive(NotificationCenter.default.publisher(for: .userThemeDidChange)) { note in
                if let key = note.object as? String {
                    themeManager.update(for: key)
                } else {
                    themeManager.update(for: authCoordinator.currentUser?.theme)
                }
            }
        }
    }
}

