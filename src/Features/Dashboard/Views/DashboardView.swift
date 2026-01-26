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

    var body: some View {
        if let user = authCoordinator.currentUser {
            Text("Welcome, \(user.name)!")
        } else {
            ProgressView()
        }
    }
}
