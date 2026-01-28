//
//  WorkoutAddView.swift
//  fitness-app
//
//  Created by Dominic Kish on 1/27/26.
//
import SwiftUI
import GRDB

struct WorkoutInfoView: View {
    @Environment(\.dismiss) private var dismiss

    private let dbQueue = DatabaseQueueProvider.shared.dbQueue
    private let workoutRepo: WorkoutRepository
    private let userRepo: UserRepository
    private let workoutId: Int64?
    private let onDismiss: () -> Void

    @State private var name: String = ""
    @State private var description: String = ""
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var blocks: [WorkoutBlockDomain] = []
    @State private var exercisesByBlock: [Int64: [ExerciseInBlock]] = [:]
    @State private var isAddingBlock = false
    @State private var editingBlocks: Set<Int64> = []
    @State private var saveDebounceTask: Task<Void, Never>? = nil
    @State private var isUserEdited = false

    @State private var isPresentingExercisePicker: Bool = false
    @State private var targetBlockIdForAdd: Int64?

    @State private var exerciseItems: [ExerciseItem] = []
    @State private var exerciseSearchText: String = ""
    @State private var unitsByExercise: [Int64: [String]] = [:]

    @State private var blockDescriptions: [Int64: String] = [:]
    @State private var blockDescriptionSaveTasks: [Int64: Task<Void, Never>] = [:]
    @State private var isShowingBlocksInfo: Bool = false

    init(workoutId: Int64? = nil, onDismiss: @escaping () -> Void = {}) {
        let db = DatabaseQueueProvider.shared.dbQueue
        self.workoutRepo = WorkoutRepository(dbQueue: db)
        self.userRepo = UserRepository(dbQueue: db)
        self.workoutId = workoutId
        self.onDismiss = onDismiss
    }

    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    HStack {
                        Text("Workout Info")
                            .font(.title)
                            .bold()
                        Spacer()
                    }
                    .padding(.horizontal)

                    // Name card
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Workout Name").bold()
                        TextField("Required", text: $name)
                            .background(AppColors.formDefault)
                            .textFieldStyle(.roundedBorder)
                            .onChange(of: name) { _ in
                                isUserEdited = true
                                scheduleAutosave()
                            }
                        
