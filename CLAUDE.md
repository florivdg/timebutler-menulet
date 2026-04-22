# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

macOS menu bar utility (SwiftUI + AppKit) that drives the Timebutler web time-tracker from a menulet. Swift Package Manager, macOS 14+, no test target.

## Commands

- `swift build` / `swift build -c release` — compile.
- `.build/debug/TimebutlerMenulet` — launch the raw binary; it runs as an `.accessory` activation policy (menu-bar only, no Dock icon) because `AppDelegate.applicationWillFinishLaunching` sets it at runtime. Handy during dev since you don't need the `.app` bundle.
- `./build-app.sh` — release-builds, wraps the binary into `build/TimebutlerMenulet.app` with an `LSUIElement` `Info.plist` and an ad-hoc codesign. `open build/TimebutlerMenulet.app` to launch.
- To replace a running instance: `pkill -x TimebutlerMenulet` then relaunch. The menulet has no restart affordance of its own.
- Menu bar does not auto-refresh on build; relaunch after changes.

## Architecture

### Single-owner state
`AppState` (`Sources/TimebutlerMenulet/App/AppState.swift`) is the only `@StateObject`. It owns the `SessionManager`, the `TimebutlerClient`, two `Timer`s (60 s poll for status, 30 s tick to re-render the menu-bar duration), and all `@Published` view state. Views receive it via `.environmentObject(state)`. The entry point `TimebutlerMenuletApp` declares a `MenuBarExtra` scene plus two `Window` scenes (`login`, `prefs`) keyed by `WindowID`.

### Two cookie jars, bridged
Authentication happens in a `WKWebView` (`LoginWindow`), so cookies land in `WKWebsiteDataStore.default()`. All programmatic calls (`TimebutlerClient`, status polling) use `URLSession.shared` → `HTTPCookieStorage.shared`. `SessionManager` is a `WKHTTPCookieStoreObserver` that mirrors every WebKit cookie change onto `HTTPCookieStorage` (`syncCookiesFromWebKit`). If you add another code path that hits Timebutler, it **must** go through `URLSession` (or re-sync first) — reading cookies only from WebKit will silently fail.

### Login flow
No programmatic auth. `LoginWindow` loads `https://app.timebutler.com/login` in a `WKWebView` with `Keychain.autofillScript()` injected (reads Keychain credentials, fills the form). 2FA is handled by a Swift-side OTP field that `evaluateJavaScript`s a heuristic injector (`LoginWindow.submitOTP`) looking for OTP-shaped inputs. Session expiry is detected throughout by `resp.url.path.contains("login")` or HTTP 401/403 → `ClientError.expired` → `status = .loggedOut`.

### Status detection is HTML-scraped
`TimebutlerClient.fetchStatus` GETs the dashboard HTML; `HTMLScraper.parseStatus` pattern-matches German **and** English markers (`"gestartet um HH:MM"`, `"arbeitszeit läuft"`, `"pausiert"`, `"ausgecheckt"`, etc.). If the page loads but no marker matches, `parseStatus` returns `nil` and `AppState` normalizes that to `.loggedIn` (logged in, activity unknown). If Timebutler ever changes its dashboard copy, this is where it breaks.

### Endpoints are hardcoded on the enum
The four actions are `enum TimebutlerAction { checkIn, pause, resume, checkOut }`. Each case carries its full `Endpoint(method, url, body)` via a computed `var endpoint` (`Net/TimebutlerClient.swift`). `TimebutlerClient.perform` substitutes two templates: `{{t}}` → unix-ms timestamp, and regex `projid=\d+` → the user-picked project value for `checkOut` (the only action whose `defaultProjects` is non-empty; the others skip the picker). Adding a new action = add an enum case + a line in the `endpoint` switch.

The `defaultProjects` list on `TimebutlerAction.checkOut` hardcodes this tenant's Timebutler project IDs (`93529` Homeoffice, `93527` Office). Anyone forking for a different Timebutler account edits this enum.

### Why there's a 30 s UI tick timer
`menuBarDurationText` reads `@Published private var tick` on purpose so SwiftUI reinvalidates the menu-bar label every 30 s, refreshing the "since HH:MM · Xh Ym" string without waiting for the 60 s status poll.

### Credentials
`Keychain` uses `kSecClassInternetPassword` with `server = "app.timebutler.com"`. The email is stored in `UserDefaults` under `timebutler.email`; the password is in the Keychain. `Keychain.autofillScript()` returns a `WKUserScript` for the login web view.

## Historical / gotchas

- `endpoints.json` is in `.gitignore` — a leftover from a deleted dev-time "record and assign endpoints" feature. Nothing reads or writes it anymore.
- `build-app.sh` still has a loop to copy `.build/release/*.bundle` into the `.app`. That bundle existed when `Package.swift` had `resources: [.copy("Resources")]`; it's currently a no-op (the Resources dir and the `resources:` line were removed), but the script is harmless and stays in case resources return.
- No `NotificationCenter`, no persistence beyond Keychain + `UserDefaults` (only `timebutler.showDurationInMenuBar` and `timebutler.email`).
