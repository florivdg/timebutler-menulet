#!/bin/bash
set -euo pipefail

NAME="TimebutlerMenulet"
BUNDLE_ID="com.local.timebutlermenulet"
ROOT="$(cd "$(dirname "$0")" && pwd)"

# Where the shipped copy lives, and the per-user login item that starts it.
# Kept out of the repo so a `rm -rf build` or a moved checkout can't break auto-launch.
INSTALL_DIR="$HOME/Applications"
INSTALLED_APP="$INSTALL_DIR/$NAME.app"
AGENT_LABEL="$BUNDLE_ID"
AGENT_PLIST="$HOME/Library/LaunchAgents/$AGENT_LABEL.plist"
GUI_DOMAIN="gui/$(id -u)"

INSTALL=true
for arg in "$@"; do
  case "$arg" in
    --no-install) INSTALL=false ;;
    *) echo "usage: $0 [--no-install]" >&2; exit 2 ;;
  esac
done

cd "$ROOT"
swift build -c release

APP="$ROOT/build/$NAME.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp ".build/release/$NAME" "$APP/Contents/MacOS/$NAME"

# SPM copies resources into a bundle named like TimebutlerMenulet_TimebutlerMenulet.bundle
for b in .build/release/*.bundle; do
  [ -e "$b" ] || continue
  cp -R "$b" "$APP/Contents/Resources/"
done

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key><string>$NAME</string>
  <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
  <key>CFBundleName</key><string>$NAME</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>0.1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

codesign --force --sign - "$APP" >/dev/null 2>&1 || true
echo "Built $APP"

if [ "$INSTALL" = false ]; then
  echo "Run: open \"$APP\""
  exit 0
fi

# Stop the managed instance (and any stray one) so the bundle can be replaced in place.
launchctl bootout "$GUI_DOMAIN/$AGENT_LABEL" >/dev/null 2>&1 || true
pkill -x "$NAME" >/dev/null 2>&1 || true

mkdir -p "$INSTALL_DIR"
rm -rf "$INSTALLED_APP"
cp -R "$APP" "$INSTALLED_APP"

mkdir -p "$HOME/Library/LaunchAgents"
cat > "$AGENT_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$AGENT_LABEL</string>
  <key>ProgramArguments</key>
  <array>
    <string>$INSTALLED_APP/Contents/MacOS/$NAME</string>
  </array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><false/>
  <key>ProcessType</key><string>Interactive</string>
</dict>
</plist>
PLIST

# bootout above makes this idempotent: re-running the script reloads cleanly.
launchctl bootstrap "$GUI_DOMAIN" "$AGENT_PLIST"
launchctl enable "$GUI_DOMAIN/$AGENT_LABEL"

echo "Installed $INSTALLED_APP"
echo "Login item: $AGENT_PLIST (running now, and at every login)"
echo
echo "Preferences → \"Launch at login\" toggles this same plist, so the two agree."
echo "To remove: launchctl bootout $GUI_DOMAIN/$AGENT_LABEL && rm \"$AGENT_PLIST\""
