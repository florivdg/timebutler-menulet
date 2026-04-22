import Foundation

struct Project: Codable, Equatable, Hashable {
    var value: String
    var label: String
}

enum TimebutlerAction: String, CaseIterable, Codable, Hashable {
    case checkIn, pause, resume, checkOut

    struct Endpoint: Equatable {
        var method: String
        var url: String
        var body: String?
    }

    var displayName: String {
        switch self {
        case .checkIn: return "Check In"
        case .pause: return "Pause"
        case .resume: return "Resume"
        case .checkOut: return "Check Out"
        }
    }

    var endpoint: Endpoint {
        switch self {
        case .checkIn:
            return Endpoint(method: "GET",
                            url: "https://app.timebutler.com/do?ha=zee&ac=101&compid=&ajx=1&_={{t}}",
                            body: nil)
        case .pause:
            return Endpoint(method: "GET",
                            url: "https://app.timebutler.com/do?ha=zee&ac=102&compid=&ajx=1&_={{t}}",
                            body: nil)
        case .resume:
            return Endpoint(method: "GET",
                            url: "https://app.timebutler.com/do?ha=zee&ac=101&compid=&ajx=1&_={{t}}",
                            body: nil)
        case .checkOut:
            return Endpoint(method: "GET",
                            url: "https://app.timebutler.com/do?ha=zee&ac=103&projid=93529&katid=-1&compid=&ajx=1&_={{t}}",
                            body: nil)
        }
    }

    var defaultProjects: [Project] {
        switch self {
        case .checkOut:
            return [
                Project(value: "93529", label: "Homeoffice"),
                Project(value: "93527", label: "Office")
            ]
        default:
            return []
        }
    }
}

@MainActor
final class TimebutlerClient {
    enum ClientError: Error, LocalizedError {
        case expired
        case http(Int)
        case malformed

        var errorDescription: String? {
            switch self {
            case .expired: return "Timebutler session expired."
            case .http(let c): return "Timebutler returned HTTP \(c)."
            case .malformed: return "Unexpected response from Timebutler."
            }
        }
    }

    private let session: SessionManager
    private let dashboard = URL(string: "https://app.timebutler.com/")!

    init(session: SessionManager) {
        self.session = session
    }

    func perform(_ action: TimebutlerAction, projectValue: String? = nil) async throws {
        let ep = action.endpoint

        let timestamp = String(Int(Date().timeIntervalSince1970 * 1000))
        func subst(_ s: String) -> String {
            var out = s
            if let v = projectValue, let re = try? NSRegularExpression(pattern: "projid=\\d+", options: []) {
                let r = NSRange(out.startIndex..., in: out)
                out = re.stringByReplacingMatches(in: out, options: [], range: r, withTemplate: "projid=\(v)")
            }
            out = out.replacingOccurrences(of: "{{t}}", with: timestamp)
            return out
        }
        let body = ep.body.map(subst)
        let url = URL(string: subst(ep.url)) ?? URL(string: ep.url)!

        var req = URLRequest(url: url)
        req.httpMethod = ep.method
        req.setValue("application/x-www-form-urlencoded; charset=UTF-8", forHTTPHeaderField: "Content-Type")
        req.setValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With")
        req.setValue(dashboard.absoluteString, forHTTPHeaderField: "Referer")
        req.setValue("application/json, text/javascript, */*; q=0.01", forHTTPHeaderField: "Accept")
        if let body, !body.isEmpty {
            req.httpBody = body.data(using: .utf8)
        }
        let (_, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw ClientError.malformed }
        if http.statusCode == 401 || http.statusCode == 403 { throw ClientError.expired }
        if let final = resp.url, final.path.lowercased().contains("login") { throw ClientError.expired }
        guard (200..<400).contains(http.statusCode) else { throw ClientError.http(http.statusCode) }
    }

    func fetchStatus() async throws -> WorkStatus {
        let html = try await fetchDashboardHTML()
        return HTMLScraper.parseStatus(from: html) ?? .loggedIn
    }

    private func fetchDashboardHTML() async throws -> String {
        var req = URLRequest(url: dashboard)
        req.setValue("text/html,application/xhtml+xml", forHTTPHeaderField: "Accept")
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw ClientError.malformed }
        if let final = resp.url, final.path.lowercased().contains("login") { throw ClientError.expired }
        if http.statusCode == 401 || http.statusCode == 403 { throw ClientError.expired }
        guard let s = String(data: data, encoding: .utf8) else { throw ClientError.malformed }
        return s
    }
}
