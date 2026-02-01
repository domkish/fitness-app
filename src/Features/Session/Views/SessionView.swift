//
//  SessionView.swift
//  fitness-app
//
//  Created by Dominic Kish on 1/25/26.
//
import SwiftUI

struct SessionView: View {
    @ObservedObject var coordinator: AppShellCoordinator
    @EnvironmentObject var authCoordinator: AuthCoordinator
    @EnvironmentObject var themeManager: ThemeManager
    
    let session: SessionRecord
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Session for \(session.workoutName)")
                .font(.title)
                .bold()
                .foregroundColor(themeManager.currentTheme.primary)
            
                
            Spacer()
        }
        .padding()
        .navigationTitle("Workout Session")
        .navigationBarTitleDisplayMode(.inline)
    }
}


