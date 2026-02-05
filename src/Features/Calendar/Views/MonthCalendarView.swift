//
//  MonthCalendarView.swift
//  fitness-app
//
//  Created by Assistant on 1/30/26.
//

import SwiftUI
import Foundation
import GRDB

struct MonthCalendarView: View {
    var onSelectDate: ((Date) -> Void)? = nil
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var authCoordinator: AuthCoordinator

    @State private var referenceDate: Date = Calendar.current.startOfDay(for: Date())
    private let workoutRepository = CalendarWorkoutRepository(dbQueue: DatabaseQueueProvider.shared.dbQueue)
    private let entryRepository = CalendarEntryRepository(dbQueue: DatabaseQueueProvider.shared.dbQueue)

    @State private var daysWithWorkouts: Set<Int> = []
    @State private var daysWithAllWorkoutsComplete: Set<Int> = []
    @State private var daysWithEntries: Set<Int> = []

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Button { shiftMonth(-1) } label: { Image(systemName: "chevron.left") }
                Spacer()
                Text(monthLabel)
                    .font(.headline)
                    .foregroundColor(themeManager.currentTheme.textDefault)
                Spacer()
                Button { shiftMonth(1) } label: { Image(systemName: "chevron.right") }
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
            .padding(.top, 16)


            let grid = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)
            LazyVGrid(columns: grid, spacing: 6) {
                ForEach(daysInMonthGrid(), id: \.self) { day in
                    ZStack(alignment: .bottom) {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(isToday(day: day) ? themeManager.currentTheme.primary.opacity(0.12) : themeManager.currentTheme.surface)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(isToday(day: day) ? themeManager.currentTheme.primary.opacity(0.6) : Color.clear, lineWidth: 1)
                            )
                        VStack(spacing: 2) {
                            // Fixed-height number area
                            Text(day == 0 ? "" : String(day))
                                .foregroundColor(isToday(day: day) ? themeManager.currentTheme.primary : themeManager.currentTheme.textDefault)
                                .frame(height: 18)
                            // Fixed-height indicators area
                            ZStack() {
                                // Invisible spacer to reserve height
                                Color.clear.frame(height: 8)
                                HStack(spacing: 4) {
                                    if let d = dateFor(day: day), hasEntry(d) {
                                        Rectangle().fill(themeManager.currentTheme.primary).frame(width: 5, height: 5)
                                    }
                                    if let d = dateFor(day: day), hasWorkouts(d) {
                                        if allWorkoutsComplete(d) {
                                            Circle()
                                                .fill(themeManager.currentTheme.error)
                                                .frame(width: 5, height: 5)
                                        } else {
                                            Circle()
                                                .stroke(themeManager.currentTheme.error, lineWidth: 1)
                                                .frame(width: 5, height: 5)
                                        }
                                    }
                                }
                            }
                            .padding(.bottom, 4)
                        }
                    }
                    .frame(height: 44)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if let date = dateFor(day: day) {
                            onSelectDate?(date)
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom)
            // Legend
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 6) {
                    Rectangle().fill(themeManager.currentTheme.primary).frame(width: 6, height: 6)
                    Text("Has Daily Check-in").foregroundColor(themeManager.currentTheme.muted)
                }
                HStack(spacing: 6) {
                    Circle().fill(themeManager.currentTheme.error).frame(width: 6, height: 6)
                    Text("Workouts Complete").foregroundColor(themeManager.currentTheme.muted)
                }
                HStack(spacing: 6) {
                    Circle().stroke(themeManager.currentTheme.error, lineWidth: 1).frame(width: 6, height: 6)
                    Text("Has Workout(s)").foregroundColor(themeManager.currentTheme.muted)
                }
                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
            .padding(.bottom, 14)
        }
        .task(id: referenceDate) { await loadMonthIndicators() }
    }

    private var monthLabel: String {
        DateFormatter.localizedString(from: referenceDate, dateStyle: .long, timeStyle: .none)
    }

    private func shiftMonth(_ delta: Int) {
        if let d = Calendar.current.date(byAdding: .month, value: delta, to: referenceDate) {
            referenceDate = d
        }
    }

    private func daysInMonthGrid() -> [Int] {
        let cal = Calendar.current
        let range = cal.range(of: .day, in: .month, for: referenceDate)!
        let components = cal.dateComponents([.year, .month], from: referenceDate)
        let firstOfMonth = cal.date(from: components)!
        let weekday = cal.component(.weekday, from: firstOfMonth)
        let leading = (weekday - cal.firstWeekday + 7) % 7
        let days = Array(1...range.count)
        return Array(repeating: 0, count: leading) + days
    }

    private func isToday(day: Int) -> Bool {
        guard day > 0 else { return false }
        let cal = Calendar.current
        var comps = cal.dateComponents([.year, .month], from: referenceDate)
        comps.day = day
        guard let date = cal.date(from: comps) else { return false }
        return cal.isDateInToday(date)
    }

    private func dateFor(day: Int) -> Date? {
        guard day > 0 else { return nil }
        let cal = Calendar.current
        var comps = cal.dateComponents([.year, .month], from: referenceDate)
        comps.day = day
        guard let date = cal.date(from: comps) else { return nil }
        return cal.startOfDay(for: date)
    }

    private func hasWorkouts(_ date: Date) -> Bool {
        let day = Calendar.current.component(.day, from: date)
        return daysWithWorkouts.contains(day)
    }

    private func allWorkoutsComplete(_ date: Date) -> Bool {
        let day = Calendar.current.component(.day, from: date)
        return daysWithAllWorkoutsComplete.contains(day)
    }

    private func hasEntry(_ date: Date) -> Bool {
        let day = Calendar.current.component(.day, from: date)
        return daysWithEntries.contains(day)
    }

    private func sessionIsCompleted(_ session: SessionRecord) -> Bool {
        let mirror = Mirror(reflecting: session)
        for child in mirror.children {
            guard let label = child.label else { continue }
            if label == "isComplete", let flag = child.value as? Bool { return flag }
            if (label == "endedAt" || label == "completedAt") {
                let childMirror = Mirror(reflecting: child.value)
                if childMirror.displayStyle == .optional {
                    if childMirror.children.first != nil { return true }
                } else if child.value is Date { return true }
            }
        }
        return false
    }

    private func loadMonthIndicators() async {
        guard let userId = authCoordinator.currentUser?.id else { return }
        let id64 = Int64(userId)
        let cal = Calendar.current
        let range = cal.range(of: .day, in: .month, for: referenceDate) ?? (1..<32)
        var workoutsDays: Set<Int> = []
        var workoutsAllCompleteDays: Set<Int> = []
        var entriesDays: Set<Int> = []
        let sessionRepo = SessionRepository(dbQueue: DatabaseQueueProvider.shared.dbQueue)
        let exceptionRepo = CalendarWorkoutExceptionRepository(dbQueue: DatabaseQueueProvider.shared.dbQueue)
        for day in range {
            var comps = cal.dateComponents([.year, .month], from: referenceDate)
            comps.day = day
            guard let date = cal.date(from: comps) else { continue }
            let dayDate = cal.startOfDay(for: date)
            do {
                let rows = try workoutRepository.workoutsWithDetails(on: dayDate, userId: id64)
                let wrks = rows.filter { row in
                    CalendarWorkoutRepository.matches(row, on: dayDate) && (try? !exceptionRepo.exists(calendarWorkoutId: row.id, on: dayDate)) ?? true
                }
                if !wrks.isEmpty {
                    workoutsDays.insert(day)
                    // Determine completion by checking for a completed session per scheduled workout row
                    let allComplete: Bool = {
                        for w in wrks {
                            do {
                                if let session = try sessionRepo.find(calendarWorkoutId: w.id, startedAt: dayDate) {
                                    if !sessionIsCompleted(session) { return false }
                                } else {
                                    // No session found for a scheduled workout means unfinished
                                    return false
                                }
                            } catch {
                                // On lookup error, treat as unfinished
                                return false
                            }
                        }
                        return true
                    }()
                    if allComplete { workoutsAllCompleteDays.insert(day) }
                }
                let has = (try? entryRepository.entry(for: id64, on: dayDate)) != nil
                if has { entriesDays.insert(day) }
            } catch {
                // Ignore errors for month-level indicators
            }
        }
        await MainActor.run {
            self.daysWithWorkouts = workoutsDays
            self.daysWithAllWorkoutsComplete = workoutsAllCompleteDays
            self.daysWithEntries = entriesDays
        }
    }
}

