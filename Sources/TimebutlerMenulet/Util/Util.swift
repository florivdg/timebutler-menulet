import Foundation

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
}