                        Text("Notes").bold()
                        TextField("Workout notes...", text: $description, axis: .vertical)
                            .background(AppColors.formDefault)
                            .foregroundColor(AppColors.muted)
                            .textFieldStyle(.roundedBorder)
                            .onChange(of: description) { _ in
                                isUserEdited = true
                                scheduleAutosave()
                            }
                    }
                    .padding()
                    .background(AppColors.surface)
                    .cornerRadius(16)
                    .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
                    .padding(.horizontal)
                    
                    // Blocks list
                    VStack(spacing: 16) {
                        ForEach(blocks, id: \._id) { block in
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    HStack(spacing: 6) {
                                        Button(action: { isShowingBlocksInfo.toggle() }) {
                                            Image(systemName: "info")
                                                .resizable()
                                                .scaledToFit()
                                                .frame(width: 12, height: 12)
                                                .foregroundColor(.white)
                                                .padding(6)
                                                .background(RoundedRectangle(cornerRadius: 4).fill(AppColors.primary))
                                                .accessibilityLabel("About exercise blocks")
                                        }
                                        // Popover for larger/regular width devices
                                        .popover(isPresented: $isShowingBlocksInfo, arrowEdge: .top) {
                                            VStack(alignment: .leading, spacing: 8) {
                                                Text("Exercise Blocks")
                                                    .font(.headline)
                                                Text("Blocks are a way to establish groups of exercises. Standard workouts may use one block, but circuit training could use several.")
                                                    .font(.subheadline)
                                                    .foregroundColor(.secondary)
                                            }
                                            .padding()
                                            .frame(maxWidth: 320)
                                        }
                                        // Alert fallback for compact environments where popover may not appear
                                        .alert("What are blocks?", isPresented: $isShowingBlocksInfo) {
                                            Button("OK", role: .cancel) { }
                                        } message: {
                                            Text("Blocks are a way to establish groups of exercises. Standard workouts may use one block, but circuit training could use several.")
                                        }
                                        
                                        
                                    }
                                    Spacer()
                                    Button {
                                        targetBlockIdForAdd = block.id
                                        Task {
                                            await loadExercises()
                                            await MainActor.run {
                                                isPresentingExercisePicker = true
                                            }
                                        }
                                    } label: {
                                        HStack(spacing: 6) {
                                            Image(systemName: "plus")
                                            Text("Exercise").bold()
                                        }
                                        .padding(.vertical, 6)
                                        .padding(.horizontal, 10)
                                        .background(AppColors.surface)
                                        .cornerRadius(8)
                                    }
                                }
                                if let bid = block.id {
                                    TextField("Block notes...", text: Binding(
                                        get: { blockDescriptions[bid] ?? (block.description ?? "") },
                                        set: { newVal in
                                            blockDescriptions[bid] = newVal
                                            // Debounce save per-block
                                            blockDescriptionSaveTasks[bid]?.cancel()
                                            blockDescriptionSaveTasks[bid] = Task {
                                                try? await Task.sleep(nanoseconds: 600_000_000)
                                                guard !Task.isCancelled else { return }
                                                await persistBlockDescription(blockId: bid, to: newVal)
                                            }
                                        }
                                    ))
                                    .background(AppColors.formDefault)
                                    .foregroundColor(AppColors.muted)
                                    .textFieldStyle(.roundedBorder)
                                } else {
                                    TextField("Block notes...", text: .constant(block.description ?? ""))
                                        .textFieldStyle(.roundedBorder)
                                }
                                
                                // Exercises in this block
                                if let bid = block.id {
                                    let items = exercisesByBlock[bid] ?? []
                                    if items.isEmpty {
                                        VStack(alignment: .leading, spacing: 8) {
                                            Text("No exercises yet")
                                                .foregroundColor(AppColors.muted)
                                                .font(.footnote)
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.vertical, 8)
                                    } else {
                                        // Use a nested List for reliable swipe and move support
                                        List {
                                            ForEach(items) { ex in
                                                exerciseRow(for: ex, bid: bid)
                                            }
                                            .onMove { indices, newOffset in
                                                var current = items
                                                current.move(fromOffsets: indices, toOffset: newOffset)
                                                exercisesByBlock[bid] = current
                                                Task { await persistOrder(forBlock: bid, items: current) }
                                            }
                                        }
                                        .listStyle(.plain)
                                        .environment(\.editMode, .constant(editingBlocks.contains(bid) ? EditMode.active : EditMode.inactive))
                                        .scrollContentBackground(.hidden)
                                        .frame(minHeight: CGFloat(items.count) * 48.0 + 8.0, maxHeight: min(CGFloat(items.count) * 56.0 + 16.0, 320))
                                        .background(AppColors.surface)
                                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                        .shadow(color: Color.black.opacity(0.03), radius: 6, x: 0, y: 3)
                                        .padding(.top, 4)
                                    }
                                    
                                    // Footer: Reorder toggle
                                    HStack {
                                        Spacer()
                                        Button {
                                            if editingBlocks.contains(bid) { editingBlocks.remove(bid) } else { editingBlocks.insert(bid) }
                                        } label: {
                                            HStack(spacing: 6) {
                                                Image(systemName: editingBlocks.contains(bid) ? "checkmark.circle" : "arrow.up.arrow.down.circle")
                                                Text(editingBlocks.contains(bid) ? "Done" : "Reorder").bold()
                                            }
                                            .padding(.vertical, 6)
                                            .padding(.horizontal, 10)
                                            .background(AppColors.surface)
                                            .cornerRadius(8)
                                        }
                                    }
                                }
                            }
                            .padding()
                            .background(AppColors.surface)
                            .cornerRadius(16)
                            .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
                        }

                        Button {
                            Task { await addBlock() }
                        } label: {
                            HStack {
                                Image(systemName: "plus")
                                Text("Add Block").bold()
                                Spacer()
                            }
                            .padding()
                            .background(AppColors.surface)
                            .cornerRadius(16)
                            .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
                        }
                    }
                    .padding(.horizontal)

                    // Error message
                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.footnote)
                            .padding(.horizontal)
                    }

                    Spacer(minLength: 16)
                }
                .padding(.top, 24)
            }
        }
        .sheet(isPresented: $isPresentingExercisePicker) {
            NavigationStack {
                ZStack {
                    AppColors.background.ignoresSafeArea()
                    // List of exercises filtered by search
                    List {
                        ForEach(filteredExerciseItems, id: \.id) { item in
                            Button(action: {
                                Task { await didSelectExercise(item) }
                            }) {
                                HStack {
                                    Text(item.name)
                                        .foregroundColor(.primary)
                                    Spacer()
                                }
                            }
                        }
                    }
                    .listStyle(.plain)

                    // Floating bottom search bar
                    VStack {
                        Spacer()
                        HStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.secondary)
                            TextField("Search exercises", text: $exerciseSearchText)
                                .textFieldStyle(.roundedBorder)
                            if !exerciseSearchText.isEmpty {
                                Button {
                                    exerciseSearchText = ""
                                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.secondary)
                                        .imageScale(.medium)
                                        .accessibilityLabel("Clear search")
                                }
                            }
                        }
                        .padding()
                        .background(AppColors.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
                        .padding(.horizontal)
                        .padding(.bottom, 34)
                    }
                }
                .navigationTitle("Select Exercise")
                .ignoresSafeArea(.keyboard, edges: .bottom)
                .onChange(of: exerciseSearchText) { newValue in
                    // Debounce ~250ms
                    Task {
                        try? await Task.sleep(nanoseconds: 250_000_000)
                        guard newValue == exerciseSearchText else { return }
                        await filterExercises()
                    }
                }
                .task { await filterExercises() }
            }
        }
        .task {
            await loadIfNeeded()
            await loadBlocks()
            await loadExercises()
            await loadExercisesForBlocks()
        }
    }

    private func scheduleAutosave() {
        // Don't autosave until the user has made an edit
        guard isUserEdited else { return }
        // Cancel any pending save
        saveDebounceTask?.cancel()
        // Schedule a new debounced save
        saveDebounceTask = Task { [name, description] in
            try? await Task.sleep(nanoseconds: 600_000_000)
            guard !Task.isCancelled else { return }
            await save()
        }
    }

    private func save() async {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            guard let user = try await userRepo.fetchUser() else {
                errorMessage = "No current user found."
                return
            }
            let now = Date()
            if let wid = workoutId {
                try await dbQueue.write { db in
                    try db.execute(sql: "UPDATE workouts SET name = ?, description = ?, color = ?, updated_at = ? WHERE id = ?", arguments: [name, description.isEmpty ? nil : description, "primary", now, wid])
                }
            } else {
                try await dbQueue.write { db in
                    try db.execute(sql: "INSERT INTO workouts (user_id, name, color, description, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?)", arguments: [user.id, name, "primary", description.isEmpty ? nil : description, now, now])
                }
            }
            // Removed auto-dismiss; view stays open after save
        } catch {
            errorMessage = "Failed to save workout: \(error.localizedDescription)"
        }
    }

    private func loadIfNeeded() async {
        guard let workoutId = workoutId else { return }
        do {
            try await dbQueue.read { db in
                if let record = try WorkoutRecord.fetchOne(db, key: workoutId) {
                    self.name = record.name
                    self.description = record.description ?? ""
                }
            }
        } catch {
            self.errorMessage = "Failed to load workout: \(error.localizedDescription)"
        }
    }

    private func loadBlocks() async {
        guard let workoutId = workoutId else { return }
        do {
            try await dbQueue.read { db in
                let recs = try WorkoutBlockRecord
                    .filter(WorkoutBlockRecord.Columns.workoutId == workoutId)
                    .order(WorkoutBlockRecord.Columns.sortOrder.asc)
                    .fetchAll(db)
                self.blocks = recs.map { WorkoutBlockDomain(from: $0) }

                // Seed/edit cache with current descriptions
                var newCache: [Int64: String] = [:]
                for b in self.blocks {
                    if let bid = b.id {
                        newCache[bid] = b.description ?? ""
                    }
                }
                self.blockDescriptions.merge(newCache) { _, new in new }
            }
            Task { await loadExercisesForBlocks() }
        } catch {
            print("[WorkoutInfo] Failed to load blocks: \(error)")
        }
    }

    private func addBlock() async {
        guard let workoutId = workoutId else { return }
        do {
            let now = Date()
            // Determine next sort order
            let nextOrder = (blocks.map { $0.sortOrder }.max() ?? 0) + 1
            let user = try await userRepo.fetchUser()
            guard let currentUser = user else { return }
            let newBlock = WorkoutBlockDomain(
                id: nil,
                userId: Int64(currentUser.id),
                workoutId: workoutId,
                name: "Block \(nextOrder)",
                description: nil,
                difficulty: nil,
                sortOrder: nextOrder,
                deletedAt: nil,
                createdAt: now,
                updatedAt: now
            )
            try await dbQueue.write { db in
                var rec = WorkoutBlockRecord(from: newBlock)
                try rec.insert(db)
            }
            await loadBlocks()
            await loadExercisesForBlocks()
            await MainActor.run { 
                isUserEdited = true
                scheduleAutosave()
            }
        } catch {
            print("[WorkoutInfo] Failed to add block: \(error)")
        }
    }

    private func updateBlockName(blockId: Int64?, to newName: String) {
        guard let id = blockId else { return }
        Task {
            do {
                try await dbQueue.write { db in
                    if var rec = try WorkoutBlockRecord.fetchOne(db, key: id) {
                        rec.name = newName
                        rec.updatedAt = Date()
                        try rec.update(db)
                    }
                }
                await MainActor.run {
                    isUserEdited = true
                    scheduleAutosave()
                }
            } catch {
                print("[WorkoutInfo] Failed to update block name: \(error)")
            }
        }
    }
    
    private func persistBlockDescription(blockId: Int64, to newValue: String) async {
        do {
            try await dbQueue.write { db in
                if var rec = try WorkoutBlockRecord.fetchOne(db, key: blockId) {
                    rec.description = newValue.isEmpty ? nil : newValue
                    rec.updatedAt = Date()
                    try rec.update(db)
                }
            }
            await MainActor.run {
                isUserEdited = true
                scheduleAutosave()
            }
        } catch {
            print("[WorkoutInfo] Failed to persist block description: \(error)")
        }
    }
    
    @ViewBuilder
    private func exerciseRow(for ex: ExerciseInBlock, bid: Int64) -> some View {
        let options = unitsByExercise[ex.exerciseId] ?? []
        HStack(spacing: 8) {
            Text(ex.name)
                .foregroundColor(.primary)
            Spacer()
            if !options.isEmpty {
                let selection = Binding<String>(
                    get: { ex.unit ?? options.first ?? "" },
                    set: { newVal in
                        Task { await updateWorkoutExerciseUnit(workoutExerciseId: ex.id, to: newVal) }
                    }
                )
                Picker("Unit", selection: selection) {
                    ForEach(options, id: \.self) { unit in
                        Text(unit).tag(unit)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
            }
        }
        .listRowBackground(AppColors.surface)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                Task { await deleteExercises(ids: [ex.id], forBlock: bid) }
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    // MARK: - Exercise Picker Data
    private struct ExerciseItem: Identifiable { let id: Int64; let name: String }
    private struct ExerciseInBlock: Identifiable { let id: Int64; let exerciseId: Int64; let name: String; var unit: String?; let sortOrder: Int }
    
    private var filteredExerciseItems: [ExerciseItem] {
        let q = exerciseSearchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return exerciseItems }
        return exerciseItems.filter { $0.name.lowercased().contains(q) }
    }

    private func filterExercises() async {
        // No-op for now since we filter in-memory; kept for symmetry and future SQL optimization
    }

    private func loadExercises() async {
        do {
            try await dbQueue.read { db in
                struct RowEx: FetchableRecord, Decodable { let id: Int64; let name: String }
                let rows = try RowEx.fetchAll(db, sql: "SELECT id, name FROM exercises WHERE deleted_at IS NULL ORDER BY name ASC")
                self.exerciseItems = rows.map { ExerciseItem(id: $0.id, name: $0.name) }
            }
        } catch {
            print("[WorkoutInfo] Failed to load exercises: \(error)")
        }
    }

    private func loadExercisesForBlocks() async {
        guard let workoutId = workoutId else { return }
        do {
            try await dbQueue.read { db in
                // Fetch all exercises joined to their block for this workout
                struct RowExInBlock: FetchableRecord, Decodable {
                    let id: Int64
                    let exerciseId: Int64
                    let name: String
                    let blockId: Int64
                    let sortOrder: Int
                    let unit: String?
                }
                let sql = """
                SELECT we.id AS id,
                       we.exercise_id AS exerciseId,
                       e.name AS name,
                       we.workout_block_id AS blockId,
                       we.sort_order AS sortOrder,
                       we.unit AS unit
                FROM workout_exercises AS we
                JOIN exercises AS e ON e.id = we.exercise_id
                WHERE we.workout_id = ? AND we.deleted_at IS NULL AND e.deleted_at IS NULL
                ORDER BY we.workout_block_id ASC, we.sort_order ASC
                """
                let rows = try RowExInBlock.fetchAll(db, sql: sql, arguments: [workoutId])
                var grouped: [Int64: [ExerciseInBlock]] = [:]
                for r in rows {
                    grouped[r.blockId, default: []].append(ExerciseInBlock(id: r.id, exerciseId: r.exerciseId, name: r.name, unit: r.unit, sortOrder: r.sortOrder))
                }
                for (key, var arr) in grouped {
                    arr.sort { $0.sortOrder < $1.sortOrder }
                    grouped[key] = arr
                }
                self.exercisesByBlock = grouped
                
                let exerciseIds = Set(grouped.values.flatMap { $0.map { $0.exerciseId } })
                Task { await loadUnitsForExercises(Array(exerciseIds)) }
                
                print("[WorkoutInfo] Loaded exercises for blocks: \(grouped.map { "\($0.key):\($0.value.count)" }.joined(separator: ", "))")
            }
        } catch {
            print("[WorkoutInfo] Failed to load exercises for blocks: \(error)")
        }
    }

    private func loadUnitsForExercises(_ exerciseIds: [Int64]) async {
        guard !exerciseIds.isEmpty else { return }
        do {
            try await dbQueue.read { db in
                struct RowUnit: FetchableRecord, Decodable { let exerciseId: Int64; let abbreviation: String }
                let placeholders = exerciseIds.map { _ in "?" }.joined(separator: ",")
                let sql = """
                SELECT eup.exercise_id AS exerciseId,
                       u.abbreviation AS abbreviation
                FROM exercise_unit_pivots AS eup
                JOIN units AS u ON u.id = eup.unit_id
                WHERE eup.exercise_id IN (\(placeholders))
                ORDER BY CASE WHEN (SELECT is_imperial FROM users LIMIT 1) = 1 THEN (u.type = '1') ELSE (u.type = '0') END DESC, u.id ASC
                """
                let rows = try RowUnit.fetchAll(db, sql: sql, arguments: StatementArguments(exerciseIds))
                var map: [Int64: [String]] = [:]
                for r in rows { map[r.exerciseId, default: []].append(r.abbreviation) }
                self.unitsByExercise = map
            }
        } catch {
            print("[WorkoutInfo] Failed to load units: \(error)")
        }
    }

    private func deleteExercises(ids: [Int64], forBlock blockId: Int64) async {
        do {
            try await dbQueue.write { db in
                let now = Date()
                var args = StatementArguments()
                args += [now]
                for id in ids { args += [id] }
                let placeholders = ids.map { _ in "?" }.joined(separator: ",")
                try db.execute(sql: "UPDATE workout_exercises SET deleted_at = ? WHERE id IN (\(placeholders))", arguments: args)
            }
            await loadExercisesForBlocks()
            await MainActor.run { 
                isUserEdited = true
                scheduleAutosave()
            }
        } catch {
            print("[WorkoutInfo] Failed to delete exercises: \(error)")
        }
    }

    private func persistOrder(forBlock blockId: Int64, items: [ExerciseInBlock]) async {
        let updates = items.enumerated().map { (idx, ex) -> (Int, Int64) in (idx + 1, ex.id) }
        do {
            try await dbQueue.write { db in
                for (order, id) in updates {
                    try db.execute(sql: "UPDATE workout_exercises SET sort_order = ? WHERE id = ?", arguments: [order, id])
                }
            }
            await loadExercisesForBlocks()
            await MainActor.run { 
                isUserEdited = true
                scheduleAutosave()
            }
        } catch {
            print("[WorkoutInfo] Failed to persist order: \(error)")
        }
    }

    private func updateWorkoutExerciseUnit(workoutExerciseId: Int64, to unit: String?) async {
        do {
            try await dbQueue.write { db in
                try db.execute(sql: "UPDATE workout_exercises SET unit = ?, updated_at = ? WHERE id = ?", arguments: [unit, Date(), workoutExerciseId])
            }
            await loadExercisesForBlocks()
            await MainActor.run { 
                isUserEdited = true
                scheduleAutosave()
            }
        } catch {
            print("[WorkoutInfo] Failed to update unit: \(error)")
        }
    }

    private func didSelectExercise(_ item: ExerciseItem) async {
        guard let blockId = targetBlockIdForAdd, let workoutId = workoutId else { return }
        do {
            // Determine next sort order for exercises in this block
            let nextOrder: Int = try await dbQueue.read { db in
                let maxOrder: Int? = try Int.fetchOne(db, sql: "SELECT MAX(sort_order) FROM workout_exercises WHERE workout_block_id = ?", arguments: [blockId])
                return (maxOrder ?? 0) + 1
            }
            let now = Date()
            guard let currentUser = try? await userRepo.fetchUser() else { return }
            var rec = WorkoutExerciseRecord(
                id: nil,
                workoutId: workoutId,
                workoutBlockId: blockId,
                exerciseId: item.id,
                userId: Int64(currentUser.id),
                unit: nil,
                sortOrder: nextOrder,
                deletedAt: nil,
                createdAt: now,
                updatedAt: now
            )
            try await dbQueue.write { db in
                try rec.insert(db)
            }
            // Dismiss picker
            await MainActor.run {
                isPresentingExercisePicker = false
                targetBlockIdForAdd = nil
            }
            await loadExercisesForBlocks()
        } catch {
            print("[WorkoutInfo] Failed to attach exercise: \(error)")
        }
    }
}
private extension WorkoutBlockDomain { var _id: Int64 { id ?? -1 } }

