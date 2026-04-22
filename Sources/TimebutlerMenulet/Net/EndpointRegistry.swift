import Foundation

struct Project: Codable, Equatable, Hashable {
    var value: String   // e.g. "93529"
    var label: String   // e.g. "Homeoffice"
}

struct EndpointRegistry: Codable, Equatable {
    struct Endpoint: Codable, Equatable {
        var method: String
        var url: String
        var body: String?
    }

    var entries: [String: Endpoint]

    static let empty = EndpointRegistry(entries: [:])

    static var url: URL {
        let fm = FileManager.default
        let base = (try? fm.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true))
            ?? fm.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")
        let dir = base.appendingPathComponent("TimebutlerMenulet", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("endpoints.json")
    }

    static func load() -> EndpointRegistry {
        guard let data = try? Data(contentsOf: url),
              let r = try? JSONDecoder().decode(EndpointRegistry.self, from: data)
        else { return .empty }
        return r
    }

    func save() {
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? enc.encode(self) {
            try? data.write(to: Self.url, options: .atomic)
        }
    }

    func has(_ action: TimebutlerAction) -> Bool { entries[action.rawValue] != nil }
    func endpoint(for action: TimebutlerAction) -> Endpoint? { entries[action.rawValue] }
    mutating func set(_ action: TimebutlerAction, _ ep: Endpoint) { entries[action.rawValue] = ep }

    static let csrfNames = [
        "csrf", "csrfToken", "csrf_token", "_csrf", "authenticityToken",
        "authenticity_token", "_token", "CSRFToken", "xsrfToken"
    ]

    private static let cacheBusterRegex: NSRegularExpression =
        (try? NSRegularExpression(pattern: "(^|[?&])_=\\d+")) ?? NSRegularExpression()

    static func rewriteCacheBuster(in s: String, template: String = "$1_={{t}}") -> String {
        let r = NSRange(s.startIndex..., in: s)
        return cacheBusterRegex.stringByReplacingMatches(in: s, options: [], range: r, withTemplate: template)
    }

    static func stripCacheBuster(_ s: String) -> String {
        rewriteCacheBuster(in: s, template: "$1")
    }

    static func templatize(_ body: String?) -> String? {
        guard var b = body, !b.isEmpty else { return body }
        for n in csrfNames {
            let escaped = NSRegularExpression.escapedPattern(for: n)
            let pattern = "(^|[?&])\(escaped)=[^&]*"
            if let re = try? NSRegularExpression(pattern: pattern, options: []) {
                let range = NSRange(b.startIndex..., in: b)
                b = re.stringByReplacingMatches(in: b, options: [], range: range, withTemplate: "$1\(n)={{csrf}}")
            }
        }
        b = rewriteCacheBuster(in: b)
        return b
    }

    static func templatizeURL(_ url: String) -> String {
        rewriteCacheBuster(in: url)
    }
}
