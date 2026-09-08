import Foundation

/// The per-user LaunchAgent that starts the menulet at login.
///
/// Deliberately not `SMAppService`: the bundle is ad-hoc signed, so its code signature changes on
/// every rebuild and macOS can silently drop the registration. `build-app.sh` writes the same
/// plist, so the Preferences toggle and the install script describe one mechanism rather than two.
///
/// Enabling and disabling only write and remove the plist — no `launchctl`. Booting the job out
/// would kill this very process whenever launchd is the one that started it, and bootstrapping it
/// while an unmanaged copy is already running would put a second icon in the menu bar. The file on
/// disk is what launchd reads at the next login, which is exactly what the toggle promises.
enum LoginItem {
    static let label = "com.local.timebutlermenulet"

    static var plistURL: URL {
        URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Library/LaunchAgents/\(label).plist")
    }

    /// The executable launchd should start, or `nil` when running the raw binary — there is no
    /// `.app` to point at, and registering the build-directory path would break on the next build.
    static var executableURL: URL? {
        guard Bundle.main.bundleURL.pathExtension == "app" else { return nil }
        return Bundle.main.executableURL
    }

    static var isEnabled: Bool {
        FileManager.default.fileExists(atPath: plistURL.path)
    }

    static func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try enable()
        } else {
            try disable()
        }
    }

    private static func enable() throws {
        guard let executableURL else { throw LoginItemError.notABundle }
        let plist: [String: Any] = [
            "Label": label,
            "ProgramArguments": [executableURL.path],
            "RunAtLoad": true,
            "KeepAlive": false,
            "ProcessType": "Interactive",
        ]
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try FileManager.default.createDirectory(
            at: plistURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: plistURL, options: .atomic)
    }

    private static func disable() throws {
        guard isEnabled else { return }
        try FileManager.default.removeItem(at: plistURL)
    }

    enum LoginItemError: LocalizedError {
        case notABundle

        var errorDescription: String? {
            switch self {
            case .notABundle:
                return "Launch at login needs the .app bundle — run ./build-app.sh and start it from ~/Applications."
            }
        }
    }
}
