# How the US 202 Trail App Works

*Written 2026-07-16 as part of a codebase handoff review. Companion docs: `README.md`
(operational caveats, beacon programming, cloud accounts) and `REPORT.md` (handoff
review findings and setup instructions).*

## What this app is

A self-guided **trail tour app** for the **US-202 Parkway to Bradford Dam connector
trail** in Warrington Township / Chalfont, PA. It is the Android sibling of an existing
iOS app, and a successor to an earlier "Lions Pride Park" app by Chariot Solutions.

A hiker opens the app at the trailhead (Stump Road across from 785, Chalfont, PA) and
gets:

1. **Park Map** — a Google Map with the trail route drawn as a polyline and markers for
   every landmark/point of interest. Tapping a marker opens a bottom sheet with a photo
   and description.
2. **Trail Tours** — a guided walk. Pick the trail, a direction (Forward/Reverse), and a
   starting landmark; the tour screen then shows your current stop, the next stop, and
   walking-distance directions between them ("Continue 0.2 miles to...").
3. **Beacon detection** — physical Bluetooth beacons (RadBeacon E4) are mounted along
   the trail. When the phone gets close to one, the app automatically advances the tour
   to that landmark, zooms the map to it, and pops up its detail sheet. No GPS
   precision or user action needed.
4. **About / Settings** — static info page; a "Simplified Text" toggle (easier-reading
   landmark descriptions, an accessibility feature), plus a live list of beacons
   currently in range (useful for field-testing the hardware).

## The data model: everything comes from one JSON file

The app has **no local database and no backend of its own**. On launch it downloads a
single JSON file:

```
https://lionspride.chariotsolutions.cloud/us202/us202trail-v2.json
```

served from an S3 bucket (see README for the messy account-ownership history). The file
contains three top-level sections (mapped in `data/model/ConnectorData.kt`):

- **`site`** — the park boundary polygon, plus the **beacon UUID** and **major code**
  that identify this trail's beacon fleet.
- **`landmarks[]`** (17 today) — each with an `id`, name, category (`"Trail"` =
  trailhead vs. point of interest), coordinates, short + long descriptions, and an
  `imageName`. Images are fetched on demand from
  `https://lionspride.chariotsolutions.cloud/us202/images/<imageName>.jpg` (Coil).
- **`trails[]`** (1 today) — an ordered list of `boundaryCoordinates` tracing the trail
  path. Most entries are just lat/lng points for drawing the polyline; entries that
  also carry a `landmarkId` are **tour stops**, with human-written distance
  descriptions to the next stop in each direction (`distanceToNextClockwise*` /
  `distanceToNextCounterClockwise*` — shown as Forward/Reverse in the UI).

**Key invariant:** a landmark's `id` doubles as the beacon **minor code**. When the
scanner reports "beacon minor 7 is closest," the app looks up landmark id 7 directly.
That mapping is maintained by hand when programming beacons (see README §Beacon
Programming).

Content updates (new landmarks, reworded descriptions, photos) therefore require **no
app release** — just upload a new JSON/images to the bucket.

## How beacon detection works

- Hardware: RadBeacon E4 units along the trail broadcasting **AltBeacon** (Android) and
  **iBeacon** (iOS) frames with UUID `035a0617-...`, major `20` (this trail), minor =
  landmark id.
- `beacon/BeaconScanner.kt` wraps the [AltBeacon Android library]. It's a Hilt
  `@Singleton` shared by all screens. It ranges beacons in a `Region` filtered to the
  UUID + major code from the JSON, smooths RSSI with an `ArmaRssiFilter`, and exposes
  two `StateFlow`s:
  - `closestBeaconMinorCode: Int?` — minor of the nearest beacon (drives tour
    auto-advance and Park Map auto-popup),
  - `detectedBeacons: List<DetectedBeacon>` — all in-range beacons with distance
    estimates, sorted nearest first (drives the Settings diagnostic list).
- Reference counting (`activeConsumers`) lets multiple screens share one scan: scanning
  starts when the first screen appears and stops when the last disappears. Screens
  signal this via `onScreenActive()`/`onScreenInactive()` in `DisposableEffect`s.
- Scanning is **foreground-only** — there is no background scanning, no foreground
  service, and the phone must be on the relevant screen (Park Map, Tour, or Settings)
  for beacons to do anything.
- Distance is estimated from RSSI; "closest" flips can still happen at boundaries. The
  original park had densely packed beacons (a design driver for the distance sorting);
  on this trail they're far apart, so usually 0–1 beacons are in range.

## Architecture

Standard modern single-module Android app, ~2,100 lines of Kotlin:

- **UI:** 100% Jetpack Compose + Material 3. One activity (`MainActivity`), a bottom
  nav bar with four tabs, each tab a nested navigation graph
  (`navigation/AppNavHost.kt`). Portrait-locked. A first-run `WelcomeScreen`
  (gated by a `welcome_seen` SharedPreference) explains the permission prompts before
  the main UI appears.
- **DI:** Hilt. `di/AppModule.kt` provides Retrofit; `BeaconScanner` and
  `TrailRepository` are constructor-injected `@Singleton`s.
- **Data:** Retrofit + Gson fetch the JSON (`ConnectorApiService`);
  `TrailRepository` holds it **in memory only** and offers simple lookup getters.
  Each ViewModel calls `loadData()` in its `init`. There is no persistence — no
  network at launch means no trail data (see REPORT.md; this matters on a rural trail).
