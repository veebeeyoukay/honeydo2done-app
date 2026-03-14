import SwiftUI

struct TaskListView: View {
    @StateObject private var taskService = TaskService()
    @State private var selectedFilter: TaskStatus?

    var filteredTasks: [Task] {
        if let filter = selectedFilter {
            return taskService.tasks.filter { $0.status == filter }
        }
        return taskService.tasks
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Filter pills
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        FilterPill(title: "All", isSelected: selectedFilter == nil) {
                            selectedFilter = nil
                        }

                        ForEach([TaskStatus.triaging, .awaitingDecision, .diyInProgress, .proRequested, .scheduled, .completed], id: \.self) { status in
                            FilterPill(title: status.displayName, isSelected: selectedFilter == status) {
                                selectedFilter = status
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
                .background(Color(.systemBackground))

                Divider()

                // Task list
                if taskService.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if filteredTasks.isEmpty {
                    EmptyStateView(
                        icon: "checkmark.circle",
                        title: selectedFilter == nil ? "No tasks yet" : "No \(selectedFilter!.displayName.lowercased()) tasks",
                        subtitle: selectedFilter == nil ? "Tap + to create your first task" : "Try a different filter"
                    )
                } else {
                    List(filteredTasks) { task in
                        NavigationLink(destination: TaskDetailView(taskId: task.id)) {
                            TaskCard(task: task)
                        }
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .listRowSeparator(.hidden)
                    }
                    .listStyle(.plain)
                    .refreshable {
                        await taskService.fetchTasks()
                    }
                }
            }
            .navigationTitle("Tasks")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: TaskCreateView()) {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .task {
            await taskService.fetchTasks()
        }
    }
}

struct FilterPill: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.blue : Color(.systemGray6))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(20)
        }
    }
}

struct EmptyStateView: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 60))
                .foregroundColor(.gray)

            Text(title)
                .font(.title3)
                .fontWeight(.semibold)

            Text(subtitle)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}
