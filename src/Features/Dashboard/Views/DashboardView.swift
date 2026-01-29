//
//  DashboardView.swift
//  fitness-app
//
//  Created by Dominic Kish on 1/25/26.
//
import SwiftUI

struct DashboardView: View {
    @ObservedObject var coordinator: AppShellCoordinator
    @EnvironmentObject var authCoordinator: AuthCoordinator
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        if let user = authCoordinator.currentUser {
            ZStack {
                themeManager.currentTheme.background.ignoresSafeArea()
                Text("Welcome, \(user.name)!")
                    .foregroundColor(themeManager.currentTheme.textDefault)
            }
        } else {
            ProgressView()
        }
    }
}
