import SwiftUI

struct StatusMenu: View {
    @EnvironmentObject var state: AppState
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Text(statusLine)
        if let err = state.lastError, !err.isEmpty {
            Text("⚠︎ \(err)").foregroundStyle(.secondary)
        }
        Divider()
        Button("Check In") { Task { await state.perform(.checkIn) } }
            .disabled(!canCheckIn)
        Button("Pause") { Task { await state.perform(.pause) } }
            .disabled(!canPause)
        Button("Resume") { Task { await state.perform(.resume) } }
            .disabled(!canResume)
        Button("Check Out") { Task { await state.perform(.checkOut) } }
            .disabled(!canCheckOut)
        Divider()
        Button("Login…") { open(.login) }
        Button("Refresh Status") { Task { await state.refreshStatus() } }
        Button("Preferences…") { open(.prefs) }
        Divider()
        Button("Quit") { NSApplication.shared.terminate(nil) }
            .keyboardShortcut("q")
    }

    private var statusLine: String {
        switch state.status {
        case .unknown: return "…"
        case .loggedOut: return "Not logged in"
        case .loggedIn: return "Logged in · activity unknown"
        case .checkedOut: return "Checked out"
        case .working(let since):
            if let since { return "Working · since \(Self.hm(since)) · \(AppState.elapsed(since))" }
            return "Working"
        case .paused(let since):
            if let since { return "Paused · since \(Self.hm(since)) · \(AppState.elapsed(since))" }
            return "Paused"
        }
    }

    private var canCheckIn: Bool { state.status == .checkedOut || state.status.isUncertainActivity }
    private var canPause: Bool { state.status.isWorking || state.status.isUncertainActivity }
    private var canResume: Bool { state.status.isPaused || state.status.isUncertainActivity }
    private var canCheckOut: Bool { state.status.isWorking || state.status.isPaused || state.status.isUncertainActivity }

    private func open(_ id: WindowID) {
        openWindow(id: id.rawValue)
        NSApp.activate(ignoringOtherApps: true)
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            if let w = NSApp.windows.first(where: { $0.title == id.title }) {
                w.makeKeyAndOrderFront(nil)
            }
        }
    }

    private static func hm(_ d: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "HH:mm"; return f.string(from: d)
    }
}
