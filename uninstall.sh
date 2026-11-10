#!/bin/bash

set -euo pipefail

LABEL="com.exchange_rate.rates"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"

echo "Removing Finance Rates automation..."

launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true

rm -f "$PLIST"

echo "Automation removed."
echo "Your Numbers file and logs were not deleted."
