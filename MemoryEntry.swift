import Foundation

/// A single memory record that maps 1-to-1 with a row in the Supabase `memories` table.
struct MemoryEntry: Identifiable, Codable, Equatable {

    // ── Primary key ───────────────────────────────────────────────────────────
    var id: UUID

    // ── Core content ─────────────────────────────────────────────────────────
    /// Raw transcript from the speech-to-text pass
    var rawTranscript: String

    /// Claude-structured summary / categorised content
    var structuredSummary: String

    /// Optional tags extracted by Claude (people, places, topics …)
    var tags: [String]

    // ── Metadata ──────────────────────────────────────────────────────────────
    var createdAt: Date
    var durationSeconds: Double

    // ── Supabase column names ─────────────────────────────────────────────────
    enum CodingKeys: String, CodingKey {
        case id
        case rawTranscript    = "raw_transcript"
        case structuredSummary = "structured_summary"
        case tags
        case createdAt        = "created_at"
        case durationSeconds  = "duration_seconds"
    }

    // ── Convenience init ──────────────────────────────────────────────────────
    init(
        id: UUID = UUID(),
        rawTranscript: String,
        structuredSummary: String,
        tags: [String] = [],
        createdAt: Date = Date(),
        durationSeconds: Double = 0
    ) {
        self.id = id
        self.rawTranscript = rawTranscript
        self.structuredSummary = structuredSummary
        self.tags = tags
        self.createdAt = createdAt
        self.durationSeconds = durationSeconds
    }
}

// MARK: - Supabase JSON helpers

extension MemoryEntry {
    /// Returns the entry as a JSON-encodable dictionary suitable for a Supabase INSERT.
    func toSupabasePayload() -> [String: Any] {
        let iso = ISO8601DateFormatter()
        return [
            "id":                 id.uuidString,
            "raw_transcript":     rawTranscript,
            "structured_summary": structuredSummary,
            "tags":               tags,
            "created_at":         iso.string(from: createdAt),
            "duration_seconds":   durationSeconds
        ]
    }
}
