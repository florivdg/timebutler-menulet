import SwiftUI

struct StatusMenu: View {
    @EnvironmentObject var state: AppState
    @Environment(\.openWindow) private var openWindow
    @AppStorage(PreferenceKey.selectedCategoryId) private var selectedCategoryId: String = ""

    var body: some View {
        Text(statusLine)
        if let err = state.lastError, !err.isEmpty {
            Text("⚠︎ \(err)").foregroundStyle(.secondary)
        }
        Divider()

        if state.status == .noToken {
            Button("Connect to Timebutler…") { open(.tokenSetup) }
        } else {
            Button("Check In") { Task { await state.perform(.start) } }
                .disabled(!canStart)
            Button("Pause") { Task { await state.perform(.pause) } }
                .disabled(!canPause)
            Button("Resume") { Task { await state.perform(.resume) } }
                .disabled(!canResume)

            checkOutMenu

            if !state.categories.isEmpty {
                categoryMenu
            }

            Divider()
            Button("Refresh Status") { Task { await state.refreshStatus() } }
        }

        Divider()
        Button("Preferences…") { open(.prefs) }
        Button("Quit") { NSApplication.shared.terminate(nil) }
            .keyboardShortcut("q")
    }

    @ViewBuilder
    private var checkOutMenu: some View {
        if let pending = state.pendingCheckout {
            Text("Auto check-out at \(Self.hm(pending.fireAt)) · \(projectName(for: pending.projectId))")
                .foregroundStyle(.secondary)
            Button("Cancel scheduled check-out") { state.cancelPendingCheckout() }
        } else if state.projects.isEmpty && !state.isProjectMandatory {
            Button("Check Out") {
                checkOut(projectId: nil, projectName: "No project")
            }
            .disabled(!canStop)
        } else if state.projects.isEmpty && state.isProjectMandatory {
            Button("Check Out (no projects loaded)") { }
                .disabled(true)
        } else {
            Menu("Check Out as…") {
                if !state.isProjectMandatory {
                    Button("No project") {
                        checkOut(projectId: nil, projectName: "No project")
                    }
                    Divider()
                }
                ForEach(state.projects) { project in
                    Button(projectLabel(project)) {
                        checkOut(projectId: project.id, projectName: project.name)
                    }
                }
            }
            .disabled(!canStop)
        }
    }

    private func checkOut(projectId: String?, projectName: String) {
        let categoryId = state.effectiveCategoryId
        Task {
            guard let shortfall = await state.requestCheckout(projectId: projectId, categoryId: categoryId) else { return }
            let fireAt = Date().addingTimeInterval(TimeInterval(shortfall))
            let confirmed = Alerts.confirm(
                title: "German legal break required",
                message: Self.confirmationMessage(
                    projectName: projectName,
                    workedSeconds: state.latestStatus?.workTimeElapsedSeconds ?? 0,
                    accumulatedBreakSeconds: state.latestStatus?.accumulatedBreakSeconds ?? 0,
                    shortfallSeconds: shortfall,
                    fireAt: fireAt
                ),
                confirm: "Pause & check out at \(Self.hm(fireAt))"
            )
            if confirmed {
                await state.confirmPendingCheckout(projectId: projectId, categoryId: categoryId, shortfallSeconds: shortfall)
            }
        }
    }

    private static func confirmationMessage(
        projectName: String,
        workedSeconds: Int,
        accumulatedBreakSeconds: Int,
        shortfallSeconds: Int,
        fireAt: Date
    ) -> String {
        let workedHM = AppState.hoursMinutes(seconds: workedSeconds)
        let breakHM = AppState.hoursMinutes(seconds: accumulatedBreakSeconds)
        let requiredMin = BreakRules.requiredBreakSeconds(workedSeconds: workedSeconds) / 60
        let shortfallMin = Int(ceil(Double(shortfallSeconds) / 60.0))
        let minuteWord = shortfallMin == 1 ? "minute" : "minutes"
        return """
        You have worked \(workedHM) with only \(breakHM) of break. Arbeitszeitgesetz §4 requires \(requiredMin) minutes for this duration.

        The menulet will keep you paused for \(shortfallMin) more \(minuteWord) and check you out as “\(projectName)” at \(hm(fireAt)) so no worked time is lost.
        """
    }

    private func projectName(for id: String?) -> String {
        guard let id else { return "No project" }
        return state.projectsById[id]?.name ?? "Unknown project"
    }

    @ViewBuilder
    private var categoryMenu: some View {
        Menu("Category: \(currentCategoryName)") {
            if !state.isCategoryMandatory {
                Button(checkmark("") + "None") { selectedCategoryId = "" }
                Divider()
            }
            ForEach(state.categories) { category in
                Button(checkmark(category.id) + category.name) {
                    selectedCategoryId = category.id
                }
            }
        }
    }

    private func checkmark(_ id: String) -> String {
        let current = state.effectiveCategoryId ?? ""
        return id == current ? "✓ " : "   "
    }

    private var currentCategoryName: String {
        if let cid = state.effectiveCategoryId, let match = state.categoriesById[cid] {
            return match.name
        }
        return "None"
    }

    private func projectLabel(_ p: Project) -> String {
        (p.isFavorite ?? false) ? "★ \(p.name)" : p.name
    }

    private var statusLine: String {
        switch state.status {
        case .unknown: return "…"
        case .noToken: return "Not connected"
        case .idle: return "Idle"
        case .running(let start):
            if let start, let dur = state.menuBarDurationText {
                return "Working · since \(Self.hm(start)) · \(dur)"
            }
            return "Working"
        case .paused(let start, _):
            if let start, let dur = state.menuBarDurationText {
                return "Paused · since \(Self.hm(start)) · break \(dur)"
            }
            return "Paused"
        case .waiting(let start):
            if let start { return "Waiting · since \(Self.hm(start))" }
            return "Waiting"
        }
    }

    private var canStart: Bool { state.status == .idle }
    private var canPause: Bool { state.status.isRunning }
    private var canResume: Bool { state.status.isPaused }
    private var canStop: Bool { state.status.isRunning || state.status.isPaused || state.status.isWaiting }

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

    private static let hmFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "HH:mm"; return f
    }()

    private static func hm(_ d: Date) -> String { hmFormatter.string(from: d) }
}
