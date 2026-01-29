import SwiftUI
import GRDB

struct ExerciseInfoView: View {
    let exerciseId: Int64
    let locked: Bool

    @EnvironmentObject var themeManager: ThemeManager
    @StateObject private var fallbackThemeManager = ThemeManager()

    // Dependencies
    private let dbQueue = DatabaseQueueProvider.shared.dbQueue
    private let exerciseRepo: ExerciseRepository
    private let userRepo: UserRepository

    // Form State
    @State private var name: String = ""
    @State private var showAdvanced: Bool = true

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
    @State private var didLoad = false

    private var effectiveThemeManager: ThemeManager {
        let mirror = Mirror(reflecting: _themeManager)
        if mirror.children.isEmpty { return fallbackThemeManager }
        return themeManager
    }

    init(exerciseId: Int64, locked: Bool) {
        self.exerciseId = exerciseId
        self.locked = locked
        let db = DatabaseQueueProvider.shared.dbQueue
        self.exerciseRepo = ExerciseRepository(dbQueue: db)
        self.userRepo = UserRepository(dbQueue: db)
    }

    var body: some View {
        ZStack {
            effectiveThemeManager.currentTheme.background.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    HStack {
                        Text("Exercise Info")
                            .font(.title)
                            .bold()
                            .foregroundColor(effectiveThemeManager.currentTheme.textDefault)
                        Spacer()
                        if locked {
                            Image(systemName: "lock.fill")
                                .foregroundColor(effectiveThemeManager.currentTheme.muted)
                                .imageScale(.small)
                                .accessibilityLabel("Locked")
                        }
                    }
                    .padding(.horizontal)

                    // Name card
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Exercise Name").bold()
                            .foregroundColor(effectiveThemeManager.currentTheme.textDefault)
                        if locked {
                            Text(name)
                                .foregroundColor(effectiveThemeManager.currentTheme.textDefault)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 6)
                        } else {
                            TextField("Required", text: $name)
                                .foregroundColor(themeManager.currentTheme.textDefault)
                                .padding(.vertical, 10)
                                .padding(.horizontal, 12)
                                .background(themeManager.currentTheme.background)
                                .cornerRadius(10)
                                .autocorrectionDisabled(true)
                        }
                    }
                    .padding()
                    .background(effectiveThemeManager.currentTheme.surface)
                    .cornerRadius(16)
                    .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
                    .padding(.horizontal)

