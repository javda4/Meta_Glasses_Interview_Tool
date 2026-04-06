import Foundation

/// Thin wrapper around the Supabase REST API.
/// Add the official `supabase-swift` package for a richer client;
/// this lightweight implementation keeps the project dependency-free.
final class SupabaseService {

    // ── Configuration ─────────────────────────────────────────────────────────
    // ⚠️  Replace with your own project URL and anon/service-role key.
    // Store secrets in the Keychain or an environment config — not source code.
    private let projectURL: URL
    private let anonKey: String

    private var baseURL: URL { projectURL.appendingPathComponent("rest/v1") }

    // MARK: - Init

    init(projectURL: URL, anonKey: String) {
        self.projectURL = projectURL
        self.anonKey = anonKey
    }

    // MARK: - Headers

    private var commonHeaders: [String: String] {
        [
            "apikey":        anonKey,
            "Authorization": "Bearer \(anonKey)",
            "Content-Type":  "application/json",
            "Prefer":        "return=representation"
        ]
    }

    // MARK: - INSERT

    /// Insert a new MemoryEntry row into the `memories` table.
    @discardableResult
    func insertMemory(_ entry: MemoryEntry) async throws -> MemoryEntry {
        let url = baseURL.appendingPathComponent("memories")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        commonHeaders.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        request.httpBody = try JSONSerialization.data(withJSONObject: entry.toSupabasePayload())

        let (data, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response, data: data)

        // Supabase returns an array of inserted rows
        var arr = try JSONDecoder().decode([MemoryEntry].self, from: data)

        // Fix snake_case ↔ camelCase + ISO date
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        arr = try decoder.decode([MemoryEntry].self, from: data)

        guard let inserted = arr.first else {
            throw SupabaseError.emptyResponse
        }
        return inserted
    }

    // MARK: - SELECT

    /// Fetch all memory entries, newest first.
    func fetchMemories(limit: Int = 50) async throws -> [MemoryEntry] {
        var components = URLComponents(url: baseURL.appendingPathComponent("memories"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "order", value: "created_at.desc"),
            URLQueryItem(name: "limit", value: "\(limit)")
        ]
        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"
        commonHeaders.forEach { request.setValue($1, forHTTPHeaderField: $0) }

        let (data, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response, data: data)

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([MemoryEntry].self, from: data)
    }

    // MARK: - DELETE

    func deleteMemory(id: UUID) async throws {
        var components = URLComponents(url: baseURL.appendingPathComponent("memories"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "id", value: "eq.\(id.uuidString)")
        ]
        var request = URLRequest(url: components.url!)
        request.httpMethod = "DELETE"
        commonHeaders.forEach { request.setValue($1, forHTTPHeaderField: $0) }

        let (data, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response, data: data)
    }

    // MARK: - Validation

    private func validateResponse(_ response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else {
            throw SupabaseError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "no body"
            throw SupabaseError.httpError(http.statusCode, body)
        }
    }
}

// MARK: - Errors

enum SupabaseError: LocalizedError {
    case invalidResponse
    case emptyResponse
    case httpError(Int, String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:          return "Invalid response from Supabase"
        case .emptyResponse:            return "Supabase returned an empty result"
        case .httpError(let code, let body): return "Supabase HTTP \(code): \(body)"
        }
    }
}
