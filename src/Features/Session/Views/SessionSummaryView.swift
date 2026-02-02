//
//  SessionComplete.swift
//  fitness-app
//
//  Created by Dominic Kish on 2/2/26.
//
import SwiftUI

struct SessionSummaryView: View {
    @ObservedObject var coordinator: AppShellCoordinator
    @EnvironmentObject var authCoordinator: AuthCoordinator
    @EnvironmentObject var themeManager: ThemeManager

    let session: SessionRecord
    
    var body: some View {
        
        ZStack {
            themeManager.currentTheme.background
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    HStack {
                        Text("hmm")
                            .foregroundColor(themeManager.currentTheme.textDefault)
                    }
                }
            }
        }
    }
}

