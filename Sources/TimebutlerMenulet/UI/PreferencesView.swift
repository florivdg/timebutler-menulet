import SwiftUI
import AppKit
import ServiceManagement

struct PreferencesView: View {
    @EnvironmentObject var state: AppState
    @Environment(\.openWindow) private var openWindow
    @AppStorage(PreferenceKey.showDurationInMenuBar) private var showDurationInMenuBar = false
    @AppStorage(PreferenceKey.launchAtLogin) private var launchAtLogin = false
    @AppStorage(PreferenceKey.selectedCategoryId) private var selectedCategoryId: String = ""
    @AppStorage(PreferenceKey.respectGermanBreakMinimums) private var respectGermanBreakMinimums = false
    @State private var launchAtLoginError: String?

    private var hasToken: Bool { state.status != .noToken }

    var body: some View {
        Form {
            Section("Personal access token") {
                HStack {
                    Image(systemName: hasToken ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(hasToken ? .green : .orange)
                    if let name = state.userDisplayName, hasToken {
                        Text("Signed in as \(name)")
                    } else if hasToken {
                        Text("Token stored in Keychain")
                    } else {
                        Text("No token configured")
                    }
                    Spacer()
                }
                HStack {
                    Button(hasToken ? "Replace token…" : "Set up token…") {
                        openWindow(id: WindowID.tokenSetup.rawValue)
                        NSApp.activate(ignoringOtherApps: true)
                    }
                    Button("Forget token", role: .destructive) {
                        Keychain.deleteToken()
                    }
                    .disabled(!hasToken)
                    Spacer()
                }
            }

            Section("Default category for check-out") {
                if state.categories.isEmpty {
                    Text("Categories will appear after the token is validated.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Picker("Category", selection: $selectedCategoryId) {
                        if !state.isCategoryMandatory {
                            Text("None").tag("")
                        }
                        ForEach(state.categories) { category in
                            Text(category.name).tag(category.id)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }

            Section("Check-out") {
                Toggle("Enforce German legal break minimums (§4 ArbZG)", isOn: $respectGermanBreakMinimums)
                    .toggleStyle(.checkbox)
                Text("When you check out before the legal break has been reached, the menulet keeps you paused for the missing minutes and performs the check-out automatically afterwards, so no worked time is lost.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Menu bar") {
                Toggle("Show duration next to icon", isOn: $showDurationInMenuBar)
                    .toggleStyle(.checkbox)
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .toggleStyle(.checkbox)
                    .onChange(of: launchAtLogin) { _, newValue in
                        applyLaunchAtLogin(newValue)
                    }
                if let launchAtLoginError {
                    Text(launchAtLoginError)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Button("Refresh status") {
                    Task { await state.refreshStatus() }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear {
            launchAtLogin = (SMAppService.mainApp.status == .enabled)
        }
    }

    private func applyLaunchAtLogin(_ enabled: Bool) {
        let service = SMAppService.mainApp
        do {
            if enabled {
                try service.register()
            } else {
                try service.unregister()
            }
            launchAtLoginError = nil
        } catch {
            launchAtLoginError = "Could not update login item: \(error.localizedDescription). Launch from the .app bundle."
            let actual = (service.status == .enabled)
            if launchAtLogin != actual {
                launchAtLogin = actual
            }
        }
    }
}
