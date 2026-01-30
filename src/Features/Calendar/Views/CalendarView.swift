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
    @EnvironmentObject var authCoordinator: AuthCoordinator

    @State private var mode: Mode = .day
    private let calendarRepo = CalendarEntryRepository(
        dbQueue: DatabaseQueueProvider.shared.dbQueue
    )

    enum Mode {
        case day, week, month
    }

    var body: some View {
        ZStack {
            themeManager.currentTheme.background
                .ignoresSafeArea()

            VStack(spacing: 12) {

                // MARK: - Custom Mode Picker
                HStack(spacing: 8) {
                    modeButton(title: "Day", value: .day)
                    modeButton(title: "Week", value: .week)
                    modeButton(title: "Month", value: .month)
                }
                .padding(6)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(themeManager.currentTheme.surface)
                )
                .padding(.horizontal)

                // MARK: - Calendar Content
                Group {
                    switch mode {
                    case .day:
                        DayCalendarView(repository: calendarRepo)
                    case .week:
                        WeekCalendarView()
                    case .month:
                        MonthCalendarView()
                    }
                }
                .environmentObject(themeManager)
                .environmentObject(authCoordinator)

                Spacer(minLength: 0)
            }
        }
    }

    // MARK: - Mode Button

    @ViewBuilder
    private func modeButton(title: String, value: Mode) -> some View {
        Text(title)
            .font(.subheadline.weight(.semibold))
            .foregroundColor(
                mode == value
                ? themeManager.currentTheme.background
                : themeManager.currentTheme.textDefault
            )
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        mode == value
                        ? themeManager.currentTheme.primary
                        : themeManager.currentTheme.surface
                    )
            )
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.2)) {
                    mode = value
                }
            }
    }
}

