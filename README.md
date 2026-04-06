# RayBan Memory App 🧠👓

An iOS app that connects to Ray-Ban Meta glasses, streams live video and audio, transcribes speech with OpenAI Whisper, organises the transcript with Claude, and persists structured memories to Supabase.

---

## Architecture

```
Ray-Ban Meta Glasses
       │
       │  Bluetooth (video via BT Classic, audio via HFP)
       ▼
  iOS App (Swift / SwiftUI)
  ├── WearablesService       ← Meta DAT SDK (MWDATCore + MWDATCamera)
  ├── AudioRecorderService   ← AVAudioEngine → .wav file
  ├── TranscriptionService
  │   ├── OpenAI Whisper     ← audio → raw transcript
  │   └── Claude Sonnet      ← transcript → structured JSON
  └── SupabaseService        ← REST API → memories table
```

---

## Prerequisites

| Requirement | Version |
|---|---|
| Xcode | 14.0+ |
| iOS target | 15.2+ |
| Meta AI app | v254+ |
| Glasses firmware (Ray-Ban Meta) | v20+ |

---

## Quick Start

### 1. Clone and open in Xcode

```bash
git clone https://github.com/javda4/Meta_Glasses_Interview_Tool.git
open RayBanMemoryApp/RayBanMemoryApp.xcodeproj
```

### 2. Add the Meta Wearables SDK via Swift Package Manager

1. File → Add Package Dependencies…
2. Paste: `https://github.com/facebook/meta-wearables-dat-ios`
3. Select `meta-wearables-dat-ios`, set version to `0.4.x`
4. Add both `MWDATCore` and `MWDATCamera` to your target

### 3. Configure your URL scheme

In `Info.plist`, replace `raybanmemory` with your own unique URL scheme (must be lowercase, no spaces).

```xml
<key>CFBundleURLSchemes</key>
<array>
  <string>YOUR_SCHEME</string>       <!-- e.g. "memoryglass" -->
</array>
...
<key>AppLinkURLScheme</key>
<string>YOUR_SCHEME://</string>
```

### 4. Fill in your API keys

Open `Utilities/AppConfiguration.swift` and replace the placeholder strings:

```swift
static let supabaseURL     = URL(string: "https://YOUR_PROJECT.supabase.co")!
static let supabaseAnonKey = "YOUR_SUPABASE_ANON_KEY"
static let openAIKey       = "YOUR_OPENAI_API_KEY"
static let anthropicKey    = "YOUR_ANTHROPIC_API_KEY"
```

> ⚠️ **Never commit real API keys to source control.** Consider reading these from the Keychain or an environment-specific config file excluded via `.gitignore`.

### 5. Set up Supabase

1. Create a new project at [supabase.com](https://supabase.com)
2. Open the SQL Editor and run the contents of `supabase_migration.sql`
3. Copy your **Project URL** and **anon public key** from Settings → API

### 6. Enable developer mode on the glasses

1. Open the Meta AI app → Settings → App Info → tap the version number **5 times**
2. Toggle **Developer Mode** on
3. Connect your glasses

### 7. Build and run

Connect a physical iPhone (the glasses use Bluetooth Classic — the simulator cannot test this).

---

## App Flow

```
Settings tab
  └── Tap "Connect to Meta AI App"
        └── Registration deep-link → Meta AI → returns to your app
              └── Tap "Request Camera Access"
                    └── Permission deep-link → Meta AI → returns to your app

Stream tab
  └── Tap "Stream" to start video preview
        └── Put on glasses → video appears in the preview
              └── Tap "Record" to start capturing audio
                    └── Tap "Save" to stop recording
                          └── Whisper transcribes → Claude structures → Supabase saves

Memories tab
  └── Browse all saved memories with tags and summaries
```

---

## Supabase Table Schema

| Column | Type | Description |
|---|---|---|
| `id` | UUID | Primary key |
| `raw_transcript` | TEXT | Verbatim speech-to-text output |
| `structured_summary` | TEXT | Claude-generated 1–3 sentence summary |
| `tags` | TEXT[] | Array of extracted tags (people, places, topics) |
| `duration_seconds` | FLOAT | Recording length |
| `created_at` | TIMESTAMPTZ | Auto-set on insert |

---

## Key Files

```
RayBanMemoryApp/
├── RayBanMemoryApp.swift          # App entry + SDK init + URL handling
├── Models/
│   ├── AppState.swift             # Central @Published state
│   └── MemoryEntry.swift          # Codable model ↔ Supabase row
├── Services/
│   ├── WearablesService.swift     # Registration, streaming, HFP audio
│   ├── AudioRecorderService.swift # AVAudioEngine → .wav file
│   ├── TranscriptionService.swift # Whisper + Claude pipeline
│   └── SupabaseService.swift      # REST CRUD operations
├── ViewModels/
│   └── MemoryViewModel.swift      # Orchestrates record → save pipeline
├── Views/
│   ├── ContentView.swift          # Root tab view
│   ├── StreamView.swift           # Live preview + controls
│   ├── MemoriesListView.swift     # Memory browser + detail
│   ├── SettingsView.swift         # Registration + permissions
│   └── ErrorBanner.swift          # Error UI
└── Utilities/
    └── AppConfiguration.swift     # API keys + service factories
```

---

## Extending the App

### Add photo storage
After `capturePhoto()`, observe `wearablesService.latestPhoto` (a `Data?`) and upload to Supabase Storage, then save the URL as a new column on the memories table.

### Real-time Supabase subscription
Replace polling with a Supabase Realtime channel to receive inserts from other devices.

### Authentication
Uncomment the Option B RLS policies in `supabase_migration.sql`, add a `user_id` column, and integrate with Supabase Auth or Sign in with Apple.

### Add the official Supabase Swift SDK
```
https://github.com/supabase/supabase-swift
```
This provides typed queries, Realtime, Auth, and Storage in one package — a drop-in replacement for the lightweight REST wrapper in this project.

---

## Troubleshooting

| Symptom | Fix |
|---|---|
| Registration fails with no internet | An internet connection is required for initial registration |
| Stream starts but no frames arrive | Ensure glasses are unfolded and worn; check that `cameraPermissionStatus == .granted` |
| No audio from glasses | HFP must be configured before `startStream()`; the 2-second sleep in `startStreamSessionWithAudio()` helps |
| Supabase 401 errors | Double-check your anon key and that RLS policies allow the operation |
| Whisper returns empty transcript | Verify `openAIKey` is valid; check the audio file was written correctly |

---

## License

MIT — see LICENSE file.
