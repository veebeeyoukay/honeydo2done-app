import SwiftUI
import AVFoundation

struct VoiceRecorderButton: View {
    @Binding var isRecording: Bool
    let onRecordingComplete: (URL) async -> Void

    @StateObject private var recorder = AudioRecorder()

    var body: some View {
        VStack(spacing: 12) {
            Button(action: {
                if isRecording {
                    stopRecording()
                } else {
                    startRecording()
                }
            }) {
                ZStack {
                    Circle()
                        .fill(isRecording ? Color.red : Color.blue)
                        .frame(width: 80, height: 80)

                    Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                        .font(.system(size: 30))
                        .foregroundColor(.white)
                }
            }
            .scaleEffect(isRecording ? 1.1 : 1.0)
            .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: isRecording)

            Text(isRecording ? "Tap to stop" : "Tap to record")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }

    private func startRecording() {
        Task {
            do {
                try await recorder.startRecording()
                isRecording = true
            } catch {
                print("Recording failed: \(error)")
            }
        }
    }

    private func stopRecording() {
        Task {
            do {
                if let url = try await recorder.stopRecording() {
                    isRecording = false
                    await onRecordingComplete(url)
                }
            } catch {
                print("Stop recording failed: \(error)")
            }
        }
    }
}

@MainActor
class AudioRecorder: ObservableObject {
    private var audioRecorder: AVAudioRecorder?
    private var recordingURL: URL?

    func startRecording() async throws {
        // Request permission
        let permission = await AVAudioApplication.requestRecordPermission()
        guard permission else {
            throw RecordingError.permissionDenied
        }

        // Configure audio session
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default)
        try session.setActive(true)

        // Create recording URL
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        recordingURL = documentsPath.appendingPathComponent("recording-\(Date().timeIntervalSince1970).m4a")

        // Configure recorder settings
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        audioRecorder = try AVAudioRecorder(url: recordingURL!, settings: settings)
        audioRecorder?.record()
    }

    func stopRecording() async throws -> URL? {
        audioRecorder?.stop()

        let session = AVAudioSession.sharedInstance()
        try session.setActive(false)

        return recordingURL
    }
}

enum RecordingError: Error {
    case permissionDenied
}
