//
//  MonthCalendarView.swift
//  fitness-app
//
//  Created by Assistant on 1/30/26.
//

import SwiftUI

struct MonthCalendarView: View {
    var onSelectDate: ((Date) -> Void)? = nil
    @EnvironmentObject var themeManager: ThemeManager

    @State private var referenceDate: Date = Calendar.current.startOfDay(for: Date())

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
            .padding(.bottom, 26)

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
                        VStack() {
                            Text(day == 0 ? "" : String(day))
                                .foregroundColor(isToday(day: day) ? themeManager.currentTheme.primary : themeManager.currentTheme.textDefault)
                            Spacer().frame(height: 4)
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
            Spacer()
        }
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
}

