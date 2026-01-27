//
//  ExerciseAddView.swift
//  fitness-app
//
//  Created by Dominic Kish on 1/26/26.
//
import SwiftUI
import GRDB

struct ExerciseAddView: View {
    // Dependencies
    private let dbQueue = DatabaseQueueProvider.shared.dbQueue
    private let exerciseRepo: ExerciseRepository
    private let userRepo: UserRepository

    // Form State
    @State private var name: String = ""
    @State private var showAdvanced: Bool = false

    // Multi-select state for tags
    @State private var selectedUnitTagIDs: Set<Int64> = []
    @State private var selectedGroupTagIDs: Set<Int64> = []
    @State private var selectedCategoryTagIDs: Set<Int64> = []
    @State private var selectedWorkoutTagIDs: Set<Int64> = []

    // Loaded tags
    @State private var unitTags: [ExerciseTagRecord] = []
    @State private var groupTags: [ExerciseTagRecord] = []
    @State private var categoryTags: [ExerciseTagRecord] = []
    @State private var workoutTags: [ExerciseTagRecord] = []
    @State private var _unitRowsStorage: [UnitRowWrapper] = []

    // UI
    @Environment(\.dismiss) private var dismiss
    @State private var isSaving = false
    @State private var errorMessage: String?

    init() {
        let db = DatabaseQueueProvider.shared.dbQueue
        self.exerciseRepo = ExerciseRepository(dbQueue: db)
        self.userRepo = UserRepository(dbQueue: db)
    }

    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    HStack {
                        Text("Add Exercise")
                            .font(.title)
                            .bold()
                        Spacer()
                    }
                    .padding(.horizontal)

