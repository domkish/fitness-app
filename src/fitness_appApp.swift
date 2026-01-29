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
            try dbService.setupDatabase(resetFirst: false) // resetFirst: false
            dbQueue = dbService.dbQueue
            DatabaseQueueProvider.shared.dbQueue = dbQueue
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

