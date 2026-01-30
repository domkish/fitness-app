//
//  DayCalendarView.swift
//  fitness-app
//
//  Created by Assistant on 1/30/26.
//

import SwiftUI
import PhotosUI

struct DayCalendarView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var authCoordinator: AuthCoordinator

    let repository: CalendarEntryRepository
    let workoutRepository = CalendarWorkoutRepository(dbQueue: DatabaseQueueProvider.shared.dbQueue)

    @State private var selectedDate: Date = Calendar.current.startOfDay(for: Date())
    @State private var entry: CalendarEntryRecord?
    @State private var priorEntry: CalendarEntryRecord?
    @State private var showingCheckin = false
    @State private var workouts: [CalendarWorkoutRecord] = []

    private var isTodayOrPast: Bool {
        let today = Calendar.current.startOfDay(for: Date())
        return selectedDate <= today
    }

    private var isTodayOrFuture: Bool {
        let today = Calendar.current.startOfDay(for: Date())
        return selectedDate >= today
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack() {
                Button(action: { shiftDay(-1) }) { Image(systemName: "chevron.left") }
                Spacer()
                Text(selectedDate.formatted(date: .abbreviated, time: .omitted))
                    .font(.headline)
                    .foregroundColor(themeManager.currentTheme.textDefault)
                Spacer()
                Button(action: { shiftDay(1) }) { Image(systemName: "chevron.right") }
            }
            .padding(.bottom, 8)

            ZStack {
                // Center: Today button always centered
                Button("Today") { selectedDate = Calendar.current.startOfDay(for: Date()) }
                    .foregroundColor(themeManager.currentTheme.primary)

                // Leading: Check-in button (today or past)
                HStack {
                    if isTodayOrPast {
                        Button(action: { showingCheckin = true }) {
                            HStack(spacing: 6) {
                                Image(systemName: entry != nil ? "checkmark.seal.fill" : "pencil.and.list.clipboard")
                            }
                            .padding(.horizontal, 12)
                            .foregroundColor(entry != nil ? themeManager.currentTheme.primary : themeManager.currentTheme.muted)
                            .clipShape(Capsule())
                        }
                    }
                    Spacer()
                }

                // Trailing: + Workout button (today or future)
                HStack {
                    Spacer()
                    if isTodayOrFuture {
                        Button(action: { /* TODO: present add workout flow */ }) {
                            HStack(spacing: 6) {
                                Image(systemName: "plus")
                                Text("Workout")
                            }
                        }
                    }
                }
            }

            if !workouts.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Scheduled Workouts")
                        .font(.subheadline)
                        .foregroundColor(themeManager.currentTheme.textDefault)
                    ForEach(workouts, id: \.id) { w in
                        HStack {
                            Image(systemName: "figure.strengthtraining.traditional")
                            Text("Workout #\(w.workoutId)")
                        }
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(themeManager.currentTheme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }

            Spacer()
        }
        .padding()
        .task(id: selectedDate) {
            await loadData()
        }
        .sheet(isPresented: $showingCheckin) {
            DailyCheckinSheet(
                date: selectedDate,
                existing: entry,
                prior: priorEntry,
                repository: repository
            ) { saved in
                showingCheckin = false
                Task { await loadData() }
            }
            .environmentObject(themeManager)
            .environmentObject(authCoordinator)
        }
    }

    private var checkinBackground: some View {
        let hasEntry = (entry != nil)
        return (hasEntry ? themeManager.currentTheme.important : themeManager.currentTheme.muted)
    }

    private func shiftDay(_ delta: Int) {
        if let d = Calendar.current.date(byAdding: .day, value: delta, to: selectedDate) {
            selectedDate = Calendar.current.startOfDay(for: d)
        }
    }

    private func loadData() async {
        guard let userId = authCoordinator.currentUser?.id else { return }
        do {
            let id64 = Int64(userId)
            entry = try repository.entry(for: id64, on: selectedDate)
            priorEntry = try repository.mostRecentPriorEntry(before: selectedDate, userId: id64)
            workouts = try workoutRepository.workouts(on: selectedDate, userId: id64)
        } catch {
            print("[DayCalendarView] loadData error: \(error)")
        }
    }
}

// MARK: - Daily Check-in Sheet
struct DailyCheckinSheet: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var authCoordinator: AuthCoordinator

    let date: Date
    let existing: CalendarEntryRecord?
    let prior: CalendarEntryRecord?
    let repository: CalendarEntryRepository
    var onSaved: (Bool) -> Void

    @State private var weightText: String = ""
    @State private var bodyFatText: String = ""
    @State private var pickedPhoto: PhotosPickerItem?
    @State private var localPhotoPath: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Metrics") {
                    TextField("Body Weight", text: $weightText)
                        .keyboardType(.decimalPad)
                    TextField("Body Fat %", text: $bodyFatText)
                        .keyboardType(.decimalPad)
                }
                Section("Progress Photo") {
                    PhotosPicker(selection: $pickedPhoto, matching: .images) {
                        HStack {
                            Image(systemName: "photo")
                            Text(localPhotoPath == nil ? "Select Photo" : "Replace Photo")
                        }
                    }
                }
            }
            .onAppear(perform: prefill)
            .onChange(of: pickedPhoto) { _, newValue in
                Task { await savePickedPhoto(newValue) }
            }
            .navigationTitle("Daily Check‑in")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onSaved(false) }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await save() } }
                        .disabled(!canSave)
                }
            }
        }
    }

    private var canSave: Bool {
        // At least one field should be present
        return !(weightText.isEmpty && bodyFatText.isEmpty && localPhotoPath == nil)
    }

    private func prefill() {
        // Existing entry
        if let e = existing {
            if let w = e.weight { weightText = String(w) }
            if let bf = e.bodyFat { bodyFatText = String(bf) }
            localPhotoPath = e.progressPhoto
            return
        }
        // Prefill from prior if empty
        if let p = prior {
            if let w = p.weight { weightText = String(w) }
            if let bf = p.bodyFat { bodyFatText = String(bf) }
        }
    }

    private func savePickedPhoto(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        do {
            if let data = try await item.loadTransferable(type: Data.self) {
                localPhotoPath = try saveProgressPhotoData(data)
            }
        } catch {
            print("[DailyCheckinSheet] photo pick error: \(error)")
        }
    }

    private func saveProgressPhotoData(_ data: Data) throws -> String {
        let fm = FileManager.default
        let docs = try fm.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let folder = docs.appendingPathComponent("progress_photos", isDirectory: true)
        try fm.createDirectory(at: folder, withIntermediateDirectories: true)
        let filename = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-").replacingOccurrences(of: ".", with: "-") + ".jpg"
        let url = folder.appendingPathComponent(filename)
        try data.write(to: url, options: .atomic)
        return "progress_photos/\(filename)"
    }

    private func save() async {
        guard let user = authCoordinator.currentUser else { return }
        let id64 = Int64(user.id)

        // Parse numeric fields
        let weight = Double(weightText)
        let bodyFat = Double(bodyFatText)

        // Build domain and persist
        let domain = CalendarEntry(
            id: existing?.id,
            userId: id64,
            date: CalendarEntry.date(from: CalendarEntry.dbString(from: date)) ?? date,
            weight: weight,
            bodyFat: bodyFat,
            progressPhoto: localPhotoPath,
            createdAt: existing?.createdAt ?? Date(),
            updatedAt: Date(),
            deletedAt: existing?.deletedAt
        )

        do {
            try repository.upsert(domain)
            onSaved(true)
        } catch {
            print("[DailyCheckinSheet] save error: \(error)")
        }
    }
}

