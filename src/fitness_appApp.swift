//
//  fitness_appApp.swift
//  SimplyFitness
//
//  Created by Dominic Kish on 1/24/26.
//

import SwiftUI
import GRDB
import UIKit
import StoreKit

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
            try dbService.setupDatabaseIfNeeded()
//            try dbService.setupDatabase(resetFirst: false) // resetFirst: false
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
        
        // Configure JWS provider for client-side verification (Approach A)
        // TODO: Replace the return value with your real JWS source when available.
        // This closure receives the `VerificationResult<Transaction>` that was verified.
        // Return a non-empty JWS string to enable server verification.
        PurchaseManager.shared.jwsProvider = { verification in
            // Example: If you later integrate a wrapper/SDK that exposes a JWS string,
            // call into it here and return the JWS.
            // For now, we support a debug-only path via UserDefaults for testing.
            if let debugJWS = UserDefaults.standard.string(forKey: "debug_jws"), !debugJWS.isEmpty {
                return debugJWS
            }
            // No JWS available yet; returning nil will cause verification to fail (by design)
            return nil
        }
    }
    
    var body: some Scene {
        WindowGroup {
            NavigationStack {
                ContentView()
                    .environmentObject(authCoordinator)
                    .environmentObject(themeManager)
                    .statusBar(hidden: false)
            }
            .tint(themeManager.currentTheme.primary)
            .onAppear {
                configureTabBarAppearance(with: uiColor(from: themeManager.currentTheme.primary))
            }
            .onReceive(authCoordinator.$currentUser) { user in
                themeManager.update(for: user?.theme)
                configureTabBarAppearance(with: uiColor(from: themeManager.currentTheme.primary))
            }
            .onReceive(NotificationCenter.default.publisher(for: .userThemeDidChange)) { note in
                if let key = note.object as? String {
                    themeManager.update(for: key)
                } else {
                    themeManager.update(for: authCoordinator.currentUser?.theme)
                }
                configureTabBarAppearance(with: uiColor(from: themeManager.currentTheme.primary))
            }
        }
    }

    private func configureTabBarAppearance(with tint: UIColor) {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        // Optionally set a stable background color to avoid material transitions
        // appearance.backgroundColor = .systemBackground

        UITabBar.appearance().standardAppearance = appearance
        if #available(iOS 15.0, *) {
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }

        // Set global tint colors for selected and unselected items
        UITabBar.appearance().tintColor = tint
        UITabBar.appearance().unselectedItemTintColor = tint.withAlphaComponent(0.6)

        // Optionally set title text attributes globally for tab bar items
        let normalAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: tint.withAlphaComponent(0.6)
        ]
        let selectedAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: tint
        ]
        UITabBarItem.appearance().setTitleTextAttributes(normalAttributes, for: .normal)
        UITabBarItem.appearance().setTitleTextAttributes(selectedAttributes, for: .selected)
    }

    private func uiColor(from color: Color) -> UIColor {
        // Use UIColor initializer that bridges from SwiftUI Color
        return UIColor(color)
    }
    
}

struct BubblesOverlay: View {
    @EnvironmentObject var themeManager: ThemeManager
    var body: some View {
        GeometryReader { geo in
            let width = max(geo.size.width, 1)
            let height = max(geo.size.height, 1)
            ZStack {
                ForEach(0..<12, id: \.self) { i in
                    let size = CGFloat(20 + (i % 5) * 10)
                    let rawX = CGFloat((i * 97) % Int(width))
                    let rawY = CGFloat((i * 137) % Int(height))
                    let x = max(0, min(rawX, width))
                    let y = max(0, min(rawY, height))
                    Circle()
                        .fill(themeManager.currentTheme.surface.opacity(0.12))
                        .frame(width: size, height: size)
                        .position(x: x, y: y)
                }
            }
        }
    }
}
