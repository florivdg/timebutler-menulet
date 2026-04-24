import Foundation
import WebKit

@MainActor
final class SessionManager: NSObject, WKHTTPCookieStoreObserver {
    let dataStore: WKWebsiteDataStore = .default()

    override init() {
        super.init()
        dataStore.httpCookieStore.add(self)
        Task { await syncCookiesFromWebKit() }
    }

    func makeSharedConfig(userScripts: [WKUserScript] = []) -> WKWebViewConfiguration {
        let cfg = WKWebViewConfiguration()
        cfg.websiteDataStore = dataStore
        let ucc = WKUserContentController()
        for s in userScripts { ucc.addUserScript(s) }
        cfg.userContentController = ucc
        return cfg
    }

    nonisolated func cookiesDidChange(in cookieStore: WKHTTPCookieStore) {
        Task { @MainActor in await self.syncCookiesFromWebKit() }
    }

    func syncCookiesFromWebKit() async {
        let store = dataStore.httpCookieStore
        let cookies: [HTTPCookie] = await withCheckedContinuation { cont in
            store.getAllCookies { cookies in cont.resume(returning: cookies) }
        }
        for c in cookies where TimebutlerHost.isTrustedCookieDomain(c.domain) {
            HTTPCookieStorage.shared.setCookie(c)
        }
    }

    func clearCookies() async {
        let types = WKWebsiteDataStore.allWebsiteDataTypes()
        let records: [WKWebsiteDataRecord] = await withCheckedContinuation { cont in
            dataStore.fetchDataRecords(ofTypes: types) { cont.resume(returning: $0) }
        }
        let toRemove = records.filter { TimebutlerHost.isTrustedCookieDomain($0.displayName) }
        if !toRemove.isEmpty {
            await withCheckedContinuation { cont in
                dataStore.removeData(ofTypes: types, for: toRemove) { cont.resume() }
            }
        }
        if let url = URL(string: "https://app.timebutler.com"),
           let cookies = HTTPCookieStorage.shared.cookies(for: url) {
            for c in cookies { HTTPCookieStorage.shared.deleteCookie(c) }
        }
    }
}
