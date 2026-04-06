import SwiftUI

/// Shown on first launch (or when keys are missing) so the user can paste in
/// their API credentials. Keys are saved to the iOS Keychain — never to disk.
struct OnboardingView: View {

    @Binding var isOnboarded: Bool

    @State private var supabaseURL     = ""
    @State private var supabaseAnonKey = ""
    @State private var openAIKey       = ""
    @State private var anthropicKey    = ""
    @State private var showError       = false
    @State private var currentPage     = 0

    var body: some View {
        TabView(selection: $currentPage) {

            // ── Page 1: Welcome ────────────────────────────────────────────
            welcomePage.tag(0)

            // ── Page 2: Supabase ──────────────────────────────────────────
            supabasePage.tag(1)

            // ── Page 3: AI Keys ───────────────────────────────────────────
            aiKeysPage.tag(2)

            // ── Page 4: Done ──────────────────────────────────────────────
            donePage.tag(3)
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .animation(.easeInOut, value: currentPage)
        .ignoresSafeArea(edges: .bottom)
    }

    // MARK: - Pages

    private var welcomePage: some View {
        VStack(spacing: 24) {
            Image(systemName: "eyeglasses")
                .font(.system(size: 80))
                .foregroundColor(.blue)

            Text("RayBan Memory")
                .font(.largeTitle.weight(.bold))

            Text("Connect your Ray-Ban Meta glasses, record what you see and hear, and let AI organise your memories automatically.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 32)

            nextButton("Get Started")
        }
        .padding()
    }

    private var supabasePage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                pageHeader(
                    icon: "cylinder.split.1x2.fill",
                    title: "Supabase Database",
                    subtitle: "Your memories are stored in your own Supabase project."
                )

                VStack(alignment: .leading, spacing: 6) {
                    Label("Project URL", systemImage: "link")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                    SecureField("https://xyz.supabase.co", text: $supabaseURL)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Label("Anon / Public Key", systemImage: "key.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                    SecureField("eyJhbGci…", text: $supabaseAnonKey)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }

                infoBox("Find these in your Supabase dashboard under\nProject Settings → API.")

                nextButton("Next")
                    .disabled(supabaseURL.isEmpty || supabaseAnonKey.isEmpty)
                    .opacity((supabaseURL.isEmpty || supabaseAnonKey.isEmpty) ? 0.4 : 1)
            }
            .padding()
        }
    }

    private var aiKeysPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                pageHeader(
                    icon: "brain",
                    title: "AI API Keys",
                    subtitle: "Used for transcription (Whisper) and memory organisation (Claude)."
                )

                VStack(alignment: .leading, spacing: 6) {
                    Label("OpenAI API Key", systemImage: "waveform")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                    SecureField("sk-…", text: $openAIKey)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Label("Anthropic API Key", systemImage: "sparkles")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                    SecureField("sk-ant-…", text: $anthropicKey)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }

                infoBox("Keys are stored securely in the iOS Keychain and never sent anywhere except the respective APIs.")

                Button("Save & Continue") {
                    saveKeysAndProceed()
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
                .disabled(openAIKey.isEmpty || anthropicKey.isEmpty)
                .opacity((openAIKey.isEmpty || anthropicKey.isEmpty) ? 0.4 : 1)

                if showError {
                    Label("Please fill in all fields.", systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            .padding()
        }
    }

    private var donePage: some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.green)

            Text("You're all set!")
                .font(.largeTitle.weight(.bold))

            Text("Go to the Settings tab to connect your glasses, then head to Stream to start recording memories.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 32)

            Button("Start using RayBan Memory") {
                isOnboarded = true
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding()
    }

    // MARK: - Helpers

    private func pageHeader(icon: String, title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 44))
                .foregroundColor(.blue)
                .padding(.bottom, 4)
            Text(title)
                .font(.title.weight(.bold))
            Text(subtitle)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }

    private func infoBox(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "info.circle.fill")
                .foregroundColor(.blue)
            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(12)
        .background(Color.blue.opacity(0.08))
        .cornerRadius(10)
    }

    private func nextButton(_ label: String) -> some View {
        Button(label) {
            withAnimation { currentPage += 1 }
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .frame(maxWidth: .infinity)
    }

    private func saveKeysAndProceed() {
        guard !supabaseURL.isEmpty, !supabaseAnonKey.isEmpty,
              !openAIKey.isEmpty, !anthropicKey.isEmpty else {
            showError = true
            return
        }
        KeychainService.set(supabaseURL,     forKey: .supabaseURL)
        KeychainService.set(supabaseAnonKey, forKey: .supabaseAnonKey)
        KeychainService.set(openAIKey,       forKey: .openAIKey)
        KeychainService.set(anthropicKey,    forKey: .anthropicKey)
        withAnimation { currentPage += 1 }
    }
}

// MARK: - Root wrapper that gates on onboarding

struct RootView: View {
    @EnvironmentObject var appState: AppState

    @AppStorage("isOnboarded") private var isOnboarded = false

    var body: some View {
        if isOnboarded {
            ContentView()
        } else {
            OnboardingView(isOnboarded: $isOnboarded)
        }
    }
}
