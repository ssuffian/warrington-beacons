# How Warrington Talking Trails for iOS Works

*Originally written during the 2026 handoff and updated for the combined app.
`REPORT.md` preserves the earlier review history.*

## Current app

The `main` branch contains one app covering Lions Pride Park and the US-202 to
Bradford Dam Trail. Its user-visible name is **Warrington Talking Trails** and it
updates the existing Lions Pride Park listing with bundle ID
`org.warringtontownship.lionspride`.

## What the app does

Same product as the Android sibling: a self-guided trail tour app. Park Map tab with
the trail route and landmark pins; Trail Tours (pick trail → direction → guided tour
with distance descriptions); physical **iBeacons** along the trail auto-advance the
tour and pop up landmark details; About and Settings (Simplified Text) tabs. Debug
builds add a fifth **Beacons** tab listing every beacon in range with distances
(the iOS equivalent of the Android app's Settings diagnostic list).

## The data

Each location has a JSON file and images folder on the project's GitHub Pages site:

```
https://trails.warringtoneac.org/us-202/us202trail-v2.json
https://trails.warringtoneac.org/lions-pride-park/lionsPrideData.json
```

The base URL lives in `Info.plist` under `base_url_string` (read by
`Service/Utils.swift`). The JSON decodes into `Model/` structs (`WarringtonTalkingTrailsData` =
`site` + `landmarks[]` + `trails[]`), mirroring the Android models. Landmark `id`
doubles as the beacon **minor** value. Fetching happens once at startup in
`MainView.loadData()` — revalidating with the server when online (ETag 304s), falling
back to the cached copy offline.

## Architecture (originally 2020 SwiftUI, modernized 2026-07-18, deployment target iOS 17)

Originally built for iOS 13 in early SwiftUI; fully modernized on 2026-07-18:
- **App entry** is the SwiftUI `App` lifecycle —
  `@main struct WarringtonTalkingTrailsApp: App` in
  `WarringtonTalkingTrailsApp.swift` (the UIKit `AppDelegate`/`SceneDelegate` were removed).
  `UserData.shared` is injected into the environment here.
- **State** uses the Observation framework: `UserData` is `@Observable` (not the old
  `ObservableObject`/`@Published`), read via `@Environment(UserData.self)` and, where
  bindings are needed, `@Bindable`. Note: because `landmarkService` is a plain global,
  the map/list views read `userData.initialized` so they re-render when trail data
  finishes loading (with `@Observable`, a view only invalidates on properties it reads).
- **Navigation** is `NavigationStack` + `navigationDestination(isPresented:)`.
- **Remote images** use SwiftUI's built-in `AsyncImage`; the third-party `URLImage`
  dependency was removed — the app now has **zero third-party dependencies**.
- Dead iOS 13/14 workaround branches deleted.

The maps remain `UIViewRepresentable`-wrapped MapKit (the correct approach — SwiftUI's
`Map` still doesn't cover the custom annotation/overlay/camera control this app needs).

- **Entry:** `WarringtonTalkingTrailsApp` (SwiftUI `App`) hosting `MainView`, a `TabView` with
  the four (five in debug) tabs. Splash is a SwiftUI view on a 2s timer, then the
  welcome screen (first launch only), then the tabs.
- **State:** `UserData.shared` — a single `@Observable` class injected via
  `.environment()`. Its own comment says it best: *"acting like a state machine…
  confusing AF and could be improved."* It holds the selected/nearby/tour landmarks,
  tour direction, and flags like `parkMapVisible`/`isTrailTour` that route beacon
  events to whichever screen is showing.
- **Services (singletons):** `LandmarkService` (in-memory indexes over the JSON:
  by-id, by-name, by-category, trail spans), `MapService` (pure trail-walking logic:
  next-landmark, distances, on-trail checks — this is what the unit tests cover),
  `BeaconScanner`, `NotificationService` (local notifications for "nearby point of
  interest" / tour progress; alerts shown only under VoiceOver, otherwise just a
  sound), `BluetoothService` (exists to trigger the system "turn on Bluetooth"
  prompt), `AccessibilityService`.
- **Maps: Apple MapKit** (`MKMapView` wrapped in `UIViewRepresentable`) — **no API
  key, no Google dependency, nothing to configure.** `MainMapView` (park map,
  camera-bounded to the park), `TrailMapView` (detail preview), `TrailTourMapView`
  (tour, with an `ArrowRenderer` that can draw direction arrows on the polyline —
  currently the arrows overlay is commented out). Landmark pins are
  `MKMarkerAnnotationView`s with SF Symbols glyphs.
- **Images:** SwiftUI's built-in `AsyncImage` (loads landmark photos from the images
  URL; caches via URLSession's shared cache). No third-party image library.

### Beacon detection (`Service/BeaconScanner.swift`)

iOS ranges **iBeacon** natively through CoreLocation (the RadBeacon E4 units on the
trail broadcast both iBeacon for iOS and AltBeacon for Android):

- Constraints come from each downloaded JSON file's `site` section. Both locations
  use iBeacon UUID `035a0617-0875-4cc7-a29c-be0caa8f557c`; Lions Pride uses major
  `17` and US-202 uses major `20`.
- Ranging runs only while the Park Map, an active tour, or the debug Beacons tab is
  showing (start/stop in `onAppear`/`onDisappear`). Requires when-in-use location
  permission; a denial shows an alert pointing to Settings.
- Debouncing, tuned for the original densely-beaconed park: a beacon must be within
  ~30m estimated accuracy (the "Update sensitivity" commit — was proximity
  near/immediate), seen **3+ times**, different from the last-notified beacon, and
  not notified in the last **60s**, before the app reacts.
- Reaction goes through `UserData.updateLocation(beacon:)`: on the park map it
  selects the landmark + fires a local notification; on a tour it advances the tour
  and notifies with the next distance description.

## Permissions

Location when-in-use (position dot + beacon ranging — on iOS beacon ranging **is** a
location feature, unlike Android's `neverForLocation` Bluetooth split), Bluetooth
usage strings, and notification authorization (requested at first
`NotificationService` use). All prompts appear on first run.

## Build & run

- Xcode: open `WarringtonTalkingTrails.xcodeproj`, scheme `WarringtonTalkingTrails`, run on any iOS 17+
  simulator. No keys, no config files, no signing needed for the simulator. CLI:

  ```bash
  xcodebuild -project WarringtonTalkingTrails.xcodeproj -scheme WarringtonTalkingTrails \
    -destination 'platform=iOS Simulator,name=iPhone 16' build
  xcodebuild test -project WarringtonTalkingTrails.xcodeproj -scheme WarringtonTalkingTrails \
    -destination 'platform=iOS Simulator,name=iPhone 16'
  ```

- Tests: `WarringtonTalkingTrailsTests` (unit — `MapServiceTest` covers trail-walking logic) and
  `WarringtonTalkingTrailsUITests` (a full walkthrough smoke test added 2026-07-18: welcome →
  park map pins → trail list → detail → tour; it doubles as proof the remote JSON
  loads and decodes).
- Device and App Store builds use the Warrington Township team (`ZA7MADZY65`)
  and update the existing Lions Pride Park app record.

## Simulating beacons in development

Debug builds can fake beacon detections on the simulator (added 2026-07-18), the iOS
counterpart to the Android fake-beacon injector. The seam: `BeaconScanner` now works
in terms of a plain `RangedBeacon` value type instead of the un-constructible
`CLBeacon`, so detections can be injected directly. A debug-only
`warringtontalkingtrails://` URL handler (registered in `Info.plist`, dispatched from
the SwiftUI app's `.onOpenURL`, and handled by
`FakeBeacon` in `BeaconScanner.swift`) drives it. Use the `simulate_beacon.sh` script
at the repo root:

```bash
./simulate_beacon.sh 7          # near landmark 7 (1.0 m)
./simulate_beacon.sh 7 2.5      # ...at 2.5 m
./simulate_beacon.sh walk       # auto-walk stops 1..16, 8s each
./simulate_beacon.sh clear      # out of range of everything
```

Behavior notes:
- Works only on a **booted simulator** running a **debug** build. It resolves to
  `xcrun simctl openurl booted warringtontalkingtrails://fakebeacon?minor=<id>&distance=<m>`.
- **First send may show an "Open in Warrington Talking Trails?" prompt** — that's iOS's
  confirmation when a URL targets the already-frontmost app; tap Open. Sending while
  the app is backgrounded delivers cleanly and foregrounds it.
- Injection is one beacon at a time (matching how iOS ranges a nearest beacon) and
  bypasses the seen-count / 60s cooldown debounce on purpose — dev loops shouldn't
  wait a minute. The debounce still governs the real radio path.
- Landmark ids: 1–16 (stops), 4001 (trailhead).
- **Release safety:** the `FakeBeacon` handler and injection methods are wrapped in
  `#if DEBUG` — verified absent from the release binary (0 symbols). The
  `warringtontalkingtrails` URL-scheme *declaration* in `Info.plist` is static and remains in
  all configs, but it's inert in release with no handler compiled in. (To strip the
  declaration too, enable `INFOPLIST_PREPROCESS` and gate it with `#if DEBUG` — a
  follow-up, not done.)

For **radio-level** testing before the field test, a second phone broadcasting
**iBeacon** (UUID `035a0617-0875-4cc7-a29c-be0caa8f557c`, major `20`, minor = landmark
id) via the Beacon Scope app exercises the real CoreLocation path on device.
