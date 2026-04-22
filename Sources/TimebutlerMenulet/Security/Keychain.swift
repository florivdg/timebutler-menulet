import Foundation
import Security
import WebKit

enum Keychain {
    struct Credentials {
        let email: String
        let password: String
    }

    private static let server = "app.timebutler.com"
    private static let emailDefaultsKey = "timebutler.email"

    static func writeCredentials(email: String, password: String) {
        let base: [String: Any] = [
            kSecClass as String: kSecClassInternetPassword,
            kSecAttrServer as String: server,
            kSecAttrAccount as String: email
        ]
        SecItemDelete(base as CFDictionary)
        var add = base
        add[kSecValueData as String] = password.data(using: .utf8)
        SecItemAdd(add as CFDictionary, nil)
        UserDefaults.standard.set(email, forKey: emailDefaultsKey)
    }

    static func readCredentials() -> Credentials? {
        guard let email = UserDefaults.standard.string(forKey: emailDefaultsKey), !email.isEmpty else { return nil }
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

