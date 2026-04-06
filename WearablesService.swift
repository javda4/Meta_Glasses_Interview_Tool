import Foundation
import AVFoundation
import MWDATCore
import MWDATCamera

/// Manages the full lifecycle of the Meta Wearables SDK:
/// registration → permissions → streaming → audio session.
@MainActor
final class WearablesService: ObservableObject {

    // ── Dependencies ──────────────────────────────────────────────────────────
    private let appState: AppState
    private let wearables = Wearables.shared

    // ── Stream session ────────────────────────────────────────────────────────
    private(set) var streamSession: StreamSession?
    private var stateListenerToken: AnyListenerToken?
    private var frameListenerToken: AnyListenerToken?
    private var photoListenerToken: AnyListenerToken?

    // ── Latest frame (published for the preview view) ─────────────────────────
    @Published var latestFrame: UIImage?
    @Published var latestPhoto: Data?

    // MARK: - Init

    init(appState: AppState) {
        self.appState = appState
        observeRegistration()
        observeDevices()
    }

    // MARK: - Registration

    func register() {
        do {
            try wearables.startRegistration()
        } catch {
            appState.errorMessage = "Registration failed: \(error.localizedDescription)"
        }
    }

    func unregister() {
        do {
            try wearables.startUnregistration()
        } catch {
            appState.errorMessage = "Unregistration failed: \(error.localizedDescription)"
        }
    }

    private func observeRegistration() {
        Task {
            for await state in wearables.registrationStateStream() {
                appState.registrationState = state
            }
        }
    }

    private func observeDevices() {
        Task {
            for await devices in wearables.devicesStream() {
                appState.availableDevices = devices
                // Auto-select first device if none selected
                if appState.selectedDeviceID == nil, let first = devices.first {
                    appState.selectedDeviceID = first.identifier
                }
            }
        }
    }

    // MARK: - Camera permissions

    func checkCameraPermission() async {
        do {
            let status = try await wearables.checkPermissionStatus(.camera)
            appState.cameraPermissionStatus = status
        } catch {
            appState.errorMessage = "Permission check failed: \(error.localizedDescription)"
        }
    }

    func requestCameraPermission() async {
        do {
            let status = try await wearables.requestPermission(.camera)
            appState.cameraPermissionStatus = status
        } catch {
            appState.errorMessage = "Permission request failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Streaming

    func startStream() async {
        guard appState.cameraPermissionStatus == .granted else {
            await requestCameraPermission()
            guard appState.cameraPermissionStatus == .granted else { return }
        }

        // 1. Configure HFP audio before streaming
        configureHFPAudioSession()
        // Give HFP time to fully initialise before starting the video stream
        try? await Task.sleep(nanoseconds: 2 * NSEC_PER_SEC)

        // 2. Build session
        let deviceSelector = AutoDeviceSelector(wearables: wearables)
        let config = StreamSessionConfig(
            videoCodec: .raw,
            resolution: .medium,    // 504 × 896 — good balance of quality vs BT bandwidth
            frameRate: 15           // 15 fps — smooth enough, conserves bandwidth
        )
        let session = StreamSession(
            streamSessionConfig: config,
            deviceSelector: deviceSelector
        )
        streamSession = session

        // 3. Observe session state
        stateListenerToken = session.statePublisher.listen { [weak self] state in
            Task { @MainActor [weak self] in
                guard let self else { return }
                appState.streamSessionState = state
                appState.isStreaming = (state == .streaming)
            }
        }

        // 4. Receive video frames
        frameListenerToken = session.videoFramePublisher.listen { [weak self] frame in
            guard let image = frame.makeUIImage() else { return }
            Task { @MainActor [weak self] in
                self?.latestFrame = image
            }
        }

        // 5. Receive photo captures
        photoListenerToken = session.photoDataPublisher.listen { [weak self] photoData in
            Task { @MainActor [weak self] in
                self?.latestPhoto = photoData.data
            }
        }

        // 6. Start
        await session.start()
    }

    func stopStream() {
        Task {
            await streamSession?.stop()
        }
        stateListenerToken?.cancel()
        frameListenerToken?.cancel()
        photoListenerToken?.cancel()
        streamSession = nil
        appState.isStreaming = false
        appState.streamSessionState = .stopped
    }

    func capturePhoto() {
        streamSession?.capturePhoto(format: .jpeg)
    }

    // MARK: - HFP Audio session

    /// Configure AVAudioSession for Bluetooth HFP so the glasses microphone is routable.
    func configureHFPAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(
                .playAndRecord,
                mode: .default,
                options: [.allowBluetooth]   // enables HFP route
            )
            try session.setActive(true, options: .notifyOthersOnDeactivation)
            print("✅ AVAudioSession configured for HFP")
        } catch {
            appState.errorMessage = "Audio session setup failed: \(error.localizedDescription)"
        }
    }

    func deactivateAudioSession() {
        try? AVAudioSession.sharedInstance().setActive(false)
    }
}
