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

    var body: some Scene {
        MenuBarExtra {
            StatusMenu().environmentObject(state)
        } label: {
            Image(systemName: state.icon)
        }
        .menuBarExtraStyle(.menu)

        Window(WindowID.login.title, id: WindowID.login.rawValue) {
            LoginWindow().environmentObject(state)
                .frame(minWidth: 520, minHeight: 680)
        }
        .windowResizability(.contentSize)

        Window(WindowID.recorder.title, id: WindowID.recorder.rawValue) {
            RecorderWindow().environmentObject(state)
                .frame(minWidth: 760, minHeight: 780)
        }
        .windowResizability(.contentSize)

        Window(WindowID.prefs.title, id: WindowID.prefs.rawValue) {
            PreferencesView().environmentObject(state)
                .frame(minWidth: 440, minHeight: 240)
        }
        .windowResizability(.contentSize)
    }
}
