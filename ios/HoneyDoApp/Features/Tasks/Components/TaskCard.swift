import SwiftUI

struct TaskCard: View {
    let task: Task

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                TaskStatusBadge(status: task.status)
                Spacer()
                TaskPriorityBadge(priority: task.priority)
            }

            // Title
            Text(task.title)
                .font(.headline)
                .lineLimit(2)

            // Description
            Text(task.description)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(2)

            // Footer
            HStack {
                if let category = task.category {
                    Label(category.displayName, systemImage: categoryIcon(for: category))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Text(task.createdAt, style: .relative)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }

    private func categoryIcon(for category: TaskCategory) -> String {
        switch category {
        case .smartHome: return "wifi"
        case .techGuard: return "desktopcomputer"
        case .aquaTech: return "drop.fill"
        case .garageTech: return "car.garage"
        case .hvac: return "thermometer"
        case .electrical: return "bolt.fill"
        case .plumbing: return "drop.fill"
        case .general: return "wrench.fill"
        case .other: return "questionmark.circle"
        }
    }
}

struct TaskStatusBadge: View {
    let status: TaskStatus

    var body: some View {
        Text(status.displayName)
            .font(.caption)
            .fontWeight(.semibold)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(backgroundColor)
            .foregroundColor(.white)
            .cornerRadius(6)
    }

    private var backgroundColor: Color {
        switch status {
        case .captured: return .gray
        case .triaging: return .blue
        case .awaitingDecision: return .orange
        case .diyInProgress: return .purple
        case .proRequested: return .yellow
        case .proAssigned: return .green
        case .scheduled: return .green
        case .inProgress: return .blue
        case .completed: return .green
        case .cancelled: return .red
        }
    }
}

struct TaskPriorityBadge: View {
    let priority: TaskPriority

    var body: some View {
        if priority != .normal {
            HStack(spacing: 4) {
                Image(systemName: icon)
                Text(priority.displayName)
            }
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundColor(color)
        }
    }

    private var icon: String {
        switch priority {
        case .urgent: return "exclamationmark.triangle.fill"
        case .high: return "arrow.up.circle.fill"
        case .normal: return "circle"
        case .low: return "arrow.down.circle"
        }
    }

    private var color: Color {
        switch priority {
        case .urgent: return .red
        case .high: return .orange
        case .normal: return .gray
        case .low: return .blue
        }
    }
}
