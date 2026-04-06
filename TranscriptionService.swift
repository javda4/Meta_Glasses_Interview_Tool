import Foundation

/// Handles the two-step pipeline:
/// 1. Transcribe audio → text  (OpenAI Whisper)
/// 2. Structure / categorise text → JSON  (Claude claude-sonnet-4-20250514)
final class TranscriptionService {

    // ── API keys ──────────────────────────────────────────────────────────────
    // ⚠️  Store these in your secrets manager / Keychain, NOT in source code.
    // These are read from the environment / bundle for illustration only.
    private let openAIKey: String
    private let anthropicKey: String

    // MARK: - Init

    init(openAIKey: String, anthropicKey: String) {
        self.openAIKey = openAIKey
        self.anthropicKey = anthropicKey
    }

    // MARK: - Step 1: Transcribe (Whisper)

    /// Sends an audio file to OpenAI Whisper and returns the transcript string.
    func transcribe(audioURL: URL) async throws -> String {
        let endpoint = URL(string: "https://api.openai.com/v1/audio/transcriptions")!
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(openAIKey)", forHTTPHeaderField: "Authorization")

        // Multipart form-data boundary
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        let audioData = try Data(contentsOf: audioURL)
        var body = Data()

        // Model field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
        body.append("whisper-1\r\n".data(using: .utf8)!)

        // Audio file
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"audio.wav\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/wav\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw TranscriptionError.whisperAPIError(String(data: data, encoding: .utf8) ?? "unknown")
        }

        struct WhisperResponse: Decodable { let text: String }
        let decoded = try JSONDecoder().decode(WhisperResponse.self, from: data)
        return decoded.text
    }

    // MARK: - Step 2: Structure with Claude

    /// Sends the raw transcript to Claude and returns a structured `MemoryEntry`.
    func structure(transcript: String, duration: TimeInterval) async throws -> MemoryEntry {
        let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(anthropicKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let systemPrompt = """
        You are a personal memory organiser. The user speaks freely and you extract
        structured information. Respond ONLY with a valid JSON object — no markdown,
        no backticks, no preamble — matching exactly this shape:
        {
          "structured_summary": "<1-3 sentence human-readable summary>",
          "tags": ["<tag1>", "<tag2>", ...]
        }

        Tags should include: people mentioned, locations, topics, and activity types.
        Keep tags lowercase, singular, and concise (1-2 words each).
        """

        let userMessage = "Here is the transcript to organise:\n\n\(transcript)"

        let payload: [String: Any] = [
            "model": "claude-sonnet-4-20250514",
            "max_tokens": 512,
            "system": systemPrompt,
            "messages": [
                ["role": "user", "content": userMessage]
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw TranscriptionError.claudeAPIError(String(data: data, encoding: .utf8) ?? "unknown")
        }

        // Extract text content from the Claude response
        struct ContentBlock: Decodable { let type: String; let text: String? }
        struct ClaudeResponse: Decodable { let content: [ContentBlock] }

        let claudeResponse = try JSONDecoder().decode(ClaudeResponse.self, from: data)
        guard let textBlock = claudeResponse.content.first(where: { $0.type == "text" }),
              let jsonText = textBlock.text,
              let jsonData = jsonText.data(using: .utf8)
        else {
            throw TranscriptionError.parseError("No text content in Claude response")
        }

        // Parse Claude's JSON output
        struct StructuredOutput: Decodable {
            let structured_summary: String
            let tags: [String]
        }

        // Strip any accidental markdown fences
        let cleanedJson = jsonText
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let structuredData = try JSONDecoder().decode(
            StructuredOutput.self,
            from: cleanedJson.data(using: .utf8)!
        )

        return MemoryEntry(
            rawTranscript: transcript,
            structuredSummary: structuredData.structured_summary,
            tags: structuredData.tags,
            createdAt: Date(),
            durationSeconds: duration
        )
    }

    // MARK: - Combined pipeline

    /// Full pipeline: audio file → transcription → structured MemoryEntry.
    func processAudio(url: URL, duration: TimeInterval) async throws -> MemoryEntry {
        let transcript = try await transcribe(audioURL: url)
        let entry = try await structure(transcript: transcript, duration: duration)
        return entry
    }
}

// MARK: - Errors

enum TranscriptionError: LocalizedError {
    case whisperAPIError(String)
    case claudeAPIError(String)
    case parseError(String)

    var errorDescription: String? {
        switch self {
        case .whisperAPIError(let msg):  return "Whisper API error: \(msg)"
        case .claudeAPIError(let msg):   return "Claude API error: \(msg)"
        case .parseError(let msg):       return "Parse error: \(msg)"
        }
    }
}
