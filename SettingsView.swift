import SwiftUI
import MWDATCore

struct SettingsView: View {

    @EnvironmentObject var appState: AppState
    @ObservedObject var wearablesService: WearablesService

    var body: some View {
        NavigationStack {
            Form {

                // ── Registration ───────────────────────────────────────────
                Section("Meta Glasses Connection") {
                    LabeledContent("Status") {
                        registrationBadge
                    }

                    switch appState.registrationState {
                    case .unregistered, .unknown:
                        Button("Connect to Meta AI App") {
                            wearablesService.register()
                        }
                    case .registered:
                        Button("Disconnect", role: .destructive) {
                            wearablesService.unregister()
                        }
                    @unknown default:
                        EmptyView()
                    }
                }

                // ── Devices ────────────────────────────────────────────────
                Section("Available Glasses") {
                    if appState.availableDevices.isEmpty {
                        Text("No glasses found — ensure they are powered on and paired.")
                            .foregroundColor(.secondary)
                            .font(.callout)
                    } else {
                        ForEach(appState.availableDevices, id: \.identifier) { device in
                            HStack {
                                Image(systemName: "eyeglasses")
                                Text(device.nameOrId())
                                Spacer()
                                if device.identifier == appState.selectedDeviceID {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                appState.selectedDeviceID = device.identifier
                            }
                        }
                    }
                }

                // ── Camera permission ──────────────────────────────────────
                Section("Camera Permission") {
                    LabeledContent("Status") {
                        permissionBadge
                    }

                    if appState.cameraPermissionStatus != .granted {
                        Button("Request Camera Access") {
                            Task { await wearablesService.requestCameraPermission() }
                        }
                    }
                }

                // ── About ──────────────────────────────────────────────────
                Section("About") {
                    LabeledContent("SDK Version", value: "DAT 0.4")
                    LabeledContent("Build", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—")
                }
            }
            .navigationTitle("Settings")
            .task { await wearablesService.checkCameraPermission() }
        }
    }

    // MARK: - Badges

    private var registrationBadge: some View {
        Group {
            switch appState.registrationState {
            case .registered:
                Label("Connected", systemImage: "checkmark.circle.fill")
                    .foregroundColor(.green)
            case .unregistered:
                Label("Not connected", systemImage: "xmark.circle.fill")
                    .foregroundColor(.red)
            default:
                Label("Unknown", systemImage: "questionmark.circle")
                    .foregroundColor(.orange)
            }
        }
        .font(.callout)
    }

    private var permissionBadge: some View {
        Group {
            switch appState.cameraPermissionStatus {
            case .granted:
                Label("Granted", systemImage: "checkmark.circle.fill")
                    .foregroundColor(.green)
            case .denied:
                Label("Denied", systemImage: "xmark.circle.fill")
                    .foregroundColor(.red)
            default:
                Label("Unknown", systemImage: "questionmark.circle")
                    .foregroundColor(.orange)
            }
        }
        .font(.callout)
    }
}
