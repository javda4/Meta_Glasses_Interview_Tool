import Foundation
import Security

/// Thin wrapper around the iOS Keychain for storing API secrets securely.
/// Use this instead of hardcoding keys in AppConfiguration.swift.
///
/// Example — store on first launch:
///   KeychainService.set("sk-...", forKey: .openAIKey)
///
/// Example — read at runtime:
///   let key = KeychainService.get(.openAIKey) ?? ""
enum KeychainService {

    // MARK: - Key names

    enum Key: String {
        case openAIKey      = "com.raybanmemory.openai_key"
        case anthropicKey   = "com.raybanmemory.anthropic_key"
        case supabaseAnonKey = "com.raybanmemory.supabase_anon_key"
        case supabaseURL    = "com.raybanmemory.supabase_url"
    }

    // MARK: - Write

    @discardableResult
    static func set(_ value: String, forKey key: Key) -> Bool {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrAccount as String: key.rawValue,
            kSecValueData as String:   data
        ]
        // Delete existing item first (update pattern)
        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    // MARK: - Read

    static func get(_ key: Key) -> String? {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrAccount as String: key.rawValue,
            kSecReturnData as String:  true,
            kSecMatchLimit as String:  kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        return string
    }

    // MARK: - Delete

    @discardableResult
    static func delete(_ key: Key) -> Bool {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrAccount as String: key.rawValue
        ]
        return SecItemDelete(query as CFDictionary) == errSecSuccess
    }
}

// MARK: - Updated AppConfiguration using Keychain

extension AppConfiguration {

    /// Reads API keys from the Keychain (preferred) or falls back to the
    /// compile-time placeholders defined in AppConfiguration.swift.
    enum Secure {
        static var openAIKey: String {
            KeychainService.get(.openAIKey) ?? AppConfiguration.openAIKey
        }
        static var anthropicKey: String {
            KeychainService.get(.anthropicKey) ?? AppConfiguration.anthropicKey
        }
        static var supabaseAnonKey: String {
            KeychainService.get(.supabaseAnonKey) ?? AppConfiguration.supabaseAnonKey
        }
        static var supabaseURL: URL {
            if let urlString = KeychainService.get(.supabaseURL),
               let url = URL(string: urlString) {
                return url
            }
            return AppConfiguration.supabaseURL
        }
    }
}
