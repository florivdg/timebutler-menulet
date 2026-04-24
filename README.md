# TimebutlerMenulet

macOS menu-bar app that drives the [Timebutler](https://www.timebutler.com/) web time-tracker.

## What it does

- Shows your current work/pause status in the menu bar, with elapsed time since check-in.
- Check in, pause, resume, and check out from the menu — no need to open the Timebutler website.
- Remembers your login via a namespaced macOS Keychain item and auto-fills the Timebutler web login form on return visits (2FA supported).
- Optional launch-at-login.

## Requirements

- macOS 14 (Sonoma) or newer
- Swift 5.9 toolchain (Xcode 15+)
- A Timebutler account

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

The menu bar does not refresh on rebuild. To replace a running instance:

```sh
pkill -x TimebutlerMenulet && .build/debug/TimebutlerMenulet
```

## First run

Click the menu-bar icon and choose **Login**. A web view opens on `app.timebutler.com/login`. Sign in once; the Keychain remembers your credentials and auto-fills the form next time. If your account has 2FA enabled, enter the one-time code in the OTP field that appears.

## Configuring for your Timebutler account

Two things are hardcoded to the original author's tenant. If you fork this for your own account, edit:

- **Project IDs** in `Sources/TimebutlerMenulet/Net/TimebutlerClient.swift` — the `defaultProjects` list on `TimebutlerAction.checkOut` (currently `93529` Homeoffice, `93527` Office). Replace with the project IDs from your own Timebutler setup. The hardcoded `projid=93529` in the check-out URL template is rewritten at runtime with the chosen project.
- **Status scraping** in `Sources/TimebutlerMenulet/Net/HTMLScraper.swift` — the dashboard HTML is read from the `#time-clock` widget's `data-*` attributes. If Timebutler changes that widget, fix it here.

## Project layout

```
Sources/TimebutlerMenulet/
├── App/        SwiftUI entry point and the single AppState store
├── Net/        TimebutlerClient, HTML scraping, WebKit↔URLSession cookie bridge
├── Security/   Keychain wrapper for storing credentials
├── UI/         Menu-bar menu, login web view, preferences window
└── Util/       Shared helpers
```

See `CLAUDE.md` for a deeper architectural tour.
