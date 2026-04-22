import SwiftUI

struct PreferencesView: View {
    @EnvironmentObject var state: AppState
    @State private var email: String = Keychain.readCredentials()?.email ?? ""
    @State private var password: String = Keychain.readCredentials()?.password ?? ""
    @State private var savedCreds = false
    @AppStorage(PreferenceKey.showDurationInMenuBar) private var showDurationInMenuBar = false

    var body: some View {
        Form {
            Section("Timebutler credentials") {
                TextField("Email", text: $email).textContentType(.username)
                SecureField("Password", text: $password).textContentType(.password)
                HStack {
                    Button("Save to Keychain") {
                        Keychain.writeCredentials(email: email, password: password)
                        savedCreds = true
                    }
                    if savedCreds { Text("Saved").foregroundStyle(.secondary) }
                    Spacer()
                }
            }

            Section("Menu bar") {
                Toggle("Show duration next to icon", isOn: $showDurationInMenuBar)
                    .toggleStyle(.checkbox)
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

            Section("Endpoints file") {
                Text(EndpointRegistry.url.path)
                    .font(.caption.monospaced())
                    .textSelection(.enabled)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}
