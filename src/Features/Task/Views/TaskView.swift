//
//  TaskView.swift
//  SimplyFitness
//
//  Created by Dominic Kish on 1/25/26.
//

import SwiftUI
import GRDB

struct TaskView: View {
    @ObservedObject var coordinator: AppShellCoordinator
    @EnvironmentObject var authCoordinator: AuthCoordinator
    @EnvironmentObject var themeManager: ThemeManager
    
    @State private var tasks: [TaskItem] = []
    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil
    @State private var isShowingAddPopup: Bool = false
    @State private var newTaskName: String = ""
    @State private var navigateToTaskId: Int64? = nil
    @State private var shouldNavigateToDetail: Bool = false
    @State private var isPremiumUser: Bool = false
    @State private var showLimitPopover: Bool = false
    @State private var showPremium: Bool = false
    
    private let taskRepo: TaskRepository = TaskRepository(dbQueue: DatabaseQueueProvider.shared.dbQueue)
    private let userRepo: UserRepository = UserRepository(dbQueue: DatabaseQueueProvider.shared.dbQueue)
    
    private struct TaskItem: Identifiable, Hashable {
        let id: Int64
        let name: String
        let color: String?
    }
    
    init(coordinator: AppShellCoordinator) {
        self.coordinator = coordinator
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                themeManager.currentTheme.background
                    .ignoresSafeArea()
                
                VStack(spacing: 30) {
                    
                    HStack {
                        Text("Weekly Tasks")
                            .font(.title)
                            .bold()
                            .foregroundColor(themeManager.currentTheme.textDefault)
                        
                        Spacer()
                        
                        let maxTasks = isPremiumUser ? 10 : 3
                        Button {
                            if tasks.count >= maxTasks {
                                showLimitPopover = true
                            } else {
                                isShowingAddPopup = true
                            }
                        } label: {
                            Image(systemName: "plus")
                                .font(.headline)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 12)
                                .background(themeManager.currentTheme.surface)
                                .foregroundColor(showLimitPopover ? themeManager.currentTheme.muted : themeManager.currentTheme.primary)
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                        .popover(isPresented: $showLimitPopover) {
                            VStack(spacing: 14) {
                                Text("Tasks Limit Reached")
                                    .font(.title3)
                                    .bold()
                                Text("Upgrade to premium to add more than \(maxTasks) tasks and unlock additional features.")
                                    .font(.callout)
                                    .multilineTextAlignment(.center)
                                    .foregroundColor(themeManager.currentTheme.surface.opacity(0.7))
                                
                                Button {
                                    showLimitPopover = false
                                    showPremium = true
                                } label: {
                                    Text("View Premium")
                                        .font(.headline)
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(themeManager.currentTheme.primary)
                                        .foregroundColor(themeManager.currentTheme.background)
                                        .cornerRadius(8)
                                }
                                
                                Button {
                                    showLimitPopover = false
                                } label: {
                                    Text("Cancel")
                                        .font(.subheadline)
                                        .foregroundColor(themeManager.currentTheme.primary)
                                }
                            }
                            .padding(24)
                            .frame(maxWidth: 300)
                        }
                    }
                    .padding(.horizontal)
                    
                    VStack(spacing: 0) {
                        if isLoading {
                            HStack {
                                Spacer()
                                ProgressView()
                                Spacer()
                            }
                            .padding()
                            .background(themeManager.currentTheme.surface)
                            .cornerRadius(12)
                            .padding(.horizontal)
                        } else if let error = errorMessage {
                            VStack(spacing: 8) {
                                Text("Error")
                                    .font(.title3)
                                    .bold()
                                Text(error)
                                    .font(.callout)
                                    .foregroundColor(themeManager.currentTheme.error)
                                    .multilineTextAlignment(.center)
                                Button {
                                    Task {
                                        await loadTasks()
                                    }
                                } label: {
                                    Text("Retry")
                                        .font(.headline)
                                        .padding(.horizontal, 32)
                                        .padding(.vertical, 10)
                                        .background(themeManager.currentTheme.primary)
                                        .foregroundColor(themeManager.currentTheme.background)
                                        .cornerRadius(8)
                                }
                            }
                            .padding()
                            .background(themeManager.currentTheme.surface)
                            .cornerRadius(12)
                            .padding(.horizontal)
                        } else if tasks.isEmpty {
                            VStack(spacing: 8) {
                                Image(systemName: "checklist")
                                    .font(.system(size: 48))
                                    .foregroundColor(themeManager.currentTheme.textDefault)
                                    .padding(.bottom, 4)
                                Text("No Tasks Yet")
                                    .font(.title3).bold()
                                    .foregroundColor(themeManager.currentTheme.textDefault)
                                Text("Tap the \"+\" button above to add your first task.")
                                    .font(.callout)
                                    .foregroundColor(themeManager.currentTheme.muted)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 40)
                            }
                            .padding(.vertical, 16)
                            
                            // Dashed separator and info under empty state
                            Capsule()
                                .stroke(style: StrokeStyle(lineWidth: 4, dash: [6, 4]))
                                .foregroundColor(themeManager.currentTheme.borderDefault)
                                .frame(height: 1)
                                .padding(.horizontal)
                                .padding(.top, 28)

                            VStack(alignment: .leading, spacing: 12) {
                                HStack(alignment: .firstTextBaseline, spacing: 8) {
                                    Text("What are Tasks?")
                                        .font(.title3)
                                        .bold()
                                        .foregroundColor(themeManager.currentTheme.textDefault)
                                }

                                Text("Tasks are your simple, repeatable goals that show up on your calendar as a friendly checklist. Make them daily or weekly — whatever fits your routine.")
                                    .font(.callout)
                                    .foregroundColor(themeManager.currentTheme.muted)
                                    .fixedSize(horizontal: false, vertical: true)

                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Examples")
                                        .font(.subheadline)
                                        .bold()
                                        .foregroundColor(themeManager.currentTheme.secondary)
                                    VStack(alignment: .leading, spacing: 6) {
                                        HStack(spacing: 8) {
                                            Circle().fill(themeManager.currentTheme.textDefault).frame(width: 6, height: 6)
                                            Text("Drink 1 Gallon of Water")
                                                .foregroundColor(themeManager.currentTheme.textDefault)
                                                .font(.callout)
                                        }
                                        HStack(spacing: 8) {
                                            Circle().fill(themeManager.currentTheme.textDefault).frame(width: 6, height: 6)
                                            Text("Get 8 Hours of Sleep")
                                                .foregroundColor(themeManager.currentTheme.textDefault)
                                                .font(.callout)
                                        }
                                        HStack(spacing: 8) {
                                            Circle().fill(themeManager.currentTheme.textDefault).frame(width: 6, height: 6)
                                            Text("Plan Meals for the Week")
                                                .foregroundColor(themeManager.currentTheme.textDefault)
                                                .font(.callout)
                                        }
                                        HStack(spacing: 8) {
                                            Circle().fill(themeManager.currentTheme.textDefault).frame(width: 6, height: 6)
                                            Text("Practice 5 Minutes of Mindfulness")
                                                .foregroundColor(themeManager.currentTheme.textDefault)
                                                .font(.callout)
                                        }
                                    }
                                }

                                HStack(alignment: .center, spacing: 10) {
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundColor(themeManager.currentTheme.primary)
                                    Text("Tap the \"+\" above to add a task to get started!")
                                        .font(.callout)
                                        .foregroundColor(themeManager.currentTheme.muted)
                                }
                            }
                            .padding(16)
                            .padding(.top, 6)
                            
                            Spacer()
                        } else {
                            ScrollView {
                                VStack(spacing: 10) {
                                    ForEach(tasks, id: \.self) { task in
                                        NavigationLink(value: task.id) {
                                            HStack(spacing: 12) {
                                                Circle()
                                                    .fill(colorForKey(task.color))
                                                    .frame(width: 14, height: 14)
                                                
                                                Text(task.name)
                                                    .font(.headline)
                                                    .foregroundColor(themeManager.currentTheme.primary)
                                                
                                                Spacer()
                                                Image(systemName: "chevron.right")
                                                    .font(.subheadline)
                                                    .foregroundColor(themeManager.currentTheme.primary.opacity(0.6))
                                            }
                                            .padding()
                                            .background(RoundedRectangle(cornerRadius: 12).fill(themeManager.currentTheme.primary).opacity(0.1))
                                            .padding(.horizontal)
                                        }
                                    }
                                    
                                    Capsule()
                                        .stroke(style: StrokeStyle(lineWidth: 4, dash: [6, 4]))
                                        .foregroundColor(themeManager.currentTheme.borderDefault)
                                        .frame(height: 1)
                                        .padding(.horizontal)
                                        .padding(.top, 28)

                                    VStack(alignment: .leading, spacing: 12) {
                                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                                            Text("What are Tasks?")
                                                .font(.title3)
                                                .bold()
                                                .foregroundColor(themeManager.currentTheme.textDefault)
                                        }

                                        Text("Tasks are your simple, repeatable goals that show up on your Dashboard as a friendly checklist. Make them daily or weekly — whatever fits your routine.")
                                            .font(.callout)
                                            .foregroundColor(themeManager.currentTheme.muted)
                                            .fixedSize(horizontal: false, vertical: true)

                                        VStack(alignment: .leading, spacing: 8) {
                                            Text("Examples")
                                                .font(.subheadline)
                                                .bold()
                                                .foregroundColor(themeManager.currentTheme.secondary)
                                            VStack(alignment: .leading, spacing: 6) {
                                                HStack(spacing: 8) {
                                                    Circle().fill(themeManager.currentTheme.textDefault).frame(width: 6, height: 6)
                                                    Text("Drink 1 Gallon of Water")
                                                        .foregroundColor(themeManager.currentTheme.textDefault)
                                                        .font(.callout)
                                                }
                                                HStack(spacing: 8) {
                                                    Circle().fill(themeManager.currentTheme.textDefault).frame(width: 6, height: 6)
                                                    Text("Get 8 Hours of Sleep")
                                                        .foregroundColor(themeManager.currentTheme.textDefault)
                                                        .font(.callout)
                                                }
                                                HStack(spacing: 8) {
                                                    Circle().fill(themeManager.currentTheme.textDefault).frame(width: 6, height: 6)
                                                    Text("Plan Meals for the Week")
                                                        .foregroundColor(themeManager.currentTheme.textDefault)
                                                        .font(.callout)
                                                }
                                                HStack(spacing: 8) {
                                                    Circle().fill(themeManager.currentTheme.textDefault).frame(width: 6, height: 6)
                                                    Text("Practice 5 Minutes of Mindfulness")
                                                        .foregroundColor(themeManager.currentTheme.textDefault)
                                                        .font(.callout)
                                                }
                                            }
                                        }

                                        HStack(alignment: .center, spacing: 10) {
                                            Image(systemName: "plus.circle.fill")
                                                .foregroundColor(themeManager.currentTheme.primary)
                                            Text("Tap the \"+\" above to add a task to get started!")
                                                .font(.callout)
                                                .foregroundColor(themeManager.currentTheme.muted)
                                        }
                                    }
                                    .padding(16)
                                    .padding(.top, 6)
                                }
                                .padding(.vertical, 10)
                            }
                        }
                    }
                    
                    Spacer()
                }
                
                if isShowingAddPopup {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .onTapGesture {
                            isShowingAddPopup = false
                        }
                    
                    VStack(spacing: 16) {
                        Text("New Task")
                            .font(.title3)
                            .bold()
                            .foregroundColor(themeManager.currentTheme.textDefault)
                        
                        TextField("", text: $newTaskName)
                            .themedPlaceholder("Task name", when: newTaskName.isEmpty, color: themeManager.currentTheme.muted)
                            .padding(12)
                            .background(themeManager.currentTheme.surface)
                            .foregroundColor(themeManager.currentTheme.textDefault)
                            .cornerRadius(8)
                            .submitLabel(.done)
                            .autocorrectionDisabled(true)
                            .onSubmit {
                                Task {
                                    await createTask()
                                }
                            }
                        
                        HStack(spacing: 16) {
                            Button {
                                isShowingAddPopup = false
                                newTaskName = ""
                            } label: {
                                Text("Cancel")
                                    .font(.headline)
                                    .foregroundColor(themeManager.currentTheme.primary)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(themeManager.currentTheme.surface)
                                    .cornerRadius(8)
                            }
                            
                            Button {
                                Task {
                                    await createTask()
                                }
                            } label: {
                                Text("Create")
                                    .font(.headline)
                                    .foregroundColor(themeManager.currentTheme.textDefault)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(newTaskName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? themeManager.currentTheme.primary.opacity(0.5) : themeManager.currentTheme.primary)
                                    .cornerRadius(8)
                            }
                            .disabled(newTaskName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                    .padding(24)
                    .background(themeManager.currentTheme.background)
                    .cornerRadius(16)
                    .padding(.horizontal, 40)
                    .shadow(radius: 20)
                }
                
                NavigationLink(
                    destination: AnyView(
                        Group {
                            if let id = navigateToTaskId {
                                TaskInfoView(taskId: id)
                                    .environmentObject(themeManager)
                            } else {
                                Text("Loading…").hidden()
                            }
                        }
                    ),
                    isActive: $shouldNavigateToDetail,
                    label: {
                        EmptyView()
                    })
                .hidden()
            }
            .navigationDestination(isPresented: $showPremium) {
                PremiumView(coordinator: coordinator)
                    .environmentObject(authCoordinator)
            }
            .navigationDestination(for: Int64.self) { taskId in
                TaskInfoView(taskId: taskId)
                    .environmentObject(themeManager)
            }
            .task {
                await loadCurrentUserPremium()
                await loadTasks()
            }
        }
    }
    
    private func colorForKey(_ key: String?) -> Color {
        guard let key = key else { return themeManager.currentTheme.primary }
        switch key.lowercased() {
        case "primary": return themeManager.currentTheme.primary
        case "secondary": return themeManager.currentTheme.secondary
        case "success": return themeManager.currentTheme.success
        case "warning": return themeManager.currentTheme.warning
        case "error": return themeManager.currentTheme.error
        case "important": return themeManager.currentTheme.important
        default: return themeManager.currentTheme.primary
        }
    }
    
    @MainActor
    private func loadTasks() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            guard let user = try await userRepo.fetchUser() else {
                self.tasks = []
                self.errorMessage = "No current user found."
                return
            }
            let rows = try taskRepo.fetchAll(for: Int64(user.id))
            self.tasks = rows.map { TaskItem(id: $0.id ?? -1, name: $0.name, color: nil) }
        } catch {
            self.errorMessage = "Failed to load tasks: \(error.localizedDescription)"
            self.tasks = []
        }
    }
    
    @MainActor
    private func createTask() async {
        let trimmedName = newTaskName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        do {
            guard let user = try await userRepo.fetchUser() else {
                self.errorMessage = "No current user found."
                return
            }
            let newId = try taskRepo.create(name: trimmedName, userId: Int64(user.id))
            isShowingAddPopup = false
            newTaskName = ""
            tasks.append(TaskItem(id: newId, name: trimmedName, color: nil))
            navigateToTaskId = newId
            shouldNavigateToDetail = true
        } catch {
            self.errorMessage = "Failed to create task: \(error.localizedDescription)"
        }
    }
    
    @MainActor
    private func loadCurrentUserPremium() async {
        do {
            if let user = try await userRepo.fetchUser() {
                self.isPremiumUser = user.isPremium
            } else {
                self.isPremiumUser = false
            }
        } catch {
            self.isPremiumUser = false
        }
    }
}

