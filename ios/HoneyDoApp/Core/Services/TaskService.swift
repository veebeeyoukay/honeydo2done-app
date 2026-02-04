import Foundation
import Supabase
import Combine

/// Service for task operations
@MainActor
class TaskService: ObservableObject {
    private let supabase = SupabaseClientManager.shared.client

    @Published var tasks: [Task] = []
    @Published var isLoading = false
    @Published var error: Error?

    /// Fetch tasks for current user's household
    func fetchTasks() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let response: [Task] = try await supabase.database
                .from("tasks")
                .select()
                .order("created_at", ascending: false)
                .execute()
                .value

            tasks = response
        } catch {
            self.error = error
            print("Error fetching tasks: \(error)")
        }
    }

    /// Fetch single task by ID
    func fetchTask(id: String) async -> Task? {
        do {
            let response: Task = try await supabase.database
                .from("tasks")
                .select()
                .eq("id", value: id)
                .single()
                .execute()
                .value

            return response
        } catch {
            self.error = error
            print("Error fetching task: \(error)")
            return nil
        }
    }

    /// Create new task
    func createTask(title: String, description: String) async -> Task? {
        do {
            // Get current user
            guard let userId = try await supabase.auth.session.user.id.uuidString else {
                print("No authenticated user")
                return nil
            }

            // Get user's household
            let householdResponse: [HouseholdMember] = try await supabase.database
                .from("household_members")
                .select("household_id")
                .eq("user_id", value: userId)
                .limit(1)
                .execute()
                .value

            guard let householdId = householdResponse.first?.householdId else {
                print("User has no household")
                return nil
            }

            // Create task
            let newTask = TaskCreate(
                householdId: householdId,
                createdBy: userId,
                title: title,
                description: description,
                status: "captured",
                priority: "normal"
            )

            let response: Task = try await supabase.database
                .from("tasks")
                .insert(newTask)
                .select()
                .single()
                .execute()
                .value

            // Refresh task list
            await fetchTasks()

            return response
        } catch {
            self.error = error
            print("Error creating task: \(error)")
            return nil
        }
    }

    /// Start DIY mode for task
    func startDIY(taskId: String) async -> Bool {
        do {
            let _: [String: String] = try await supabase.functions
                .invoke("task-diy-start/\(taskId)", options: FunctionInvokeOptions(
                    method: .post
                ))

            await fetchTasks()
            return true
        } catch {
            self.error = error
            print("Error starting DIY: \(error)")
            return false
        }
    }

    /// Request professional help
    func requestPro(taskId: String) async -> Bool {
        do {
            let _: [String: String] = try await supabase.functions
                .invoke("task-pro-request/\(taskId)", options: FunctionInvokeOptions(
                    method: .post
                ))

            await fetchTasks()
            return true
        } catch {
            self.error = error
            print("Error requesting pro: \(error)")
            return false
        }
    }

    /// Subscribe to task updates via Realtime
    func subscribeToTask(id: String, onUpdate: @escaping (Task) -> Void) async {
        let channel = await supabase.channel("task-\(id)")

        await channel
            .on(
                .postgresChanges(
                    event: .update,
                    schema: "public",
                    table: "tasks",
                    filter: "id=eq.\(id)"
                )
            ) { payload in
                if let task = try? JSONDecoder().decode(Task.self, from: payload.record) {
                    onUpdate(task)
                }
            }
            .subscribe()
    }
}

/// Helper struct for task creation
struct TaskCreate: Encodable {
    let householdId: String
    let createdBy: String
    let title: String
    let description: String
    let status: String
    let priority: String

    enum CodingKeys: String, CodingKey {
        case householdId = "household_id"
        case createdBy = "created_by"
        case title, description, status, priority
    }
}

/// Helper struct for household member query
struct HouseholdMember: Decodable {
    let householdId: String

    enum CodingKeys: String, CodingKey {
        case householdId = "household_id"
    }
}
