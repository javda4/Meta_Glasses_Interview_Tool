import Foundation

/// Central configuration.
/// ⚠️  In a real app, pull these from the Keychain or a server-side secrets endpoint.
/// Never commit real keys to source control.
enum AppConfiguration {

    // MARK: - Supabase

    /// Your Supabase project URL  (e.g. https://xyzcompany.supabase.co)
    static let supabaseURL = URL(string: "https://YOUR_PROJECT.supabase.co")!

    /// Supabase anon / public key — safe for client-side use with Row-Level Security enabled
    static let supabaseAnonKey = "YOUR_SUPABASE_ANON_KEY"

    // MARK: - OpenAI (Whisper)

    static let openAIKey = "YOUR_OPENAI_API_KEY"

    // MARK: - Anthropic (Claude)

    static let anthropicKey = "YOUR_ANTHROPIC_API_KEY"

    // MARK: - Service factories

    static func makeSupabaseService() -> SupabaseService {
        SupabaseService(projectURL: supabaseURL, anonKey: supabaseAnonKey)
    }

    static func makeTranscriptionService() -> TranscriptionService {
        TranscriptionService(openAIKey: openAIKey, anthropicKey: anthropicKey)
    }
}
