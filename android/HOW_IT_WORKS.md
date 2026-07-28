# How the Warrington Parks & Trails App Works

*Written 2026-07-16 as part of a codebase handoff review. Companion docs: `README.md`
(operational caveats, beacon programming, cloud accounts) and `REPORT.md` (handoff
review findings and setup instructions).*

## What this app is

A self-guided **trail tour app** covering **two locations**: **Lions Pride Park** and
the **US-202 Parkway to Bradford Dam connector trail**, both in Warrington Township /
Chalfont, PA. It is the Android sibling of an existing iOS app (which still targets the
US202 trail only), and a successor to an earlier standalone "Lions Pride Park" app by
Chariot Solutions — the two apps were merged into this one app in July 2026.

A visitor opens the app, sees both locations' addresses on the Welcome screen, and
gets:

1. **Park Map** — a map with every landmark/point of interest from *both* locations
   plotted, and every trail (four polylines total, across the two locations) drawn as a
   route. Tapping a marker opens a bottom sheet with a photo and description.
2. **Trail Tours** — a guided walk, with trails grouped under a header for their
   location. Pick a trail, a direction (Forward/Reverse), and a starting landmark; the
   tour screen then shows your current stop, the next stop, and walking-distance
   directions between them ("Continue 0.2 miles to...").
3. **Beacon detection** — physical Bluetooth beacons (RadBeacon E4) are mounted at both
   locations. When the phone gets close to one, the app automatically advances the tour
   to that landmark, zooms the map to it, and pops up its detail sheet. No GPS
   precision or user action needed, and it doesn't matter which location's beacon it is
   — detections from both locations are merged into one "closest" result.
4. **About / Settings** — static info page listing both locations' addresses; a
   "Simplified Text" toggle (easier-reading landmark descriptions, an accessibility
   feature), plus a live list of beacons currently in range across both locations
   (useful for field-testing the hardware).

## The data model: everything comes from one JSON file, covering both locations

The app has **no local database and no backend of its own**. On launch it downloads a
single JSON file:

```
https://trails.warringtoneac.org/warrington-trails.json
```

served from GitHub Pages (see README for the hosting/DNS setup and the messy
account-ownership history). The file contains four top-level sections (mapped in
`data/model/TrailsData.kt`):

- **`beaconUUID`** — the single beacon UUID shared by every beacon at both locations.
- **`locations[]`** (2 today: Lions Pride Park and US202 to Bradford Dam) — each with an
  `id`, name, address, and its own **beacon major code** (17 for Lions Pride, 20 for
  US202). This is the one place the data (and `TrailRepository`) distinguish the two
  locations.
- **`landmarks[]`** (40 today, across both locations) — each with an `id`, a `location`
  (which of the two locations it belongs to), name, category, coordinates, short + long
  descriptions, and an `imagePath`. Landmark ids are unique across both locations (US202
  uses 1–16 and 4001; Lions Pride uses 1002–3008), so a bare id is still enough to look
  one up. Images are fetched on demand from
  `https://trails.warringtoneac.org/<imagePath>` (Coil).
- **`trails[]`** (4 today, across both locations) — each tagged with a `location`, with
  an ordered list of `boundaryCoordinates` tracing that trail's path. Most entries are
  just lat/lng points for drawing the polyline; entries that also carry a `landmarkId`
  are **tour stops**, with human-written distance descriptions to the next stop in each
  direction (`distanceToNextClockwise*` / `distanceToNextCounterClockwise*` — shown as
  Forward/Reverse in the UI).

**Key invariant:** a landmark's `id` doubles as the beacon **minor code**, and ids are
unique across both locations. When the scanner reports "beacon minor 7 is closest," the
app looks up landmark id 7 directly — it doesn't need to know which location the beacon
belongs to. That mapping is maintained by hand when programming beacons (see README
§Beacon Programming).

Content updates (new landmarks, reworded descriptions, photos, for either location)
therefore require **no app release** — just push a change to `server/` in the monorepo
(auto-deployed to GitHub Pages). Note that the iOS app still reads the old
`us-202/us202trail-v2.json` file directly, so a US202 data edit currently has to be made
in both files until iOS migrates to `warrington-trails.json`.

## How beacon detection works

- Hardware: RadBeacon E4 units at both locations broadcasting **AltBeacon** (Android)
  and **iBeacon** (iOS) frames, all sharing UUID `035a0617-...`; the major code is
  per-location (`17` Lions Pride, `20` US202), and minor = landmark id.
- `beacon/BeaconScanner.kt` wraps the [AltBeacon Android library]. It's a Hilt
  `@Singleton` shared by all screens. Rather than a single `Region`, it ranges **one
  AltBeacon region per location** (same UUID, each location's own major code, built
  from `TrailRepository.getBeaconRegions()`), smooths RSSI with an `ArmaRssiFilter`, and
  exposes two `StateFlow`s:
  - `closestBeaconMinorCode: Int?` — minor of the nearest beacon **across all regions**
    (drives tour auto-advance and Park Map auto-popup),
  - `detectedBeacons: List<DetectedBeacon>` — all in-range beacons from every region,
    with distance estimates, sorted nearest first (drives the Settings diagnostic
    list).
  Because AltBeacon delivers range results per region on its own schedule, the scanner
  accumulates the latest result per region (`detectionsByRegion`, keyed by region id)
  and merges across regions on every callback (`mergeDetections`/`accumulateAndMerge`)
  — otherwise an empty ranging cycle for one location's region would wipe out a live
  detection from the other location's region.
- Reference counting (`activeConsumers`) lets multiple screens share one scan: scanning
  starts when the first screen appears and stops when the last disappears. Screens
  signal this via `onScreenActive()`/`onScreenInactive()` in `DisposableEffect`s.
