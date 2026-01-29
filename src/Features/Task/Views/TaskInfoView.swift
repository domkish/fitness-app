import SwiftUI
import GRDB

struct TaskInfoView: View {
    let taskId: Int64?
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var themeManager: ThemeManager

    // Dependencies
    private let taskRepo: TaskRepository = TaskRepository(dbQueue: DatabaseQueueProvider.shared.dbQueue)
    private let userRepo: UserRepository = UserRepository(dbQueue: DatabaseQueueProvider.shared.dbQueue)

    // State
    @State private var name: String = ""
    @State private var sunday: Bool = false
    @State private var monday: Bool = false
    @State private var tuesday: Bool = false
    @State private var wednesday: Bool = false
    @State private var thursday: Bool = false
    @State private var friday: Bool = false
    @State private var saturday: Bool = false

    @State private var startedAt: Date? = nil
    @State private var endsAt: Date? = nil

    @State private var isSaving = false
    @State private var errorMessage: String? = nil

    @State private var saveDebounceTask: Task<Void, Never>? = nil
    @State private var isUserEdited: Bool = false
    @State private var confirmDeleteTask: Bool = false

    init(taskId: Int64? = nil) {
        self.taskId = taskId
    }

    var body: some View {
        ZStack {
            themeManager.currentTheme.background.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    HStack {
                        Text("Task Info")
                            .font(.title)
                            .bold()
                        Spacer()
                    }
                    .padding(.horizontal)

                    // Name card
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Task Name").bold()
                        TextField("Required", text: $name)
                            .background(themeManager.currentTheme.formDefault)
                            .textFieldStyle(.roundedBorder)
                            .autocorrectionDisabled(true)
                            .onChange(of: name) { _ in
                                isUserEdited = true
                                scheduleAutosave()
                            }
                    }
                    .padding()
                    .background(themeManager.currentTheme.surface)
                    .cornerRadius(16)
                    .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
                    .padding(.horizontal)

                    // Days of week card
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Days").bold()
                        HStack(spacing: 8) {
                            presetButton(title: "Every day") { setDays(everyDay: true) }
                            presetButton(title: "Weekdays") { setDays(weekdays: true) }
                            presetButton(title: "Weekends") { setDays(weekends: true) }
                        }
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                        .padding(.bottom, 4)

                        VStack(spacing: 8) {
                            dayToggle("Sunday", isOn: Binding(get: { sunday }, set: { sunday = $0; isUserEdited = true; scheduleAutosave() }))
                            dayToggle("Monday", isOn: Binding(get: { monday }, set: { monday = $0; isUserEdited = true; scheduleAutosave() }))
                            dayToggle("Tuesday", isOn: Binding(get: { tuesday }, set: { tuesday = $0; isUserEdited = true; scheduleAutosave() }))
                            dayToggle("Wednesday", isOn: Binding(get: { wednesday }, set: { wednesday = $0; isUserEdited = true; scheduleAutosave() }))
                            dayToggle("Thursday", isOn: Binding(get: { thursday }, set: { thursday = $0; isUserEdited = true; scheduleAutosave() }))
                            dayToggle("Friday", isOn: Binding(get: { friday }, set: { friday = $0; isUserEdited = true; scheduleAutosave() }))
                            dayToggle("Saturday", isOn: Binding(get: { saturday }, set: { saturday = $0; isUserEdited = true; scheduleAutosave() }))
                        }
                    }
                    .padding()
                    .background(themeManager.currentTheme.surface)
                    .cornerRadius(16)
                    .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
                    .padding(.horizontal)

                    // Date range card
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Active Date Range (Optional)").bold()

