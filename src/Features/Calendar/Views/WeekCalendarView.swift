//
//  WeekCalendarView.swift
//  fitness-app
//
//  Created by Assistant on 1/30/26.
//

import SwiftUI

struct WeekCalendarView: View {
    var onSelectDate: ((Date) -> Void)? = nil
    
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var authCoordinator: AuthCoordinator

    @State private var startOfWeek: Date = {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let weekday = cal.component(.weekday, from: today)
        let diff = (weekday - cal.firstWeekday + 7) % 7
        return cal.date(byAdding: .day, value: -diff, to: today) ?? today
    }()
    
    @State private var showingCheckin = false
    @State private var selectedDateForSheet: Date = Date()
    @State private var currentEntry: CalendarEntryRecord?
    @State private var priorEntry: CalendarEntryRecord?

    private let workoutRepository = CalendarWorkoutRepository(dbQueue: DatabaseQueueProvider.shared.dbQueue)
    private let entryRepository = CalendarEntryRepository(dbQueue: DatabaseQueueProvider.shared.dbQueue)

    @State private var weekWorkouts: [Int: [CalendarWorkoutRepository.ScheduledWorkoutRow]] = [:] // key: 0..6 offset

    private func colorForKey(_ key: String?) -> Color {
        switch key ?? "primary" {
        case "primary": return themeManager.currentTheme.primary
        case "secondary": return themeManager.currentTheme.secondary
        case "success": return AppColors.success
        case "warning": return AppColors.warning
        case "error": return themeManager.currentTheme.error
        case "important": return themeManager.currentTheme.important
        default: return themeManager.currentTheme.primary
        }
    }

    private func isTodayOrPast(_ date: Date) -> Bool {
        let today = Calendar.current.startOfDay(for: Date())
        let compareDate = Calendar.current.startOfDay(for: date)
        return compareDate <= today
    }
    
    private func isToday(_ date: Date) -> Bool {
        Calendar.current.isDateInToday(date)
    }
    
    // Assuming weekEntries is defined somewhere or needs to be added for the checkmark logic:
    @State private var weekEntries: [Int: Bool] = [:]

    var body: some View {
        VStack(spacing: 0) {
            header
            List {
                ForEach(0..<7, id: \.self) { offset in
                    let date = Calendar.current.date(byAdding: .day, value: offset, to: startOfWeek)!
                    let isTodayCell = isToday(date)

                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(date.formatted(.dateTime.weekday(.wide)))
                                .font(.subheadline)
                                .foregroundColor(isTodayCell ? themeManager.currentTheme.important : themeManager.currentTheme.textDefault)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    onSelectDate?(date)
                                }
                            Text(date.formatted(date: .abbreviated, time: .omitted))
                                .font(.caption)
                                .foregroundColor(isTodayCell ? themeManager.currentTheme.important : themeManager.currentTheme.textDefault.opacity(0.8))
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    onSelectDate?(date)
                                }
                        }
                        Spacer()

                        let canCheckin = isTodayOrPast(date)
                        let hasEntry = weekEntries[offset] ?? false
                        if canCheckin {
                            Button {
                                selectedDateForSheet = date
                                Task {
                                    await loadEntryContext(for: date)
                                    await MainActor.run { showingCheckin = true }
                                }
                            } label: {
                                Image(systemName: hasEntry ? "checkmark.seal.fill" : "pencil.and.list.clipboard")
                                    .foregroundColor(hasEntry ? themeManager.currentTheme.primary : themeManager.currentTheme.muted)
                            }
                        }
                    }
                    .listRowBackground(themeManager.currentTheme.surface)

                    if let workouts = weekWorkouts[offset], !workouts.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(workouts, id: \.id) { w in
                                let c = colorForKey(w.workoutColor)
                                HStack(spacing: 10) {
                                    Circle()
                                        .fill(c)
                                        .frame(width: 14, height: 14)
                                    Text(w.workoutName)
                                        .font(.headline)
                                        .foregroundColor(c)
                                    Spacer()
                                }
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(c.opacity(0.1))
                                )
                            }
                        }
                        .listRowBackground(themeManager.currentTheme.surface)
                        .padding(.top, 6)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(themeManager.currentTheme.background)
            .task(id: startOfWeek) {
                await loadWeekData()
            }
            .sheet(isPresented: $showingCheckin) {
                DailyCheckinSheet(
                    date: selectedDateForSheet,
                    existing: currentEntry,
                    prior: priorEntry,
                    repository: entryRepository
                ) { _ in
                    showingCheckin = false
                    Task { await loadWeekData() }
                }
                .id(selectedDateForSheet)
                .environmentObject(themeManager)
                .environmentObject(authCoordinator)
                .task(id: selectedDateForSheet) {
                    await loadEntryContext(for: selectedDateForSheet)
                }
            }
        }
    }

    private var header: some View {
        HStack {
            Button { shiftWeek(-1) } label: { Image(systemName: "chevron.left") }
            Spacer()
            Text(weekLabel)
                .font(.headline)
                .foregroundColor(themeManager.currentTheme.textDefault)
            Spacer()
            Button { shiftWeek(1) } label: { Image(systemName: "chevron.right") }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(themeManager.currentTheme.background)
    }

    private var weekLabel: String {
        let end = Calendar.current.date(byAdding: .day, value: 6, to: startOfWeek) ?? startOfWeek
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return "\(f.string(from: startOfWeek)) - \(f.string(from: end))"
    }

    private func shiftWeek(_ delta: Int) {
        if let d = Calendar.current.date(byAdding: .day, value: delta * 7, to: startOfWeek) {
            startOfWeek = d
        }
    }

    private func loadWeekData() async {
        guard let userId = authCoordinator.currentUser?.id else { return }
        let id64 = Int64(userId)
        var map: [Int: [CalendarWorkoutRepository.ScheduledWorkoutRow]] = [:]
        var entriesMap: [Int: Bool] = [:]
        for offset in 0..<7 {
            if let date = Calendar.current.date(byAdding: .day, value: offset, to: startOfWeek) {
                do {
                    let rows = try workoutRepository.workoutsWithDetails(on: date, userId: id64)
                    map[offset] = rows
                    let has = (try? entryRepository.entry(for: id64, on: date)) != nil
                    entriesMap[offset] = has
                } catch {
                    print("[WeekCalendarView] loadWeekData error: \(error)")
                    map[offset] = []
                    entriesMap[offset] = false
                }
            }
        }
        await MainActor.run {
            self.weekWorkouts = map
            self.weekEntries = entriesMap
        }
    }
    
    private func loadEntryContext(for date: Date) async {
        guard let userId = authCoordinator.currentUser?.id else { return }
        let id64 = Int64(userId)
        do {
            self.currentEntry = try entryRepository.entry(for: id64, on: date)
        } catch {
            self.currentEntry = nil
        }
        do {
            self.priorEntry = try entryRepository.mostRecentPriorEntry(before: date, userId: id64)
        } catch {
            self.priorEntry = nil
        }
    }
}

