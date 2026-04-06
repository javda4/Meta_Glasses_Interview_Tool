import Foundation
import AVFoundation

/// Records PCM audio from the active input route (HFP / glasses microphone).
/// Buffers raw audio and writes a timestamped .wav file to the temp directory.
@MainActor
final class AudioRecorderService: ObservableObject {

    // ── State ─────────────────────────────────────────────────────────────────
    @Published var isRecording = false
    @Published var recordingDuration: TimeInterval = 0

    // ── AVAudio objects ───────────────────────────────────────────────────────
    private let engine = AVAudioEngine()
    private var audioFile: AVAudioFile?
    private var currentFileURL: URL?
    private var startTime: Date?
    private var durationTimer: Timer?

    // ── Callback ──────────────────────────────────────────────────────────────
    /// Called when a recording is finished. Provides the file URL and duration.
    var onRecordingFinished: ((URL, TimeInterval) -> Void)?

    // MARK: - Start

    func startRecording() throws {
        guard !isRecording else { return }

        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        // Create output file
        let fileName = "memory_\(Int(Date().timeIntervalSince1970)).wav"
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        currentFileURL = fileURL
        audioFile = try AVAudioFile(forWriting: fileURL, settings: inputFormat.settings)

        // Tap the input node
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
            guard let self, let file = self.audioFile else { return }
            try? file.write(from: buffer)
        }

        try engine.start()
        isRecording = true
        startTime = Date()

        // Update UI duration every second
        durationTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self, let start = self.startTime else { return }
            Task { @MainActor in
                self.recordingDuration = Date().timeIntervalSince(start)
            }
        }

        print("🎙️ Recording started → \(fileURL.lastPathComponent)")
    }

    // MARK: - Stop

    func stopRecording() {
        guard isRecording else { return }

        engine.inputNode.removeTap(onBus: 0)
        engine.stop()

        durationTimer?.invalidate()
        durationTimer = nil

        let duration = startTime.map { Date().timeIntervalSince($0) } ?? 0
        isRecording = false
        recordingDuration = 0
        startTime = nil

        if let url = currentFileURL {
            audioFile = nil           // flush / close the file
            currentFileURL = nil
            print("🎙️ Recording stopped — duration: \(String(format: "%.1f", duration))s")
            onRecordingFinished?(url, duration)
        }
    }

    // MARK: - Helpers

    /// Format seconds as mm:ss for display
    var formattedDuration: String {
        let mins = Int(recordingDuration) / 60
        let secs = Int(recordingDuration) % 60
        return String(format: "%02d:%02d", mins, secs)
    }
}
