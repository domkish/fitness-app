//
//  MonthCalendarView.swift
//  fitness-app
//
//  Created by Assistant on 1/30/26.
//

import SwiftUI

struct MonthCalendarView: View {
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

            let grid = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)
            LazyVGrid(columns: grid, spacing: 6) {
                ForEach(daysInMonthGrid(), id: \.self) { day in
                    ZStack(alignment: .bottom) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(themeManager.currentTheme.surface)
                        VStack(spacing: 4) {
                            Spacer()
                            Text(day == 0 ? "" : String(day))
                                .foregroundColor(themeManager.currentTheme.textDefault)
                            Circle()
                                .fill(themeManager.currentTheme.muted)
                                .frame(width: 6, height: 6)
                                .opacity(day == 0 ? 0 : 1)
                            Spacer().frame(height: 4)
                        }
                    }
                    .frame(height: 40)
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
}

