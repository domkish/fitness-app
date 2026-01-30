//
//  WeekCalendarView.swift
//  fitness-app
//
//  Created by Assistant on 1/30/26.
//

import SwiftUI

struct WeekCalendarView: View {
    @EnvironmentObject var themeManager: ThemeManager

    @State private var startOfWeek: Date = {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let weekday = cal.component(.weekday, from: today)
        let diff = (weekday - cal.firstWeekday + 7) % 7
        return cal.date(byAdding: .day, value: -diff, to: today) ?? today
    }()

    var body: some View {
        VStack(spacing: 0) {
            header
            List {
                ForEach(0..<7, id: \.self) { offset in
                    let date = Calendar.current.date(byAdding: .day, value: offset, to: startOfWeek)!
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(date.formatted(.dateTime.weekday(.wide)))
                                .font(.subheadline)
                                .foregroundColor(themeManager.currentTheme.textDefault)
                            Text(date.formatted(date: .abbreviated, time: .omitted))
                                .font(.caption)
                                .foregroundColor(themeManager.currentTheme.textDefault.opacity(0.8))
                        }
                        Spacer()
                        // Entry indicator placeholder (muted)
                        Circle()
                            .fill(themeManager.currentTheme.muted)
                            .frame(width: 8, height: 8)
                    }
                    .listRowBackground(themeManager.currentTheme.surface)
                }
            }
            .scrollContentBackground(.hidden)
            .background(themeManager.currentTheme.background)
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
}

