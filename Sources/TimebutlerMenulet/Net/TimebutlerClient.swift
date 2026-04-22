import Foundation

enum TimebutlerAction: String, CaseIterable, Codable, Hashable {
    case checkIn, pause, resume, checkOut

    var displayName: String {
        switch self {
        case .checkIn: return "Check In"
        case .pause: return "Pause"
        case .resume: return "Resume"
        case .checkOut: return "Check Out"
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
        case noEndpoint(TimebutlerAction)
        case http(Int)
        case malformed

        var errorDescription: String? {
            switch self {
            case .expired: return "Timebutler session expired."
            case .noEndpoint(let a): return "No recorded endpoint for \(a.displayName). Use Record Endpoints…"
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
        let registry = EndpointRegistry.load()
        guard let ep = registry.endpoint(for: action) else { throw ClientError.noEndpoint(action) }

        let needsCSRF = ep.url.contains("{{csrf}}") || (ep.body ?? "").contains("{{csrf}}")
        let token: String? = needsCSRF ? try await fetchCSRFToken() : nil
        let timestamp = String(Int(Date().timeIntervalSince1970 * 1000))
        func subst(_ s: String) -> String {
            var out = s
            if let v = projectValue {
                out = out.replacingOccurrences(of: "{{project}}", with: v)
                if let re = try? NSRegularExpression(pattern: "projid=\\d+", options: []) {
                    let r = NSRange(out.startIndex..., in: out)
                    out = re.stringByReplacingMatches(in: out, options: [], range: r, withTemplate: "projid=\(v)")
                }
            }
            out = out.replacingOccurrences(of: "{{csrf}}", with: token ?? "")
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

    private func fetchCSRFToken() async throws -> String? {
        let html = try await fetchDashboardHTML()
        return HTMLScraper.extractCSRFToken(from: html)
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
