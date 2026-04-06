import Foundation
import MWDATCore

/// Central observable store — injected as an environment object throughout the app.
@MainActor
final class AppState: ObservableObject {

    // ── Registration ──────────────────────────────────────────────────────────
    @Published var registrationState: RegistrationState = .unregistered

    // ── Devices ───────────────────────────────────────────────────────────────
    @Published var availableDevices: [Device] = []
    @Published var selectedDeviceID: String?

    // ── Camera permission ─────────────────────────────────────────────────────
    @Published var cameraPermissionStatus: PermissionStatus = .denied

    // ── Streaming ─────────────────────────────────────────────────────────────
    @Published var isStreaming: Bool = false
    @Published var streamSessionState: StreamSessionState = .stopped

    // ── Audio / transcription ─────────────────────────────────────────────────
    @Published var isRecording: Bool = false
    @Published var liveTranscript: String = ""

    // ── Memories (Supabase rows) ───────────────────────────────────────────────
    @Published var memories: [MemoryEntry] = []
    @Published var isSavingMemory: Bool = false

    // ── Error banner ──────────────────────────────────────────────────────────
    @Published var errorMessage: String?
}
