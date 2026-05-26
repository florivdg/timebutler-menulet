import Foundation

enum APIError: Error, LocalizedError {
    case noToken
    case unauthorized
    case forbidden
    case rateLimited
    case http(code: Int, body: String?)
    case malformed(String)
    case transport(Error)

    var errorDescription: String? {
        switch self {
        case .noToken: return "No personal access token configured."
        case .unauthorized: return "Personal access token is invalid or revoked."
        case .forbidden: return "Access denied by Timebutler (403)."
        case .rateLimited: return "Too many requests — try again in a minute."
        case .http(let code, let body):
            if let body, !body.isEmpty { return "Timebutler returned HTTP \(code): \(body)" }
            return "Timebutler returned HTTP \(code)."
        case .malformed(let detail): return "Unexpected response from Timebutler: \(detail)"
        case .transport(let e): return e.localizedDescription
        }
    }
}

@MainActor
final class TimebutlerAPI {
    static let baseURL = URL(string: "https://app.timebutler.com/api/v2")!

    private let session: URLSession
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private var token: String?

    init() {
        let config = URLSessionConfiguration.default
        config.httpCookieStorage = nil
        config.httpShouldSetCookies = false
        config.httpCookieAcceptPolicy = .never
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        self.session = URLSession(configuration: config)
        self.token = Keychain.readToken()
    }

    deinit {
        session.invalidateAndCancel()
    }

    func reloadToken() {
        self.token = Keychain.readToken()
    }

    var hasToken: Bool { (token?.isEmpty == false) }

    // MARK: - Endpoints

    func status() async throws -> ClockStatus {
        try await request("/time-clock/status", method: "GET")
    }

    func start() async throws -> ClockStatus {
        try await request("/time-clock/start", method: "POST")
    }

    func pause() async throws -> ClockStatus {
        try await request("/time-clock/pause", method: "POST")
    }

    func resume() async throws -> ClockStatus {
        try await request("/time-clock/resume", method: "POST")
    }

    func cancel() async throws -> ClockStatus {
        try await request("/time-clock/cancel", method: "POST")
    }

    struct StopBody: Encodable {
        let projectId: Int?
        let categoryId: Int?
        let remarks: String?
    }

    struct StopResult: Decodable {
        let id: String?
        let workedMinutes: Int?
        let breakMinutes: Int?
    }

    @discardableResult
    func stop(projectId: String?, categoryId: String?, remarks: String? = nil) async throws -> StopResult? {
        let body = StopBody(
            projectId: projectId.flatMap(Int.init),
            categoryId: categoryId.flatMap(Int.init),
            remarks: (remarks?.isEmpty ?? true) ? nil : remarks
        )
        let (data, http) = try await raw("/time-clock/stop", method: "POST", body: body)
        if http.statusCode == 204 { return nil }
        try checkStatus(http, data: data)
        if data.isEmpty { return nil }
        do {
            return try decoder.decode(StopResult.self, from: data)
        } catch {
            throw APIError.malformed(String(describing: error))
        }
    }

    func projects() async throws -> ProjectsResponse {
        try await request("/projects", method: "GET")
    }

    func categories() async throws -> CategoriesResponse {
        try await request("/categories", method: "GET")
    }

    func profile() async throws -> UserProfile {
        try await request("/user/profile", method: "GET")
    }

    // MARK: - Plumbing

    private func request<R: Decodable>(_ path: String, method: String) async throws -> R {
        let (data, http) = try await raw(path, method: method, body: Optional<Empty>.none)
        try checkStatus(http, data: data)
        do {
            return try decoder.decode(R.self, from: data)
        } catch {
            throw APIError.malformed(String(describing: error))
        }
    }

    private func raw<B: Encodable>(_ path: String, method: String, body: B?) async throws -> (Data, HTTPURLResponse) {
        guard let token, !token.isEmpty else { throw APIError.noToken }
        let url = Self.baseURL.appending(path: path)
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            do {
                req.httpBody = try encoder.encode(body)
            } catch {
                throw APIError.malformed("encoding body: \(error)")
            }
        }
        let data: Data
        let resp: URLResponse
        do {
            (data, resp) = try await session.data(for: req)
        } catch {
            throw APIError.transport(error)
        }
        guard let http = resp as? HTTPURLResponse else {
            throw APIError.malformed("non-HTTP response")
        }
        return (data, http)
    }

    private func checkStatus(_ http: HTTPURLResponse, data: Data) throws {
        switch http.statusCode {
        case 200...299: return
        case 401: throw APIError.unauthorized
        case 403: throw APIError.forbidden
        case 429: throw APIError.rateLimited
        default:
            let body = String(data: data, encoding: .utf8)
            throw APIError.http(code: http.statusCode, body: body)
        }
    }
}

private struct Empty: Encodable {}
