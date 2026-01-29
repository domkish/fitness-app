//
//  CalendarView.swift
//  fitness-app
//
//  Created by Dominic Kish on 1/25/26.
//

import SwiftUI

struct CalendarView: View {
    @ObservedObject var coordinator: AppShellCoordinator
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        ZStack {
            themeManager.currentTheme.background.ignoresSafeArea()
            VStack(spacing: 20) {
                Text("Calendar")
                    .font(.title)
                    .bold()
                    .foregroundColor(themeManager.currentTheme.textDefault)
                
                Text("This is where your main app content goes.")
                    .multilineTextAlignment(.center)
                    .padding()
                    .foregroundColor(themeManager.currentTheme.muted)
            }
        }
    }
}
