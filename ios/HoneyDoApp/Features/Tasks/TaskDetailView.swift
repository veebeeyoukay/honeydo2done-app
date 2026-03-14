import SwiftUI

struct TaskDetailView: View {
    let taskId: String

    @StateObject private var viewModel: TaskDetailViewModel
    @State private var showingActionSheet = false

    init(taskId: String) {
        self.taskId = taskId
        _viewModel = StateObject(wrappedValue: TaskDetailViewModel(taskId: taskId))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let task = viewModel.task {
                    // Status and priority
                    HStack {
                        TaskStatusBadge(status: task.status)
                        Spacer()
                        TaskPriorityBadge(priority: task.priority)
                    }

                    // Title and description
                    VStack(alignment: .leading, spacing: 8) {
                        Text(task.title)
                            .font(.title2)
                            .fontWeight(.bold)

                        Text(task.description)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }

                    Divider()

                    // Decision prompt (if awaiting decision)
                    if task.status == .awaitingDecision {
                        DecisionPromptView(task: task)
                            .environmentObject(viewModel.taskService)
                    }

                    // DIY plan (if in DIY mode)
                    if task.status == .diyInProgress {
                        DIYPlanView(taskId: taskId)
                    }

                    // Chat/Messages
                    ChatView(taskId: taskId)

                } else if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: 200)
                } else {
                    Text("Task not found")
                        .foregroundColor(.secondary)
                }
            }
            .padding()
        }
        .navigationTitle("Task Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingActionSheet = true }) {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .confirmationDialog("Task Actions", isPresented: $showingActionSheet) {
            if let task = viewModel.task {
                if task.status == .awaitingDecision {
                    Button("Start DIY") {
                        Task {
                            await viewModel.startDIY()
                        }
                    }

                    Button("Request Pro") {
                        Task {
                            await viewModel.requestPro()
                        }
                    }
                }

                Button("Cancel Task", role: .destructive) {
                    // TODO: Cancel task
                }
            }
        }
        .task {
            await viewModel.loadTask()
            await viewModel.subscribeToUpdates()
        }
    }
}

@MainActor
class TaskDetailViewModel: ObservableObject {
    let taskId: String
    let taskService = TaskService()

    @Published var task: Task?
    @Published var isLoading = false

    init(taskId: String) {
        self.taskId = taskId
    }

    func loadTask() async {
        isLoading = true
        task = await taskService.fetchTask(id: taskId)
        isLoading = false
    }

    func subscribeToUpdates() async {
        await taskService.subscribeToTask(id: taskId) { [weak self] updatedTask in
            self?.task = updatedTask
        }
    }

    func startDIY() async {
        let success = await taskService.startDIY(taskId: taskId)
        if success {
            await loadTask()
        }
    }

    func requestPro() async {
        let success = await taskService.requestPro(taskId: taskId)
        if success {
            await loadTask()
        }
    }
}