- Scanning is **foreground-only** — there is no background scanning, no foreground
  service, and the phone must be on the relevant screen (Park Map, Tour, or Settings)
  for beacons to do anything.
- Distance is estimated from RSSI; "closest" flips can still happen at boundaries, now
  including flips between the two locations' beacons if someone is (implausibly) in
  range of both at once. Lions Pride Park had densely packed beacons (a design driver
  for the distance sorting); on the US202 trail they're far apart, so usually 0–1
  beacons are in range there.

## Architecture

Standard modern single-module Android app, ~2,100 lines of Kotlin:

- **UI:** 100% Jetpack Compose + Material 3. One activity (`MainActivity`), a bottom
  nav bar with four tabs, each tab a nested navigation graph
  (`navigation/AppNavHost.kt`). Portrait-locked. A first-run `WelcomeScreen`
  (gated by a `welcome_seen` SharedPreference) explains the permission prompts before
  the main UI appears.
- **DI:** Hilt. `di/AppModule.kt` provides Retrofit; `BeaconScanner` and
  `TrailRepository` are constructor-injected `@Singleton`s.
- **Data:** Retrofit + Gson fetch the JSON (`TrailsApiService`); `TrailRepository`
  holds it **in memory only** and offers simple lookup getters
  (`getLandmarks()`/`getLandmarkById()`, `getTrails()`/`getTrailById()`,
  `getLocations()`, `getTrailsByLocation()` for the Trail Tours location headers,
  `getBeaconRegions()` for the scanner, `getCombinedBounds()`/`getBoundsForTrail()` for
  the map, `imageUrlFor()`). **`TrailRepository` is the one class in the app that knows
  the data covers more than one location** — every screen otherwise sees a single flat
  set of landmarks and trails. Each ViewModel calls `loadData()` in its `init`. There is
  no persistence — no network at launch means no trail data (see REPORT.md; this
  matters on a rural trail).
- **Maps:** [osmdroid] rendering OpenStreetMap tiles — **no API key, no Google
  dependency** (replaced Google Maps on 2026-07-18; the GCP-project/key saga in the
  README is history for Android). `ui/common/TrailMap.kt` is the shared map
  composable, an `AndroidView`-wrapped osmdroid `MapView`: camera auto-fit to the
  combined bounds of both locations, **one polyline per trail (four today, across the
  two locations)**, markers for all 40 landmarks from both locations with custom icons
  (trailhead / POI / current stop), optional "my location" overlay once fine-location
  permission is granted, and camera-follow behaviors used by the tour screen
  (`focusPosition` pans if the current stop is off-screen; `centerZoomPosition` zooms
  to a beacon hit). Tiles come from tile.openstreetmap.org (identified by package-name
  user agent, with the required "© OpenStreetMap contributors" overlay) and are cached
  on disk automatically — areas viewed once render offline afterwards. OSM's tile
  policy forbids bulk pre-downloading, so guaranteed-offline would mean bundling a
  self-built tile archive (MBTiles/pmtiles) in the APK — a documented follow-up, not
  done yet.
- **Per-tab ViewModels** (Hilt, scoped to the tab's nav graph so they survive
  navigation within a tab):
  - `ParkMapViewModel` — loads markers (all 40, both locations), listens to the
    scanner, and emits a navigation event when a new closest beacon appears so the
    screen opens that landmark's sheet, regardless of which location it belongs to.
  - `TrailToursViewModel` — shared by the list, detail, and tour screens in that tab;
    same load + scan pattern, re-emits beacon hits to the tour screen. The list screen
    groups trails under a header per location (via
    `TrailRepository.getTrailsByLocation()`) instead of one flat list.
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
into `BeaconScanner`, so all beacon-driven behavior works on the emulator, for either
location's landmark ids. The `simulate_beacon.sh` script in `android/` wraps it:

```bash
./simulate_beacon.sh 7                  # near US202 landmark 7 (1.0 m)
./simulate_beacon.sh 7 2.5              # ...at 2.5 m
./simulate_beacon.sh 7:2.5 1002:10      # several beacons at once, even across locations
./simulate_beacon.sh walk               # auto-walk US202 stops 1..16, 8s each
./simulate_beacon.sh clear              # out of range of everything
```

Landmark ids: US202 uses 1–16 (trail stops) and 4001 (trailhead); Lions Pride Park uses
1002–3008. While a simulation is active, real scan results are ignored (otherwise each
empty scan cycle would overwrite the fakes within a second); `clear` hands control back
to the radio. Two things to know: the closest-beacon flow dedupes, so re-sending the
*same* minor won't re-trigger the popup (send a different one in between, like real
walking); and leaving a beacon-consuming screen clears the injected state (same as real
detections), so re-send after navigating. For radio-level testing on a real phone, use
a transmitter app such as Beacon Scope (by the AltBeacon library's author) with an
AltBeacon layout, UUID `035a0617-0875-4cc7-a29c-be0caa8f557c`, major `17` (Lions Pride)
or `20` (US202), minor = landmark id.

## Things that are intentionally simple (don't be surprised)

- No backend, no auth, no analytics, no crash reporting.
- No offline persistence of the JSON (in-memory only, refetched per ViewModel).
- Beacon scanning only in the foreground on specific screens.
- Four trails today, across two locations; the code supports any number of trails or
  locations in the JSON (`trails[]` and `locations[]` are both lists, and the Trail
  Tours screen renders a card per trail, grouped under a header per location).
- The `NavRoutes.PARK_MAP_DETAIL` / `SETTINGS_DETAIL` routes are defined but unused —
  leftovers from an earlier navigation design.
