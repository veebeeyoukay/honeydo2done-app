# HoneyDo2Done Mobile App

React Native mobile app built with Expo.

## Features

- **Task Creation**: Voice, text, and photo capture
- **Task Chat**: Real-time messaging with AI and team members
- **Decision Flow**: DIY vs Assign vs Pro recommendations
- **Household Management**: Multi-user households with personas
- **Voice Capture**: Whisper-powered voice-to-text

## Setup

1. **Install dependencies**
   ```bash
   npm install
   ```

2. **Configure environment**
   Create `.env` file:
   ```bash
   EXPO_PUBLIC_SUPABASE_URL=https://your-project.supabase.co
   EXPO_PUBLIC_SUPABASE_ANON_KEY=your-anon-key
   ```

3. **Start development**
   ```bash
   npm start
   ```

4. **Run on device**
   - iOS: `npm run ios` (requires Xcode)
   - Android: `npm run android` (requires Android Studio)
   - Web: `npm run web`

## App Structure

```
app/
├── (auth)/              # Authentication screens
│   ├── login.tsx
│   └── signup.tsx
├── (tabs)/              # Main app tabs
│   ├── index.tsx        # Tasks list
│   ├── create.tsx       # Task creation
│   ├── household.tsx    # Household management
│   └── settings.tsx     # User settings
├── task/
│   └── [id].tsx         # Task detail & chat
└── _layout.tsx          # Root layout

components/
├── TaskCard.tsx         # Task list item
├── TaskChat.tsx         # Chat interface
├── VoiceRecorder.tsx    # Voice capture
├── DecisionPrompt.tsx   # DIY/Assign/Pro options
└── PersonaBadge.tsx     # Persona indicator

lib/
├── supabase.ts          # Supabase client
├── api.ts               # API calls
└── types.ts             # TypeScript types
```

## Key Screens

### Task Create (`app/(tabs)/create.tsx`)
- Text input
- Voice recording (Whisper)
- Photo attachment
- Property selection

### Task Detail (`app/task/[id].tsx`)
- Task summary
- Chat interface
- Decision prompt (DIY/Assign/Pro)
- Status updates

### Task Chat (`components/TaskChat.tsx`)
- Real-time messaging
- AI responses with persona
- Triage Q&A
- DIY plan display

## Voice Capture

Uses Expo Audio + Whisper API:

```typescript
import * as Audio from 'expo-audio';

// Record audio
const recording = await Audio.Recording.createAsync(
  Audio.RecordingOptionsPresets.HIGH_QUALITY
);

// Get URI and send to Whisper
const uri = recording.getURI();
const transcript = await transcribeAudio(uri);
```

## Push Notifications

Configured for task updates:

```typescript
import * as Notifications from 'expo-notifications';

// Register for push
const token = await Notifications.getExpoPushTokenAsync();

// Store token in Supabase user metadata
await supabase.auth.updateUser({
  data: { push_token: token.data }
});
```

## Testing

```bash
npm test
```

## Build for Production

```bash
# iOS
eas build --platform ios

# Android
eas build --platform android
```

## Troubleshooting

### Supabase Connection Issues
- Verify `.env` variables are set
- Check Supabase URL is accessible
- Ensure anon key is correct

### Audio Recording Not Working
- iOS: Add microphone permission to Info.plist
- Android: Add RECORD_AUDIO permission to AndroidManifest.xml

### Push Notifications Not Received
- Verify push token is registered
- Check notification permissions
- Test with Expo push tool: https://expo.dev/notifications
