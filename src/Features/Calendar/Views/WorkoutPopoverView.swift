//
//  WorkoutPopover.swift
//  fitness-app
//
//  Created by Dominic Kish on 2/4/26.
//
import SwiftUI

struct WorkoutQuickActionsPopover: View {
    @EnvironmentObject var authCoordinator: AuthCoordinator
    @State private var selectedDeleteType = 0
    
    var themeManager: ThemeManager
    let workoutRow: CalendarWorkoutRepository.ScheduledWorkoutRow?
    let exercises: [String]
    let canEnterSession: Bool
    let error: String?
    let onEnterSession: () -> Void
    let onDeleteSingle: () -> Void
    let onDeleteThisAndFuture: () -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                themeManager.currentTheme.background
                    .ignoresSafeArea()
                VStack(alignment: .leading, spacing: 20) {
                    
                    // MARK: Workout Title
                    if let row = workoutRow {
                        VStack(alignment: .leading, spacing: 8) {
                            
                            Text(row.workoutName)
                                .font(.largeTitle.bold())
                                .foregroundColor(themeManager.currentTheme.textDefault)
                            
                            if let err = error {
                                Text(err)
                                    .foregroundColor(themeManager.currentTheme.error)
                                    .font(.footnote)
                            }
                        }
                        .padding(.top, 24)
                        
                        // MARK: Exercise List
                        VStack(alignment: .leading, spacing: 0) {
                            if exercises.isEmpty {
                                Text("No exercises found")
                                    .foregroundColor(themeManager.currentTheme.muted)
                                    .padding(.vertical, 8)
                            } else {
                                Text("Routine Summary")
                                    .foregroundColor(themeManager.currentTheme.muted)
                                    .font(.title.bold())
                                
                                ScrollView {
                                    VStack(spacing: 0) {
                                        ForEach(exercises.prefix(12), id: \.self) { name in
                                            HStack(spacing: 12) {
                                                Circle()
                                                    .fill(themeManager.currentTheme.primary.opacity(0.2))
                                                    .frame(width: 8, height: 8)
                                                Text(name)
                                                    .foregroundColor(themeManager.currentTheme.textDefault)
                                                    .font(.body)
                                                Spacer()
                                            }
                                            .padding(.vertical, 10)
                                            .padding(.horizontal, 12)
                                            .background(themeManager.currentTheme.surface.opacity(0.1))
                                            .cornerRadius(8)
                                        }
                                        
                                        if exercises.count > 12 {
                                            Text("+ \(exercises.count - 12) more")
                                                .font(.footnote)
                                                .foregroundColor(themeManager.currentTheme.muted)
                                                .padding(.top, 4)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.top, 20)
                        .padding(.bottom, 4)
                        
                        // MARK: Info text
                        if !canEnterSession {
                            Text("This session will be available on the scheduled day.")
                                .font(.footnote)
                                .foregroundColor(themeManager.currentTheme.muted)
                                .padding(.top, 4)
                        }
                        
                        // MARK: Action Buttons
                        if !exercises.isEmpty {
                            HStack() {
                                Button {
                                    onEnterSession()
                                } label: {
                                    Label("Enter Session", systemImage: "figure.strengthtraining.traditional")
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(canEnterSession ? themeManager.currentTheme.primary : themeManager.currentTheme.muted.opacity(0.5))
                                        .foregroundColor(.white)
                                        .cornerRadius(12)
                                }
                                .disabled(!canEnterSession)
                            }
                        }
                        VStack(alignment: .leading, spacing: 16) {

                            // Custom Tabs
                            HStack(spacing: 8) {
                                Button {
                                    selectedDeleteType = 0
                                } label: {
                                    Text("Single Session")
                                        .fontWeight(.semibold)
                                        .padding(.vertical, 8)
                                        .frame(maxWidth: .infinity)
                                        .background(selectedDeleteType == 0 ? themeManager.currentTheme.error.opacity(0.2) : themeManager.currentTheme.surface.opacity(0.4))
                                        .foregroundColor(selectedDeleteType == 0 ? themeManager.currentTheme.error : themeManager.currentTheme.muted)
                                        .cornerRadius(8)
                                }

                                Button {
                                    selectedDeleteType = 1
                                } label: {
                                    Text("This & Future")
                                        .fontWeight(.semibold)
                                        .padding(.vertical, 8)
                                        .frame(maxWidth: .infinity)
                                        .background(selectedDeleteType == 1 ? themeManager.currentTheme.error.opacity(0.2) : themeManager.currentTheme.surface.opacity(0.4))
                                        .foregroundColor(selectedDeleteType == 1 ? themeManager.currentTheme.error : themeManager.currentTheme.muted)
                                        .cornerRadius(8)
                                }
                            }

                            // Single Session Delete Tab
                            if selectedDeleteType == 0 {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Removes only this workout session from your calendar. Future scheduled sessions remain unchanged.")
                                        .font(.footnote)
                                        .foregroundColor(themeManager.currentTheme.textDefault)
                                        .padding(.horizontal, 8)
                                        .fixedSize(horizontal: false, vertical: true)
                                        .padding(.vertical, 8)
                                    
                                    Button(role: .destructive) {
                                        onDeleteSingle()
                                    } label: {
                                        HStack {
                                            Label("Remove This Session", systemImage: "trash.fill")
                                            Spacer()
                                        }
                                        .padding()
                                        .background(themeManager.currentTheme.error.opacity(0.2))
                                        .foregroundColor(themeManager.currentTheme.error)
                                        .cornerRadius(12)
                                    }
                                }
                            }

                            // This & Future Sessions Delete Tab
                            if selectedDeleteType == 1 {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Removes this session and all upcoming sessions of this workout based on its recurrence schedule.")
                                        .font(.footnote)
                                        .foregroundColor(themeManager.currentTheme.textDefault)
                                        .padding(.horizontal, 8)
                                        .fixedSize(horizontal: false, vertical: true)
                                        .padding(.vertical, 8)
                                    
                                    Button(role: .destructive) {
                                        onDeleteThisAndFuture()
                                    } label: {
                                        HStack {
                                            Label("Remove This & Future", systemImage: "trash.fill")
                                            Spacer()
                                        }
                                        .padding()
                                        .background(themeManager.currentTheme.error.opacity(0.2))
                                        .foregroundColor(themeManager.currentTheme.error)
                                        .cornerRadius(12)
                                    }
                                }
                            }
                        }
                        .padding()
                        .background(themeManager.currentTheme.error.opacity(0.1))
                        .cornerRadius(12)
                        
                    } else {
                        Text("No workout selected")
                            .foregroundColor(themeManager.currentTheme.muted)
                            .font(.body)
                    }
                }
                .padding(20)
                .cornerRadius(20)
                .frame(maxWidth: 350)
            }
        }
    }
}
