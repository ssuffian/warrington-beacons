#!/usr/bin/env bash
#
# Fake a trail beacon on a connected device/emulator running a DEBUG build of the app.
# (Backed by FakeBeaconReceiver, which only exists in debug builds.)
#
# Usage:
#   ./simulate_beacon.sh <minor> [distance-meters]   # one beacon (minor = landmark id)
#   ./simulate_beacon.sh 7:2.5 8:10 4001:40          # several beacons at once
#   ./simulate_beacon.sh clear                       # walk out of range of everything
#   ./simulate_beacon.sh walk [seconds-per-stop]     # auto-walk landmarks 1..16 (Ctrl-C stops)
#
# Landmark ids in the current data file: 1-16 (trail stops) and 4001 (trailhead).
set -euo pipefail

PKG="org.warringtontownship.us202.android"
RECEIVER="$PKG/.beacon.FakeBeaconReceiver"
ACTION_SET="org.warringtontownship.us202.FAKE_BEACON"
ACTION_CLEAR="org.warringtontownship.us202.FAKE_BEACON_CLEAR"

ADB="${ADB:-$(command -v adb || echo "$HOME/Library/Android/sdk/platform-tools/adb")}"
if ! "$ADB" get-state >/dev/null 2>&1; then
    echo "error: no device/emulator connected (checked: $ADB)" >&2
    exit 1
fi

usage() { sed -n '3,11p' "$0" | sed 's/^# \{0,1\}//'; exit 1; }

send_one() { # minor [distance]
    "$ADB" shell am broadcast -n "$RECEIVER" -a "$ACTION_SET" \
        --ei minor "$1" --ef distance "${2:-1.0}" >/dev/null
    echo "faked beacon: landmark $1 at ${2:-1.0} m"
}

case "${1:-}" in
    "" ) usage ;;
    clear )
        "$ADB" shell am broadcast -n "$RECEIVER" -a "$ACTION_CLEAR" >/dev/null
        echo "cleared all fake beacons"
        ;;
    walk )
        for minor in $(seq 1 16); do
            send_one "$minor" 2.0
            sleep "${2:-8}"
        done
        "$ADB" shell am broadcast -n "$RECEIVER" -a "$ACTION_CLEAR" >/dev/null
        echo "walk finished, beacons cleared"
        ;;
    *:* )
        spec=$(IFS=,; echo "$*")
        "$ADB" shell am broadcast -n "$RECEIVER" -a "$ACTION_SET" --es beacons "$spec" >/dev/null
        echo "faked beacons: $spec"
        ;;
    * )
        send_one "$1" "${2:-}"
        ;;
esac
