import Foundation
import Security

enum Keychain {
    static let tokenDidChange = Notification.Name("com.local.timebutlermenulet.tokenDidChange")

    struct KeychainError: Error, LocalizedError {
        let operation: String
        let status: OSStatus

        var errorDescription: String? {
            let message = SecCopyErrorMessageString(status, nil) as String? ?? "OSStatus \(status)"
            return "\(operation) failed: \(message)"
        }
    }

    private static let service = "com.local.timebutlermenulet.timebutler.pat"
    private static let account = "personal-access-token"

    static func writeToken(_ token: String) throws {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        let data = Data(trimmed.utf8)
        let base = baseQuery()
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        let updateStatus = SecItemUpdate(base as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess {
            NotificationCenter.default.post(name: tokenDidChange, object: nil)
            return
        }
        guard updateStatus == errSecItemNotFound else {
            throw KeychainError(operation: "Updating token", status: updateStatus)
        }

        var add = base
        add.merge(attributes) { _, new in new }
        let addStatus = SecItemAdd(add as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw KeychainError(operation: "Saving token", status: addStatus)
        }
        NotificationCenter.default.post(name: tokenDidChange, object: nil)
    }

    static func readToken() -> String? {
        var query = baseQuery()
        query.merge([
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]) { _, new in new }
        var out: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &out)
        guard status == errSecSuccess,
              let data = out as? Data,
              let token = String(data: data, encoding: .utf8),
              !token.isEmpty
        else { return nil }
        return token
    }

    @discardableResult
    static func deleteToken() -> Bool {
        let status = SecItemDelete(baseQuery() as CFDictionary)
        let ok = (status == errSecSuccess || status == errSecItemNotFound)
        if ok {
            NotificationCenter.default.post(name: tokenDidChange, object: nil)
        }
        return ok
    }

    private static func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}
