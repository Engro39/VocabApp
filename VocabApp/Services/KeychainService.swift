import Foundation
import Security

final class KeychainService {
    static let shared = KeychainService()
    private let service = "com.chulhoon.VocabApp"
    private init() {}

    // MARK: - Anthropic API Key

    func saveAPIKey(_ key: String)   { save(key, account: "anthropic_api_key") }
    func loadAPIKey() -> String?     { load(account: "anthropic_api_key") }
    func deleteAPIKey()              { delete(account: "anthropic_api_key") }
    var hasAPIKey: Bool              { !(loadAPIKey() ?? "").isEmpty }

    // MARK: - Google TTS API Key

    func saveGoogleTTSKey(_ key: String) { save(key, account: "google_tts_api_key") }
    func loadGoogleTTSKey() -> String?   { load(account: "google_tts_api_key") }
    func deleteGoogleTTSKey()            { delete(account: "google_tts_api_key") }
    var hasGoogleTTSKey: Bool            { !(loadGoogleTTSKey() ?? "").isEmpty }

    // MARK: - Private helpers

    private func save(_ value: String, account: String) {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let status = SecItemUpdate(query as CFDictionary,
                                   [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound {
            var item = query
            item[kSecValueData as String] = data
            SecItemAdd(item as CFDictionary, nil)
        }
    }

    private func load(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func delete(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
