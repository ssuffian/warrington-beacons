# Handoff Review — US 202 Trail App (Android)

*Prepared overnight 2026-07-16/17. Read `HOW_IT_WORKS.md` first for the architecture
walkthrough; this file covers review findings, local setup, and what needs your
attention. Verification status of each item is marked honestly — anything not yet
verified on the emulator is labeled.*

## TL;DR

- **What it is:** a small, clean Jetpack Compose app (~2,100 LOC) that guides hikers
  along the US-202→Bradford Dam trail with a Google Map, guided "tours," and Bluetooth
  beacons that auto-advance the tour as you walk. Content comes from one JSON file on
  S3/CloudFront; there is no backend to run.
- **State:** genuinely close to done. Code quality is good for its size. The README's
  own TODO list is accurate: the remaining work is *operational* (accounts, keys, field
  test, Play Store), not engineering.
- **I built it locally on your machine successfully** and fixed a handful of real bugs
  (details below), the worst being an app crash when opening Settings with no network —
  exactly the situation you'd hit on the trail.
- **Blockers only you can resolve:** the Google Maps API key, and the accounts saga
  (Play Store access, S3 bucket ownership) described in the README.

## How to run it on your machine

Your machine already has everything: JDK 17 (Zulu), Android SDK at
`~/Library/Android/sdk`, Android Studio, and a `Pixel_6_API_33` emulator.

```bash
cd ~/projects/warrington/us202-android

# 1. Build (I already did this once; ~3 min cold, seconds warm)
./gradlew assembleDebug

# 2. Start the emulator (or just open the project in Android Studio and press Run)
~/Library/Android/sdk/emulator/emulator -avd Pixel_6_API_33 &

# 3. Install + launch
~/Library/Android/sdk/platform-tools/adb install -r app/build/outputs/apk/debug/app-debug.apk
~/Library/Android/sdk/platform-tools/adb shell am start -n org.warringtontownship.us202.android/.MainActivity
```

I created `local.properties` for you (git-ignored) with `sdk.dir` set. **No API keys
are needed** — on 2026-07-18 the map was switched from Google Maps to
osmdroid/OpenStreetMap (see HOW_IT_WORKS.md §Architecture), which eliminated the
`MAPS_API_KEY` requirement entirely.

Useful debug loop: `adb logcat -s BeaconScanner ParkMapVM SettingsVM AndroidRuntime`
shows the app's own log tags.

**Simulating beacons** (added 2026-07-18): debug builds ship a fake-beacon injector, so
beacon behavior is testable on the emulator — `./simulate_beacon.sh 7` puts you "near"
landmark 7, `walk` auto-walks the whole trail, `clear` walks away. See
HOW_IT_WORKS.md §"Simulating beacons in development". Verified on the emulator: the
Park Map auto-popup, the Settings "Nearby Landmarks" list (multi-beacon, sorted by
distance), and clear all work; the release APK contains no trace of the receiver. For
radio-level testing before the field test, broadcast AltBeacon from a second Android
phone (e.g. the "Beacon Scope" app) with UUID `035a0617-0875-4cc7-a29c-be0caa8f557c`,
major 20, minor = a landmark id (1–16, 4001 = trailhead).

## Things you need to figure out (can't be solved from the code)

1. ~~**Google Maps API key**~~ — **resolved 2026-07-18**: the map now uses
   osmdroid/OpenStreetMap, so the Android app no longer needs the "Lions Pride
   Android Maps" GCP project (owned by Russ Diamond, his credit card on file) at
   all. Steve plans the same change on iOS; once done, that GCP project can be
   retired.
2. **Play Store access** — "Warrington Parks" account owned by Andy Oles; Aaron's
   access expired (README says he emailed Andy). Needed to ship anything.
3. **Release signing** — no keystore/signing config in the repo. Find out whether an
   upload key already exists (from whoever built previous releases) or whether the Play
   listing uses Google Play App Signing and you can enroll a new upload key.
4. **S3/CloudFront hosting** — data + images live in Chariot Solutions' sandbox AWS
   account (bucket `lionspride.chariotsolutions.cloud`). The README itself says this
   should move to a Warrington-owned account. Until then, content updates go through
   whoever has Chariot access, and the app is one bucket-deletion away from an empty
   map (mitigated somewhat by the offline cache I added — see fixes).
5. **The beacon programming key** (`lions-pride-beacon-key.r12`) is "ask Aaron Mulder"
   — worth getting a copy now while he's reachable, or you can never reprogram/replace
   beacons.
6. **Field test** — the README's top TODO. Beacon spacing/RSSI behavior can only be
   validated on the trail.

## Bugs found and fixed (all in this working tree, not committed)

1. **Crash: opening Settings with no network** — `SettingsViewModel` ran
   `trailRepository.loadData()` in a coroutine with no try/catch; any network failure
   crashed the app (uncaught exception in `viewModelScope`). The other two ViewModels
   had the try/catch; this one was missed. *Fixed; crash confirmed and re-tested on
   emulator — see Verification below.*
