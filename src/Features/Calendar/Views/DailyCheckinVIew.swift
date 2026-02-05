//
//  DailyCheckinVIew.swift
//  fitness-app
//
//  Created by Dominic Kish on 2/4/26.
//
import SwiftUI
import PhotosUI

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

    private enum Field: Hashable { case weight, bodyFat }
    @FocusState private var focusedField: Field?

    private var weightUnit: String {
        authCoordinator.currentUser?.isImperial == true ? "lbs" : "kg"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                themeManager.currentTheme.background
                    .ignoresSafeArea()
                Form {
                    metricsSection
                    Section("Progress Photo") {
                        PhotosPicker(selection: $pickedPhoto, matching: .images) {
                            HStack {
                                Image(systemName: "photo")
                                Text(localPhotoPath == nil ? "Select Photo" : "Replace Photo")
                                    .foregroundColor(themeManager.currentTheme.textDefault)
                            }
                        }
                    }
                    .scrollContentBackground(.hidden)
                    .listRowBackground(themeManager.currentTheme.surface)
                    .foregroundColor(themeManager.currentTheme.muted)
                }
                .scrollContentBackground(.hidden)
                .onAppear(perform: prefill)
                .onChange(of: existing?.id) { _, _ in
                    prefill()
                }
                .onChange(of: prior?.id) { _, _ in
                    // Only prefill remaining empty fields so we don't overwrite user edits.
                    prefill()
                }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { onSaved(false) }
                    }
                    ToolbarItem(placement: .principal) {
                        Text("Daily Check-in")
                            .foregroundColor(themeManager.currentTheme.textDefault)
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") { Task { await save() } }
                            .disabled(!canSave)
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("CustomNumericKeyboardNext"))) { _ in
                switch focusedField {
                case .weight:
                    focusedField = .bodyFat
                default:
                    focusedField = nil
                }
            }
        }
    }

    @ViewBuilder
    private var metricsSection: some View {
        Section("Metrics") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Body Weight")
                InputWithSuffixDecimal(
                    title: "Body Weight",
                    digits: $weightText,
                    suffix: weightUnit,
                    maxValue: 999.9,
                    decimal: true
                )
                .focused($focusedField, equals: .weight)

                Text("Body Fat %")
                InputWithSuffixDecimal(
                    title: "Body Fat %",
                    digits: $bodyFatText,
                    suffix: "%",
                    maxValue: 99.9,
                    decimal: true
                )
                .focused($focusedField, equals: .bodyFat)
            }
            .foregroundColor(themeManager.currentTheme.textDefault)
            .listRowBackground(themeManager.currentTheme.surface)
        }
        .foregroundColor(themeManager.currentTheme.muted)
    }

    private var canSave: Bool {
        // At least one field should be present
        return !(weightText.isEmpty && bodyFatText.isEmpty && localPhotoPath == nil)
    }

    private func prefill() {
        // Existing entry
        if let e = existing {
            if weightText.isEmpty, let w = e.weight { weightText = String(Int((w * 10.0).rounded())) }
            if bodyFatText.isEmpty, let bf = e.bodyFat { bodyFatText = String(Int((bf * 10.0).rounded())) }
            if localPhotoPath == nil { localPhotoPath = e.progressPhoto }
            return
        }
        // Prefill from prior if empty
        if let p = prior {
            if weightText.isEmpty, let w = p.weight { weightText = String(Int((w * 10.0).rounded())) }
            if bodyFatText.isEmpty, let bf = p.bodyFat { bodyFatText = String(Int((bf * 10.0).rounded())) }
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
        let weight = Double(weightText).map { $0 / 10.0 }
        let bodyFat = Double(bodyFatText).map { $0 / 10.0 }

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