                    // Name card (required)
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Exercise Name").bold()
                        TextField("Required", text: $name)
                            .textFieldStyle(.roundedBorder)
                    }
                    .padding()
                    .background(AppColors.surface)
                    .cornerRadius(16)
                    .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
                    .padding(.horizontal)

                    // Units card (required)
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Unit(s)").bold()
                            Spacer()
                        }
                        NavigationLink {
                            MultiSelectListView(
                                title: "Unit(s)",
                                items: _unitRowsStorage.map { ($0.id, $0.name) },
                                selection: $selectedUnitTagIDs
                            )
                        } label: {
                            HStack {
                                Text(unitsSummary)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Image(systemName: "chevron.right").foregroundColor(.secondary)
                            }
                            .contentShape(Rectangle())
                        }
                        Rectangle()
                            .fill(Color.secondary.opacity(0.3))
                            .frame(height: 1)
                            .overlay(
                                Rectangle()
                                    .stroke(style: StrokeStyle(lineWidth: 1, dash: [4]))
                                    .foregroundColor(AppColors.background)
                            )
                            .padding(.vertical, 6)
                        Text("Select the unit(s) of measurement you'd be tracking for this exercise.")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(AppColors.surface)
                    .cornerRadius(16)
                    .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
                    .padding(.horizontal)

                    // Advanced options (collapsible)
                    VStack(spacing: 0) {
                        Button(action: { withAnimation { showAdvanced.toggle() } }) {
                            HStack {
                                Text("Advanced Options").bold()
                                Spacer()
                                Image(systemName: showAdvanced ? "chevron.up" : "chevron.down")
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(AppColors.surface)
                        }
                        if showAdvanced {
                            VStack(alignment: .leading, spacing: 16) {
                                MultiSelectFieldRow(title: "Muscle Group(s)", items: groupTags, selection: $selectedGroupTagIDs)
                                MultiSelectFieldRow(title: "Category(s)", items: categoryTags, selection: $selectedCategoryTagIDs)
                                MultiSelectFieldRow(title: "Common Workout(s)", items: workoutTags, selection: $selectedWorkoutTagIDs, nameTransform: { $0 + " Day" })
                            }
                            .padding()
                            .background(AppColors.surface)
                        }
                    }
                    .cornerRadius(16)
                    .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
                    .padding(.horizontal)

                    // Error message
                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.footnote)
                            .padding(.horizontal)
                    }

                    // Save button
                    Button(action: { Task { await save() } }) {
                        HStack {
                            if isSaving { ProgressView() }
                            Text(isSaving ? "Saving…" : "Save Exercise").bold()
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background((name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selectedUnitTagIDs.isEmpty) ? Color.gray.opacity(0.3) : AppColors.surface)
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    .disabled(isSaving || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selectedUnitTagIDs.isEmpty)

                    Spacer(minLength: 16)
                }
                .padding(.top, 24)
            }
        }
        .task { await loadTags() }
        .onChange(of: selectedUnitTagIDs) { ids in
            print("[Add] Units selection changed: \(ids)")
        }
    }

    private var unitValid: Bool { !selectedUnitTagIDs.isEmpty }
    private var unitsSummary: String {
        if selectedUnitTagIDs.isEmpty { return "None" }
        let abbrevs = _unitRowsStorage.filter { selectedUnitTagIDs.contains($0.id) }
            .compactMap { $0.abbreviation }
        if abbrevs.isEmpty { return "None" }
        if abbrevs.count <= 3 { return abbrevs.joined(separator: ", ") }
        return "\(abbrevs.count) selected"
    }

    // MARK: - Actions
    private func save() async {
        print("[Add] save() tapped — name: \(name), units: \(selectedUnitTagIDs)")
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { print("[Add] save() aborted — empty name"); return }
        guard !selectedUnitTagIDs.isEmpty else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            guard let user = try await userRepo.fetchUser() else {
                errorMessage = "No current user found."
                print("[Add] save() aborted — no current user")
                return
            }
            // Create and persist the exercise via ExerciseRecord
            let now = Date()
            var record = ExerciseRecord(
                userId: Int64(user.id),
                name: name,
                locked: false,
                deletedAt: nil,
                createdAt: now,
                updatedAt: now
            )
            try await dbQueue.write { db in
                try record.insert(db)
                // Ensure the generated id is captured
                record.id = Int64(db.lastInsertedRowID)
            }
            print("[Add] inserted exercise id: \(String(describing: record.id))")

            // Attach units and non-unit tags using the inserted id
            if let insertedId = record.id {
                // Units first
                try await dbQueue.write { db in
                    print("[Add] Saving unit pivots for exerciseId: \(insertedId), unitIds: \(selectedUnitTagIDs)")
                    try ExerciseUnitPivotRecord
                        .filter(ExerciseUnitPivotRecord.Columns.exerciseId == insertedId)
                        .deleteAll(db)
                    for unitId in selectedUnitTagIDs {
                        var pivot = ExerciseUnitPivotRecord(id: nil, exerciseId: insertedId, unitId: unitId, createdAt: Date(), updatedAt: Date())
                        try pivot.insert(db)
                    }
                }
                // Then non-unit tags
                try await attachSelectedNonUnitTags(toExerciseId: insertedId)
            }

            await MainActor.run { dismiss() }
        } catch {
            errorMessage = "Failed to save exercise: \(error)"
        }
    }

    private func loadTags() async {
        do {
            try await dbQueue.read { db in
                // Units: fetch all from `units` table excluding gallons/liters and order by id
                struct UnitRow: FetchableRecord, Decodable { let id: Int64; let name: String; let abbreviation: String? }
                let unitRows = try UnitRow.fetchAll(
                    db,
                    sql: """
                    SELECT id, name, abbreviation
                    FROM units
                    WHERE LOWER(name) NOT IN ('gallons', 'gallon', 'liters', 'liter', 'l', 'gal')
                    ORDER BY id ASC
                    """
                )
                // Map units into ExerciseTagRecord-like objects for selection view (uses name)
                self.unitTags = unitRows.map { row in
                    ExerciseTagRecord(id: row.id, name: row.name, type: "unit", createdAt: Date(), updatedAt: Date())
                }
                // Store unit rows in an associated state for summary display
                self._unitRowsStorage = unitRows.map { UnitRowWrapper(id: $0.id, name: $0.name, abbreviation: $0.abbreviation) }

                // Muscle Groups/Categories/Workout from exercise_tags where type = 'Group'/'Category'/'Workout'
                self.groupTags = try ExerciseTagRecord
                    .filter(ExerciseTagRecord.Columns.type == "Group")
                    .order(ExerciseTagRecord.Columns.name.asc)
                    .fetchAll(db)

                self.categoryTags = try ExerciseTagRecord
                    .filter(ExerciseTagRecord.Columns.type == "Category")
                    .order(ExerciseTagRecord.Columns.name.asc)
                    .fetchAll(db)

                self.workoutTags = try ExerciseTagRecord
                    .filter(ExerciseTagRecord.Columns.type == "Workout")
                    .order(ExerciseTagRecord.Columns.name.asc)
                    .fetchAll(db)
            }
        } catch {
            errorMessage = "Failed to load tags: \(error)"
        }
    }

    private func attachSelectedNonUnitTags(toExerciseId exId: Int64) async throws {
        try await dbQueue.write { db in
            func attach(_ ids: Set<Int64>) throws {
                for tagId in ids {
                    var pivot = ExerciseTagPivotRecord(id: nil, exerciseId: exId, exerciseTagId: tagId, createdAt: Date(), updatedAt: Date())
                    try pivot.insert(db)
                }
            }
            // Units are persisted in exercise_unit_pivots; only attach non-unit tags here
            try attach(selectedGroupTagIDs)
            try attach(selectedCategoryTagIDs)
            try attach(selectedWorkoutTagIDs)
        }
    }
}

