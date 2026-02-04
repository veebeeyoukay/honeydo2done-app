# HoneyDo2Done iOS App

Native iOS companion app for HoneyDo2Done, built with SwiftUI.

## Requirements

- Xcode 15+
- iOS 17.0+
- Swift 5.9+
- CocoaPods or Swift Package Manager

## Architecture

- **SwiftUI**: Modern UI framework
- **Supabase Swift SDK**: Backend integration
- **Combine**: Reactive programming
- **AVFoundation**: Voice recording
- **Push Notifications**: APNs integration

## Project Structure

```
HoneyDoApp/
├── App/
│   ├── HoneyDoApp.swift          # App entry point
│   └── AppDelegate.swift         # App lifecycle
├── Core/
│   ├── Network/
│   │   ├── SupabaseClient.swift  # Supabase client
│   │   └── APIService.swift      # API calls
│   ├── Models/
│   │   ├── Task.swift            # Task model
│   │   ├── User.swift            # User model
│   │   └── TaskMessage.swift     # Message model
│   └── Services/
│       ├── AuthService.swift     # Authentication
│       ├── TaskService.swift     # Task operations
│       └── VoiceService.swift    # Voice recording
├── Features/
│   ├── Auth/
│   │   ├── LoginView.swift
│   │   └── SignUpView.swift
│   ├── Tasks/
│   │   ├── TaskListView.swift
│   │   ├── TaskDetailView.swift
│   │   ├── TaskCreateView.swift
│   │   └── Components/
│   │       ├── TaskCard.swift
│   │       └── TaskStatusBadge.swift
│   ├── Chat/
│   │   ├── ChatView.swift
│   │   └── MessageBubble.swift
│   ├── Decision/
│   │   └── DecisionPromptView.swift
│   └── Settings/
│       ├── SettingsView.swift
│       └── HouseholdView.swift
├── Shared/
│   ├── Components/
│   │   ├── VoiceRecorderButton.swift
│   │   ├── ImagePicker.swift
│   │   └── PersonaBadge.swift
│   ├── Extensions/
│   │   ├── View+Extensions.swift
│   │   └── Date+Extensions.swift
│   └── Theme/
│       ├── Colors.swift
│       └── Fonts.swift
└── Resources/
    ├── Assets.xcassets/
    ├── Info.plist
    └── HoneyDo2Done.entitlements
```

## Setup

### 1. Install Dependencies

**Option A: Swift Package Manager (Recommended)**

Add packages in Xcode:
- File > Add Packages
- Add: `https://github.com/supabase/supabase-swift`

**Option B: CocoaPods**

```bash
cd ios/HoneyDoApp
pod install
open HoneyDoApp.xcworkspace
```

### 2. Configure Environment

Create `Config.xcconfig`:

```
SUPABASE_URL = https:/$()/your-project.supabase.co
SUPABASE_ANON_KEY = your-anon-key
```

Or use `Config.swift`:

```swift
struct Config {
    static let supabaseURL = "https://your-project.supabase.co"
    static let supabaseAnonKey = "your-anon-key"
}
```

### 3. Enable Capabilities

In Xcode project settings:

- ✅ Push Notifications
- ✅ Background Modes (Remote notifications, Audio)
- ✅ Sign in with Apple (optional)

### 4. Configure Info.plist

Add required permissions:

```xml
<key>NSMicrophoneUsageDescription</key>
<string>HoneyDo2Done needs microphone access to record voice task descriptions</string>

<key>NSCameraUsageDescription</key>
<string>HoneyDo2Done needs camera access to attach photos to tasks</string>

<key>NSPhotoLibraryUsageDescription</key>
<string>HoneyDo2Done needs photo library access to attach photos to tasks</string>
```

## Features

### Voice Recording

Record task descriptions using AVFoundation:

```swift
import AVFoundation

class VoiceService: ObservableObject {
    private var audioRecorder: AVAudioRecorder?

    func startRecording() throws {
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        audioRecorder = try AVAudioRecorder(url: getAudioURL(), settings: settings)
        audioRecorder?.record()
    }
}
```

### Realtime Task Updates

