# One app, all trail points — design

Date: 2026-07-27
Scope: Android app. iOS gets its own spec afterward, reusing the same data file.

## Goal

Today the Android app shows only the US202 to Bradford Dam trail; Lions Pride
Park's 23 landmarks and 3 trails live in a data file nothing reads. Merge both
sets into the single surviving app so one map shows every point, and rename the
app to match its wider scope.

Lions Pride Park's beacons are still installed and broadcasting, and its data is
accurate as-is. No content revision is needed.

## Why this is cheap

The two hosted data files already share a schema, share a beacon UUID
(`035a0617-0875-4cc7-a29c-be0caa8f557c`), and have no landmark-ID collisions
(Lions Pride uses 1002–3008, US202 uses 1–16 plus 4001). Lions Pride Park also
sits geographically *inside* the US202 trail's bounding box, so a single fitted
map camera shows both without any two-island problem.

## Data format

One hand-edited file, `server/warrington-trails.json`, becomes the source of
truth:

```json
{
  "beaconUUID": "035a0617-0875-4cc7-a29c-be0caa8f557c",
  "locations": [
    { "id": "lions-pride-park",
      "name": "Lions Pride Park",
      "address": "3129 Bradley Rd, Warrington, PA 18976",
      "beaconMajorCode": 17 },
    { "id": "us-202",
      "name": "US202 to Bradford Dam",
      "address": "Stump Road across from 785, Chalfont, PA 18914",
      "beaconMajorCode": 20 }
  ],
  "landmarks": [
    { "id": 1002,
      "location": "lions-pride-park",
      "imagePath": "lions-pride-park/images/Yellow_trail.jpg",
      "coordinates": { "latitude": 40.24613, "longitude": -75.177778 },
      "name": "Yellow Trail",
      "category": "Trail",
      "description": "...",
      "longDescription": "...",
      "imageAlt": "Picture of Yellow Trail",
      "isOpen": false,
      "trailDistanceDescription": "..." }
  ],
  "trails": [
    { "id": 1002,
      "location": "lions-pride-park",
      "name": "Yellow Trail",
      "isOpen": false,
      "trailDistanceDescription": "...",
      "boundaryCoordinates": [ { "latitude": …, "longitude": …,
                                 "landmarkId": 1002,
                                 "distanceToNextClockwise": "...", … } ] }
  ]
}
```

Differences from the current per-site format, and why:

* **No `site` object, no per-site nesting.** `landmarks` and `trails` are flat
  lists carrying a `location` key. The app then does no flattening at all.
* **`site.boundaryCoordinates` is dropped.** It was used for exactly one thing —
  `zoomToBoundingBox` on the map camera — and never drawn. Combined bounds are
  computed from landmark and trail coordinates; per-trail bounds from that
  trail's own points.
* **`site.imageBaseUrl` is dropped** in favour of a per-landmark `imagePath`
  resolved against the domain root. The photos stay exactly where they are in
  `server/lions-pride-park/images/` and `server/us-202/images/` — no moves, no
  duplication.
* **`beaconUUID` moves to the top level** (both locations share it).
* **`beaconMajorCode` stays per location**, in the `locations` lookup rather than
  repeated on every landmark: it is a property of the installation, and the app
  derives its scan regions from the distinct set.
* `landmarks[].id` doubles as the beacon minor code, unchanged from today.

### Legacy files

`server/us-202/us202trail-v2.json` must keep being served at its current URL:
the shipped iOS "202 Connector" app reads it. It and
`server/lions-pride-park/lionsPrideData.json` freeze in place as legacy copies
and stop being the source of truth. Until the iOS migration lands, a data edit
has to be made in both `warrington-trails.json` and `us202trail-v2.json`; the
README will say so. Data changes are rare and the iOS spec is next.

There is no shipped Android app, so nothing else depends on the old format.

## Android changes

### Data layer

* `data/model/ConnectorData.kt` → `TrailsData.kt`:
  ```kotlin
  data class TrailsData(
      val beaconUUID: String,
      val locations: List<Location>,
      val landmarks: List<Landmark>,
      val trails: List<Trail>,
  )
  data class Location(val id: String, val name: String, val address: String, val beaconMajorCode: Int)
  ```
  `Landmark` and `Trail` each gain `location: String`; `Landmark` swaps
  `imageName` for `imagePath`. `Site` is deleted.
* `data/network/ConnectorApiService.kt` → `TrailsApiService`, `@GET("warrington-trails.json")`.
* `di/AppModule.kt`: Retrofit base URL becomes `https://trails.warringtoneac.org/`.
  The offline cache interceptor is unchanged.
