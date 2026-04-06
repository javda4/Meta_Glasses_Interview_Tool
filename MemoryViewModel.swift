import Foundation
import SwiftUI

/// Orchestrates the full memory pipeline:
/// start recording → stop → transcribe (Whisper) → structure (Claude) → save (Supabase)
@MainActor
final class MemoryViewModel: ObservableObject {

    // ── Dependencies ──────────────────────────────────────────────────────────
    private let appState: AppState
    private let recorder: AudioRecorderService
    private let transcriptionService: TranscriptionService
    private let supabaseService: SupabaseService

    // ── Local processing state ────────────────────────────────────────────────
    @Published var processingStage: ProcessingStage = .idle
    @Published var processingError: String?

    // MARK: - Init

    init(
        appState: AppState,
        recorder: AudioRecorderService,
        transcriptionService: TranscriptionService,
        supabaseService: SupabaseService
    ) {
        self.appState = appState
        self.recorder = recorder
        self.transcriptionService = transcriptionService
        self.supabaseService = supabaseService

        // Wire up recorder callback
        recorder.onRecordingFinished = { [weak self] url, duration in
            guard let self else { return }
            Task { await self.processAudio(url: url, duration: duration) }
        }
    }

    // MARK: - Recording controls

    func startRecording() {
        do {
            try recorder.startRecording()
            appState.isRecording = true
            processingStage = .recording
            processingError = nil
        } catch {
            processingError = error.localizedDescription
        }
    }

    func stopRecording() {
        recorder.stopRecording()
        appState.isRecording = false
        processingStage = .transcribing
    }

    // MARK: - Pipeline

    private func processAudio(url: URL, duration: TimeInterval) async {
        processingStage = .transcribing

        do {
            // Step 1 + 2: Whisper transcription + Claude structuring
            let entry = try await transcriptionService.processAudio(url: url, duration: duration)
            appState.liveTranscript = entry.rawTranscript
            processingStage = .saving

            // Step 3: Persist to Supabase
            let saved = try await supabaseService.insertMemory(entry)
            appState.memories.insert(saved, at: 0)
            processingStage = .done

            // Clean up temp audio file
            try? FileManager.default.removeItem(at: url)

            // Reset after a short pause so the UI shows "Done"
            try? await Task.sleep(nanoseconds: 2 * NSEC_PER_SEC)
            processingStage = .idle
            appState.liveTranscript = ""

        } catch {
            processingStage = .failed
            processingError = error.localizedDescription
        }
    }

    // MARK: - Load existing memories

    func loadMemories() async {
        do {
            let memories = try await supabaseService.fetchMemories()
            appState.memories = memories
        } catch {
            processingError = "Failed to load memories: \(error.localizedDescription)"
        }
    }

    // MARK: - Delete

    func deleteMemory(_ entry: MemoryEntry) async {
        do {
            try await supabaseService.deleteMemory(id: entry.id)
            appState.memories.removeAll { $0.id == entry.id }
        } catch {
            processingError = "Failed to delete memory: \(error.localizedDescription)"
        }
    }
}

// MARK: - Processing Stage

enum ProcessingStage: Equatable {
    case idle
    case recording
    case transcribing
    case saving
    case done
    case failed

    var displayText: String {
        switch self {
        case .idle:         return ""
        case .recording:    return "Recording…"
        case .transcribing: return "Transcribing…"
        case .saving:       return "Saving to database…"
        case .done:         return "Memory saved ✓"
        case .failed:       return "Something went wrong"
        }
    }

    var isWorking: Bool {
        switch self {
        case .transcribing, .saving: return true
        default: return false
        }
    }
}
