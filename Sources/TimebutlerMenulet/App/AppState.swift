import SwiftUI
import AppKit
import Combine

enum WorkStatus: Equatable {
    case unknown
    case loggedOut
    case loggedIn
    case checkedOut
    case working(start: Date?, origin: Date)
    case paused(start: Date?, origin: Date)

    var isWorking: Bool { if case .working = self { return true } else { return false } }
    var isPaused: Bool { if case .paused = self { return true } else { return false } }
    var isUncertainActivity: Bool { self == .loggedIn || self == .unknown }

    var since: Date? {
        switch self {
        case .working(let s, _), .paused(let s, _): return s
        default: return nil
        }
    }
}

@MainActor
final class AppState: ObservableObject {
    @Published var status: WorkStatus = .unknown
    @Published var lastError: String?
    @Published private var tick: Date = .init()

    let session: SessionManager
    let client: TimebutlerClient

    private var pollTimer: Timer?
    private var uiTickTimer: Timer?

    var icon: String {
        switch status {
        case .working: return "clock.fill"
        case .paused: return "pause.circle.fill"
        case .checkedOut: return "clock"
        case .loggedIn: return "clock"
        case .loggedOut: return "person.crop.circle.badge.exclamationmark"
        case .unknown: return "clock.badge.questionmark"
        }
    }

    static func elapsed(_ since: Date, now: Date = Date()) -> String {
        let s = max(0, Int(now.timeIntervalSince(since)))
        return String(format: "%dh %02dm", s / 3600, (s % 3600) / 60)
    }

    var menuBarDurationText: String? {
        _ = tick
        switch status {
        case .working(_, let origin), .paused(_, let origin):
            return Self.elapsed(origin)
        default:
            return nil
        }
    }

    init() {
        let session = SessionManager()
        self.session = session
        self.client = TimebutlerClient(session: session)

        Task { await self.refreshStatus() }
        pollTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { await self?.refreshStatus() }
        }
        uiTickTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick = Date() }
        }
    }

    func refreshStatus() async {
        do {
            let s = try await client.fetchStatus()
            self.status = s
        } catch TimebutlerClient.ClientError.expired {
            self.status = .loggedOut
        } catch {
            self.lastError = error.localizedDescription
        }
    }

    func perform(_ action: TimebutlerAction) async {
        do {
            var projectValue: String? = nil
            let projects = action.defaultProjects
            if !projects.isEmpty {
                guard let picked = AppState.pickProject(for: action, from: projects) else { return }
                projectValue = picked.value
            }
            try await client.perform(action, projectValue: projectValue)
            await refreshStatus()
        } catch TimebutlerClient.ClientError.expired {
            self.status = .loggedOut
            self.lastError = "Session expired — please log in again."
        } catch {
            self.lastError = error.localizedDescription
        }
    }

    private static func pickProject(for action: TimebutlerAction, from projects: [Project]) -> Project? {
        let alert = NSAlert()
        alert.messageText = action.displayName
        alert.informativeText = "Pick the project to book against."
        let pop = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 260, height: 26))
        for p in projects {
            pop.addItem(withTitle: p.label.isEmpty ? p.value : "\(p.label)  (\(p.value))")
        }
        alert.accessoryView = pop
        alert.addButton(withTitle: action.displayName)
        alert.addButton(withTitle: "Cancel")
        NSApp.activate(ignoringOtherApps: true)
        let r = alert.runModal()
        guard r == .alertFirstButtonReturn else { return nil }
        let i = pop.indexOfSelectedItem
        guard projects.indices.contains(i) else { return nil }
        return projects[i]
    }
}
