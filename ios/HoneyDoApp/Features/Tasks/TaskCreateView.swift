import SwiftUI
import AVFoundation

struct TaskCreateView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel = TaskCreateViewModel()

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Title input
                    VStack(alignment: .leading, spacing: 8) {
                        Text("What needs to be done?")
                            .font(.headline)

                        TextField("e.g., WiFi router not working", text: $viewModel.title)
                            .textFieldStyle(.roundedBorder)
                    }

                    // Description input
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Tell us more")
                            .font(.headline)

                        TextEditor(text: $viewModel.description)
                            .frame(height: 120)
                            .padding(8)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }

                    // Voice recording button
                    VoiceRecorderButton(
                        isRecording: $viewModel.isRecording,
                        onRecordingComplete: { url in
                            await viewModel.transcribeRecording(url)
                        }
                    )

                    // Photo picker
                    PhotoPickerButton(selectedImages: $viewModel.photos)

                    // Create button
                    Button(action: {
                        Task {
                            let success = await viewModel.createTask()
                            if success {
                                dismiss()
                            }
                        }
                    }) {
                        if viewModel.isCreating {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("Create Task")
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(viewModel.canCreate ? Color.blue : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .disabled(!viewModel.canCreate || viewModel.isCreating)

                    if let error = viewModel.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                .padding()
            }
            .navigationTitle("New Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

@MainActor
class TaskCreateViewModel: ObservableObject {
    @Published var title = ""
    @Published var description = ""
    @Published var photos: [UIImage] = []
    @Published var isRecording = false
    @Published var isCreating = false
    @Published var errorMessage: String?

    private let taskService = TaskService()
    private let voiceService = VoiceService()

    var canCreate: Bool {
        !title.isEmpty && !description.isEmpty
    }

    func transcribeRecording(_ url: URL) async {
        do {
            let audioData = try Data(contentsOf: url)
            let transcript = try await voiceService.transcribe(audioData: audioData)

            // Append to description
            if description.isEmpty {
                description = transcript
            } else {
                description += "\n\n" + transcript
            }

            // Try to extract a title if empty
            if title.isEmpty {
                let sentences = transcript.components(separatedBy: ".")
                if let first = sentences.first, !first.isEmpty {
                    title = String(first.prefix(50))
                }
            }
        } catch {
            errorMessage = "Failed to transcribe audio"
            print("Transcription error: \(error)")
        }
    }

    func createTask() async -> Bool {
        isCreating = true
        errorMessage = nil

        let combinedDescription = buildDescription()

        let task = await taskService.createTask(
            title: title,
            description: combinedDescription
        )

        isCreating = false

        if task == nil {
            errorMessage = "Failed to create task"
            return false
        }

        return true
    }

    private func buildDescription() -> String {
        var parts = [description]

        if !photos.isEmpty {
            parts.append("\n[Attached \(photos.count) photo(s)]")
        }

        return parts.joined(separator: "\n")
    }
}
