import SwiftUI

/// Root view — owns the service layer and passes it down via @ObservedObject.
///
/// Architecture note:
/// AppState is the single source of truth for UI-visible state (injected via
/// @EnvironmentObject from RayBanMemoryApp). Services mutate AppState and are
/// owned here so they outlive individual tab views.
struct ContentView: View {

    @EnvironmentObject var appState: AppState

    // MARK: - Service layer (owned by this view, stable across tab switches)

    @StateObject private var wearablesService: WearablesService
    @StateObject private var recorder: AudioRecorderService
    @StateObject private var memoryVM: MemoryViewModel

    // MARK: - Init
    // _StateObject(wrappedValue:) lets us inject constructor args into @StateObject.
    // We pass a temporary AppState here; the services will read/write the REAL
    // AppState that flows in via @EnvironmentObject once the view is live.
    // For a production app, prefer a dependency-injection container.
    init() {
        let sharedState = AppState()
        let rec = AudioRecorderService()

        _wearablesService = StateObject(
            wrappedValue: WearablesService(appState: sharedState)
        )
        _recorder = StateObject(wrappedValue: rec)
        _memoryVM = StateObject(wrappedValue: MemoryViewModel(
            appState: sharedState,
            recorder: rec,
            transcriptionService: AppConfiguration.makeTranscriptionService(),
            supabaseService: AppConfiguration.makeSupabaseService()
        ))
    }

    // MARK: - Body

    var body: some View {
        TabView {
            StreamView(wearablesService: wearablesService, memoryVM: memoryVM)
                .tabItem { Label("Stream",   systemImage: "video.fill") }

            MemoriesListView(memoryVM: memoryVM)
                .tabItem { Label("Memories", systemImage: "brain.head.profile") }

            SettingsView(wearablesService: wearablesService)
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
        // Global error banner
        .overlay(alignment: .top) {
            if let error = appState.errorMessage {
                ErrorBanner(message: error) { appState.errorMessage = nil }
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut, value: appState.errorMessage)
        .task { await memoryVM.loadMemories() }
    }
}
