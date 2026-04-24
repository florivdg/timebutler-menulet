import Foundation
import Security
import WebKit

enum Keychain {
    struct Credentials {
        let email: String
        let password: String
    }

    struct KeychainError: Error, LocalizedError {
        let operation: String
        let status: OSStatus

        var errorDescription: String? {
            let message = SecCopyErrorMessageString(status, nil) as String? ?? "OSStatus \(status)"
            return "\(operation) failed: \(message)"
        }
    }

    private static let server = TimebutlerHost.appHost
    private static let service = "com.local.timebutlermenulet.timebutler.credentials"
    private static let emailDefaultsKey = "timebutler.email"

    static func writeCredentials(email: String, password: String) throws {
        let email = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let data = Data(password.utf8)
        let base = genericQuery(email: email)
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        let updateStatus = SecItemUpdate(base as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess {
            UserDefaults.standard.set(email, forKey: emailDefaultsKey)
            return
        }
        guard updateStatus == errSecItemNotFound else {
            throw KeychainError(operation: "Updating credentials", status: updateStatus)
        }

        var add = base
        add.merge(attributes) { _, new in new }
        let addStatus = SecItemAdd(add as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw KeychainError(operation: "Saving credentials", status: addStatus)
        }
        UserDefaults.standard.set(email, forKey: emailDefaultsKey)
    }

    static func readCredentials() -> Credentials? {
        guard let email = UserDefaults.standard.string(forKey: emailDefaultsKey), !email.isEmpty else { return nil }
        if let credentials = readGenericCredentials(email: email) {
            return credentials
        }
        guard let legacy = readLegacyCredentials(email: email) else {
            return nil
        }
        do {
            try writeCredentials(email: legacy.email, password: legacy.password)
            return readGenericCredentials(email: legacy.email)
        } catch {
            return nil
        }
    }

    private static func genericQuery(email: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: email
        ]
    }

    private static func readGenericCredentials(email: String) -> Credentials? {
        var query = genericQuery(email: email)
        query.merge([
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]) { _, new in new }
        var out: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &out)
        guard status == errSecSuccess,
              let data = out as? Data,
              let pw = String(data: data, encoding: .utf8)
        else { return nil }
        return Credentials(email: email, password: pw)
    }

    private static func readLegacyCredentials(email: String) -> Credentials? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassInternetPassword,
            kSecAttrServer as String: server,
            kSecAttrAccount as String: email,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var out: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &out)
        guard status == errSecSuccess,
              let data = out as? Data,
              let pw = String(data: data, encoding: .utf8)
        else { return nil }
        return Credentials(email: email, password: pw)
    }

    static func autofillScript() -> WKUserScript {
        let creds = readCredentials()
        let email = (creds?.email ?? "").jsEscaped
        let password = (creds?.password ?? "").jsEscaped
        let src = """
        (function() {
          if (window.location.hostname.toLowerCase() !== "\(TimebutlerHost.appHost)") return;
          const e = "\(email)"; const p = "\(password)";
          if (!e && !p) return;
          const fill = () => {
            const em = document.querySelector('input[type=email], input[name*="mail" i], input[name="user"], input[name="username"]');
            const pw = document.querySelector('input[type=password]');
            if (em && !em.value && e) em.value = e;
            if (pw && !pw.value && p) pw.value = p;
          };
          if (document.readyState === 'loading')
            document.addEventListener('DOMContentLoaded', fill);
          else
            fill();
        })();
        """
        return WKUserScript(source: src, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
    }
}
