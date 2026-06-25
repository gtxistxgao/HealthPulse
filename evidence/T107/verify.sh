#!/bin/bash
#
# T107 — Dashboard 接入设置入口: end-to-end runtime verification.
#
# Builds HealthPulse, drives the booted iOS Simulator with idb (taps/swipes
# injected directly into the sim — macOS AppleScript/accessibility is blocked
# in this sandbox), and captures a screenshot at each rubric step into the
# directory this script lives in.
#
# Rubrics verified:
#   ① a gear button is visible in the Dashboard toolbar
#   ② tapping the gear opens SettingsView
#   ③ switching the language updates the Dashboard copy after returning
#
# Prereqs (already provisioned in this environment):
#   brew install facebook/fb/idb-companion
#   pip3 install --user fb-idb
#
# Usage: bash evidence/T107/verify.sh
set -euo pipefail

EVID_DIR="$(cd "$(dirname "$0")" && pwd)"
BID="com.healthpulse.HealthPulse"
DD=/tmp/hp-dd
export PATH="$HOME/Library/Python/3.9/bin:$PATH"

UDID="$(xcrun simctl list devices booted | grep -Eo '[0-9A-F-]{36}' | head -1)"
[ -n "$UDID" ] || { echo "No booted simulator"; exit 1; }
echo "Device: $UDID"
echo "Run timestamp: $(date '+%Y-%m-%d %H:%M:%S %Z')"

shot() { sleep "${2:-2}"; xcrun simctl io "$UDID" screenshot "$EVID_DIR/$1" >/dev/null 2>&1; echo "  -> $1"; }
tap()  { idb ui tap   --udid "$UDID" "$1" "$2" >/dev/null 2>&1; }
swipe(){ idb ui swipe --udid "$UDID" --duration 0.6 "$1" "$2" "$3" "$4" >/dev/null 2>&1; }

echo "== Build =="
xcodebuild -project HealthPulse.xcodeproj -scheme HealthPulse -sdk iphonesimulator \
  -configuration Debug -destination "platform=iOS Simulator,id=$UDID" \
  -derivedDataPath "$DD" build >/dev/null
APP="$DD/Build/Products/Debug-iphonesimulator/HealthPulse.app"
echo "Built: $APP"

echo "== Reset app state (clears HealthKit auth + language selection) =="
xcrun simctl terminate "$UDID" "$BID" >/dev/null 2>&1 || true
xcrun simctl uninstall "$UDID" "$BID" >/dev/null 2>&1 || true
xcrun simctl install "$UDID" "$APP"
idb connect "$UDID" >/dev/null 2>&1 || true

echo "== Launch =="
xcrun simctl launch "$UDID" "$BID" >/dev/null
sleep 3
shot 01-healthkit-auth.png 1     # system HealthKit authorization sheet

echo "== Dismiss HealthKit sheet (Turn On All -> Allow) =="
tap 220 473   # "Turn On All"
sleep 1
tap 220 831   # "Allow" (enabled after Turn On All)
shot 02-dashboard-en.png 3       # Rubric ①: Dashboard in English w/ gear button

echo "== Tap gear (frame center ~398,84) =="
tap 398 84
shot 03-settings-en.png          # Rubric ②: SettingsView opens

echo "== Tap 简体中文 row (frame y=280 h=52 -> center 220,306) =="
tap 220 306
shot 04-settings-zh.png          # Settings re-rendered live in Chinese

echo "== Swipe down to dismiss sheet, back to Dashboard =="
swipe 220 180 220 950
shot 05-dashboard-zh.png 3       # Rubric ③: Dashboard copy now Chinese

echo "Done. Screenshots written to $EVID_DIR"