// Convenience to use ExerciseTagRecord in ForEach by stable id
private extension ExerciseTagRecord {
    var _id: Int64 { id ?? -1 }
}

struct UnitRowWrapper: Identifiable {
    let id: Int64
    let name: String
    let abbreviation: String?
}

// MARK: - Reusable Multi-Select Screen
struct MultiSelectListView: View {
    let title: String
    let items: [(id: Int64, name: String)]
    let nameTransform: ((String) -> String)?
    @Binding var selection: Set<Int64>
    
    init(title: String, items: [(id: Int64, name: String)], selection: Binding<Set<Int64>>, nameTransform: ((String) -> String)? = nil) {
        self.title = title
        self.items = items
        self._selection = selection
        self.nameTransform = nameTransform
    }

    var body: some View {
        List(items, id: \.id) { item in
            Button(action: { toggle(item.id) }) {
                HStack {
                    Text((nameTransform?(item.name) ?? item.name).capitalized)
                        .foregroundColor(.primary)
                    Spacer()
                    if selection.contains(item.id) {
                        Image(systemName: "checkmark")
                            .foregroundColor(.accentColor)
                    }
                }
            }
        }
        .navigationTitle(title)
        .listStyle(.plain)
    }

    private func toggle(_ id: Int64) {
        if selection.contains(id) {
            selection.remove(id)
        } else {
            selection.insert(id)
        }
    }
}

// A compact row that shows a field title and a selection summary, and navigates to MultiSelectListView
struct MultiSelectFieldRow: View {
    let title: String
    let items: [ExerciseTagRecord]
    let nameTransform: ((String) -> String)?
    @Binding var selection: Set<Int64>
    
    init(title: String, items: [ExerciseTagRecord], selection: Binding<Set<Int64>>, nameTransform: ((String) -> String)? = nil) {
        self.title = title
        self.items = items
        self._selection = selection
        self.nameTransform = nameTransform
    }

    var body: some View {
        NavigationLink {
            MultiSelectListView(
                title: title,
                items: items.compactMap { tag in
                    guard let id = tag.id else { return nil }
                    return (id: id, name: tag.name)
                },
                selection: $selection,
                nameTransform: nameTransform
            )
        } label: {
            HStack {
                Text(title).bold()
                Spacer()
                Text(summary)
                    .foregroundColor(.secondary)
            }
            .contentShape(Rectangle())
        }
    }
    private var summary: String {
        if selection.isEmpty { return "None" }
        let selectedNames = items.filter { tag in
            if let id = tag.id { return selection.contains(id) }
            return false
        }.map { $0.name.capitalized }
        if selectedNames.isEmpty { return "None" }
        if selectedNames.count <= 2 {
            return selectedNames.joined(separator: ", ")
        } else {
            return "\(selectedNames.count) selected"
        }
    }
}

struct UnitsMultiSelectFieldRow: View {
    let title: String
    let items: [UnitRowWrapper]
    @Binding var selection: Set<Int64>
    var body: some View {
        NavigationLink {
            MultiSelectListView(
                title: title,
                items: items.map { ($0.id, $0.name) },
                selection: $selection
            )
        } label: {
            HStack {
                Text(title).bold()
                Spacer()
                Text(summary)
                    .foregroundColor(.secondary)
            }
            .contentShape(Rectangle())
        }
    }

    private var summary: String {
        if selection.isEmpty { return "None" }
        let selectedAbbrevs = items.filter { selection.contains($0.id) }
            .compactMap { $0.abbreviation }
            .map { $0 }
        if selectedAbbrevs.isEmpty { return "None" }
        if selectedAbbrevs.count <= 3 {
            return selectedAbbrevs.joined(separator: ", ")
        } else {
            return "\(selectedAbbrevs.count) selected"
        }
    }
}

