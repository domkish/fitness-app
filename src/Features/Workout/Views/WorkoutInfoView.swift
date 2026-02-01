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
    @EnvironmentObject private var themeManager: ThemeManager
    @StateObject private var fallbackThemeManager = ThemeManager()

    private var effectiveThemeManager: ThemeManager {
        // Use environment themeManager if injected; otherwise fallback
        // Mirror-based check to avoid touching an uninjected EnvironmentObject
        let mirror = Mirror(reflecting: _themeManager)
        if mirror.children.isEmpty { return fallbackThemeManager }
        return themeManager
    }

    private let dbQueue = DatabaseQueueProvider.shared.dbQueue
    private let workoutRepo: WorkoutRepository
    private let exerciseRepo: ExerciseRepository
    private let userRepo: UserRepository
    private let workoutId: Int64?
    private let onDismiss: () -> Void

    @State private var name: String = ""
    @State private var description: String = ""
    @State private var colorIdentity: String = "primary"
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var blocks: [WorkoutBlockDomain] = []
    @State private var exercisesByBlock: [Int64: [ExerciseInBlock]] = [:]
    @State private var isAddingBlock = false
    @State private var editingBlocks: Set<Int64> = []
    @State private var saveDebounceTask: Task<Void, Never>? = nil
    @State private var isUserEdited = false
    @State private var isPremiumUser: Bool = false
    @State private var showExerciseLimitInfo: Bool = false
    
    @State private var confirmDeleteRoutine: Bool = false

    @State private var isPresentingExercisePicker: Bool = false
    @State private var targetBlockIdForAdd: Int64?

    @State private var exerciseItems: [ExerciseItem] = []
    @State private var exerciseSearchText: String = ""
    @State private var unitsByExercise: [Int64: [String]] = [:]

    @State private var blockDescriptions: [Int64: String] = [:]
    @State private var blockDescriptionSaveTasks: [Int64: Task<Void, Never>] = [:]
    
    @State private var infoPopoverBlockId: Int64? = nil
    @State private var deletePopoverBlockId: Int64? = nil
    
    @State private var showBlockLimitInfo: Bool = false

    init(workoutId: Int64? = nil, onDismiss: @escaping () -> Void = {}) {
        let db = DatabaseQueueProvider.shared.dbQueue
        self.workoutRepo = WorkoutRepository(dbQueue: db)
        self.exerciseRepo = ExerciseRepository(dbQueue: db)
        self.userRepo = UserRepository(dbQueue: db)
        self.workoutId = workoutId
        self.onDismiss = onDismiss
    }

    var body: some View {
        ZStack {
            effectiveThemeManager.currentTheme.background.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    HStack {
                        Text("Routine Info")
                            .font(.title)
                            .bold()
                            .foregroundColor(themeManager.currentTheme.textDefault)
                        Spacer()
                    }
                    .padding(.horizontal)

                    // Name card
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Routine Name").bold()
                            .foregroundColor(themeManager.currentTheme.textDefault)
                        TextField("Required", text: $name)
                            .foregroundColor(themeManager.currentTheme.textDefault)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 12)
                            .background(themeManager.currentTheme.background)
                            .cornerRadius(10)
                            .autocorrectionDisabled(true)
                            .onChange(of: name) { _ in
                                isUserEdited = true
                                scheduleAutosave()
                            }
                        
                        Text("Notes").bold()
                            .foregroundColor(themeManager.currentTheme.textDefault)
                        TextField("Routine notes...", text: $description, axis: .vertical)
                            .foregroundColor(themeManager.currentTheme.textDefault)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 12)
                            .background(themeManager.currentTheme.background)
                            .cornerRadius(10)
                            .autocorrectionDisabled(true)
                            .onChange(of: description) { _ in
                                isUserEdited = true
                                scheduleAutosave()
                            }
                        
                        Text("Color Identity").bold()
                            .foregroundColor(themeManager.currentTheme.textDefault)
                        HStack(spacing: 10) {
                            ForEach(["primary","secondary","success","warning","error","important"], id: \.self) { key in
                                let isSelected = (key == colorIdentity)
                                let color = appColor(for: key)
                                Button(action: {
                                    colorIdentity = key
                                    isUserEdited = true
                                    scheduleAutosave()
                                }) {
                                    Rectangle()
                                        .fill(color)
                                        .frame(width: 32, height: 32)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 6)
                                                .stroke(isSelected ? Color.white : Color.clear, lineWidth: 2)
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 6)
                                                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
                                        )
                                        .cornerRadius(6)
                                        .overlay(
                                            Group {
                                                if isSelected {
                                                    Image(systemName: "checkmark.circle.fill")
                                                        .foregroundColor(.white)
                                                        .shadow(color: Color.black.opacity(0.25), radius: 2, x: 0, y: 1)
                                                        .background(
                                                            Circle().fill(Color.accentColor)
                                                        )
                                                        .frame(width: 18, height: 18)
                                                        .offset(x: 10, y: -10)
                                                }
                                            }
                                        )
                                        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(Text("Select \(key) color"))
                            }
                        }
                    }
                    .padding()
                    .background(effectiveThemeManager.currentTheme.surface)
                    .cornerRadius(16)
                    .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
                    .padding(.horizontal)
                    
                    // Blocks list
                    VStack(spacing: 16) {
                        ForEach(blocks, id: \._id) { block in
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    HStack(spacing: 6) {
                                        Button(action: { infoPopoverBlockId = (block.id ?? -1) }) {
                                            Image(systemName: "info")
                                                .resizable()
                                                .scaledToFit()
                                                .frame(width: 12, height: 12)
                                                .foregroundColor(.white)
                                                .padding(6)
                                                .background(RoundedRectangle(cornerRadius: 4).fill(effectiveThemeManager.currentTheme.primary))
                                                .accessibilityLabel("About exercise blocks")
                                        }
                                        .popover(isPresented: Binding<Bool>(
                                            get: { infoPopoverBlockId == (block.id ?? -1) },
                                            set: { newVal in if !newVal { infoPopoverBlockId = nil } }
                                        ), arrowEdge: .top) {
                                            VStack(alignment: .leading, spacing: 8) {
                                                Text("Exercise Blocks")
                                                    .font(.headline)
                                                Text("Blocks are a way to establish groups of exercises. Standard routines may use one block, but circuit training could use several.")
                                                    .font(.subheadline)
                                                    .foregroundColor(.secondary)
                                            }
                                            .padding()
                                            .frame(maxWidth: 320)
                                        }
                                    }
                                    Spacer()
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
                                    .foregroundColor(themeManager.currentTheme.textDefault)
                                    .padding(.vertical, 10)
                                    .padding(.horizontal, 12)
                                    .background(themeManager.currentTheme.background)
                                    .cornerRadius(10)
                                    .autocorrectionDisabled(true)
                                } else {
                                    TextField("Block notes...", text: .constant(block.description ?? ""))
                                        .foregroundColor(themeManager.currentTheme.textDefault)
                                        .padding(.vertical, 10)
                                        .padding(.horizontal, 12)
                                        .background(themeManager.currentTheme.background)
                                        .cornerRadius(10)
                                        .autocorrectionDisabled(true)
                                }
                                
                                // Exercises in this block
                                if let bid = block.id {
                                    let items = exercisesByBlock[bid] ?? []
                                    if items.isEmpty {
                                        VStack(alignment: .leading, spacing: 8) {
                                            Text("No exercises yet")
                                                .foregroundColor(effectiveThemeManager.currentTheme.textDefault)
                                                .font(.footnote)
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.vertical, 8)
                                        
                                        // Add Exercise button moved to bottom of exercise list
                                        HStack {
                                            Spacer()
                                            let maxPerBlock = isPremiumUser ? 10 : 5
                                            let currentCount = (exercisesByBlock[bid]?.count) ?? 0
                                            Button {
                                                if currentCount >= maxPerBlock {
                                                    showExerciseLimitInfo = true
                                                } else {
                                                    targetBlockIdForAdd = block.id
                                                    Task {
                                                        await loadExercises()
                                                        await MainActor.run { isPresentingExercisePicker = true }
                                                    }
                                                }
                                            } label: {
                                                HStack(spacing: 6) {
                                                    Image(systemName: "plus")
                                                    Text("Exercise").bold()
                                                }
                                                .padding(.vertical, 6)
                                                .padding(.horizontal, 10)
                                                .background(effectiveThemeManager.currentTheme.surface)
                                                .cornerRadius(8)
                                            }
                                            .disabled(currentCount >= maxPerBlock)
                                            .alert("Exercise Limit Reached", isPresented: $showExerciseLimitInfo) {
                                                Button("OK", role: .cancel) {}
                                            } message: {
                                                Text("You've reached the maximum of \(maxPerBlock) exercises for this block. Upgrade to premium for higher limits.")
                                            }
                                        }
                                    } else {
                                        // Use a nested List for reliable swipe and move support
                                        LazyVStack(spacing: 0) {
                                            ForEach(items) { ex in
                                                exerciseRow(for: ex, bid: bid)
                                                    .background(effectiveThemeManager.currentTheme.surface)
                                                    .clipShape(Rectangle())
                                                    .padding(.vertical, 4)
                                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                                        Button(role: .destructive) {
                                                            Task { await deleteExercises(ids: [ex.id], forBlock: bid) }
                                                        } label: {
                                                            Label("Delete", systemImage: "trash")
                                                        }
                                                    }
                                            }
                                        }
                                        .padding(.top, 4)
                                        
                                        // Add Exercise button moved to bottom of exercise list
                                        HStack {
                                            Spacer()
                                            let maxPerBlock = isPremiumUser ? 10 : 5
                                            let currentCount = (exercisesByBlock[bid]?.count) ?? 0
                                            Button {
                                                if currentCount >= maxPerBlock {
                                                    showExerciseLimitInfo = true
                                                } else {
                                                    targetBlockIdForAdd = block.id
                                                    Task {
                                                        await loadExercises()
                                                        await MainActor.run { isPresentingExercisePicker = true }
                                                    }
                                                }
                                            } label: {
                                                HStack(spacing: 6) {
                                                    Image(systemName: "plus")
                                                    Text("Exercise").bold()
                                                }
                                                .padding(.vertical, 6)
                                                .padding(.horizontal, 10)
                                                .background(effectiveThemeManager.currentTheme.surface)
                                                .cornerRadius(8)
                                            }
                                            .disabled(currentCount >= maxPerBlock)
                                            .alert("Exercise Limit Reached", isPresented: $showExerciseLimitInfo) {
                                                Button("OK", role: .cancel) {}
                                            } message: {
                                                Text("You've reached the maximum of \(maxPerBlock) exercises for this block. Upgrade to premium for higher limits.")
                                            }
                                        }
                                    }
                                    
                                    HStack {
                                        let canDelete = (exercisesByBlock[bid]?.isEmpty ?? true) && (blocks.count > 1)
                                        if canDelete {
                                            Button(role: .destructive) {
                                                Task { await deleteBlockIfEmpty(bid) }
                                            } label: {
                                                HStack(spacing: 6) {
                                                    Image(systemName: "trash")
                                                }
                                                .padding(.vertical, 6)
                                                .padding(.horizontal, 10)
                                                .background(effectiveThemeManager.currentTheme.surface)
                                                .cornerRadius(8)
                                            }
                                        } else {
                                            Button {
                                                deletePopoverBlockId = (block.id ?? -1)
                                            } label: {
                                                HStack(spacing: 6) {
                                                    Image(systemName: "trash")
                                                }
                                                .padding(.vertical, 6)
                                                .padding(.horizontal, 10)
                                                .foregroundColor(effectiveThemeManager.currentTheme.muted)
                                                .cornerRadius(8)
                                            }
                                        }

                                        // Copy block button (only on last block)
                                        if let lastBlock = blocks.sorted(by: { $0.sortOrder < $1.sortOrder }).last, lastBlock.id == bid {
                                            Button {
                                                Task { await copyBlock(bid) }
                                            } label: {
                                                HStack(spacing: 6) {
                                                    Image(systemName: "doc.on.doc")
                                                }
                                                .padding(.vertical, 6)
                                                .padding(.horizontal, 10)
                                                .background(effectiveThemeManager.currentTheme.surface)
                                                .cornerRadius(8)
                                            }
                                        }

                                        Spacer()

                                        Button {
                                            if editingBlocks.contains(bid) { editingBlocks.remove(bid) } else { editingBlocks.insert(bid) }
                                        } label: {
                                            HStack(spacing: 6) {
                                                Image(systemName: editingBlocks.contains(bid) ? "checkmark.circle" : "arrow.up.arrow.down.circle")
                                            }
                                            .padding(.vertical, 6)
                                            .padding(.horizontal, 10)
                                            .background(effectiveThemeManager.currentTheme.surface)
                                            .cornerRadius(8)
                                        }
                                    }
                                    .popover(isPresented: Binding<Bool>(
                                        get: { deletePopoverBlockId == (block.id ?? -1) },
                                        set: { newVal in if !newVal { deletePopoverBlockId = nil } }
                                    ), arrowEdge: .top) {
                                        VStack(alignment: .leading, spacing: 8) {
                                            Text("Cannot Delete Block")
                                                .font(.headline)
                                            Text("You can only remove blocks if there are no exercises tied to them. At least one block is required per routine.")
                                                .font(.subheadline)
                                                .foregroundColor(.secondary)
                                        }
                                        .padding()
                                        .frame(maxWidth: 320)
                                    }
                                }
                            }
                            .padding()
                            .background(effectiveThemeManager.currentTheme.surface)
                            .cornerRadius(16)
                            .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
                        }

                        let maxBlocks = isPremiumUser ? 5 : 2
                        let currentBlocks = blocks.count
                        HStack {
                            Spacer()
                            Button {
                                if currentBlocks >= maxBlocks {
                                    showBlockLimitInfo = true
                                } else {
                                    Task { await addBlock() }
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "plus")
                                    Text("Block").bold()
                                }
                                .padding(.vertical, 6)
                                .padding(.horizontal, 10)
                            }
                            .disabled(currentBlocks >= maxBlocks)
                            .alert("Block Limit Reached", isPresented: $showBlockLimitInfo) {
                                Button("OK", role: .cancel) {}
                            } message: {
                                Text("You've reached the maximum of \(maxBlocks) blocks for this routine. Upgrade to premium for higher limits.")
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    // Delete routine button
                    if workoutId != nil {
                        Button(role: .destructive) {
                            confirmDeleteRoutine = true
                        } label: {
                            HStack {
                                Spacer()
                                Text("Delete Routine")
                                    .bold()
                                Spacer()
                            }
                            .padding()
                            .background(effectiveThemeManager.currentTheme.error.opacity(0.1))
                            .cornerRadius(12)
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)
                        .alert("Delete Routine?", isPresented: $confirmDeleteRoutine) {
                            Button("Cancel", role: .cancel) {}
                            Button("Delete", role: .destructive) {
                                Task { await deleteRoutine() }
                            }
                        } message: {
                            Text("This will remove this routine from being added to your calendar again. All past workout sessions that used this routine will remain saved.")
                        }
                    }

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
                    effectiveThemeManager.currentTheme.background
                        .ignoresSafeArea()

                    VStack(spacing: 12) {

                        // Header
                        Text("Exercise Library")
                            .font(.title)
                            .bold()
                            .foregroundColor(themeManager.currentTheme.textDefault)
                            .padding(.top, 20)

                        // 🔍 Search bar (ABOVE list)
                        HStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(themeManager.currentTheme.secondary)

                            TextField("Search exercises", text: $exerciseSearchText)
                                .foregroundColor(themeManager.currentTheme.textDefault)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 12)
                                .background(themeManager.currentTheme.formDefault)
                                .cornerRadius(10)

                            if !exerciseSearchText.isEmpty {
                                Button {
                                    exerciseSearchText = ""
                                    UIApplication.shared.sendAction(
                                        #selector(UIResponder.resignFirstResponder),
                                        to: nil,
                                        from: nil,
                                        for: nil
                                    )
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(themeManager.currentTheme.secondary)
                                        .accessibilityLabel("Clear search")
                                }
                            }
                        }
                        .padding(.horizontal)

                        // Exercise list
                        List {
                            ForEach(filteredExerciseItems, id: \.id) { item in
                                Button {
                                    Task { await didSelectExercise(item) }
                                } label: {
                                    HStack {
                                        Text(item.name)
                                            .foregroundColor(themeManager.currentTheme.textDefault)
                                        Spacer()
                                    }
                                }
                                .listRowBackground(themeManager.currentTheme.surface)
                            }
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                        .background(themeManager.currentTheme.surface)
                        .clipShape(
                            RoundedRectangle(
                                cornerRadius: 16,
                                style: .continuous
                            )
                        )
                        .shadow(
                            color: Color.black.opacity(0.05),
                            radius: 10,
                            x: 0,
                            y: 5
                        )
                        .padding(.horizontal)
                        .padding(.bottom)
                    }
                }
                .onChange(of: exerciseSearchText) { newValue in
                    // Debounce ~250ms
                    Task {
                        try? await Task.sleep(nanoseconds: 250_000_000)
                        guard newValue == exerciseSearchText else { return }
                        await filterExercises()
                    }
                }
                .task {
                    await filterExercises()
                }
            }
        }

        .task {
            await loadCurrentUserPremium()
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
            try workoutRepo.saveWorkout(
                id: workoutId,
                userId: Int64(user.id),
                name: name,
                description: description.isEmpty ? nil : description,
                color: colorIdentity
            )
        } catch {
            errorMessage = "Failed to save routine: \(error.localizedDescription)"
        }
    }

    private func loadIfNeeded() async {
        guard let workoutId = workoutId else { return }
        do {
            if let record = try workoutRepo.fetchWorkout(id: workoutId) {
                self.name = record.name
                self.description = record.description ?? ""
                self.colorIdentity = record.color
            }
        } catch {
            self.errorMessage = "Failed to load routine: \(error.localizedDescription)"
        }
    }
    
    private func loadCurrentUserPremium() async {
        do {
            if let user = try await userRepo.fetchUser() {
                await MainActor.run {
                    self.isPremiumUser = user.isPremium
                }
            }
        } catch {
            print("[WorkoutInfo] Failed to load current user premium: \(error)")
        }
    }

    private func loadBlocks() async {
        guard let workoutId = workoutId else { return }
        do {
            let recs = try workoutRepo.fetchBlocks(forWorkoutId: workoutId)
            self.blocks = recs.filter { $0.deletedAt == nil }
            var newCache: [Int64: String] = [:]
            for b in self.blocks {
                if let bid = b.id {
                    newCache[bid] = b.description ?? ""
                }
            }
            self.blockDescriptions.merge(newCache) { _, new in new }
            Task { await loadExercisesForBlocks() }
        } catch {
            print("[WorkoutInfo] Failed to load blocks: \(error)")
        }
    }

    private func addBlock() async {
        guard let workoutId = workoutId else { return }
        let maxBlocks = isPremiumUser ? 5 : 2
        if blocks.count >= maxBlocks {
            await MainActor.run { showBlockLimitInfo = true }
            return
        }
        do {
            let now = Date()
            let nextOrder = (blocks.map { $0.sortOrder }.max() ?? 0) + 1
            guard let currentUser = try await userRepo.fetchUser() else { return }
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
            try workoutRepo.createBlock(newBlock)
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
                try workoutRepo.updateBlockName(blockId: id, to: newName)
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
            try workoutRepo.updateBlockDescription(blockId: blockId, to: newValue)
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
                .foregroundColor(themeManager.currentTheme.textDefault)
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
        .listRowBackground(effectiveThemeManager.currentTheme.surface)
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
            let rows = try exerciseRepo.fetchAllIdName()
            self.exerciseItems = rows.map { ExerciseItem(id: $0.id, name: $0.name) }
        } catch {
            print("[WorkoutInfo] Failed to load exercises: \(error)")
        }
    }

    private func loadExercisesForBlocks() async {
        guard let workoutId = workoutId else { return }
        do {
            let groupedRows = try workoutRepo.fetchExercisesByBlock(forWorkoutId: workoutId)
            var grouped: [Int64: [ExerciseInBlock]] = [:]
            for (key, rows) in groupedRows {
                grouped[key] = rows.map { ExerciseInBlock(id: $0.id, exerciseId: $0.exerciseId, name: $0.name, unit: $0.unit, sortOrder: $0.sortOrder) }
            }
            self.exercisesByBlock = grouped

            let exerciseIds = Set(grouped.values.flatMap { $0.map { $0.exerciseId } })
            Task { await loadUnitsForExercises(Array(exerciseIds)) }

            print("[WorkoutInfo] Loaded exercises for blocks: \(grouped.map { "\($0.key):\($0.value.count)" }.joined(separator: ", "))")
        } catch {
            print("[WorkoutInfo] Failed to load exercises for blocks: \(error)")
        }
    }

    private func loadUnitsForExercises(_ exerciseIds: [Int64]) async {
        guard !exerciseIds.isEmpty else { return }
        do {
            let map = try workoutRepo.loadUnitsForExercises(exerciseIds)
            self.unitsByExercise = map
        } catch {
            print("[WorkoutInfo] Failed to load units: \(error)")
        }
    }

    private func deleteExercises(ids: [Int64], forBlock blockId: Int64) async {
        do {
            try workoutRepo.deleteExercises(ids: ids)
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
            try workoutRepo.updateExerciseOrder(forBlockId: blockId, items: updates)
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
            try workoutRepo.updateWorkoutExerciseUnit(id: workoutExerciseId, to: unit)
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

        let maxPerBlock = isPremiumUser ? 10 : 5
        let currentCount = exercisesByBlock[blockId]?.count ?? 0
        if currentCount >= maxPerBlock {
            await MainActor.run {
                showExerciseLimitInfo = true
                isPresentingExercisePicker = false
            }
            return
        }

        do {
            guard let currentUser = try? await userRepo.fetchUser() else { return }

            try workoutRepo.addExercise(
                toBlockId: blockId,
                workoutId: workoutId,
                exerciseId: item.id,
                userId: Int64(currentUser.id)
            )

            await MainActor.run {
                exerciseSearchText = ""
                UIApplication.shared.sendAction(
                    #selector(UIResponder.resignFirstResponder),
                    to: nil,
                    from: nil,
                    for: nil
                )

                isPresentingExercisePicker = false
                targetBlockIdForAdd = nil
            }

            await loadExercisesForBlocks()
        } catch {
            print("[WorkoutInfo] Failed to attach exercise: \(error)")
        }
    }
    
    private func deleteBlockIfEmpty(_ blockId: Int64) async {
        print("[WorkoutInfo] Attempting delete for blockId:", blockId,
              "exCount:", exercisesByBlock[blockId]?.count ?? -1,
              "blocks:", blocks.count)
        let hasExercises = (exercisesByBlock[blockId]?.isEmpty == false)
        if hasExercises {
            print("[WorkoutInfo] Cannot delete block: it has exercises.")
            return
        }

        do {
            try workoutRepo.softDeleteBlock(id: blockId)
            print("[WorkoutInfo] softDeleteBlock OK")
            await loadBlocks()
            await loadExercisesForBlocks()
            await MainActor.run {
                isUserEdited = true
                scheduleAutosave()
            }
        } catch {
            print("[WorkoutInfo] Failed to soft delete block:", error)
        }
    }
    
    private func copyBlock(_ blockId: Int64) async {
        do {
            try workoutRepo.cloneBlock(blockId: blockId)
            await loadBlocks()
            await loadExercisesForBlocks()
            await MainActor.run {
                isUserEdited = true
                scheduleAutosave()
            }
        } catch {
            print("[WorkoutInfo] Failed to copy block: \(error)")
        }
    }
    
    private func deleteRoutine() async {
        guard let wid = workoutId else { return }
        do {
            try workoutRepo.softDelete(id: wid)
            await MainActor.run {
                dismiss()
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to delete routine: \(error.localizedDescription)"
            }
        }
    }
    
    private func appColor(for key: String) -> Color {
        switch key {
        case "primary": return effectiveThemeManager.currentTheme.primary
        case "secondary": return effectiveThemeManager.currentTheme.secondary
        case "success": return effectiveThemeManager.currentTheme.success
        case "warning": return effectiveThemeManager.currentTheme.warning
        case "error": return effectiveThemeManager.currentTheme.error
        case "important": return effectiveThemeManager.currentTheme.important
        default: return effectiveThemeManager.currentTheme.primary
        }
    }
}