                    // Units card
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Unit(s)").bold()
                                .foregroundColor(themeManager.currentTheme.textDefault)
                            Spacer()
                        }
                        if locked {
                            HStack {
                                Text(unitsSummary)
                                    .foregroundColor(effectiveThemeManager.currentTheme.muted)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .contentShape(Rectangle())
                        } else {
                            NavigationLink {
                                MultiSelectListView(
                                    title: "Unit(s)",
                                    items: _unitRowsStorage.map { ($0.id, $0.name) },
                                    selection: $selectedUnitTagIDs
                                )
                                .environmentObject(themeManager)
                            } label: {
                                HStack {
                                    Text(unitsSummary)
                                        .foregroundColor(effectiveThemeManager.currentTheme.muted)
                                    Spacer()
                                    Image(systemName: "chevron.right").foregroundColor(effectiveThemeManager.currentTheme.muted)
                                }
                                .contentShape(Rectangle())
                            }
                        }
                        Rectangle()
                            .fill(effectiveThemeManager.currentTheme.muted.opacity(0.3))
                            .frame(height: 1)
                            .overlay(
                                Rectangle()
                                    .stroke(style: StrokeStyle(lineWidth: 1, dash: [4]))
                                    .foregroundColor(effectiveThemeManager.currentTheme.background)
                            )
                            .padding(.vertical, 6)
                        if !locked {
                            Text("Select the unit(s) of measurement you'd be tracking for this exercise.")
                                .font(.footnote)
                                .foregroundColor(effectiveThemeManager.currentTheme.muted)
                        }
                    }
                    .padding()
                    .background(effectiveThemeManager.currentTheme.surface)
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
                                    .foregroundColor(effectiveThemeManager.currentTheme.muted)
                            }
                            .padding()
                            .background(effectiveThemeManager.currentTheme.surface)
                        }
                        if showAdvanced {
                            VStack(alignment: .leading, spacing: 16) {
                                MultiSelectFieldRow(title: "Muscle Group(s)", items: groupTags, selection: $selectedGroupTagIDs)
                                    .disabled(locked)
                                MultiSelectFieldRow(title: "Category(s)", items: categoryTags, selection: $selectedCategoryTagIDs)
                                    .disabled(locked)
                                MultiSelectFieldRow(title: "Common Workout(s)", items: workoutTags, selection: $selectedWorkoutTagIDs, nameTransform: { $0 + " Day" })
                                    .disabled(locked)
                            }
                            .padding()
                            .background(effectiveThemeManager.currentTheme.surface)
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

                    // Save button (only if not locked)
                    if !locked {
                        Button(action: { Task { await save() } }) {
                            HStack {
                                if isSaving { ProgressView() }
                                Text(isSaving ? "Saving…" : "Save Changes").bold()
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background((name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selectedUnitTagIDs.isEmpty) ? Color.gray.opacity(0.3) : effectiveThemeManager.currentTheme.surface)
                            .cornerRadius(12)
                        }
                        .padding(.horizontal)
                        .disabled(isSaving || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selectedUnitTagIDs.isEmpty)
                    }

                    Spacer(minLength: 16)
                }
                .padding(.top, 24)
            }
        }
        .task {
            if !didLoad {
                didLoad = true
                await loadData()
            }
        }
    }

    private var unitsSummary: String {
        if selectedUnitTagIDs.isEmpty { return "None" }
        let abbrevs = _unitRowsStorage.filter { selectedUnitTagIDs.contains($0.id) }
            .compactMap { $0.abbreviation }
        if abbrevs.isEmpty { return "None" }
        if abbrevs.count <= 3 { return abbrevs.joined(separator: ", ") }
        return "\(abbrevs.count) selected"
    }

    // MARK: - Data
    private func loadData() async {
        await loadTags()
        await loadExercise()
    }

    private func loadTags() async {
        do {
            try await dbQueue.read { db in
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
                self._unitRowsStorage = unitRows.map { UnitRowWrapper(id: $0.id, name: $0.name, abbreviation: $0.abbreviation) }

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

    private func loadExercise() async {
        do {
            try await dbQueue.read { db in
                // Fetch exercise record
                if let record = try ExerciseRecord.fetchOne(db, key: exerciseId) {
                    self.name = record.name
                }
                // Fetch attached tag ids
                let pivots = try ExerciseTagPivotRecord
                    .filter(ExerciseTagPivotRecord.Columns.exerciseId == exerciseId)
                    .fetchAll(db)
                let tagIds = Set(pivots.map { $0.exerciseTagId })

                // Partition into sets based on tag type
                let tags = try ExerciseTagRecord.filter(keys: Array(tagIds)).fetchAll(db)
                self.selectedGroupTagIDs = Set(tags.filter { $0.type == "Group" }.compactMap { $0.id })
                self.selectedCategoryTagIDs = Set(tags.filter { $0.type == "Category" }.compactMap { $0.id })
                self.selectedWorkoutTagIDs = Set(tags.filter { $0.type == "Workout" }.compactMap { $0.id })

                // Load units directly from exercise_unit_pivots
                let unitPivots = try ExerciseUnitPivotRecord
                    .filter(ExerciseUnitPivotRecord.Columns.exerciseId == exerciseId)
                    .fetchAll(db)
                self.selectedUnitTagIDs = Set(unitPivots.map { $0.unitId })
            }
        } catch {
            errorMessage = "Failed to load exercise: \(error)"
        }
    }

    // MARK: - Save
    private func save() async {
        guard !locked else { return }
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard !selectedUnitTagIDs.isEmpty else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            // Update the exercise record
            try await dbQueue.write { db in
                if var record = try ExerciseRecord.fetchOne(db, key: exerciseId) {
                    record.name = name
                    record.updatedAt = Date()
                    try record.update(db)
                }
            }

            // Replace unit pivots and non-unit tag pivots atomically
            try await dbQueue.write { db in
                print("[Info] Replacing unit pivots for exerciseId: \(exerciseId), unitIds: \(selectedUnitTagIDs)")
                // Units
                try ExerciseUnitPivotRecord
                    .filter(ExerciseUnitPivotRecord.Columns.exerciseId == exerciseId)
                    .deleteAll(db)
                for unitId in selectedUnitTagIDs {
                    var unitPivot = ExerciseUnitPivotRecord(id: nil, exerciseId: exerciseId, unitId: unitId, createdAt: Date(), updatedAt: Date())
                    try unitPivot.insert(db)
                }

                // Non-unit tags
                try ExerciseTagPivotRecord
                    .filter(ExerciseTagPivotRecord.Columns.exerciseId == exerciseId)
                    .deleteAll(db)
                func attach(_ ids: Set<Int64>) throws {
                    for tagId in ids {
                        var tagPivot = ExerciseTagPivotRecord(id: nil, exerciseId: exerciseId, exerciseTagId: tagId, createdAt: Date(), updatedAt: Date())
                        try tagPivot.insert(db)
                    }
                }
                try attach(selectedGroupTagIDs)
                try attach(selectedCategoryTagIDs)
                try attach(selectedWorkoutTagIDs)
            }
            await MainActor.run { dismiss() }
        } catch {
            errorMessage = "Failed to save changes: \(error)"
        }
    }
}

