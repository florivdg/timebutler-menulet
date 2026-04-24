import SwiftUI
import WebKit

@MainActor
final class WebViewRef: ObservableObject {
    @Published var webView: WKWebView?
}

struct LoginWindow: View {
    @EnvironmentObject var state: AppState
    @StateObject private var ref = WebViewRef()
    @State private var otp: String = ""
    @State private var lastResult: String = ""

    var body: some View {
        VStack(spacing: 0) {
            WebViewHost(
                url: URL(string: "https://app.timebutler.com/login")!,
                config: state.session.makeSharedConfig(userScripts: [Keychain.autofillScript()]),
                onFinish: { url in
                    if Self.looksLoggedIn(url) {
                        Task {
                            await state.session.syncCookiesFromWebKit()
                            await state.refreshStatus()
                        }
                    }
                },
                onReady: { wv in
                    if ref.webView !== wv { ref.webView = wv }
                },
                allowsNavigation: TimebutlerHost.isTrustedLoginURL
            )
            Divider()
            HStack(spacing: 8) {
                Text("OTP:").foregroundStyle(.secondary)
                TextField("6-digit code", text: $otp)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 140)
                    .onSubmit(submitOTP)
                Button("Submit OTP", action: submitOTP)
                    .keyboardShortcut(.defaultAction)
                    .disabled(otp.isEmpty)
                Spacer()
                Button("Sync cookies") {
                    Task {
                        await state.session.syncCookiesFromWebKit()
                        await state.refreshStatus()
                    }
                }
            }
            .padding(8)
            HStack {
                Text(lastResult.isEmpty
                     ? "Log in normally. If 2FA is prompted, paste the code above and hit Return."
                     : lastResult)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
        }
    }

    private func submitOTP() {
        let trimmed = otp.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard let wv = ref.webView else {
            lastResult = "WebView not ready yet — try again in a moment."
            return
        }
        let escaped = trimmed.jsEscaped
        let js = """
        (function(code) {
          const inputs = Array.from(document.querySelectorAll('input'));
          const tag = (i) => ((i.name || '') + ' ' + (i.id || '') + ' ' + (i.placeholder || '') + ' ' + (i.getAttribute('autocomplete') || '')).toLowerCase();
          let otp = inputs.find(i => /otp|code|token|2fa|mfa|verify|passcode|pin|one.?time|tan/.test(tag(i)))
                 || inputs.find(i => (i.inputMode === 'numeric' || i.type === 'tel') && (!i.maxLength || i.maxLength <= 10));
          if (!otp) return 'no-input';
          otp.focus();
          const setter = Object.getOwnPropertyDescriptor(window.HTMLInputElement.prototype, 'value').set;
          setter.call(otp, code);
          otp.dispatchEvent(new Event('input', { bubbles: true }));
          otp.dispatchEvent(new Event('change', { bubbles: true }));
          const form = otp.closest('form');
          setTimeout(() => {
            if (form) {
              const btn = form.querySelector('button[type=submit], input[type=submit], button.submit, button');
              if (btn) btn.click(); else form.submit();
            }
          }, 120);
          return 'submitted';
        })("\(escaped)");
        """
        wv.evaluateJavaScript(js) { result, _ in
            let r = result as? String ?? "?"
            Task { @MainActor in
                self.lastResult = r == "submitted" ? "OTP submitted." : "No OTP field found on this page."
                if r == "submitted" { self.otp = "" }
            }
        }
    }

    private static func looksLoggedIn(_ url: URL) -> Bool {
        guard TimebutlerHost.isTrustedLoginURL(url) else { return false }
        let path = url.path.lowercased()
        let query = (url.query ?? "").lowercased()
        let blockers = ["login", "signup", "otp", "2fa", "mfa", "verify", "challenge", "two-factor", "twofactor", "authcode"]
        for b in blockers where path.contains(b) || query.contains(b) { return false }
        return true
    }
}
