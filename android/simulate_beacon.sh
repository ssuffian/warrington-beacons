#!/usr/bin/env bash
#
# Fake a trail beacon on a connected device/emulator running a DEBUG build of the app.
# (Backed by FakeBeaconReceiver, which only exists in debug builds.)
#
# Usage:
#   ./simulate_beacon.sh <minor> [distance-meters]   # one beacon (minor = landmark id)
#   ./simulate_beacon.sh 7:2.5 8:10 4001:40          # several beacons at once
#   ./simulate_beacon.sh clear                       # walk out of range of everything
#   ./simulate_beacon.sh walk [seconds-per-stop]     # auto-walk US202 landmarks 1..16 (Ctrl-C stops)
#
# Landmark ids: US202 1-16 (trail stops) and 4001 (trailhead); Lions Pride Park 1002-3008.
#
# The app only announces a landmark once it's been seen 3 times within 30 meters
# (see AnnouncementGate), so a single call does nothing by design — send the same
# minor 3 times, a second or so apart, to trigger an announcement. Distances of 30m
# or more are ignored entirely. Note: three calls with the *exact* same distance
# collapse into one update (the underlying beacon state is a StateFlow, which drops
# consecutive equal values), so the gate never reaches 3 sightings — vary the
# distance slightly on each call (e.g. 2.0, 2.01, 2.02) to be sure each one lands.
set -euo pipefail

PKG="org.warringtontownship.parks.android"
RECEIVER="$PKG/.beacon.FakeBeaconReceiver"
ACTION_SET="org.warringtontownship.parks.FAKE_BEACON"
ACTION_CLEAR="org.warringtontownship.parks.FAKE_BEACON_CLEAR"

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
