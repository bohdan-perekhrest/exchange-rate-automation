#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG_FILE="$XDG_STATE_HOME/exchange-rate-automation/logs/rates.log"
PLIST_NAME="com.exchange_rate.rates.plist"
PLIST_SOURCE="$SCRIPT_DIR/launchd/$PLIST_NAME"
PLIST_TARGET="$HOME/Library/LaunchAgents/$PLIST_NAME"

echo "=================================="
echo " Finance Rates - Installer"
echo "=================================="

if [[ "$(uname)" != "Darwin" ]]; then
    echo "ERROR: This installer requires macOS."
    exit 1
fi

for cmd in curl jq osascript; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "ERROR: Missing dependency: $cmd"
        exit 1
    fi
done

if [[ ! -f "$SCRIPT_DIR/update_rates.sh" ]]; then
    echo "ERROR: update_rates.sh not found."
    exit 1
fi

mkdir -p "$HOME/Library/LaunchAgents"
mkdir -p "$(dirname "$LOG_FILE")"

chmod +x "$SCRIPT_DIR/update_rates.sh"

mkdir -p "$SCRIPT_DIR/launchd"

cat > "$PLIST_SOURCE" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
"http://www.apple.com/DTDs/PropertyList-1.0.dtd">

<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.exchange_rate.rates</string>

    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>$SCRIPT_DIR/update_rates.sh</string>
    </array>

    <key>WorkingDirectory</key>
    <string>$SCRIPT_DIR</string>

    <key>StartCalendarInterval</key>
    <dict>
        <key>Hour</key>
        <integer>17</integer>
        <key>Minute</key>
        <integer>30</integer>
    </dict>

    <key>StandardOutPath</key>
    <string>$XDG_STATE_HOME/exchange-rate-automation/logs/launchd.log</string>

    <key>StandardErrorPath</key>
    <string>$XDG_STATE_HOME/exchange-rate-automation/logs/launchd-error.log</string>
</dict>
</plist>
EOF

plutil -lint "$PLIST_SOURCE"

if launchctl list | grep -q "com.exchange_rate.rates"; then
    launchctl bootout "gui/$(id -u)/com.exchange_rate.rates" 2>/dev/null || true
fi

cp "$PLIST_SOURCE" "$PLIST_TARGET"

launchctl bootstrap "gui/$(id -u)" "$PLIST_TARGET"

echo ""
echo "=================================="
echo " Installation completed!"
echo "=================================="
echo "Schedule: Every day at 17:30"
echo "Script:   $SCRIPT_DIR/update_rates.sh"
echo "Logs:     $LOG_FILE"
echo ""

read -r -p "Run an initial update now? [y/N] " answer

if [[ "$answer" =~ ^[Yy]$ ]]; then
    "$SCRIPT_DIR/update_rates.sh"
fi

echo ""
echo "Finance Rates automation is ready!"
