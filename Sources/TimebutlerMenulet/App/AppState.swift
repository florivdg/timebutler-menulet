import SwiftUI
import AppKit
import Combine

enum WorkStatus: Equatable {
    case unknown
    case noToken
    case idle
    case running(startedAt: Date?)
    case paused(startedAt: Date?, pausedAt: Date?)
    case waiting(startedAt: Date?)

    var isRunning: Bool { if case .running = self { return true } else { return false } }
    var isPaused: Bool { if case .paused = self { return true } else { return false } }
    var isWaiting: Bool { if case .waiting = self { return true } else { return false } }

    var startedAt: Date? {
        switch self {
        case .running(let s), .paused(let s, _), .waiting(let s): return s
        default: return nil
        }
    }
}

enum ActionKind {
    case start, pause, resume, cancel
    case stop(projectId: String?, categoryId: String?)
}

@MainActor
final class AppState: ObservableObject {
    @Published var status: WorkStatus = .unknown
    @Published var lastError: String?
    @Published var projects: [Project] = []
    @Published var categories: [TimebutlerCategory] = [] {
        didSet { categoriesById = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0) }) }
    }
    @Published private(set) var categoriesById: [String: TimebutlerCategory] = [:]
    @Published var defaultProjectId: String?
    @Published var defaultCategoryId: String?
    @Published var isProjectMandatory: Bool = false
    @Published var isCategoryMandatory: Bool = false
    @Published var userDisplayName: String?
    @Published private(set) var latestStatus: ClockStatus?
    @Published private var tick: Date = .init()

    let api: TimebutlerAPI

    private var pollTimer: Timer?
    private var uiTickTimer: Timer?
    private var tokenObserver: NSObjectProtocol?
    private var hasLoadedLookups = false

    var needsToken: Bool { !api.hasToken }

    var icon: String {
        switch status {
        case .running: return "clock.fill"
        case .paused: return "pause.circle.fill"
        case .waiting: return "hourglass"
        case .idle: return "clock"
        case .noToken: return "person.crop.circle.badge.exclamationmark"
        case .unknown: return "clock.badge.questionmark"
        }
    }

    static func elapsed(_ since: Date, now: Date = Date(), subtractingSeconds: Int = 0) -> String {
        let s = max(0, Int(now.timeIntervalSince(since)) - subtractingSeconds)
        return String(format: "%dh %02dm", s / 3600, (s % 3600) / 60)
    }

    var menuBarDurationText: String? {
        _ = tick
        switch status {
        case .paused(_, let pausedAt):
            guard let pausedAt else { return nil }
            return Self.elapsed(pausedAt)
        case .running(let startedAt):
            guard let startedAt else { return nil }
            let breakSec = latestStatus?.accumulatedBreakSeconds ?? 0
            return Self.elapsed(startedAt, subtractingSeconds: breakSec)
        case .waiting(let startedAt):
            guard let startedAt else { return nil }
            return Self.elapsed(startedAt)
        default:
            return nil
        }
    }

    init() {
        let api = TimebutlerAPI()
        self.api = api

        if !api.hasToken {
            self.status = .noToken
        }

        tokenObserver = NotificationCenter.default.addObserver(
            forName: Keychain.tokenDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in await self?.handleTokenChange() }
        }

        Task { await self.refreshStatus() }
        pollTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { await self?.refreshStatus() }
        }
        uiTickTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick = Date() }
        }
    }

    deinit {
        if let tokenObserver { NotificationCenter.default.removeObserver(tokenObserver) }
    }

    private func handleTokenChange() async {
        api.reloadToken()
        hasLoadedLookups = false
        projects = []
        categories = []
        userDisplayName = nil
        if api.hasToken {
            status = .unknown
            await refreshStatus()
        } else {
            status = .noToken
        }
    }

    func refreshStatus() async {
        guard api.hasToken else {
            status = .noToken
            return
        }
        do {
            let s = try await api.status()
            self.latestStatus = s
            self.status = s.toWorkStatus()
            self.lastError = nil
            if !hasLoadedLookups {
                hasLoadedLookups = true
                await loadLookups()
            }
        } catch {
            handle(error)
        }
    }

    private func handle(_ error: Error) {
        switch error {
        case APIError.unauthorized:
            status = .noToken
            lastError = "Personal access token is invalid — please re-enter."
        case APIError.noToken:
            status = .noToken
        default:
            lastError = error.localizedDescription
        }
    }

    func loadLookups() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { @MainActor [weak self] in
                guard let self else { return }
                do {
                    let p = try await self.api.projects()
                    self.projects = p.projects.sorted { lhs, rhs in
                        if (lhs.isFavorite ?? false) != (rhs.isFavorite ?? false) {
                            return (lhs.isFavorite ?? false) && !(rhs.isFavorite ?? false)
                        }
                        return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
                    }
                    self.defaultProjectId = p.defaultProjectId
                    self.isProjectMandatory = p.isProjectMandatory ?? false
                } catch {
                    self.lastError = "Could not load projects: \(error.localizedDescription)"
                }
            }
            group.addTask { @MainActor [weak self] in
                guard let self else { return }
                do {
                    let c = try await self.api.categories()
                    self.categories = c.categories.sorted {
                        $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
                    }
                    self.defaultCategoryId = c.defaultCategoryId
                    self.isCategoryMandatory = c.isCategoryMandatory ?? false
                } catch {
                    self.lastError = "Could not load categories: \(error.localizedDescription)"
                }
            }
            group.addTask { @MainActor [weak self] in
                guard let self else { return }
                if let profile = try? await self.api.profile() {
                    self.userDisplayName = profile.displayName
                }
            }
        }
    }

    var effectiveCategoryId: String? {
        let stored = UserDefaults.standard.string(forKey: PreferenceKey.selectedCategoryId)
        if let stored, categoriesById[stored] != nil { return stored }
        return defaultCategoryId
    }

    func perform(_ kind: ActionKind) async {
        do {
            let newStatus: ClockStatus?
            switch kind {
            case .start:
                newStatus = try await api.start()
            case .pause:
                newStatus = try await api.pause()
            case .resume:
                newStatus = try await api.resume()
            case .cancel:
                newStatus = try await api.cancel()
            case .stop(let projectId, let categoryId):
                _ = try await api.stop(projectId: projectId, categoryId: categoryId)
                newStatus = try await api.status()
            }
            if let newStatus {
                self.latestStatus = newStatus
                self.status = newStatus.toWorkStatus()
            }
            self.lastError = nil
        } catch {
            handle(error)
        }
    }
}
