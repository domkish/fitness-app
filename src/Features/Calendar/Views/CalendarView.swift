//
//  CalendarView.swift
//  SimplyFitness
//
//  Created by Dominic Kish on 1/25/26.
//
import SwiftUI

struct CalendarView: View {
    @ObservedObject var coordinator: AppShellCoordinator
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var authCoordinator: AuthCoordinator

    @StateObject private var viewModel = CalendarViewModel()

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
                    switch viewModel.mode {
                    case .day:
                        DayCalendarView(
                            coordinator: coordinator,
                            repository: viewModel.calendarRepo,
                            selectedDate: $viewModel.selectedDayDate
                        )

                    case .week:
                        WeekCalendarView { date in
                            viewModel.selectDate(date)
                        }

                    case .month:
                        MonthCalendarView { date in
                            viewModel.selectDate(date)
                        }
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
    private func modeButton(
        title: String,
        value: CalendarViewModel.Mode
    ) -> some View {
        Text(title)
            .font(.subheadline.weight(.semibold))
            .foregroundColor(
                viewModel.mode == value
                ? themeManager.currentTheme.background
                : themeManager.currentTheme.textDefault
            )
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        viewModel.mode == value
                        ? themeManager.currentTheme.primary
                        : themeManager.currentTheme.surface
                    )
            )
            .contentShape(Rectangle())
            .onTapGesture {
                viewModel.selectMode(value)
            }
    }
}
