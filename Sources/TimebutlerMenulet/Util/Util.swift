import Foundation
import AppKit

enum WindowID: String, CaseIterable {
    case tokenSetup, prefs

    var title: String {
        switch self {
        case .tokenSetup: return "Connect to Timebutler"
        case .prefs: return "Preferences"
        }
    }
}

enum PreferenceKey {
    static let showDurationInMenuBar = "timebutler.showDurationInMenuBar"
    static let launchAtLogin = "timebutler.launchAtLogin"
    static let selectedCategoryId = "timebutler.selectedCategoryId"
    static let respectGermanBreakMinimums = "timebutler.respectGermanBreakMinimums"
    static let pendingCheckout = "timebutler.pendingCheckout"
}

@MainActor
enum Alerts {
    static func confirm(title: String, message: String, confirm: String, cancel: String = "Cancel") -> Bool {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: confirm)
        alert.addButton(withTitle: cancel)
        return alert.runModal() == .alertFirstButtonReturn
    }
}
