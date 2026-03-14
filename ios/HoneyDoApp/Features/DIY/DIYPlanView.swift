import SwiftUI

struct DIYPlanView: View {
    let taskId: String
    @State private var diyPlan: DIYPlan?
    @State private var isLoading = true
    @State private var completedSteps: Set<Int> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: "hammer.circle.fill")
                    .font(.title2)
                    .foregroundColor(.purple)

                VStack(alignment: .leading) {
                    Text("DIY Plan")
                        .font(.headline)

                    if let plan = diyPlan {
                        Text("\(plan.difficulty.capitalized) • ~\(plan.timeEstimateMinutes) min")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()
            }

            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
            } else if let plan = diyPlan {
                // Safety warnings
                if !plan.safetyWarnings.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Safety First", systemImage: "exclamationmark.triangle.fill")
                            .font(.headline)
                            .foregroundColor(.orange)

                        ForEach(plan.safetyWarnings, id: \.self) { warning in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .foregroundColor(.orange)
                                Text(warning)
                                    .font(.subheadline)
                            }
                        }
                    }
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
                }

                // Tools and materials
                if !plan.toolsNeeded.isEmpty || !plan.materialsNeeded.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        if !plan.toolsNeeded.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Label("Tools Needed", systemImage: "wrench.fill")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)

                                ForEach(plan.toolsNeeded, id: \.self) { tool in
                                    HStack {
                                        Image(systemName: "checkmark.circle")
                                        Text(tool)
                                            .font(.subheadline)
                                    }
                                }
                            }
                        }

                        if !plan.materialsNeeded.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Label("Materials", systemImage: "shippingbox.fill")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)

                                ForEach(plan.materialsNeeded, id: \.self) { material in
                                    HStack {
                                        Image(systemName: "checkmark.circle")
                                        Text(material)
                                            .font(.subheadline)
                                    }
                                }
                            }
                        }
                    }
                }

                // Steps
                VStack(alignment: .leading, spacing: 8) {
                    Text("Steps")
                        .font(.headline)

                    ForEach(plan.steps) { step in
                        DIYStepCard(
                            step: step,
                            isCompleted: completedSteps.contains(step.number)
                        ) {
                            toggleStep(step.number)
                        }
                    }
                }

                // Stop conditions
                if !plan.stopConditions.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Stop and call a pro if:", systemImage: "hand.raised.fill")
                            .font(.headline)
                            .foregroundColor(.red)

                        ForEach(plan.stopConditions, id: \.self) { condition in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.red)
                                Text(condition)
                                    .font(.subheadline)
                            }
                        }
                    }
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
                }
            } else {
                Text("DIY plan not available")
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .task {
            await loadDIYPlan()
        }
    }

    private func loadDIYPlan() async {
        // Fetch DIY plan from task artifacts
        let supabase = SupabaseClientManager.shared.client

        do {
            let response: [TaskArtifact] = try await supabase.database
                .from("task_artifacts")
                .select()
                .eq("task_id", value: taskId)
                .eq("type", value: "ai_diy_plan")
                .order("created_at", ascending: false)
                .limit(1)
                .execute()
                .value

            if let artifact = response.first,
               let jsonData = try? JSONSerialization.data(withJSONObject: artifact.content),
               let plan = try? JSONDecoder().decode(DIYPlan.self, from: jsonData) {
                diyPlan = plan
            }
        } catch {
            print("Error loading DIY plan: \(error)")
        }

        isLoading = false
    }

    private func toggleStep(_ number: Int) {
        if completedSteps.contains(number) {
            completedSteps.remove(number)
        } else {
            completedSteps.insert(number)
        }
    }
}

struct DIYStepCard: View {
    let step: DIYStep
    let isCompleted: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(alignment: .top, spacing: 12) {
                // Checkbox
                Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundColor(isCompleted ? .green : .gray)

                // Content
                VStack(alignment: .leading, spacing: 6) {
                    Text("Step \(step.number): \(step.title)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)

                    Text(step.instruction)
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    if let safetyNote = step.safetyNote {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text(safetyNote)
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                }

                Spacer()
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(8)
            .opacity(isCompleted ? 0.6 : 1.0)
        }
    }
}

// Models
struct DIYPlan: Codable {
    let title: String
    let difficulty: String
    let timeEstimateMinutes: Int
    let toolsNeeded: [String]
    let materialsNeeded: [String]
    let safetyWarnings: [String]
    let stopConditions: [String]
    let steps: [DIYStep]

    enum CodingKeys: String, CodingKey {
        case title, difficulty, steps
        case timeEstimateMinutes = "time_estimate_minutes"
        case toolsNeeded = "tools_needed"
        case materialsNeeded = "materials_needed"
        case safetyWarnings = "safety_warnings"
        case stopConditions = "stop_conditions"
    }
}

struct DIYStep: Codable, Identifiable {
    let number: Int
    let title: String
    let instruction: String
    let safetyNote: String?

    var id: Int { number }

    enum CodingKeys: String, CodingKey {
        case number, title, instruction
        case safetyNote = "safety_note"
    }
}

struct TaskArtifact: Codable {
    let id: String
    let taskId: String
    let type: String
    let content: [String: Any]

    enum CodingKeys: String, CodingKey {
        case id, type
        case taskId = "task_id"
        case content
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        taskId = try container.decode(String.self, forKey: .taskId)
        type = try container.decode(String.self, forKey: .type)

        // Decode content as dictionary
        let contentData = try container.decode(Data.self, forKey: .content)
        content = try JSONSerialization.jsonObject(with: contentData) as? [String: Any] ?? [:]
    }
}
