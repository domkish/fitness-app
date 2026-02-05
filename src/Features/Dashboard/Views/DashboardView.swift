//
//  DashboardView.swift
//  fitness-app
//
//  Created by Dominic Kish on 1/25/26.
//
import SwiftUI
import Combine
import GRDB

struct DashboardView: View {
    @ObservedObject var coordinator: AppShellCoordinator
    @EnvironmentObject var authCoordinator: AuthCoordinator
    @EnvironmentObject var themeManager: ThemeManager

    @StateObject var viewModel: DashboardViewModel

    init(coordinator: AppShellCoordinator, userId: Int64? = nil, viewModel: DashboardViewModel? = nil) {
        self.coordinator = coordinator
        if let vm = viewModel {
            _viewModel = StateObject(wrappedValue: vm)
        } else {
            let uid = userId ?? 0
            let repo = SessionRepository(dbQueue: DatabaseQueueProvider.shared.dbQueue)
            _viewModel = StateObject(wrappedValue: DashboardViewModel(sessionRepository: repo, userId: uid))
        }
    }

    private var currentUserName: String { authCoordinator.currentUser?.name ?? "" }
    private var isImperial: Bool { authCoordinator.currentUser?.isImperial ?? true }

    var body: some View {
        ZStack {
            themeManager.currentTheme.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .trailing, spacing: 16) {
                    Text("Welcome back, \(currentUserName)")
                        .bold()
                        .foregroundStyle(themeManager.currentTheme.textDefault)
                        .padding(.horizontal)
                        .padding(.top, 4)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
                VStack(alignment: .center, spacing: 16) {
                    Button {
                        viewModel.showingDatePicker = true
                    } label: {
                        HStack(spacing: 4) {
                            Text(viewModel.dateRangeLabel)
                                .fontWeight(.semibold)
                            Image(systemName: "chevron.down")
                                .font(.footnote.weight(.semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .foregroundColor(themeManager.currentTheme.primary)
                        .background(themeManager.currentTheme.primary.opacity(0.1))
                        .cornerRadius(8)
                    }
                    .padding(.horizontal)
                    .sheet(isPresented: $viewModel.showingDatePicker) {
                        NavigationStack {
                            DateRangePickerView(
                                initialSelection: viewModel.dateSelection,
                                onDone: { newSelection in
                                    self.viewModel.dateSelection = newSelection
                                    viewModel.showingDatePicker = false
                                },
                                onCancel: {
                                    viewModel.showingDatePicker = false
                                }
                            )
                        }
                    }

                    HStack(spacing: 16) {
                        let weight = viewModel.formattedWeight(isImperial: isImperial)
                        MetricTile(title: "Weight", icon: "scalemass", value: weight.value, unit: weight.unit)

                        let distance = viewModel.formattedDistance(isImperial: isImperial)
                        MetricTile(title: "Distance", icon: "figure.walk.motion", value: distance.value, unit: distance.unit)
                    }
                    .padding(.horizontal)
                    
                    HStack(spacing: 16) {
                        let freq = viewModel.formattedWorkoutFrequency()
                        MetricTile(title: "Avg Workouts", icon: "calendar", value: freq.value, unit: freq.unit)
                        
                        MetricTile(title: "Duration", icon: "clock", value: viewModel.formattedDuration(), unit: nil)
                    }
                    .padding(.horizontal)
                    
                    HStack(spacing: 16) {
                        // Exercise Log goes here
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .task { await viewModel.loadDashboardData() }
            .onChange(of: viewModel.dateSelection) { _ in Task { await viewModel.loadDashboardData() } }
            .onReceive(authCoordinator.$currentUser) { user in
                if let id = user?.id {
                    Task { @MainActor in
                        self.viewModel.updateUser(id: Int64(id))
                        await self.viewModel.loadDashboardData()
                    }
                }
            }
                
        }
    }

    struct MetricTile: View {
        @EnvironmentObject var themeManager: ThemeManager
        
        let title: String
        let icon: String
        let value: String
        let unit: String?

        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(title)
                        .font(.callout)
                        .bold()
                        .foregroundStyle(themeManager.currentTheme.textDefault)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Image(systemName: icon)
                        .font(.callout)
                        .foregroundStyle(themeManager.currentTheme.textDefault)
                        .lineLimit(1)
                    Text(value)
                        .font(.callout)
                        .foregroundStyle(themeManager.currentTheme.textDefault)
                        .lineLimit(1)
                    if let unit = unit {
                        Text(unit)
                            .font(.callout)
                            .foregroundStyle(themeManager.currentTheme.textDefault)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding()
            .background(themeManager.currentTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    struct DateRangePickerView: View {
        @Environment(\.dismiss) private var dismiss

        @State private var customStart: Date
        @State private var customEnd: Date

        var initialSelection: DashboardViewModel.DateRangeSelection
        var onDone: (DashboardViewModel.DateRangeSelection) -> Void
        var onCancel: () -> Void

        init(initialSelection: DashboardViewModel.DateRangeSelection,
             onDone: @escaping (DashboardViewModel.DateRangeSelection) -> Void,
             onCancel: @escaping () -> Void)
        {
            self.initialSelection = initialSelection
            self.onDone = onDone
            self.onCancel = onCancel

            switch initialSelection {
            case .lifetime:
                let now = Date()
                _customEnd = State(initialValue: now)
                _customStart = State(initialValue: Calendar.current.date(byAdding: .day, value: -30, to: now) ?? now)
            case let .custom(start, end):
                _customStart = State(initialValue: start)
                _customEnd = State(initialValue: end)
            }
        }

        var body: some View {
            Form {
                Section {
                    Button("Select Lifetime") {
                        onDone(.lifetime)
                        dismiss()
                    }
                }

                Section("Custom Range") {
                    DatePicker("Start Date", selection: $customStart, displayedComponents: [.date])
                        .datePickerStyle(.graphical)
                    DatePicker("End Date", selection: $customEnd, in: customStart..., displayedComponents: [.date])
                        .datePickerStyle(.graphical)
                }
            }
            .navigationTitle("Select Date Range")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        onDone(.custom(customStart.startOfDay, customEnd.endOfDay))
                        dismiss()
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                        dismiss()
                    }
                }
            }
        }
    }
}
private extension Date {
    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }
    var endOfDay: Date {
        let start = startOfDay
        return Calendar.current.date(byAdding: DateComponents(day: 1, second: -1), to: start) ?? self
    }
}

#Preview {
    let coordinator = AppShellCoordinator()
    let themeManager = ThemeManager()
    let userRepo = UserRepository(dbQueue: DatabaseQueueProvider.shared.dbQueue)
    let authCoordinator = AuthCoordinator(authService: AuthService(userRepository: userRepo), userRepository: userRepo)
    return DashboardView(coordinator: coordinator)
        .environmentObject(authCoordinator)
        .environmentObject(themeManager)
}