* `TrailRepository` is the only place that knows locations exist:
  * `getLandmarks()` / `getTrails()` — return the lists as parsed.
  * `getLandmarkById(id)` / `getTrailById(id)` — unchanged behaviour.
  * `imageUrlFor(landmark)` — `BASE_URL + landmark.imagePath`.
  * `getTrailsByLocation(): List<Pair<Location, List<Trail>>>` — for the grouped
    tours list, ordered as `locations` is ordered.
  * `getCombinedBounds(): List<Coordinates>` — all landmark coordinates plus all
    trail polyline points.
  * `getBoundsForTrail(id): List<Coordinates>` — that trail's own points.
  * `getBeaconRegions(): List<BeaconRegion>` — distinct `(beaconUUID, major)`
    pairs from `locations`.
  * `getBoundary()` and `getFirstTrail()` are removed.

### Beacon scanning

`BeaconScanner.startScanning(consumer, regions: List<BeaconRegion>)` builds one
altbeacon `Region` per pair and ranges all of them.

The range callback fires **per region**. The notifier must therefore keep a
`region → beacons` map and recompute the merged closest beacon on every
callback. Taking the callback's beacon list directly, as the current code does,
would let an empty Lions Pride cycle wipe a live US202 detection roughly once a
second. `stopScanning` stops every region and clears the map.

Minor codes remain unambiguous across locations (1–16 vs 1002–3008), so a
detected minor still maps to exactly one landmark.

### UI

* `TrailMap`: `routeCoordinates: List<Coordinates>` becomes
  `routes: List<List<Coordinates>>`, drawing one blue polyline per trail (4
  total). Everything else — markers, bounds fitting, location overlay — is
  unchanged.
* `ParkMapScreen` / `ParkMapViewModel`: markers from all landmarks, routes from
  all trails, camera from `getCombinedBounds()`. No location concept in the UI.
* `TrailDetailScreen` / `TrailTourScreen`: switch from the site-wide bounds to
  `getBoundsForTrail(trailId)`. Without this the Yellow Trail tour would open
  zoomed out across three miles.
* `TrailToursScreen`: sectioned list with "Lions Pride Park" and "US202 to
  Bradford Dam" headers over their trails. `TrailToursViewModel` exposes the
  grouped structure.
* `LandmarkBottomSheet`: takes an image URL from state instead of building a
  hardcoded one. Prefs file renamed `us202_prefs` → `warrington_prefs`.
* `WelcomeScreen` / `AboutScreen`: opening line becomes location-neutral
  ("Welcome to Warrington's parks and trails"). The single hardcoded trailhead
  address is replaced by one entry per location, rendered from `locations`
  (name + address). The rest of the copy — what the app does, beacon and
  location permission explanation, Trail Tours explanation — is unchanged.

### Rename to Warrington Parks & Trails

* Package and source directory `org.warringtontownship.us202.android` →
  `org.warringtontownship.parks.android` (all 26 Kotlin files, main and debug).
* `applicationId` and `namespace` → `org.warringtontownship.parks.android`.
* `US202App` → `WarringtonParksApp`, referenced from `AndroidManifest.xml`.
* Manifest `android:label` → "Warrington Parks & Trails".
* `Theme.US202.Splash` → `Theme.WarringtonParks.Splash` in `themes.xml` and the
  manifest.
* Debug broadcast actions `org.warringtontownship.us202.FAKE_BEACON` /
  `…FAKE_BEACON_CLEAR` → `org.warringtontownship.parks.…`, in
  `app/src/debug/AndroidManifest.xml` and `simulate_beacon.sh`.
* `settings.gradle.kts` `rootProject.name` → `WarringtonParksAndTrails`.
* `versionName` → `2026.7.27`; `versionCode` stays 1 (nothing shipped).

## Testing

The app has no tests and no test source set today. This change adds
`app/src/test/` plus a JUnit dependency in the version catalog, covering the two
places the merge can break silently:

* **`TrailRepository`**, against a fixture parsed from the real
  `warrington-trails.json`: landmark IDs are globally unique; every `location`
  key resolves to a `locations` entry; every `imagePath` is well-formed;
  `getTrailsByLocation` groups 4 trails into 2 sections; `getBoundsForTrail`
  returns only that trail's points; `getBeaconRegions` yields exactly two
  regions.
* **`BeaconScanner`** merge logic, extracted into a pure function over
  `region → beacons` so it can be tested without the radio: a range callback for
  one region must not clear another region's detections, and the closest beacon
  is the minimum across all regions.

Manual verification, since none of the above touches the radio or the map:

* `./gradlew assembleDebug` and `./gradlew test`.
* Emulator run with `simulate_beacon.sh` for one minor from each location
  (e.g. 4 and 1002), confirming each opens the right landmark sheet.
* Visual check that the map shows all 40 landmarks and 4 polylines, and that
  landmark photos load from both image directories.

## Documentation

Update `README.md` (server layout, the two-file edit rule until iOS migrates),
`android/README.md` (app name, data file, beacon major codes for both
locations), and `android/HOW_IT_WORKS.md` / `android/REPORT.md` where they
describe the single-site data flow.

## Out of scope

* iOS. It keeps reading `us202trail-v2.json` until its own spec lands.
* Any Play Store release work.
* Revising Lions Pride Park's landmark content or photos.
