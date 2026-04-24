import Foundation

enum WindowID: String, CaseIterable {
    case login, prefs

    var title: String {
        switch self {
        case .login: return "Timebutler Login"
        case .prefs: return "Preferences"
        }
    }
}

enum PreferenceKey {
    static let showDurationInMenuBar = "timebutler.showDurationInMenuBar"
    static let launchAtLogin = "timebutler.launchAtLogin"
}

enum TimebutlerHost {
    static let appHost = "app.timebutler.com"
    private static let rootHost = "timebutler.com"

    static func isTrustedAppHost(_ host: String?) -> Bool {
        host?.lowercased() == appHost
    }

    static func isTrustedLoginURL(_ url: URL) -> Bool {
        url.scheme?.lowercased() == "https" && isTrustedAppHost(url.host)
    }

    static func isTrustedCookieDomain(_ domain: String) -> Bool {
        let normalized = domain
            .trimmingCharacters(in: CharacterSet(charactersIn: "."))
            .lowercased()
        return normalized == rootHost || normalized.hasSuffix(".\(rootHost)")
    }
}

extension String {
    var jsEscaped: String {
        var out = ""
        out.reserveCapacity(count)
        for ch in self {
            switch ch {
            case "\\": out += "\\\\"
            case "\"": out += "\\\""
            case "\n": out += "\\n"
            case "\r": out += "\\r"
            case "\t": out += "\\t"
            default: out.append(ch)
            }
        }
        return out
    }
}
