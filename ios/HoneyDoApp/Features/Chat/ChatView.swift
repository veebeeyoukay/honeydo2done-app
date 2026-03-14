import SwiftUI

struct ChatView: View {
    let taskId: String

    @StateObject private var viewModel: ChatViewModel
    @State private var messageText = ""

    init(taskId: String) {
        self.taskId = taskId
        _viewModel = StateObject(wrappedValue: ChatViewModel(taskId: taskId))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "message.fill")
                    .foregroundColor(.blue)
                Text("Conversation")
                    .font(.headline)
                Spacer()
            }
            .padding()
            .background(Color(.systemGray6))

            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.messages) { message in
                            MessageBubble(message: message)
                                .id(message.id)
                        }
                    }
                    .padding()
                }
                .onChange(of: viewModel.messages.count) { _ in
                    if let lastMessage = viewModel.messages.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }

            // Input
            HStack(spacing: 12) {
                TextField("Type a message...", text: $messageText, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...5)

                Button(action: sendMessage) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(messageText.isEmpty ? .gray : .blue)
                }
                .disabled(messageText.isEmpty)
            }
            .padding()
            .background(Color(.systemBackground))
        }
        .task {
            await viewModel.loadMessages()
            await viewModel.subscribeToMessages()
        }
    }

    private func sendMessage() {
        let text = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        Task {
            await viewModel.sendMessage(text)
            messageText = ""
        }
    }
}

struct MessageBubble: View {
    let message: TaskMessage

    var body: some View {
        HStack {
            if message.isFromUser {
                Spacer()
            }

            VStack(alignment: message.isFromUser ? .trailing : .leading, spacing: 4) {
                // Sender label for AI/system messages
                if !message.isFromUser {
                    HStack(spacing: 4) {
                        Image(systemName: senderIcon)
                            .font(.caption)
                        Text(senderName)
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.secondary)
                }

                // Message content
                Text(message.content)
                    .padding(12)
                    .background(bubbleColor)
                    .foregroundColor(message.isFromUser ? .white : .primary)
                    .cornerRadius(16)

                // Timestamp
                Text(message.createdAt, style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            if !message.isFromUser {
                Spacer()
            }
        }
    }

    private var bubbleColor: Color {
        if message.isFromUser {
            return .blue
        } else if message.isFromAI {
            return Color(.systemGray6)
        } else {
            return Color(.systemGray5)
        }
    }

    private var senderIcon: String {
        switch message.senderType {
        case .ai: return "sparkles"
        case .partner: return "wrench.fill"
        case .system: return "info.circle"
        case .user: return "person.fill"
        }
    }

    private var senderName: String {
        switch message.senderType {
        case .ai:
            if let persona = message.personaUsed {
                return persona.displayName
            }
            return "AI Assistant"
        case .partner: return "Partner"
        case .system: return "System"
        case .user: return "You"
        }
    }
}

@MainActor
class ChatViewModel: ObservableObject {
    let taskId: String
    private let supabase = SupabaseClientManager.shared.client

    @Published var messages: [TaskMessage] = []
    @Published var isLoading = false

    init(taskId: String) {
        self.taskId = taskId
    }

    func loadMessages() async {
        isLoading = true

        do {
            let response: [TaskMessage] = try await supabase.database
                .from("task_messages")
                .select()
                .eq("task_id", value: taskId)
                .order("created_at", ascending: true)
                .execute()
                .value

            messages = response
        } catch {
            print("Error loading messages: \(error)")
        }

        isLoading = false
    }

    func sendMessage(_ text: String) async {
        do {
            guard let userId = try await supabase.auth.session.user.id.uuidString else {
                return
            }

            let newMessage = TaskMessageCreate(
                taskId: taskId,
                senderId: userId,
                senderType: "user",
                content: text
            )

            let _: TaskMessage = try await supabase.database
                .from("task_messages")
                .insert(newMessage)
                .select()
                .single()
                .execute()
                .value

            // Message will appear via realtime subscription
        } catch {
            print("Error sending message: \(error)")
        }
    }

    func subscribeToMessages() async {
        let channel = await supabase.channel("task-messages-\(taskId)")

        await channel
            .on(
                .postgresChanges(
                    event: .insert,
                    schema: "public",
                    table: "task_messages",
                    filter: "task_id=eq.\(taskId)"
                )
            ) { [weak self] payload in
                if let message = try? JSONDecoder().decode(TaskMessage.self, from: payload.record) {
                    DispatchQueue.main.async {
                        self?.messages.append(message)
                    }
                }
            }
            .subscribe()
    }
}

struct TaskMessageCreate: Encodable {
    let taskId: String
    let senderId: String
    let senderType: String
    let content: String

    enum CodingKeys: String, CodingKey {
        case taskId = "task_id"
        case senderId = "sender_id"
        case senderType = "sender_type"
        case content
    }
}
