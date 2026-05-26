# TimebutlerMenulet

macOS menu-bar app that drives the [Timebutler](https://www.timebutler.com/) web time-tracker via its official REST API (v2).

## What it does

- Shows your current work/pause status in the menu bar, with live elapsed time (net work time while running, break time while paused).
- Check in, pause, resume, and check out from the menu — no need to open the Timebutler website.
- Pick project and category for check-out dynamically from your Timebutler account; favorites surface first.
- Stores a personal access token in the macOS Keychain. No browser session, no cookies, no HTML scraping.
- Optional launch-at-login.

## Requirements

- macOS 14 (Sonoma) or newer
- Swift 5.9 toolchain (Xcode 15+)
- A Timebutler account that can create personal access tokens

## Build & run

For development, build and run the raw binary. It launches as an `.accessory` app (menu-bar only, no Dock icon):

```sh
swift build
.build/debug/TimebutlerMenulet
```

For a proper `.app` bundle:

```sh
./build-app.sh
open build/TimebutlerMenulet.app
```

Run the unit tests (Codable model decoding):

```sh
swift test
```

The menu bar does not refresh on rebuild. To replace a running instance:

```sh
pkill -x TimebutlerMenulet && .build/debug/TimebutlerMenulet
```

## First run

On first launch the menulet opens a **Connect to Timebutler** window. Click "Open Timebutler token settings" to land on the PAT page (`/do?ha=personaltoken&ac=1`) in your default browser, create a token (it starts with `tb_`), paste it into the window, and hit **Validate & Save**. The app calls `GET /user/profile` to confirm the token works, stores it in the Keychain, and starts polling status. You can revoke a token any time in Timebutler; the next request will see a 401, the menulet will flip to "Not connected" and reopen the setup window.

## Configuring

There is nothing tenant-specific to edit. Projects and categories come from the API (`/projects`, `/categories`); the dropdown menu builds itself from whatever your account has. A default category for check-out can be pinned via Preferences or the menu's "Category" submenu.

## Project layout

```
Sources/TimebutlerMenulet/
├── App/        SwiftUI entry point and the single AppState store
├── Model/      Codable types for ClockStatus, Project, Category, UserProfile
├── Net/        TimebutlerAPI — Bearer-PAT JSON client
├── Security/   Keychain wrapper for the personal access token
├── UI/         Menu, preferences, token setup window
└── Util/       Shared helpers (WindowID, UserDefaults keys)
```

See `CLAUDE.md` for the architectural details (state model, status mapping, polling cadence).
