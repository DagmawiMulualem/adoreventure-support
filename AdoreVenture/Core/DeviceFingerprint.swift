import Foundation
import Security
import CryptoKit
import UIKit

enum DeviceFingerprint {
    static let keychainKey = "av_device_uuid"

    static func getOrCreateDeviceUUID() -> String {
        if let existing = Keychain.load(key: keychainKey) {
            return existing
        }
        let uuid = UUID().uuidString
        Keychain.save(key: keychainKey, data: uuid)
        return uuid
    }

    static func fingerprint() -> String {
        // Primary: Keychain UUID (survives reinstall)
        let base = getOrCreateDeviceUUID()

        // Optional salt with IDFV to make it harder to spoof
        let idfv = UIDevice.current.identifierForVendor?.uuidString ?? "no-idfv"
        let composite = base + "|" + idfv

        let hash = SHA256.hash(data: composite.data(using: .utf8)!)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}

// Minimal Keychain helper with proper namespacing and device-only storage
enum Keychain {
    private static let service = "com.adoreventure.device"

    static func save(key: String, data: String) {
        let d = Data(data.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: d,
            // Prevent migration to other devices via backup/restore
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    static func load(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var out: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &out)
        guard status == errSecSuccess, let data = out as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
