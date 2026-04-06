import XCTest
import MWDATCore
import MWDATCamera
@testable import RayBanMemoryApp

/// Test suite that uses MockDeviceKit to simulate Ray-Ban Meta glasses
/// without needing physical hardware.
///
/// Run these in Xcode with: Product → Test (⌘U)
/// They require a real device OR a simulator with iOS 15.2+ support.
@MainActor
final class WearablesServiceTests: XCTestCase {

    private var appState: AppState!
    private var wearablesService: WearablesService!
    private var mockDevice: (any MockRaybanMeta)?

    // MARK: - Setup / Teardown

    override func setUp() async throws {
        try await super.setUp()

        // Configure SDK (safe to call multiple times — it's idempotent in test mode)
        try? Wearables.configure()

        appState = AppState()
        wearablesService = WearablesService(appState: appState)

        // Pair a simulated Ray-Ban Meta device
        mockDevice = MockDeviceKit.shared.pairRaybanMeta()
        XCTAssertNotNil(mockDevice, "Failed to pair a mock Ray-Ban Meta device")
    }

    override func tearDown() async throws {
        // Unpair all mock devices so tests are isolated
        MockDeviceKit.shared.pairedDevices.forEach { device in
            MockDeviceKit.shared.unpairDevice(device)
        }
        mockDevice = nil
        wearablesService = nil
        appState = nil
        try await super.tearDown()
    }

    // MARK: - Device Discovery

    func testMockDeviceAppearsInDeviceList() async throws {
        guard let device = mockDevice else { return XCTFail("No mock device") }

        // Power on the mock device so it becomes discoverable
        device.powerOn()

        // Allow the async stream a moment to deliver the update
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 s

        XCTAssertFalse(
            appState.availableDevices.isEmpty,
            "Expected at least one device after powering on the mock"
        )
    }

    // MARK: - Streaming with mock video

    func testStreamSessionTransitionsToStreaming() async throws {
        guard let device = mockDevice else { return XCTFail("No mock device") }
        let cameraKit = device.getCameraKit()

        // Provide a short mock video (bundle a test video in your test target)
        if let videoURL = Bundle(for: type(of: self)).url(forResource: "test_video", withExtension: "mov") {
            await cameraKit.setCameraFeed(fileURL: videoURL)
        }

        device.powerOn()
        device.unfold()
        device.don()

        // Request camera permission — in mock mode this is auto-granted
        let status = try await Wearables.shared.requestPermission(.camera)
        appState.cameraPermissionStatus = status

        await wearablesService.startStream()

        // Wait up to 5 seconds for the stream to reach .streaming state
        let deadline = Date().addingTimeInterval(5)
        while Date() < deadline {
            if appState.streamSessionState == .streaming { break }
            try await Task.sleep(nanoseconds: 200_000_000)
        }

        XCTAssertEqual(
            appState.streamSessionState, .streaming,
            "Expected stream to reach .streaming within 5 seconds"
        )

        wearablesService.stopStream()
    }

    // MARK: - Photo capture with mock image

    func testPhotoCaptureDeliversData() async throws {
        guard let device = mockDevice else { return XCTFail("No mock device") }
        let cameraKit = device.getCameraKit()

        // Provide a mock capture image
        if let imageURL = Bundle(for: type(of: self)).url(forResource: "test_photo", withExtension: "jpg") {
            await cameraKit.setCapturedImage(fileURL: imageURL)
        }

        device.powerOn()
        device.unfold()
        device.don()

        let status = try await Wearables.shared.requestPermission(.camera)
        appState.cameraPermissionStatus = status

        await wearablesService.startStream()

        // Wait for streaming state
        let streamDeadline = Date().addingTimeInterval(5)
        while Date() < streamDeadline, appState.streamSessionState != .streaming {
            try await Task.sleep(nanoseconds: 200_000_000)
        }

        // Trigger capture
        wearablesService.capturePhoto()

        // Wait for photo data
        let photoDeadline = Date().addingTimeInterval(3)
        while Date() < photoDeadline, wearablesService.latestPhoto == nil {
            try await Task.sleep(nanoseconds: 200_000_000)
        }

        XCTAssertNotNil(wearablesService.latestPhoto, "Expected photo data after capturePhoto()")
        wearablesService.stopStream()
    }

    // MARK: - Session pause / resume

    func testFoldingGlassesPausesSession() async throws {
        guard let device = mockDevice else { return XCTFail("No mock device") }

        device.powerOn()
        device.unfold()
        device.don()

        let status = try await Wearables.shared.requestPermission(.camera)
        appState.cameraPermissionStatus = status

        await wearablesService.startStream()

        // Wait for streaming
        let streamDeadline = Date().addingTimeInterval(5)
        while Date() < streamDeadline, appState.streamSessionState != .streaming {
            try await Task.sleep(nanoseconds: 200_000_000)
        }
        guard appState.streamSessionState == .streaming else {
            return XCTFail("Stream never reached .streaming")
        }

        // Simulate folding the glasses
        device.fold()
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 s

        XCTAssertNotEqual(
            appState.streamSessionState, .streaming,
            "Expected stream to pause or stop after folding glasses"
        )

        wearablesService.stopStream()
    }
}

// MARK: - MemoryEntry Tests (no hardware needed)

final class MemoryEntryTests: XCTestCase {

    func testSupabasePayloadContainsAllKeys() {
        let entry = MemoryEntry(
            rawTranscript: "Test transcript",
            structuredSummary: "A brief summary",
            tags: ["work", "meeting"],
            durationSeconds: 42.5
        )
        let payload = entry.toSupabasePayload()

        XCTAssertNotNil(payload["id"])
        XCTAssertEqual(payload["raw_transcript"] as? String, "Test transcript")
        XCTAssertEqual(payload["structured_summary"] as? String, "A brief summary")
        XCTAssertEqual(payload["tags"] as? [String], ["work", "meeting"])
        XCTAssertEqual(payload["duration_seconds"] as? Double, 42.5)
        XCTAssertNotNil(payload["created_at"])
    }

    func testProcessingStageDisplayText() {
        XCTAssertEqual(ProcessingStage.recording.displayText, "Recording…")
        XCTAssertEqual(ProcessingStage.transcribing.displayText, "Transcribing…")
        XCTAssertEqual(ProcessingStage.saving.displayText, "Saving to database…")
        XCTAssertEqual(ProcessingStage.done.displayText, "Memory saved ✓")
    }

    func testProcessingStageIsWorking() {
        XCTAssertTrue(ProcessingStage.transcribing.isWorking)
        XCTAssertTrue(ProcessingStage.saving.isWorking)
        XCTAssertFalse(ProcessingStage.idle.isWorking)
        XCTAssertFalse(ProcessingStage.recording.isWorking)
        XCTAssertFalse(ProcessingStage.done.isWorking)
        XCTAssertFalse(ProcessingStage.failed.isWorking)
    }
}
