#!/usr/bin/env bash
#
# Fake a trail beacon on a booted iOS simulator running a DEBUG build of the app.
# (Backed by the bradfordtrail:// URL handler, which only exists in debug builds.)
#
# Usage:
#   ./simulate_beacon.sh <minor> [distance-meters]   # one beacon (minor = landmark id)
#   ./simulate_beacon.sh clear                       # walk out of range
#   ./simulate_beacon.sh walk [seconds-per-stop]     # auto-walk landmarks 1..16 (Ctrl-C stops)
#
# Landmark ids in the current data file: 1-16 (trail stops) and 4001 (trailhead).
# Note: opening a URL briefly foregrounds the app if it was backgrounded.
set -euo pipefail

usage() { sed -n '3,10p' "$0" | sed 's/^# \{0,1\}//'; exit 1; }

send_one() { # minor [distance]
    xcrun simctl openurl booted "bradfordtrail://fakebeacon?minor=$1&distance=${2:-1.0}"
    echo "faked beacon: landmark $1 at ${2:-1.0} m"
}

case "${1:-}" in
    "" ) usage ;;
    clear )
        xcrun simctl openurl booted "bradfordtrail://fakebeacon/clear"
        echo "cleared all fake beacons"
        ;;
    walk )
        for minor in $(seq 1 16); do
            send_one "$minor" 2.0
            sleep "${2:-8}"
        done
        xcrun simctl openurl booted "bradfordtrail://fakebeacon/clear"
        echo "walk finished, beacons cleared"
        ;;
    * )
        send_one "$1" "${2:-}"
        ;;
esac
