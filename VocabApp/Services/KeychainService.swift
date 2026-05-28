import Foundation
import Security
import os.log

private let keychainLog = Logger(subsystem: "com.chulhoon.VocabApp", category: "Keychain")

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
        var status = SecItemUpdate(query as CFDictionary,
                                   [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound {
            var item = query
            item[kSecValueData as String] = data
            status = SecItemAdd(item as CFDictionary, nil)
            keychainLog.debug("SecItemAdd account=\(account) status=\(status)")
        } else {
            keychainLog.debug("SecItemUpdate account=\(account) status=\(status)")
        }
        if status != errSecSuccess {
            keychainLog.error("Keychain save FAILED account=\(account) status=\(status)")
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
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status != errSecSuccess {
            keychainLog.debug("Keychain load account=\(account) status=\(status) → nil")
            return nil
        }
        guard let data = item as? Data,
              let value = String(data: data, encoding: .utf8) else {
            keychainLog.error("Keychain load account=\(account): data decode failed")
            return nil
        }
        keychainLog.debug("Keychain load account=\(account) → \(value.prefix(8))… (len=\(value.count))")
        return value
    }

    private func delete(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let status = SecItemDelete(query as CFDictionary)
        keychainLog.debug("Keychain delete account=\(account) status=\(status)")
    }
}
