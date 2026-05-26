import SwiftUI
import AppKit

struct TokenSetupWindow: View {
    @EnvironmentObject var state: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var token: String = Keychain.readToken() ?? ""
    @State private var isValidating = false
    @State private var message: String?
    @State private var isError = false

    private let tokenSettingsURL = URL(string: "https://app.timebutler.com/do?ha=personaltoken&ac=1")!

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Connect to Timebutler")
                .font(.title2.bold())

            Text("Paste a personal access token. Create one in Timebutler under your account settings; tokens start with “tb_”.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                NSWorkspace.shared.open(tokenSettingsURL)
            } label: {
                Label("Open Timebutler token settings", systemImage: "safari")
            }
            .buttonStyle(.link)

            SecureField("tb_…", text: $token)
                .textFieldStyle(.roundedBorder)
                .disabled(isValidating)
                .onSubmit(validateAndSave)

            HStack {
                if let message {
                    Text(message)
                        .font(.callout)
                        .foregroundStyle(isError ? .red : .secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                if isValidating { ProgressView().controlSize(.small) }
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Validate & Save", action: validateAndSave)
                    .keyboardShortcut(.defaultAction)
                    .disabled(token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isValidating)
            }
        }
        .padding(20)
        .frame(width: 460)
    }

    private func validateAndSave() {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        isValidating = true
        message = nil
        isError = false
        Task {
            defer { isValidating = false }
            do {
                try Keychain.writeToken(trimmed)
                state.api.reloadToken()
                _ = try await state.api.profile()
                await state.refreshStatus()
                dismiss()
            } catch APIError.unauthorized {
                Keychain.deleteToken()
                state.api.reloadToken()
                isError = true
                message = "Token rejected by Timebutler (401). Double-check that it was copied in full and is still active."
            } catch {
                isError = true
                message = error.localizedDescription
            }
        }
    }
}
