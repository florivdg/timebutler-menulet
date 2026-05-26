import SwiftUI
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}

@main
struct TimebutlerMenuletApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var state = AppState()
    @AppStorage(PreferenceKey.showDurationInMenuBar) private var showDurationInMenuBar = false
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        MenuBarExtra {
            StatusMenu().environmentObject(state)
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Image(systemName: state.icon)
                if showDurationInMenuBar, let duration = state.menuBarDurationText {
                    Text(duration)
                }
            }
            .font(.system(size: NSFont.systemFontSize))
        }
        .menuBarExtraStyle(.menu)

        Window(WindowID.tokenSetup.title, id: WindowID.tokenSetup.rawValue) {
            TokenSetupWindow().environmentObject(state)
                .onAppear { NSApp.activate(ignoringOtherApps: true) }
        }
        .windowResizability(.contentSize)

        Window(WindowID.prefs.title, id: WindowID.prefs.rawValue) {
            PreferencesView().environmentObject(state)
                .frame(minWidth: 440, minHeight: 240)
        }
        .windowResizability(.contentSize)
    }
}
