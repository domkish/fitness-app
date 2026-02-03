import SwiftUI
import Foundation

// MARK: - Routine Picker
struct RoutinePickerSheet: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var authCoordinator: AuthCoordinator

    @ObservedObject var coordinator: AppShellCoordinator

    let onPicked: (Int64) -> Void

    private let workoutRepo = WorkoutRepository(dbQueue: DatabaseQueueProvider.shared.dbQueue)

    @State private var routines: [WorkoutDomain] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    init(coordinator: AppShellCoordinator, onPicked: @escaping (Int64) -> Void) {
        self.coordinator = coordinator
        self.onPicked = onPicked
    }

    var body: some View {
        NavigationStack {
            ZStack {
                themeManager.currentTheme.background.ignoresSafeArea()

                VStack(spacing: 16) {
                    if isLoading {
                        HStack { Spacer(); ProgressView(); Spacer() }
                            .padding()
                    } else if let msg = errorMessage {
                        VStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                                .imageScale(.large)
                            Text(msg)
                                .multilineTextAlignment(.center)
                                .foregroundColor(themeManager.currentTheme.textDefault)
                                .padding(.horizontal)
                        }
                        .padding()
                    } else if routines.isEmpty {
                        VStack(spacing: 10) {
                            Image(systemName: "dumbbell")
                                .font(.system(size: 28))
                                .foregroundColor(themeManager.currentTheme.muted)
                            Text("No routines yet")
                                .foregroundColor(themeManager.currentTheme.textDefault)
                            Text("Create a routine first, then add it to your calendar.")
                                .font(.footnote)
                                .foregroundColor(themeManager.currentTheme.muted)
                            Button {
                                coordinator.currentStep = .workout
                                onPicked(-1) // dismiss the sheet
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
                        }
                        .padding(.horizontal)
                    } else {
                        ScrollView {
                            VStack(spacing: 10) {
                                ForEach(routines.indices, id: \.self) { idx in
                                    let item = routines[idx]
                                    if let id = item.id {
                                        let c = colorForKey(item.color)
                                        Button(action: { onPicked(id) }) {
                                            VStack(alignment: .leading, spacing: 8) {
                                                HStack(spacing: 10) {
                                                    Circle()
                                                        .fill(c)
                                                        .frame(width: 14, height: 14)
                                                    Text(item.name)
                                                        .font(.headline)
                                                        .foregroundColor(c)
                                                    Spacer()
                                                }
                                            }
                                            .padding(12)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .background(
                                                RoundedRectangle(cornerRadius: 6)
                                                    .fill(c.opacity(0.1))
                                            )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }

                    Spacer(minLength: 0)
                }
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Select Routine")
                        .foregroundColor(themeManager.currentTheme.textDefault)
                        .font(.headline)
                }

                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onPicked(-1) }
                }
            }
            .task { await load() }
        }
    }

    private func load() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            guard let user = authCoordinator.currentUser else { return }
            let all = try workoutRepo.fetchAll(for: Int64(user.id))
            await MainActor.run {
                self.errorMessage = nil
                self.routines = all
            }
        } catch {
            await MainActor.run { self.errorMessage = error.localizedDescription }
            print("[RoutinePickerSheet] load error: \(error)")
        }
    }

    private func colorForKey(_ key: String?) -> Color {
        switch key ?? "primary" {
        case "primary": return themeManager.currentTheme.primary
        case "secondary": return themeManager.currentTheme.secondary
        case "success": return AppColors.success
        case "warning": return AppColors.warning
        case "error": return themeManager.currentTheme.error
        case "important": return themeManager.currentTheme.important
        default: return themeManager.currentTheme.primary
        }
    }
}

// MARK: - Frequency Picker
struct FrequencyPickerSheet: View {
    @EnvironmentObject var themeManager: ThemeManager

    let onPicked: (Int?) -> Void

    private struct Option: Identifiable { let id: Int?; let title: String }
    private var options: [Option] {
        [
            Option(id: nil, title: "Just selected date"),
            Option(id: 1, title: "Weekly"),
            Option(id: 2, title: "Every 2 Weeks")
        ]
    }

    var body: some View {
        NavigationStack {
            List(options) { opt in
                Button(action: { onPicked(opt.id) }) {
                    HStack {
                        Text(opt.title)
                            .foregroundColor(themeManager.currentTheme.textDefault)
                        Spacer()
                    }
                }
                .listRowBackground(themeManager.currentTheme.surface)
            }
            .scrollContentBackground(.hidden)
            .background(themeManager.currentTheme.background)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Select Routine")
                        .foregroundColor(themeManager.currentTheme.textDefault)
                        .font(.headline)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onPicked(-1) }
                }
            }
        }
    }
}

// MARK: - Weekday Picker
struct WeekdayPickerSheet: View {
    @EnvironmentObject var themeManager: ThemeManager

    let initialSelectedWeekday: Int // 1 = Sunday ... 7 = Saturday (Calendar.current.component(.weekday, from: date))
    let onDone: (_ days: (mon: Bool, tues: Bool, wed: Bool, thurs: Bool, fri: Bool, sat: Bool, sun: Bool)) -> Void

    @State private var mon = false
    @State private var tues = false
    @State private var wed = false
    @State private var thurs = false
    @State private var fri = false
    @State private var sat = false
    @State private var sun = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Days of Week") {
                    Toggle("Sunday", isOn: $sun)
                        .foregroundColor(themeManager.currentTheme.textDefault)
                    Toggle("Monday", isOn: $mon)
                        .foregroundColor(themeManager.currentTheme.textDefault)
                    Toggle("Tuesday", isOn: $tues)
                        .foregroundColor(themeManager.currentTheme.textDefault)
                    Toggle("Wednesday", isOn: $wed)
                        .foregroundColor(themeManager.currentTheme.textDefault)
                    Toggle("Thursday", isOn: $thurs)
                        .foregroundColor(themeManager.currentTheme.textDefault)
                    Toggle("Friday", isOn: $fri)
                        .foregroundColor(themeManager.currentTheme.textDefault)
                    Toggle("Saturday", isOn: $sat)
                        .foregroundColor(themeManager.currentTheme.textDefault)
                }
                .listRowBackground(themeManager.currentTheme.surface)
                .foregroundColor(themeManager.currentTheme.textDefault)
            }
            .scrollContentBackground(.hidden)
            .background(themeManager.currentTheme.background)
            .onAppear(perform: preselect)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        onDone((mon, tues, wed, thurs, fri, sat, sun))
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onDone((false,false,false,false,false,false,false)) }
                }
            }
        }
    }

    private func preselect() {
        switch initialSelectedWeekday { // 1 = Sunday ... 7 = Saturday
        case 1: sun = true
        case 2: mon = true
        case 3: tues = true
        case 4: wed = true
        case 5: thurs = true
        case 6: fri = true
        case 7: sat = true
        default: break
        }
    }
}