Subscribe to task changes using Supabase Realtime:

```swift
let channel = supabase.channel("tasks")
await channel
    .on(.postgresChanges(event: .update, schema: "public", table: "tasks", filter: "id=eq.\(taskId)")) { payload in
        // Update UI
    }
    .subscribe()
```

### Push Notifications

Register for APNs:

```swift
import UserNotifications

func registerForPushNotifications() {
    UNUserNotificationCenter.current()
        .requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            guard granted else { return }

            DispatchQueue.main.async {
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
}
```

## Key Views

### TaskCreateView

```swift
struct TaskCreateView: View {
    @State private var description = ""
    @State private var isRecording = false
    @StateObject private var voiceService = VoiceService()

    var body: some View {
        VStack {
            TextEditor(text: $description)
                .frame(height: 200)

            VoiceRecorderButton(isRecording: $isRecording) {
                Task {
                    let audioData = try await voiceService.stopRecording()
                    // Send to backend for transcription
                }
            }

            Button("Create Task") {
                Task {
                    await createTask()
                }
            }
        }
    }
}
```

### TaskDetailView

```swift
struct TaskDetailView: View {
    let taskId: String
    @StateObject private var viewModel: TaskDetailViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading) {
                // Task info
                TaskInfoSection(task: viewModel.task)

                // Decision prompt (if awaiting decision)
                if viewModel.task?.status == "awaiting_decision" {
                    DecisionPromptView(task: viewModel.task!)
                }

                // Chat
                ChatView(taskId: taskId)
            }
        }
        .navigationTitle(viewModel.task?.title ?? "Task")
    }
}
```

### ChatView

```swift
struct ChatView: View {
    let taskId: String
    @StateObject private var viewModel: ChatViewModel

    var body: some View {
        VStack {
            ScrollView {
                LazyVStack {
                    ForEach(viewModel.messages) { message in
                        MessageBubble(message: message)
                    }
                }
            }

            // Input
            HStack {
                TextField("Type a message", text: $viewModel.newMessage)
                Button("Send") {
                    viewModel.sendMessage()
                }
            }
        }
        .onAppear {
            viewModel.subscribeToMessages(taskId: taskId)
        }
    }
}
```

## Building & Running

### Development

```bash
# Open in Xcode
open ios/HoneyDoApp.xcodeproj

# Or if using CocoaPods
open ios/HoneyDoApp.xcworkspace

# Select simulator/device
# Press Cmd+R to run
```

### Production Build

```bash
# Archive
xcodebuild archive \
  -scheme HoneyDoApp \
  -archivePath build/HoneyDoApp.xcarchive

# Export IPA
xcodebuild -exportArchive \
  -archivePath build/HoneyDoApp.xcarchive \
  -exportPath build \
  -exportOptionsPlist ExportOptions.plist
```

## Testing

```bash
# Run tests
xcodebuild test \
  -scheme HoneyDoApp \
  -destination 'platform=iOS Simulator,name=iPhone 15'

# Or in Xcode: Cmd+U
```

## Deployment

### TestFlight

1. Archive app in Xcode (Product > Archive)
2. Upload to App Store Connect
3. Submit for TestFlight review
4. Add testers

### App Store

1. Complete App Store Connect setup
2. Submit for review
3. Wait for approval
4. Release

## Troubleshooting

### Supabase Connection Issues
- Verify `Config.swift` has correct URL and key
- Check network permissions in Info.plist
- Ensure Supabase project allows iOS domain

### Voice Recording Not Working
- Check microphone permission in Settings
- Verify Info.plist has `NSMicrophoneUsageDescription`
- Test on physical device (not simulator for best results)

### Push Notifications Not Received
- Verify APNs certificates in App Store Connect
- Check device token is registered with backend
- Test with production certificates

## Resources

- [Supabase Swift SDK](https://github.com/supabase/supabase-swift)
- [SwiftUI Documentation](https://developer.apple.com/documentation/swiftui)
- [AVFoundation Guide](https://developer.apple.com/documentation/avfoundation)
- [Apple Push Notifications](https://developer.apple.com/documentation/usernotifications)
