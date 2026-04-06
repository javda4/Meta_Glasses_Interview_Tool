import SwiftUI
import MWDATCore

struct StreamView: View {

    @EnvironmentObject var appState: AppState
    @ObservedObject var wearablesService: WearablesService
    @ObservedObject var memoryVM: MemoryViewModel

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 0) {

                    // ── Live video preview ─────────────────────────────────
                    cameraPreview
                        .frame(maxWidth: .infinity)
                        .aspectRatio(9/16, contentMode: .fit)
                        .clipped()
                        .cornerRadius(16)
                        .padding(.horizontal)
                        .padding(.top, 8)

                    // ── Processing / transcript status ─────────────────────
                    statusBanner
                        .padding(.top, 12)

                    Spacer()

                    // ── Controls ──────────────────────────────────────────
                    controlBar
                        .padding(.bottom, 32)
                }
            }
            .navigationTitle("RayBan Memory")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .preferredColorScheme(.dark)
        }
    }

    // MARK: - Camera Preview

    @ViewBuilder
    private var cameraPreview: some View {
        if let frame = wearablesService.latestFrame {
            Image(uiImage: frame)
                .resizable()
                .scaledToFill()
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.06))
                VStack(spacing: 12) {
                    Image(systemName: "video.slash.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)
                    Text(appState.isStreaming ? "Waiting for frames…" : "Stream not started")
                        .font(.callout)
                        .foregroundColor(.gray)
                }
            }
        }
    }

    // MARK: - Status Banner

    @ViewBuilder
    private var statusBanner: some View {
        if memoryVM.processingStage != .idle {
            HStack(spacing: 10) {
                if memoryVM.processingStage.isWorking {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(0.8)
                }
                Text(memoryVM.processingStage.displayText)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(stageColor.opacity(0.85))
            .clipShape(Capsule())
        }
    }

    private var stageColor: Color {
        switch memoryVM.processingStage {
        case .recording:    return .red
        case .transcribing: return .orange
        case .saving:       return .blue
        case .done:         return .green
        case .failed:       return .red
        default:            return .gray
        }
    }

    // MARK: - Control Bar

    private var controlBar: some View {
        HStack(spacing: 32) {

            // Stream toggle
            CircleButton(
                icon: appState.isStreaming ? "video.slash.fill" : "video.fill",
                label: appState.isStreaming ? "Stop" : "Stream",
                tint: appState.isStreaming ? .orange : .blue
            ) {
                if appState.isStreaming {
                    wearablesService.stopStream()
                } else {
                    Task { await wearablesService.startStream() }
                }
            }

            // Record toggle (only active during stream)
            CircleButton(
                icon: appState.isRecording ? "stop.fill" : "mic.fill",
                label: appState.isRecording ? "Save" : "Record",
                tint: appState.isRecording ? .red : .green,
                pulsing: appState.isRecording
            ) {
                if appState.isRecording {
                    memoryVM.stopRecording()
                } else {
                    memoryVM.startRecording()
                }
            }
            .disabled(!appState.isStreaming && !appState.isRecording)
            .opacity((!appState.isStreaming && !appState.isRecording) ? 0.4 : 1)

            // Capture photo
            CircleButton(
                icon: "camera.fill",
                label: "Photo",
                tint: .purple
            ) {
                wearablesService.capturePhoto()
            }
            .disabled(!appState.isStreaming)
            .opacity(appState.isStreaming ? 1 : 0.4)
        }
    }
}

// MARK: - Circle Button component

struct CircleButton: View {
    let icon: String
    let label: String
    var tint: Color = .blue
    var pulsing: Bool = false
    let action: () -> Void

    @State private var pulse = false

    var body: some View {
        VStack(spacing: 6) {
            Button(action: action) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 64, height: 64)
                    .background(tint)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(tint.opacity(0.5), lineWidth: pulse ? 16 : 0)
                            .opacity(pulse ? 0 : 1)
                    )
            }
            .onAppear {
                if pulsing {
                    withAnimation(.easeOut(duration: 1).repeatForever(autoreverses: false)) {
                        pulse = true
                    }
                }
            }
            .onChange(of: pulsing) { _ in
                pulse = false
                if pulsing {
                    withAnimation(.easeOut(duration: 1).repeatForever(autoreverses: false)) {
                        pulse = true
                    }
                }
            }

            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}
