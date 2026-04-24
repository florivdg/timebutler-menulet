import SwiftUI
import ServiceManagement

struct PreferencesView: View {
    @EnvironmentObject var state: AppState
    @State private var email: String = Keychain.readCredentials()?.email ?? ""
    @State private var password: String = Keychain.readCredentials()?.password ?? ""
    @State private var savedCreds = false
    @State private var credentialsError: String?
    @AppStorage(PreferenceKey.showDurationInMenuBar) private var showDurationInMenuBar = false
    @AppStorage(PreferenceKey.launchAtLogin) private var launchAtLogin = false
    @State private var launchAtLoginError: String?

    var body: some View {
        Form {
            Section("Timebutler credentials") {
                TextField("Email", text: $email).textContentType(.username)
                SecureField("Password", text: $password).textContentType(.password)
                HStack {
                    Button("Save to Keychain") {
                        do {
                            try Keychain.writeCredentials(email: email, password: password)
                            savedCreds = true
                            credentialsError = nil
                        } catch {
                            savedCreds = false
                            credentialsError = error.localizedDescription
                        }
                    }
                    if savedCreds { Text("Saved").foregroundStyle(.secondary) }
                    Spacer()
                }
                if let credentialsError {
                    Text(credentialsError)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
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

            Section("Check-out projects (built-in)") {
                ForEach(TimebutlerAction.checkOut.defaultProjects, id: \.value) { p in
                    HStack {
                        Text(p.label).bold()
                        Spacer()
                        Text("projid=\(p.value)")
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                    }
                }
                Text("Edit TimebutlerAction.defaultProjects in source to change.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("Session") {
                HStack {
                    Button("Clear cookies (force re-login)") {
                        Task { await state.session.clearCookies() }
                    }
                    Spacer()
                    Button("Refresh status") {
                        Task { await state.refreshStatus() }
                    }
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
