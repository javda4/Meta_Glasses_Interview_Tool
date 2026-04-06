import SwiftUI
import MWDATCore

@main
struct RayBanMemoryApp: App {

    @StateObject private var appState = AppState()

    init() {
        configureWearablesSDK()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                // Handle Meta AI callback URL (registration / permission flows)
                .onOpenURL { url in
                    Task {
                        do {
                            try await Wearables.shared.handleUrl(url)
                        } catch {
                            print("⚠️ Wearables URL handling failed: \(error)")
                        }
                    }
                }
        }
    }

    // MARK: - SDK init

    private func configureWearablesSDK() {
        do {
            try Wearables.configure()
            print("✅ Wearables SDK configured")
        } catch {
            // In production you would surface this to the user
            assertionFailure("Failed to configure Wearables SDK: \(error)")
        }
    }
}
