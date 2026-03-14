import SwiftUI

struct DecisionPromptView: View {
    let task: Task
    @EnvironmentObject var taskService: TaskService
    @State private var isProcessing = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.yellow)
                Text("Ready to decide")
                    .font(.headline)
            }

            Text("Based on what you've told me, here are your options:")
                .font(.subheadline)
                .foregroundColor(.secondary)

            // Options
            VStack(spacing: 12) {
                DecisionOptionCard(
                    icon: "hammer.fill",
                    title: "DIY It",
                    subtitle: "I'll guide you step-by-step",
                    color: .purple,
                    isProcessing: isProcessing
                ) {
                    await handleDIY()
                }

                DecisionOptionCard(
                    icon: "person.2.fill",
                    title: "Assign to Someone",
                    subtitle: "Give this to a household member",
                    color: .blue,
                    isProcessing: isProcessing
                ) {
                    // TODO: Show household member picker
                }

                DecisionOptionCard(
                    icon: "wrench.and.screwdriver.fill",
                    title: "Get a Pro",
                    subtitle: "We'll find a trusted professional",
                    color: .green,
                    isProcessing: isProcessing
                ) {
                    await handlePro()
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private func handleDIY() async {
        isProcessing = true
        let success = await taskService.startDIY(taskId: task.id)
        isProcessing = false

        if !success {
            // Show error
            print("Failed to start DIY")
        }
    }

    private func handlePro() async {
        isProcessing = true
        let success = await taskService.requestPro(taskId: task.id)
        isProcessing = false

        if !success {
            // Show error
            print("Failed to request pro")
        }
    }
}

struct DecisionOptionCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let isProcessing: Bool
    let action: () async -> Void

    var body: some View {
        Button(action: {
            Task {
                await action()
            }
        }) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                    .frame(width: 40)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if isProcessing {
                    ProgressView()
                } else {
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(10)
        }
        .disabled(isProcessing)
    }
}