                        VStack(alignment: .leading, spacing: 8) {
                            Toggle(isOn: Binding<Bool>(
                                get: { startedAt != nil },
                                set: { newVal in startedAt = newVal ? Date() : nil; isUserEdited = true; scheduleAutosave() }
                            )) { Text("Starts at") }
                            .tint(themeManager.currentTheme.primary)
                            if let binding = optionalDateBinding($startedAt), startedAt != nil {
                                DatePicker("", selection: binding, displayedComponents: [.date])
                                    .datePickerStyle(.compact)
                                    .labelsHidden()
                                    .onChange(of: binding.wrappedValue) { _ in
                                        isUserEdited = true
                                        scheduleAutosave()
                                    }
                            }
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Toggle(isOn: Binding<Bool>(
                                get: { endsAt != nil },
                                set: { newVal in endsAt = newVal ? Date() : nil; isUserEdited = true; scheduleAutosave() }
                            )) { Text("Ends at") }
                            .tint(themeManager.currentTheme.primary)
                            if let binding = optionalDateBinding($endsAt), endsAt != nil {
                                DatePicker("", selection: binding, displayedComponents: [.date])
                                    .datePickerStyle(.compact)
                                    .labelsHidden()
                                    .onChange(of: binding.wrappedValue) { _ in
                                        isUserEdited = true
                                        scheduleAutosave()
                                    }
                            }
                        }
                    }
                    .padding()
                    .background(themeManager.currentTheme.surface)
                    .cornerRadius(16)
                    .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
                    .padding(.horizontal)

                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.footnote)
                            .padding(.horizontal)
                    }

                    if let _ = taskId {
                        Button(role: .destructive) {
                            confirmDeleteTask = true
                        } label: {
                            HStack {
                                Spacer()
                                Text("Delete Task").bold()
                                Spacer()
                            }
                            .padding()
                            .background(themeManager.currentTheme.error.opacity(0.1))
                            .cornerRadius(12)
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)
                        .alert("Delete Task?", isPresented: $confirmDeleteTask) {
                            Button("Cancel", role: .cancel) {}
                            Button("Delete", role: .destructive) {
                                if let id = taskId {
                                    Task { await deleteTask(id: id) }
                                }
                            }
                        } message: {
                            Text("Deleting this task will remove it from your Dashboard view.")
                        }
                    }

                    Spacer(minLength: 16)
                }
                .padding(.top, 24)
            }
        }
        .task { await loadIfNeeded() }
    }

    // MARK: - Subviews

    private func dayToggle(_ label: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            Text(label)
                .foregroundColor(isOn.wrappedValue ? themeManager.currentTheme.primary : .primary)
                .fontWeight(isOn.wrappedValue ? .semibold : .regular)
        }
        .tint(themeManager.currentTheme.primary)
    }

    private func presetButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.footnote)
                .padding(.vertical, 6)
                .padding(.horizontal, 10)
                .background(themeManager.currentTheme.surface)
                .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Data

    private func scheduleAutosave() {
        guard isUserEdited else { return }
        saveDebounceTask?.cancel()
        saveDebounceTask = Task { [name, sunday, monday, tuesday, wednesday, thursday, friday, saturday, startedAt, endsAt] in
            try? await Task.sleep(nanoseconds: 600_000_000)
            guard !Task.isCancelled else { return }
            await save()
        }
    }

    private func setDays(everyDay: Bool = false, weekdays: Bool = false, weekends: Bool = false) {
        if everyDay {
            sunday = true; monday = true; tuesday = true; wednesday = true; thursday = true; friday = true; saturday = true
        } else if weekdays {
            sunday = false; saturday = false
            monday = true; tuesday = true; wednesday = true; thursday = true; friday = true
        } else if weekends {
            monday = false; tuesday = false; wednesday = false; thursday = false; friday = false
            sunday = true; saturday = true
        }
        isUserEdited = true
        scheduleAutosave()
    }

    private func optionalDateBinding(_ binding: Binding<Date?>) -> Binding<Date>? {
        Binding<Date>(
            get: { binding.wrappedValue ?? Date() },
            set: { binding.wrappedValue = $0 }
        )
    }

    private func loadIfNeeded() async {
        guard let taskId = taskId else { return }
        do {
            if let task = try taskRepo.fetchOne(id: taskId) {
                await MainActor.run {
                    self.name = task.name
                    self.sunday = task.sunday
                    self.monday = task.monday
                    self.tuesday = task.tuesday
                    self.wednesday = task.wednesday
                    self.thursday = task.thursday
                    self.friday = task.friday
                    self.saturday = task.saturday
                    self.startedAt = task.startedAt
                    self.endsAt = task.endsAt
                }
            }
        } catch {
            await MainActor.run { self.errorMessage = "Failed to load task: \(error.localizedDescription)" }
        }
    }

    private func save() async {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            if let id = taskId {
                try taskRepo.updateName(id: id, to: name)
                try taskRepo.updateSchedule(
                    id: id,
                    sunday: sunday,
                    monday: monday,
                    tuesday: tuesday,
                    wednesday: wednesday,
                    thursday: thursday,
                    friday: friday,
                    saturday: saturday,
                    startedAt: startedAt,
                    endsAt: endsAt
                )
            }
        } catch {
            await MainActor.run { self.errorMessage = "Failed to save task: \(error.localizedDescription)" }
        }
    }
    
    private func deleteTask(id: Int64) async {
        do {
            try taskRepo.delete(id: id)
            await MainActor.run { dismiss() }
        } catch {
            await MainActor.run { self.errorMessage = "Failed to delete task: \(error.localizedDescription)" }
        }
    }
}

#Preview {
    TaskInfoView(taskId: 1)
}

