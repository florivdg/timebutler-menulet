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
        if state.projects.isEmpty && !state.isProjectMandatory {
            Button("Check Out") {
                Task { await state.perform(.stop(projectId: nil, categoryId: state.effectiveCategoryId)) }
            }
            .disabled(!canStop)
        } else if state.projects.isEmpty && state.isProjectMandatory {
            Button("Check Out (no projects loaded)") { }
                .disabled(true)
        } else {
            Menu("Check Out as…") {
                if !state.isProjectMandatory {
                    Button("No project") {
                        Task { await state.perform(.stop(projectId: nil, categoryId: state.effectiveCategoryId)) }
                    }
                    Divider()
                }
                ForEach(state.projects) { project in
                    Button(projectLabel(project)) {
                        Task { await state.perform(.stop(projectId: project.id, categoryId: state.effectiveCategoryId)) }
                    }
                }
            }
            .disabled(!canStop)
        }
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

    private static func hm(_ d: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "HH:mm"; return f.string(from: d)
    }
}
