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
