import Foundation
import Security

/// Remembers how much of the free tier has been used, in the Keychain.
///
/// UserDefaults is wiped when the app is deleted, so counting there meant deleting
/// and reinstalling handed out two fresh free scans every time. Keychain items stay
/// on the device across a reinstall. Nothing here leaves the phone, and all it holds
/// is two small numbers: no bill, no text, nothing about the user.
enum FreeTierStore {

    enum Counter: String {
        case scans = "freeScansUsed"
        case letters = "freeLettersUsed"
    }

    private static let service = "com.limeshield.LimeShield.freetier"

    static func value(_ counter: Counter) -> Int {
        var query = baseQuery(counter)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let text = String(data: data, encoding: .utf8),
              let number = Int(text) else { return 0 }
        return number
    }

    static func set(_ number: Int, for counter: Counter) {
        let data = Data(String(number).utf8)
        let status = SecItemUpdate(baseQuery(counter) as CFDictionary,
                                   [kSecValueData as String: data] as CFDictionary)
        guard status == errSecItemNotFound else { return }
        var item = baseQuery(counter)
        item[kSecValueData as String] = data
        // Readable in the background after the first unlock; never synced or backed
        // up to another device, so a new phone starts with its own free scans.
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(item as CFDictionary, nil)
    }

    private static func baseQuery(_ counter: Counter) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: counter.rawValue]
    }
}