- **Maps:** [osmdroid] rendering OpenStreetMap tiles — **no API key, no Google
  dependency** (replaced Google Maps on 2026-07-18; the GCP-project/key saga in the
  README is history for Android). `ui/common/TrailMap.kt` is the shared map
  composable, an `AndroidView`-wrapped osmdroid `MapView`: camera auto-fit to the
  site boundary, polyline route, custom marker icons (trailhead / POI / current
  stop), optional "my location" overlay once fine-location permission is granted,
  and camera-follow behaviors used by the tour screen (`focusPosition` pans if the
  current stop is off-screen; `centerZoomPosition` zooms to a beacon hit). Tiles
  come from tile.openstreetmap.org (identified by package-name user agent, with the
  required "© OpenStreetMap contributors" overlay) and are cached on disk
  automatically — areas viewed once render offline afterwards. OSM's tile policy
  forbids bulk pre-downloading, so guaranteed-offline would mean bundling a
  self-built tile archive (MBTiles/pmtiles) in the APK — a documented follow-up,
  not done yet.
- **Per-tab ViewModels** (Hilt, scoped to the tab's nav graph so they survive
  navigation within a tab):
  - `ParkMapViewModel` — loads markers, listens to the scanner, and emits a navigation
    event when a new closest beacon appears so the screen opens that landmark's sheet.
  - `TrailToursViewModel` — shared by the list, detail, and tour screens in that tab;
    same load + scan pattern, re-emits beacon hits to the tour screen.
  - `SettingsViewModel` — the Simplified Text preference and the live beacon list.

### Screen flow

```
WelcomeScreen (first run only)
└─▶ Bottom nav
    ├─ Park Map ──── tap marker or beacon hit ──▶ LandmarkBottomSheet
    ├─ Trail Tours ─▶ TrailDetailScreen (direction + start pick)
    │                 └─▶ TrailTourScreen (Prev/Next buttons; beacon auto-advance)
    │                      └─ tap marker or beacon hit ──▶ LandmarkBottomSheet
    ├─ About (static)
    └─ Settings (Simplified Text toggle, nearby-beacon diagnostics, version)
```

### Tour mechanics (`TrailTourScreen`)

The tour is an index walk over the trail's stops (the `boundaryCoordinates` entries
with a `landmarkId`), in JSON order for Forward and reversed for Reverse. The screen
shows current stop, next stop, and the direction-appropriate distance description.
Prev/Next buttons move the index and open the new stop's sheet; a beacon hit jumps the
index to that landmark, opens its sheet, and zooms the map. The starting index comes
from (in priority order): a beacon already in range, the landmark picked on the detail
screen, or stop 0. The tour doesn't wrap at the ends (deliberate — commit "Don't wrap
the trail ends").

## Permissions

Declared in the manifest and requested at runtime the first time the Park Map shows:

- `ACCESS_FINE_LOCATION` — only to show the blue "my location" dot on the map (maps
  SDK requirement). Beacon scanning explicitly does **not** use location
  (`BLUETOOTH_SCAN` is declared with `neverForLocation`).
- `BLUETOOTH_SCAN` (Android 12+) — beacon ranging.
- `INTERNET` — data file + images.

Denying either permission degrades gracefully: no location dot / no beacon
auto-advance, but the map, content, and manual tour navigation all still work.

## Build & configuration

- Gradle 8.13 / AGP 8.13.2, Kotlin 2.0.21, JDK 17, compile/target SDK 36,
  **minSdk 31** (Android 12+ only — chosen to keep the Bluetooth permission story
  simple; excludes older phones).
- No API keys required (the Google Maps key requirement went away with the osmdroid
  swap); `local.properties` only needs `sdk.dir`.
- Debug build: `./gradlew assembleDebug` → `app/build/outputs/apk/debug/app-debug.apk`.
- No tests, no CI, no release signing config in-repo (release deploys go through the
  Play Store account saga described in the README).

## Simulating beacons in development

Debug builds include a `FakeBeaconReceiver` (in `app/src/debug/`, never compiled into
release — verified by inspecting the release APK manifest) that injects fake detections
into `BeaconScanner`, so all beacon-driven behavior works on the emulator. The
`simulate_beacon.sh` script at the repo root wraps it:

```bash
./simulate_beacon.sh 7          # near landmark 7 (1.0 m)
./simulate_beacon.sh 7 2.5      # ...at 2.5 m
./simulate_beacon.sh 7:2.5 8:10 # several beacons at once
./simulate_beacon.sh walk       # auto-walk stops 1..16, 8s each
./simulate_beacon.sh clear      # out of range of everything
```

While a simulation is active, real scan results are ignored (otherwise each empty scan
cycle would overwrite the fakes within a second); `clear` hands control back to the
radio. Two things to know: the closest-beacon flow dedupes, so re-sending the *same*
minor won't re-trigger the popup (send a different one in between, like real walking);
and leaving a beacon-consuming screen clears the injected state (same as real
detections), so re-send after navigating. For radio-level testing on a real phone, use
a transmitter app such as Beacon Scope (by the AltBeacon library's author) with an
AltBeacon layout, UUID `035a0617-0875-4cc7-a29c-be0caa8f557c`, major `20`,
minor = landmark id.

## Things that are intentionally simple (don't be surprised)

- No backend, no auth, no analytics, no crash reporting.
- No offline persistence of the JSON (in-memory only, refetched per ViewModel).
- Beacon scanning only in the foreground on specific screens.
- One trail today; the code supports multiple trails in the JSON (`trails[]` is a
  list, and the Trail Tours screen renders a card per trail).
- The `NavRoutes.PARK_MAP_DETAIL` / `SETTINGS_DETAIL` routes are defined but unused —
  leftovers from an earlier navigation design.
