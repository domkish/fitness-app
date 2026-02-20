//
//  DashboardView.swift
//  SimplyFitness
//
//  Created by Dominic Kish on 1/25/26.
//

import SwiftUI
import Charts
import UIKit
import Combine

// MARK: - DashboardView

struct DashboardView: View {
    @ObservedObject var coordinator: AppShellCoordinator
    @EnvironmentObject var authCoordinator: AuthCoordinator
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.scenePhase) private var scenePhase

    @StateObject var viewModel: DashboardViewModel

    @State private var selectedWeightDate: Date? = nil
    @State private var selectedWeightPosition: CGPoint = .zero
    @State private var selectedFatDate: Date? = nil
    @State private var selectedFatPosition: CGPoint = .zero
    @State private var showingFullScreenPhoto = false

    init(
        coordinator: AppShellCoordinator,
        userId: Int64? = nil,
        viewModel: DashboardViewModel? = nil
    ) {
        self.coordinator = coordinator

        if let vm = viewModel {
            _viewModel = StateObject(wrappedValue: vm)
        } else {
            let uid = userId ?? 0
            let repo = SessionRepository(dbQueue: DatabaseQueueProvider.shared.dbQueue)
            _viewModel = StateObject(
                wrappedValue: DashboardViewModel(
                    sessionRepository: repo,
                    userId: uid,
                    userCreatedAtProvider: { AuthCoordinatorProvider.currentUserCreatedAt }
                )
            )
        }
    }

    private struct AuthCoordinatorProvider {
        static var instance: AuthCoordinator?
        static var currentUserCreatedAt: Date? { instance?.currentUser?.createdAt }
    }

    private var currentUserName: String {
        authCoordinator.currentUser?.name ?? ""
    }

    private var isImperial: Bool {
        authCoordinator.currentUser?.isImperial ?? true
    }

    var body: some View {
        NavigationStack {
            ZStack {
                themeManager.currentTheme.background
                    .ignoresSafeArea()
                VStack(spacing: 30) {
                    VStack(spacing: 0) {
                        ScrollView {
                            VStack(spacing: 16) {
                                
                                Text("Welcome back, \(currentUserName)")
                                    .bold()
                                    .foregroundStyle(themeManager.currentTheme.textDefault)
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                                    .padding(.horizontal)
                                
                                dateRangeButton
                                metricTiles
                                exerciseLogSection

                                // Progress Photos carousel (conditional)
                                if(authCoordinator.currentUser?.photo == true) && !viewModel.progressPhotos.isEmpty {
                                    VStack(alignment: .leading, spacing: 12) {
                                        HStack {
                                            Text("Progress Photos")
                                                .font(.headline)
                                                .foregroundStyle(themeManager.currentTheme.textDefault)
                                            Spacer()
                                        }

                                        // Wrap HStack in container limiting width
                                        GeometryReader { geo in
                                            let totalWidth = geo.size.width
                                            let spacing: CGFloat = 12
                                            let columnWidth = max(0, (totalWidth - spacing) / 2)
                                            let aspect: CGFloat = 3.0 / 4.0 // portrait w:h
                                            let columnHeight = columnWidth / aspect

                                            HStack(alignment: .top, spacing: spacing) {
                                                // Left: Static first image in range
                                                if let firstItem = viewModel.progressPhotos.first, let firstImg = viewModel.loadImage(from: firstItem.relativePath) {
                                                    Image(uiImage: firstImg)
                                                        .resizable()
                                                        .scaledToFill()
                                                        .frame(width: columnWidth, height: columnHeight, alignment: .top)
                                                        .clipped(antialiased: true)
                                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                                } else {
                                                    RoundedRectangle(cornerRadius: 12)
                                                        .fill(themeManager.currentTheme.surface.opacity(0.5))
                                                        .frame(width: columnWidth, height: columnHeight)
                                                }

                                                // Right: Interactive crossfade current/next image
                                                ZStack {
                                                    let total = viewModel.progressPhotos.count
                                                    let clamped = max(0, min(Double(max(0, total - 1)), viewModel.currentPhotoIndex))
                                                    let baseIndex = Int(floor(clamped))
                                                    let nextIndex = min(baseIndex + 1, max(0, total - 1))
                                                    let fraction = clamped - Double(baseIndex)

                                                    if total > 0 {
                                                        let baseItem = viewModel.progressPhotos[baseIndex]
                                                        if let img = viewModel.loadImage(from: baseItem.relativePath) {
                                                            Image(uiImage: img)
                                                                .resizable()
                                                                .scaledToFill()
                                                                .frame(width: columnWidth, height: columnHeight, alignment: .top)
                                                                .clipped(antialiased: true)
                                                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                                                .opacity(1.0 - fraction)
                                                        } else {
                                                            RoundedRectangle(cornerRadius: 12)
                                                                .fill(themeManager.currentTheme.surface.opacity(0.5))
                                                                .frame(width: columnWidth, height: columnHeight)
                                                                .opacity(1.0 - fraction)
                                                        }
                                                    }

                                                    if total > 0 {
                                                        let nextItem = viewModel.progressPhotos[nextIndex]
                                                        if let img = viewModel.loadImage(from: nextItem.relativePath) {
                                                            Image(uiImage: img)
                                                                .resizable()
                                                                .scaledToFill()
                                                                .frame(width: columnWidth, height: columnHeight, alignment: .top)
                                                                .clipped(antialiased: true)
                                                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                                                .opacity(fraction)
                                                        } else {
                                                            RoundedRectangle(cornerRadius: 12)
                                                                .fill(themeManager.currentTheme.surface.opacity(0.5))
                                                                .frame(width: columnWidth, height: columnHeight)
                                                                .opacity(fraction)
                                                        }
                                                    }
                                                    
                                                    // Date overlay for the currently displayed photo
                                                    VStack {
                                                        Spacer()
                                                        HStack {
                                                            Spacer()
                                                            let total = viewModel.progressPhotos.count
                                                            let clamped = max(0, min(Double(max(0, total - 1)), viewModel.currentPhotoIndex))
                                                            let baseIndex = Int(floor(clamped))
                                                            let nextIndex = min(baseIndex + 1, max(0, total - 1))
                                                            let fraction = clamped - Double(baseIndex)
                                                            let displayIndex = (fraction > 0.5 ? nextIndex : baseIndex)
                                                            if total > 0 {
                                                                let item = viewModel.progressPhotos[displayIndex]
                                                                let dateText: String = {
                                                                    let f = DateFormatter(); f.dateStyle = .medium; return f.string(from: item.date)
                                                                }()
                                                                Text(dateText)
                                                                    .font(.caption)
                                                                    .foregroundColor(.white)
                                                                    .padding(6)
                                                                    .background(Color.black.opacity(0.35))
                                                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                                                    .padding(8)
                                                            }
                                                        }
                                                    }
                                                    
                                                    // Tap to present full screen photo
                                                    Color.clear
                                                        .contentShape(Rectangle())
                                                        .onTapGesture {
                                                            showingFullScreenPhoto = true
                                                        }
                                                }
                                            }
                                            .frame(width: totalWidth, height: columnHeight, alignment: .top)
                                        }
                                        .frame(height: {
                                            // Provide a height so GeometryReader collapses to content
                                            // Use the available width from the parent by approximating half of the card width with spacing.
                                            // This outer frame will be overridden by the inner calculation when laid out.
                                            // Setting a placeholder height here ensures no overflow during initial layout.
                                            200
                                        }())

                                        // Scrubber slider
                                        Slider(value: $viewModel.currentPhotoIndex, in: 0...Double(max(0, viewModel.progressPhotos.count - 1))) {
                                            Text("Photo Index")
                                        } minimumValueLabel: {
                                            let firstDateText: String = {
                                                if let first = viewModel.progressPhotos.first?.date {
                                                    let f = DateFormatter(); f.dateFormat = "M/d"; return f.string(from: first)
                                                }
                                                return "--"
                                            }()
                                            Text(firstDateText)
                                                .foregroundStyle(themeManager.currentTheme.muted)
                                        } maximumValueLabel: {
                                            let lastDateText: String = {
                                                if let last = viewModel.progressPhotos.last?.date {
                                                    let f = DateFormatter(); f.dateFormat = "M/d"; return f.string(from: last)
                                                }
                                                return "--"
                                            }()
                                            Text(lastDateText)
                                                .foregroundStyle(themeManager.currentTheme.muted)
                                        }
                                        .tint(themeManager.currentTheme.primary)
                                        .onChange(of: viewModel.currentPhotoIndex) { _ in
                                            withAnimation(.easeInOut(duration: 0.3)) { /* animate scrubbing fade */ }
                                        }
                                    }
                                    .padding()
                                    .background(themeManager.currentTheme.surface)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .onAppear {
                                        let total = viewModel.progressPhotos.count
                                        guard total > 0 else { return }
                                        let last = Double(total - 1)
                                        if viewModel.currentPhotoIndex.isNaN || viewModel.currentPhotoIndex < 0 || viewModel.currentPhotoIndex > last || viewModel.currentPhotoIndex == 0 {
                                            viewModel.currentPhotoIndex = last
                                        }
                                    }
                                    .onChange(of: viewModel.progressPhotos.count) { _ in
                                        let total = viewModel.progressPhotos.count
                                        guard total > 0 else { return }
                                        let last = Double(total - 1)
                                        if viewModel.currentPhotoIndex.isNaN || viewModel.currentPhotoIndex < 0 || viewModel.currentPhotoIndex > last || viewModel.currentPhotoIndex == 0 {
                                            viewModel.currentPhotoIndex = last
                                        }
                                    }
                                    .fullScreenCover(isPresented: $showingFullScreenPhoto) {
                                        ZStack {
                                            themeManager.currentTheme.background.ignoresSafeArea()
                                            let total = viewModel.progressPhotos.count
                                            let clamped = max(0, min(Double(max(0, total - 1)), viewModel.currentPhotoIndex))
                                            let baseIndex = Int(floor(clamped))
                                            let nextIndex = min(baseIndex + 1, max(0, total - 1))
                                            let fraction = clamped - Double(baseIndex)
                                            let displayIndex = (fraction > 0.5 ? nextIndex : baseIndex)
                                            if total > 0 {
                                                let item = viewModel.progressPhotos[displayIndex]
                                                if let img = viewModel.loadImage(from: item.relativePath) {
                                                    Image(uiImage: img)
                                                        .resizable()
                                                        .scaledToFit()
                                                        .ignoresSafeArea()
                                                }
                                            }
                                            VStack {
                                                HStack {
                                                    Spacer()
                                                    Button(action: { showingFullScreenPhoto = false }) {
                                                        Image(systemName: "xmark.circle.fill")
                                                            .font(.system(size: 28))
                                                            .foregroundStyle(themeManager.currentTheme.textDefault)
                                                            .padding()
                                                    }
                                                }
                                                Spacer()
                                            }
                                        }
                                    }
                                }

                                // Weight chart (conditional)
                                if (authCoordinator.currentUser?.weight == true) && !viewModel.weightSeries.isEmpty {
                                    VStack(alignment: .leading, spacing: 12) {
                                        HStack {
                                            Text("Body Weight")
                                                .font(.headline)
                                                .foregroundStyle(themeManager.currentTheme.textDefault)
                                            Spacer()
                                        }
                                        ZStack {
                                            Chart {
                                                ForEach(viewModel.weightSeries.sorted(by: { $0.key < $1.key }), id: \.key) { (date, value) in
                                                    LineMark(
                                                        x: .value("Date", date),
                                                        y: .value("Weight", value)
                                                    )
                                                    .foregroundStyle(themeManager.currentTheme.primary)
                                                    .symbol(.circle)
                                                    .symbolSize(60)
                                                }
                                            }
                                            .chartXScale(domain: viewModel.prDateDomain ?? {
                                                let now = Date(); return (Calendar.current.date(byAdding: .day, value: -12, to: now) ?? now)...(Calendar.current.date(byAdding: .day, value: 1, to: now) ?? now)
                                            }())
                                            .chartYScale(domain: {
                                                let values = viewModel.weightSeries.values
                                                if let minV = values.min(), let maxV = values.max() {
                                                    let lower = minV - 5.0
                                                    let upper = maxV + 5.0
                                                    return lower...upper
                                                } else { return 0...100 }
                                            }())
                                            .chartXAxis {
                                                AxisMarks(values: .automatic(desiredCount: 5)) { value in
                                                    AxisGridLine().foregroundStyle(themeManager.currentTheme.textDefault.opacity(0.2))
                                                    AxisTick().foregroundStyle(themeManager.currentTheme.textDefault)
                                                    AxisValueLabel(format: .dateTime.month().day())
                                                        .foregroundStyle(themeManager.currentTheme.textDefault)
                                                }
                                            }
                                            .chartYAxis {
                                                AxisMarks() { value in
                                                    AxisGridLine().foregroundStyle(themeManager.currentTheme.textDefault.opacity(0.2))
                                                    AxisTick().foregroundStyle(themeManager.currentTheme.textDefault)
                                                    AxisValueLabel().foregroundStyle(themeManager.currentTheme.textDefault)
                                                }
                                            }
                                            .chartOverlay { proxy in
                                                GeometryReader { geo in
                                                    Rectangle()
                                                        .fill(Color.clear)
                                                        .contentShape(Rectangle())
                                                        .simultaneousGesture(
                                                            SpatialTapGesture()
                                                                .onEnded { value in
                                                                    let location = value.location
                                                                    if let xDate: Date = proxy.value(atX: location.x) {
                                                                        // Find nearest by date
                                                                        let sorted = viewModel.weightSeries.sorted { $0.key < $1.key }
                                                                        if let nearest = sorted.min(by: { abs($0.key.timeIntervalSince1970 - xDate.timeIntervalSince1970) < abs($1.key.timeIntervalSince1970 - xDate.timeIntervalSince1970) }) {
                                                                            selectedWeightDate = nearest.key
                                                                            if let px = proxy.position(forX: nearest.key), let py = proxy.position(forY: nearest.value) {
                                                                                selectedWeightPosition = CGPoint(x: px, y: py)
                                                                            }
                                                                        }
                                                                    }
                                                                }
                                                        )
                                                }
                                            }

                                            if let selDate = selectedWeightDate, let val = viewModel.weightSeries[selDate] {
                                                let unit = isImperial ? "lbs" : "kg"
                                                let text = String(format: "%.1f %@", val, unit)
                                                Text(text)
                                                    .font(.caption)
                                                    .padding(8)
                                                    .background(themeManager.currentTheme.surface)
                                                    .foregroundColor(themeManager.currentTheme.primary)
                                                    .cornerRadius(8)
                                                    .shadow(radius: 4)
                                                    .position(x: selectedWeightPosition.x, y: selectedWeightPosition.y + 30)
                                                    .onTapGesture { selectedWeightDate = nil }
                                            }
                                        }
                                    }
                                    .padding()
                                    .background(themeManager.currentTheme.surface)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                }

                                // Body fat chart (conditional)
                                if (authCoordinator.currentUser?.fat == true) && !viewModel.bodyFatSeries.isEmpty {
                                    VStack(alignment: .leading, spacing: 12) {
                                        HStack {
                                            Text("Body Fat %")
                                                .font(.headline)
                                                .foregroundStyle(themeManager.currentTheme.textDefault)
                                            Spacer()
                                        }
                                        ZStack {
                                            Chart {
                                                ForEach(viewModel.bodyFatSeries.sorted(by: { $0.key < $1.key }), id: \.key) { (date, value) in
                                                    LineMark(
                                                        x: .value("Date", date),
                                                        y: .value("Body Fat", value)
                                                    )
                                                    .foregroundStyle(themeManager.currentTheme.secondary)
                                                    .symbol(.square)
                                                    .symbolSize(60)
                                                }
                                            }
                                            .chartXScale(domain: viewModel.prDateDomain ?? {
                                                let now = Date(); return (Calendar.current.date(byAdding: .day, value: -12, to: now) ?? now)...(Calendar.current.date(byAdding: .day, value: 1, to: now) ?? now)
                                            }())
                                            .chartYScale(domain: {
                                                let values = viewModel.bodyFatSeries.values
                                                if let minV = values.min(), let maxV = values.max() {
                                                    let lower = minV - 2.0
                                                    let upper = maxV + 2.0
                                                    return lower...upper
                                                } else { return 0...50 }
                                            }())
                                            .chartXAxis {
                                                AxisMarks(values: .automatic(desiredCount: 5)) { value in
                                                    AxisGridLine().foregroundStyle(themeManager.currentTheme.textDefault.opacity(0.2))
                                                    AxisTick().foregroundStyle(themeManager.currentTheme.textDefault)
                                                    AxisValueLabel(format: .dateTime.month().day())
                                                        .foregroundStyle(themeManager.currentTheme.textDefault)
                                                }
                                            }
                                            .chartYAxis {
                                                AxisMarks() { value in
                                                    AxisGridLine().foregroundStyle(themeManager.currentTheme.textDefault.opacity(0.2))
                                                    AxisTick().foregroundStyle(themeManager.currentTheme.textDefault)
                                                    AxisValueLabel().foregroundStyle(themeManager.currentTheme.textDefault)
                                                }
                                            }
                                            .chartOverlay { proxy in
                                                GeometryReader { geo in
                                                    Rectangle()
                                                        .fill(Color.clear)
                                                        .contentShape(Rectangle())
                                                        .simultaneousGesture(
                                                            SpatialTapGesture()
                                                                .onEnded { value in
                                                                    let location = value.location
                                                                    if let xDate: Date = proxy.value(atX: location.x) {
                                                                        let sorted = viewModel.bodyFatSeries.sorted { $0.key < $1.key }
                                                                        if let nearest = sorted.min(by: { abs($0.key.timeIntervalSince1970 - xDate.timeIntervalSince1970) < abs($1.key.timeIntervalSince1970 - xDate.timeIntervalSince1970) }) {
                                                                            selectedFatDate = nearest.key
                                                                            if let px = proxy.position(forX: nearest.key), let py = proxy.position(forY: nearest.value) {
                                                                                selectedFatPosition = CGPoint(x: px, y: py)
                                                                            }
                                                                        }
                                                                    }
                                                                }
                                                        )
                                                }
                                            }

                                            if let selDate = selectedFatDate, let val = viewModel.bodyFatSeries[selDate] {
                                                let text = String(format: "%.1f%%", val)
                                                Text(text)
                                                    .font(.caption)
                                                    .padding(8)
                                                    .background(themeManager.currentTheme.surface)
                                                    .foregroundColor(themeManager.currentTheme.secondary)
                                                    .cornerRadius(8)
                                                    .shadow(radius: 4)
                                                    .position(x: selectedFatPosition.x, y: selectedFatPosition.y + 30)
                                                    .onTapGesture { selectedFatDate = nil }
                                            }
                                        }
                                    }
                                    .padding()
                                    .background(themeManager.currentTheme.surface)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                            }
                            .padding()
                        }
                        .task {
                            AuthCoordinatorProvider.instance = authCoordinator
                            await viewModel.loadDashboardData()
                            await viewModel.loadExerciseLog()
                            DispatchQueue.main.async { 
                                let total = viewModel.progressPhotos.count
                                guard total > 0 else { return }
                                let last = Double(total - 1)
                                if viewModel.currentPhotoIndex.isNaN || viewModel.currentPhotoIndex < 0 || viewModel.currentPhotoIndex > last || viewModel.currentPhotoIndex == 0 {
                                    viewModel.currentPhotoIndex = last
                                }
                            }
                        }
                        .onChange(of: viewModel.dateSelection) { _ in
                            Task {
                                await viewModel.loadDashboardData()
                                await viewModel.loadExerciseLog()
                                DispatchQueue.main.async { 
                                    let total = viewModel.progressPhotos.count
                                    guard total > 0 else { return }
                                    let last = Double(total - 1)
                                    if viewModel.currentPhotoIndex.isNaN || viewModel.currentPhotoIndex < 0 || viewModel.currentPhotoIndex > last || viewModel.currentPhotoIndex == 0 {
                                        viewModel.currentPhotoIndex = last
                                    }
                                }
                            }
                        }
                        .onReceive(authCoordinator.$currentUser) { user in
                            if let id = user?.id {
                                viewModel.updateUser(id: Int64(id))
                                Task {
                                    await viewModel.loadDashboardData()
                                    await viewModel.loadExerciseLog()
                                }
                            }
                        }
                    }
                    Spacer()
                }
            }
            .onChange(of: coordinator.currentStep) { step in
                // When navigating back to Dashboard, prefer newest photo
                if case .dashboard = step {
                    let total = viewModel.progressPhotos.count
                    guard total > 0 else { return }
                    let last = Double(total - 1)
                    if viewModel.currentPhotoIndex.isNaN || viewModel.currentPhotoIndex < 0 || viewModel.currentPhotoIndex > last || viewModel.currentPhotoIndex == 0 {
                        viewModel.currentPhotoIndex = last
                    }
                }
            }
            .onChange(of: scenePhase) { phase in
                guard phase == .active else { return }
                let total = viewModel.progressPhotos.count
                guard total > 0 else { return }
                let last = Double(total - 1)
                if viewModel.currentPhotoIndex.isNaN || viewModel.currentPhotoIndex < 0 || viewModel.currentPhotoIndex > last || viewModel.currentPhotoIndex == 0 {
                    viewModel.currentPhotoIndex = last
                }
            }
        }
    }

    // MARK: - Subviews

    private var dateRangeButton: some View {
        Button {
            viewModel.showingDatePicker = true
        } label: {
            HStack {
                Text(viewModel.dateRangeLabel).fontWeight(.semibold)
                Image(systemName: "chevron.down")
            }
            .frame(maxWidth: .infinity)
            .padding()
            .foregroundColor(themeManager.currentTheme.primary)
            .background(themeManager.currentTheme.primary.opacity(0.1))
            .cornerRadius(8)
        }
        .sheet(isPresented: $viewModel.showingDatePicker) {
            NavigationStack {
                DateRangePickerView(
                    initialSelection: viewModel.dateSelection,
                    onDone: {
                        viewModel.dateSelection = $0
                        viewModel.showingDatePicker = false
                    },
                    onCancel: { viewModel.showingDatePicker = false }
                )
            }
        }
    }

    private var metricTiles: some View {
        VStack(spacing: 16) {
            HStack {
                let weight = viewModel.formattedWeight(isImperial: isImperial)
                MetricTile(title: "Lifted", icon: "scalemass", value: weight.value, unit: weight.unit)

                let distance = viewModel.formattedDistance(isImperial: isImperial)
                MetricTile(title: "Traveled", icon: "figure.walk.motion", value: distance.value, unit: distance.unit)
            }

            HStack {
                MetricTile(title: "Duration", icon: "clock", value: viewModel.formattedDuration(), unit: nil)

                let freq = viewModel.formattedWorkoutFrequency()
                MetricTile(title: "Avg Workouts", icon: "calendar", value: freq.value, unit: freq.unit)
            }
        }
    }

    private var exerciseLogSection: some View {
        Group {
            if !viewModel.completedExercises.isEmpty {
                VStack(alignment: .leading, spacing: 12) {

                    HStack {
                        Text("Exercise Log")
                            .font(.headline)
                            .foregroundStyle(themeManager.currentTheme.textDefault)
                        Spacer()
                        if viewModel.isLoadingExerciseLog {
                            ProgressView()
                        }
                    }

                    if let error = viewModel.exerciseLogError {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(themeManager.currentTheme.error)
                    }

                    Picker("Exercise", selection: $viewModel.selectedExerciseId) {
                        ForEach(viewModel.completedExercises) { opt in
                            Text(opt.name).tag(Optional(opt.id))
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: viewModel.selectedExerciseId) { id in
                        guard let id else { return }
                        Task { await viewModel.loadPRPoints(for: id) }
                    }

                    SetsChartView(points: viewModel.prPoints, xDomain: viewModel.prDateDomain)
                        .environmentObject(themeManager)
                }
                .padding()
                .background(themeManager.currentTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            } else if viewModel.hasWorkoutRoutines && !viewModel.hasAnySessions {
                // Y: User has routines but no sessions yet
                VStack(spacing: 12) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 40))
                        .foregroundColor(themeManager.currentTheme.primary)
                    Text("Start logging your workouts")
                        .font(.headline)
                        .foregroundColor(themeManager.currentTheme.textDefault)
                    Text("You have routines set up. Get your first workout session in to start tracking progress.")
                        .font(.callout)
                        .foregroundColor(themeManager.currentTheme.muted)
                        .multilineTextAlignment(.center)
                    Button {
                        coordinator.currentStep = .calendar
                    } label: {
                        HStack {
                            Image(systemName: "calendar")
                            Text("Open Calendar")
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(themeManager.currentTheme.surface)
                        .cornerRadius(8)
                    }
                    .padding(.top, 6)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.horizontal)
                .padding(.vertical, 24)
            } else {
                // Z: No routines yet — existing onboarding card
                VStack(spacing: 8) {
                    Image(systemName: "dumbbell.fill")
                        .font(.system(size: 44))
                        .foregroundColor(themeManager.currentTheme.textDefault)
                    Text("Welcome to SimplyFitness")
                        .font(.title3).bold()
                        .foregroundColor(themeManager.currentTheme.textDefault)
                    Text("Looking to get started? Let's create a workout routine!")
                        .foregroundColor(themeManager.currentTheme.muted)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 16)

                Button {
                    coordinator.currentStep = .workout
                } label: {
                    HStack {
                        Image(systemName: "plus")
                        Text("Create a routine")
                            .foregroundColor(themeManager.currentTheme.textDefault)
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(themeManager.currentTheme.surface)
                    .cornerRadius(8)
                }
                .padding(16)
                .padding(.top, 6)
                .padding(.bottom, 24)
            }
        }
    }
}

// MARK: - MetricTile

struct MetricTile: View {
    @EnvironmentObject var themeManager: ThemeManager

    let title: String
    let icon: String
    let value: String
    let unit: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.callout)
                .bold()
                .foregroundStyle(themeManager.currentTheme.textDefault)
                .frame(maxWidth: .infinity, alignment: .center)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Image(systemName: icon)
                Text(value)
                if let unit { Text(unit) }
            }
            .font(.callout)
            .foregroundStyle(themeManager.currentTheme.textDefault)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(.vertical)
        .background(themeManager.currentTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - DateRangePickerView

struct DateRangePickerView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss

    @State private var customStart: Date
    @State private var customEnd: Date

    @State private var customStartOptional: Date?
    @State private var customEndOptional: Date?

    let initialSelection: DashboardViewModel.DateRangeSelection
    let onDone: (DashboardViewModel.DateRangeSelection) -> Void
    let onCancel: () -> Void

    init(
        initialSelection: DashboardViewModel.DateRangeSelection,
        onDone: @escaping (DashboardViewModel.DateRangeSelection) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.initialSelection = initialSelection
        self.onDone = onDone
        self.onCancel = onCancel

        let now = Date()
        let defaultStart = Calendar.current.date(byAdding: .day, value: -12, to: now) ?? now
        let defaultEnd = Calendar.current.date(byAdding: .day, value: 1, to: now) ?? now
        switch initialSelection {
        case .lifetime:
            _customStart = State(initialValue: defaultStart)
            _customEnd = State(initialValue: defaultEnd)
        case let .custom(start, end):
            _customStart = State(initialValue: start)
            _customEnd = State(initialValue: end)
        }
    }

    var body: some View {
        ZStack {
            themeManager.currentTheme.background.ignoresSafeArea()
            VStack(spacing: 16) {
                HStack(){
                    Text("Select Date Range")
                        .foregroundColor(themeManager.currentTheme.textDefault)
                        .font(.largeTitle)
                        .bold()
                        .padding(.top, 16)
                }
                
                Section("Custom Range") {
                    DateRangeCalendarView(
                        startDate: $customStartOptional,
                        endDate: $customEndOptional,
                        initialStart: customStart,
                        initialEnd: customEnd
                    )
                }
                .bold()
                .foregroundColor(themeManager.currentTheme.textDefault)
                .padding(.horizontal)
                .cornerRadius(12)
                
                Spacer()
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        if let start = customStartOptional, let end = customEndOptional {
                            onDone(.custom(start.startOfDay, end.endOfDay))
                        }
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
            .onAppear {
                customStartOptional = customStart
                customEndOptional = customEnd
            }
        }
    }
}

// MARK: - Custom Calendar View

struct DateRangeCalendarView: View {
    
    @EnvironmentObject var themeManager: ThemeManager
    @Binding var startDate: Date?
    @Binding var endDate: Date?

    var initialStart: Date
    var initialEnd: Date

    @State private var displayedMonth: Date
    private let calendar = Calendar.current
    private let haptic = UIImpactFeedbackGenerator(style: .light)

    init(startDate: Binding<Date?>, endDate: Binding<Date?>, initialStart: Date, initialEnd: Date) {
        self._startDate = startDate
        self._endDate = endDate
        self.initialStart = initialStart
        self.initialEnd = initialEnd
        _displayedMonth = State(initialValue: initialStart.startOfDay)
    }

    var body: some View {
        VStack(spacing: 12) {
            header
            
            let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
            
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(weekdays, id: \.self) {
                    Text($0)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                ForEach(daysInMonth, id: \.self) { date in
                    dayCell(for: date)
                }.padding(0)
            }
        }
        .padding(.vertical)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Button {
                displayedMonth = calendar.date(byAdding: .month, value: -1, to: displayedMonth)!
            } label: {
                Image(systemName: "chevron.left")
            }

            Spacer()

            Text(displayedMonth, format: .dateTime.month().year())
                .font(.headline)

            Spacer()

            Button {
                displayedMonth = calendar.date(byAdding: .month, value: 1, to: displayedMonth)!
            } label: {
                Image(systemName: "chevron.right")
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Day Cell

    private func dayCell(for date: Date) -> some View {
        let isStart = startDate.map { calendar.isDate(date, inSameDayAs: $0) } ?? false
        let isEnd = endDate.map { calendar.isDate(date, inSameDayAs: $0) } ?? false
        let inRange = isBetween(date)

        return Text("\(calendar.component(.day, from: date))")
            .frame(maxWidth: .infinity)
            .frame(height: 36)
            .background(
                ZStack {
                    if inRange {
                        Rectangle().fill(themeManager.currentTheme.primary.opacity(0.25))
                    }
                    if isStart && isEnd {
                        Capsule().fill(themeManager.currentTheme.primary)
                    } else if isStart {
                        Rectangle()
                            .fill(themeManager.currentTheme.primary)
                            .clipShape(RoundedCornersShape(corners: [.topLeft, .bottomLeft], radius: 18))
                    } else if isEnd {
                        Rectangle()
                            .fill(themeManager.currentTheme.primary)
                            .clipShape(RoundedCornersShape(corners: [.topRight, .bottomRight], radius: 18))
                    }
                }
            )
            .foregroundStyle(themeManager.currentTheme.textDefault)
            .onTapGesture { handleTap(date) }
    }


    // MARK: - Selection Logic

    private func handleTap(_ date: Date) {
        haptic.impactOccurred()
        if startDate == nil || (startDate != nil && endDate != nil) {
            startDate = date
            endDate = nil
            displayedMonth = date.startOfDay
        } else if let start = startDate, date < start {
            startDate = date
        } else {
            endDate = date
        }
    }

    private func isBetween(_ date: Date) -> Bool {
        guard let start = startDate, let end = endDate else { return false }
        return date > start && date < end
    }

    // MARK: - Date Math

    private var daysInMonth: [Date] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: displayedMonth),
              let firstWeek = calendar.dateInterval(of: .weekOfMonth, for: monthInterval.start)
        else { return [] }

        return calendar.generateDates(
            inside: DateInterval(start: firstWeek.start, end: monthInterval.end),
            matching: DateComponents(hour: 0)
        )
    }

    private var weekdays: [String] {
        calendar.shortWeekdaySymbols
    }
}

// MARK: - Calendar Helper

extension Calendar {
    func generateDates(
        inside interval: DateInterval,
        matching components: DateComponents
    ) -> [Date] {
        var dates: [Date] = []
        dates.append(interval.start)

        enumerateDates(
            startingAfter: interval.start,
            matching: components,
            matchingPolicy: .nextTime
        ) { date, _, stop in
            guard let date, date < interval.end else {
                stop = true
                return
            }
            dates.append(date)
        }
        return dates
    }
}

struct RoundedCornersShape: Shape {
    var corners: UIRectCorner
    var radius: CGFloat

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

