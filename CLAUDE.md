# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

macOS menu bar utility (SwiftUI + AppKit) that drives the Timebutler web time-tracker from a menulet via the official REST API (`https://app.timebutler.com/api/v2`). Swift Package Manager, macOS 14+.

## Commands

- `swift build` / `swift build -c release` — compile.
- `swift test` — run unit tests (Codable models, etc.).
- `.build/debug/TimebutlerMenulet` — launch the raw binary; it runs as an `.accessory` activation policy (menu-bar only, no Dock icon) because `AppDelegate.applicationWillFinishLaunching` sets it at runtime. Handy during dev since you don't need the `.app` bundle.
- `./build-app.sh` — release-builds, wraps the binary into `build/TimebutlerMenulet.app` with an `LSUIElement` `Info.plist` and an ad-hoc codesign. `open build/TimebutlerMenulet.app` to launch.
- To replace a running instance: `pkill -x TimebutlerMenulet` then relaunch.

## Architecture

### Single-owner state
`AppState` (`Sources/TimebutlerMenulet/App/AppState.swift`) is the only `@StateObject`. It owns the `TimebutlerAPI` client, two `Timer`s (60 s poll for status, 30 s tick to re-render the menu-bar duration), and all `@Published` view state — including the live `categories` array loaded from the API. Views receive it via `.environmentObject(state)`. The entry point `TimebutlerMenuletApp` declares a `MenuBarExtra` scene plus two `Window` scenes (`tokenSetup`, `prefs`) keyed by `WindowID`.

### Authentication: personal access token (PAT)
All requests carry `Authorization: Bearer <token>`. The token is stored as a `kSecClassGenericPassword` Keychain item with service `com.local.timebutlermenulet.timebutler.pat` (account `personal-access-token`). On any keychain change, `Keychain.tokenDidChange` is posted; `TimebutlerAPI` re-reads, and `AppState` clears cached categories and refreshes status.

The PAT is entered in `TokenSetupWindow` (a SwiftUI window scene). The "Validate & Save" path writes the token, then calls `GET /user/profile` to confirm it. A 401 anywhere (initial validation or any later request) flips `status` to `.noToken`; the menu surfaces a "Connect to Timebutler…" entry that opens the setup window.

There is no browser login flow, no `WKWebView`, no cookie storage. `TimebutlerAPI` uses a dedicated `URLSession` configured with `httpCookieStorage = nil` and `httpCookieAcceptPolicy = .never` so a stale browser session cookie can't accidentally substitute for a missing PAT.

### API surface
`TimebutlerAPI` (`Sources/TimebutlerMenulet/Net/TimebutlerAPI.swift`) exposes async functions for the endpoints the menulet actually uses:

| Function | Endpoint |
| --- | --- |
| `status()` | `GET /time-clock/status` |
| `start()` | `POST /time-clock/start` |
| `pause()` | `POST /time-clock/pause` |
| `resume()` | `POST /time-clock/resume` |
| `stop(categoryId:remarks:)` | `POST /time-clock/stop` |
| `cancel()` | `POST /time-clock/cancel` |
| `categories()` | `GET /categories` |
| `profile()` | `GET /user/profile` |

Errors are normalized into `APIError`: `noToken`, `unauthorized` (401), `forbidden` (403), `rateLimited` (429), `http(code, body)`, `malformed`, `transport`.

### Status mapping
The clock endpoints all return a `ClockStatus` JSON with `status ∈ {idle, running, paused, waiting}` plus `startTimestamp`, `pauseTimestamp`, etc. `ClockStatus.toWorkStatus()` projects that onto `WorkStatus { unknown, noToken, idle, running, paused, waiting }`. The menulet renders working/paused/waiting durations from the `startedAt: Date?` carried on the case.

### Categories and check-out
Checking out takes no per-check-out selection: the menu has a single "Check Out" button that calls `stop(categoryId:)` with `AppState.effectiveCategoryId`. There is deliberately no project support — the tenant dropped the Office/Home-Office distinction, so `GET /projects` and the `Project` model were removed.

Categories are fetched after the token validates (in `loadLookups()`) and cached on `AppState`. `hasLoadedLookups` latches only once `/categories` actually succeeds, so a transient failure is retried by the next 60 s status poll; `isLoadingLookups` keeps overlapping polls from double-fetching. While the list is missing and a category is pinned, `isCategoryUnresolved` is true and the menu hard-disables check-out rather than silently booking an uncategorised entry. A "Category" submenu lets the user pin a default category whose ID is persisted via `@AppStorage(PreferenceKey.selectedCategoryId)`; `effectiveCategoryId` distinguishes three states of that key: absent (never chosen) uses the API's `defaultCategoryId`, an empty string means the user explicitly pinned "None" and no category is sent, and a pinned id that is no longer in the account falls back to the default. `isCategoryMandatory` from the API drives whether a "None" entry is offered. Nothing is hardcoded per tenant.

### Why there's a 30 s UI tick timer
`menuBarDurationText` reads `@Published private var tick` on purpose so SwiftUI reinvalidates the menu-bar label every 30 s, refreshing the "since HH:MM · Xh Ym" string without waiting for the 60 s status poll.

## Gotchas

- `endpoints.json` is in `.gitignore` — leftover from a deleted dev-time feature. Nothing reads or writes it anymore.
- `build-app.sh` still has a loop to copy `.build/release/*.bundle` into the `.app`. That bundle existed when `Package.swift` had `resources: [.copy("Resources")]`; currently a no-op, harmless, kept in case resources return.
- Persistence is intentionally narrow: Keychain holds the PAT; `UserDefaults` only holds `timebutler.showDurationInMenuBar`, `timebutler.launchAtLogin`, `timebutler.selectedCategoryId`, `timebutler.respectGermanBreakMinimums`, and `timebutler.pendingCheckout`.
- The Swift type for categories is named `TimebutlerCategory` to avoid colliding with the system `Category` typealias.
