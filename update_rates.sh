#!/bin/bash

set -eou pipefail

NUMBERS_FILE="/Users/user/Documents/notes/budget-2027.numbers"

SHEET_NAME="rates"
TABLE_NAME="Table 1"

CURRENCIES=("UAH" "USD" "CZK")
BASE_CURRENCY="EUR"

API_URL="https://api.frankfurter.dev/v2/rates"
LOG_FILE="$XDG_STATE_HOME/exchange-rate-automation/logs/rates.log"

mkdir -p "$(dirname "$LOG_FILE")"

function join_by { local IFS="$1"; shift; echo "$*"; }

function log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"; }

for cmd in curl jq osascript; do
  command -v "$cmd" >/dev/null 2>&1 || {
    log "ERROR: $cmd is not installed"
    exit 1
  }
done

if [[ ! -f "$NUMBERS_FILE" ]]; then
  log "ERROR: Numbers file not found: $NUMBERS_FILE"
  exit 1
fi

log "Fetching exchange rates..."

RESPONSE=$(curl -fsS --max-time 30 "$API_URL?base=$BASE_CURRENCY&quotes=$(join_by , ${CURRENCIES[@]})")

RATE_DATE=$(jq -er '.[0].date' <<< "$RESPONSE")
log "Rate date: $RATE_DATE"

for rate in ${CURRENCIES[@]}; do
  declare $rate=$(jq -er "[.[] | select(.quote == \"$rate\")][0].rate" <<< "$RESPONSE")
  if ! [[ "${!rate}" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
    log "ERROR: Invalid exchange rate: ${!rate}"
    exit 1
  fi
  log "Rate received: $rate=${!rate}"
done


osascript - "$NUMBERS_FILE" "$SHEET_NAME" "$TABLE_NAME" "$RATE_DATE" <<APPLESCRIPT

on run argv
    set filePath to item 1 of argv
    set sheetName to item 2 of argv
    set tableName to item 3 of argv
    set rateDate to item 4 of argv

    tell application "Numbers"
        open POSIX file filePath

        tell document 1
            tell sheet sheetName
                tell table tableName

                    -- Prevent duplicate dates
                    repeat with r from 2 to (row count)
                        if (value of cell 1 of row r as text) is rateDate then
                            error "Rate for this date already exists"
                        end if
                    end repeat

                    -- Add new row
                    set newRow to (row count) + 1
                    add row below last row

                    set value of cell 1 of row newRow to rateDate

                    -- Direct numeric values, no string conversion
                    set value of cell 2 of row newRow to $UAH
                    set value of cell 3 of row newRow to $USD
                    set value of cell 4 of row newRow to $CZK

                end tell
            end tell
        end tell

        save front document
    end tell
end run

APPLESCRIPT

log "Rates successfully updated"