2. **Beacon scanning could be stopped by the wrong screen** — `BeaconScanner` used a
   bare int refcount, but every ViewModel calls `stopScanning()` unconditionally on
   screen-hide *and again* in `onCleared()`, even if it never successfully started
   (e.g. data hadn't loaded yet). One screen could decrement another screen's count and
   kill its scan — the same class of tab-switching bug commit `75748dc` fought before.
   *Fixed by keying consumers by name (a set instead of a counter), making start/stop
   idempotent per screen.*
3. **No offline tolerance** — the trail JSON was fetched fresh by every ViewModel and
   never cached, so no signal at the trailhead = empty app (and the README's top TODO
   is to test on the actual trail). *Fixed: OkHttp disk cache (10 MB) + an interceptor
   that serves the cached copy when the network is unreachable. The server sends
   `ETag`/`Last-Modified`, so online requests revalidate cheaply. Side effect: the JSON
   is now also fetched once per process instead of three times at startup
   (`TrailRepository.loadData()` now no-ops after first success). Content edits to the
   JSON now show up on next app cold start, not next screen visit — I judged that
   acceptable for a trail app; flag if you disagree.*
4. **Two data-dependent crash risks** — `TrailRepository.getFirstTrail()` used
   `.first()` (throws if `trails` is empty in the JSON) and `TrailTourScreen` indexed
   `stops[currentIndex]` with no guard for a trail with zero landmark stops. *Fixed:
   `firstOrNull()` and an empty-stops message screen.*

Nothing else was changed. Notably I did **not** touch: the duplicate AltBeacon parser
registration in `BeaconScanner.init` (the library already includes that layout by
default; harmless, and the current behavior is field-proven), or the permission-request
flow (see nits).

## Known limitations / nits (not fixed — your call, some need decisions)

- **No tests, no CI.** The project has zero test code. If you plan to keep developing,
  a small JVM test setup around `TrailRepository`/tour-index logic would pay for
  itself. (Decision for morning: worth the setup?)
- **Trail Tours screen has `isLoading`/`error` state that the UI never renders** — on a
  slow fetch the list is just empty with no spinner; on failure, no message or retry
  button. Leaving the tab and returning retries. Cosmetic but worth doing before
  launch. (Needs a small UX decision, so left alone.)
- **Beacon scanning starts before the `BLUETOOTH_SCAN` permission dialog is answered**
  on first run (Park Map requests it, but `onScreenActive` fires first). The AltBeacon
  library tolerates this and later scan cycles pick up after grant, but if the user
  denies, there's no explanation or re-prompt anywhere. Also only the Park Map screen
  requests it — fine today because it's the start tab, but fragile.
- **`minSdk 31`** excludes Android 11 and older phones (~15–20% of active devices).
  Probably intentional (Android 12+ Bluetooth permission model is much simpler) —
  confirm it's acceptable for a public park app.
- **Gson + non-null Kotlin fields**: if a future JSON edit drops a required field, Gson
  will happily create objects with null in non-null fields and crash at first use.
  Moshi/kotlinx-serialization would fail fast; low priority while the JSON is stable.
- The welcome/About screens are near-duplicates of each other by design (About = the
  welcome text, revisitable).
- `NavRoutes.PARK_MAP_DETAIL` / `SETTINGS_DETAIL` are dead code (unused routes).
- `versionCode = 1` / `versionName = "2026.2.8"` — remember to bump for any Play upload.

## Verification status (all done on the Pixel_6_API_33 emulator)

- `./gradlew assembleDebug` — **passed**, before and after my changes (my first
  attempt failed only because a sandboxed shell blocked Gradle's network; nothing
  wrong with the project).
- **Settings offline crash — reproduced, then fix verified.** With the pre-fix build
  in airplane mode, tapping the Settings tab produced `FATAL EXCEPTION: main` and the
  process was killed. With the fixed build under identical conditions, Settings
  renders normally and logcat shows the caught exception
  (`SettingsVM: Unable to load beacon config — HTTP 504 Unsatisfiable Request
  (only-if-cached)` — i.e. the offline interceptor fell back to a not-yet-populated
  cache and the try/catch contained it).
- **Happy-path smoke test — passed** (fixed build, online): welcome screen →
  Continue → Park Map (blank tiles as expected with no Maps key) → Trail Tours list
  ("202 Connector Trail, 17 Points of Interest") → detail (Forward/Reverse, "Starting
  at: 202 Connector Trail") → Start Tour → tour shows "Current: 202 Connector Trail /
  Next: Bluebird and cavity nesting bird program / 319 yards…", Previous disabled at
  the first stop → Next advances and opens the landmark bottom sheet with the full
  description. Both runtime permission dialogs (location, nearby devices) appear and
  granting them works.
- **Offline cache — verified**: after one online run, enabling airplane mode and
  cold-starting the app still shows the full trail list, served from the new OkHttp
  cache. Before the fix this scenario showed an empty app.
- **OpenStreetMap swap — verified on the emulator (2026-07-18)**: tiles render with
  no API key (real Warrington streets, trail polyline, all markers, OSM attribution
  overlay); bounds auto-fit works; marker tap opens the landmark sheet; a fake
  beacon on the tour screen zooms the map and highlights the stop; and after one
  online view, an airplane-mode cold start renders the full map from the tile
  cache. Not yet done: bundling tiles in the APK for guaranteed offline on
  never-online devices (OSM policy forbids bulk pre-download from their servers;
  needs a self-built MBTiles/pmtiles archive — good follow-up task).
- Beacon-driven behavior is testable on the emulator via `./simulate_beacon.sh`
  (see above); real-radio behavior still needs a physical phone / the field test.
- Changes are **uncommitted** in the working tree (11 files, +277/−153) so you can
  review with `git diff` first thing.
