# One App, All Trail Points — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the single Android app show every landmark and trail from both Lions Pride Park and the US202 to Bradford Dam trail, and rename it to "Warrington Parks & Trails".

**Architecture:** A new hosted file `server/warrington-trails.json` holds flat `landmarks` and `trails` lists, each row tagged with a `location` key that resolves against a two-entry `locations` lookup. `TrailRepository` is the only class that knows locations exist — every screen except the Trail Tours list treats the data as one undifferentiated set. `BeaconScanner` ranges one altbeacon `Region` per location and merges detections across regions.

**Tech Stack:** Kotlin, Jetpack Compose, Hilt, Retrofit + Gson, osmdroid, AltBeacon android-beacon-library, JUnit 4.

## Global Constraints

- Spec: `docs/superpowers/specs/2026-07-27-single-app-all-trail-points-design.md`.
- New package and applicationId: `org.warringtontownship.parks.android`.
- User-visible app name: `Warrington Parks & Trails`.
- Data URL base: `https://trails.warringtoneac.org/` (trailing slash — Retrofit requires it).
- Data file name: `warrington-trails.json`, served from the domain root.
- `server/us-202/us202trail-v2.json` must keep existing, byte-identical, at its current path — the shipped iOS app reads it. Same for `server/lions-pride-park/lionsPrideData.json` and both `images/` directories.
- Beacon UUID (both locations): `035a0617-0875-4cc7-a29c-be0caa8f557c`. Major codes: Lions Pride Park `17`, US202 `20`.
- Lions Pride Park address: `3129 Bradley Rd, Warrington, PA 18976`. US202 trailhead address: `Stump Road across from 785, Chalfont, PA 18914`.
- Landmark `id` doubles as the beacon minor code. IDs are globally unique across locations (Lions Pride 1002–3008, US202 1–16 and 4001) and must stay that way.
- Run all Gradle commands from `android/`.

---

## File Structure

**Created:**

| Path | Responsibility |
|---|---|
| `server/warrington-trails.json` | The one hosted data file, source of truth for both locations |
| `android/app/src/test/java/org/warringtontownship/parks/android/data/TrailsDataParsingTest.kt` | Parses the real shipped JSON, asserts its invariants |
| `android/app/src/test/java/org/warringtontownship/parks/android/data/TrailRepositoryTest.kt` | Repository grouping, bounds, image URLs, beacon regions |
| `android/app/src/test/java/org/warringtontownship/parks/android/beacon/BeaconMergeTest.kt` | Cross-region detection merge |

**Renamed (Task 2):** the whole of `android/app/src/main/java/org/warringtontownship/us202/android/` and `android/app/src/debug/java/org/warringtontownship/us202/android/` → `.../parks/android/`. All paths below use the **new** package.

**Modified:**

| Path | Change |
|---|---|
| `data/model/ConnectorData.kt` → `data/model/TrailsData.kt` | Flat multi-location model; `Site` deleted |
| `data/network/ConnectorApiService.kt` → `data/network/TrailsApiService.kt` | New endpoint |
| `di/AppModule.kt` | Base URL to domain root; provides `TrailsApiService` |
| `data/repository/TrailRepository.kt` | Location-aware lookups; the only place locations are visible |
| `beacon/BeaconScanner.kt` | Multi-region ranging + `mergeDetections` |
| `ui/common/TrailMap.kt` | `routes: List<List<Coordinates>>` |
| `ui/common/LandmarkBottomSheet.kt` | Image URL from caller |
| `ui/parkmap/ParkMapViewModel.kt`, `ui/parkmap/ParkMapScreen.kt` | All landmarks, all routes, combined bounds |
| `ui/trailtours/TrailToursViewModel.kt` | Grouped trails, per-trail bounds, multi-region scanning |
| `ui/trailtours/TrailToursScreen.kt` | Sectioned list |
| `ui/trailtours/TrailDetailScreen.kt`, `ui/trailtours/TrailTourScreen.kt` | Per-trail bounds, image URLs |
| `ui/settings/SettingsViewModel.kt` | Multi-region scanning |
| `ui/welcome/WelcomeScreen.kt`, `ui/about/AboutScreen.kt` | Location-neutral copy, both addresses |

---

### Task 1: Build the merged data file

**Files:**
- Create: `server/warrington-trails.json`
- Read (do not modify): `server/us-202/us202trail-v2.json`, `server/lions-pride-park/lionsPrideData.json`

**Interfaces:**
- Consumes: nothing.
- Produces: the JSON contract every later task depends on — top-level keys `beaconUUID` (String), `locations` (list of `{id, name, address, beaconMajorCode}`), `landmarks`, `trails`. Every landmark and trail carries `location` (String, matching a `locations[].id`). Every landmark carries `imagePath` (String, path relative to the domain root) and no longer carries `imageName`.

- [ ] **Step 1: Write the conversion script**

This is a one-off — put it in your scratchpad, not in the repo. The spec deliberately drops the generator: after this task the JSON is hand-edited.

```python
# /tmp/convert.py — run from the repo root
import json, collections

SOURCES = [
    ("lions-pride-park", "Lions Pride Park", "3129 Bradley Rd, Warrington, PA 18976",
     "server/lions-pride-park/lionsPrideData.json"),
    ("us-202", "US202 to Bradford Dam", "Stump Road across from 785, Chalfont, PA 18914",
     "server/us-202/us202trail-v2.json"),
]

out = {"beaconUUID": None, "locations": [], "landmarks": [], "trails": []}

for loc_id, name, address, path in SOURCES:
    data = json.load(open(path))
    site = data["site"]
    if out["beaconUUID"] is None:
        out["beaconUUID"] = site["beaconUUID"]
    assert site["beaconUUID"] == out["beaconUUID"], "locations must share one UUID"
    out["locations"].append({
        "id": loc_id, "name": name, "address": address,
        "beaconMajorCode": site["beaconMajorCode"],
    })
    for lm in data["landmarks"]:
        new = collections.OrderedDict()
        new["id"] = lm["id"]
        new["location"] = loc_id
        new["imagePath"] = f"{loc_id}/images/{lm['imageName']}.jpg"
        for k, v in lm.items():
            if k not in ("id", "imageName"):
                new[k] = v
        out["landmarks"].append(new)
    for tr in data["trails"]:
        new = collections.OrderedDict()
        new["id"] = tr["id"]
        new["location"] = loc_id
        for k, v in tr.items():
            if k != "id":
                new[k] = v
        out["trails"].append(new)

with open("server/warrington-trails.json", "w") as f:
    json.dump(out, f, indent=2)
    f.write("\n")
print("landmarks", len(out["landmarks"]), "trails", len(out["trails"]))
```

- [ ] **Step 2: Run it**

```bash
cd /Users/steve/projects/warrington-beacons && python3 /tmp/convert.py
```

Expected: `landmarks 40 trails 4`

- [ ] **Step 3: Write the validation script**

```python
# /tmp/validate.py — run from the repo root
import json, os, collections

d = json.load(open("server/warrington-trails.json"))
loc_ids = {l["id"] for l in d["locations"]}
assert loc_ids == {"lions-pride-park", "us-202"}, loc_ids
assert d["beaconUUID"] == "035a0617-0875-4cc7-a29c-be0caa8f557c"
assert {l["id"]: l["beaconMajorCode"] for l in d["locations"]} == \
       {"lions-pride-park": 17, "us-202": 20}
assert all(l.get("address") for l in d["locations"])

ids = [l["id"] for l in d["landmarks"]]
dupes = [i for i, n in collections.Counter(ids).items() if n > 1]
assert not dupes, f"duplicate landmark ids: {dupes}"

for l in d["landmarks"]:
    assert l["location"] in loc_ids, l
    assert "imageName" not in l, l["id"]
    p = os.path.join("server", l["imagePath"])
    assert os.path.exists(p), f"missing image {p} for landmark {l['id']}"

for t in d["trails"]:
    assert t["location"] in loc_ids, t
    for c in t["boundaryCoordinates"]:
        if c.get("landmarkId") is not None:
            assert c["landmarkId"] in ids, f"trail {t['id']} references unknown {c['landmarkId']}"

print("OK:", len(d["landmarks"]), "landmarks,", len(d["trails"]), "trails")
```

- [ ] **Step 4: Run the validation**

```bash
cd /Users/steve/projects/warrington-beacons && python3 /tmp/validate.py
```

Expected: `OK: 40 landmarks, 4 trails`

- [ ] **Step 5: Confirm the legacy files are untouched**

```bash
cd /Users/steve/projects/warrington-beacons && git status --porcelain server/
```

Expected: exactly one line, `?? server/warrington-trails.json`. If `us202trail-v2.json` or `lionsPrideData.json` shows as modified, revert them — the shipped iOS app depends on the former.

- [ ] **Step 6: Commit**

```bash
cd /Users/steve/projects/warrington-beacons
git add server/warrington-trails.json
git commit -m "Add merged warrington-trails.json covering both locations"
```

Pushing this to `main` publishes it via `.github/workflows/pages.yml`. That is safe: nothing reads it yet.

---

### Task 2: Rename to Warrington Parks & Trails

Mechanical and self-contained, done before the functional work so every later task uses final paths. No behaviour changes.

**Files:**
- Move: `android/app/src/main/java/org/warringtontownship/us202/android/` → `android/app/src/main/java/org/warringtontownship/parks/android/`
- Move: `android/app/src/debug/java/org/warringtontownship/us202/android/` → `android/app/src/debug/java/org/warringtontownship/parks/android/`
- Rename: `MainActivity.kt`'s sibling `US202App.kt` → `WarringtonParksApp.kt`
- Modify: `android/app/build.gradle.kts`, `android/settings.gradle.kts`, `android/app/src/main/AndroidManifest.xml`, `android/app/src/debug/AndroidManifest.xml`, `android/app/src/main/res/values/themes.xml`, `android/simulate_beacon.sh`, and every `.kt` file

**Interfaces:**
- Consumes: nothing.
- Produces: package root `org.warringtontownship.parks.android`; `WarringtonParksApp`; `WarringtonParksTheme(darkTheme, content)`; prefs file name `warrington_prefs`; broadcast actions `org.warringtontownship.parks.FAKE_BEACON` and `org.warringtontownship.parks.FAKE_BEACON_CLEAR`.

- [ ] **Step 1: Move the source directories**

```bash
cd /Users/steve/projects/warrington-beacons/android/app/src
mkdir -p main/java/org/warringtontownship/parks debug/java/org/warringtontownship/parks
git mv main/java/org/warringtontownship/us202/android main/java/org/warringtontownship/parks/android
git mv debug/java/org/warringtontownship/us202/android debug/java/org/warringtontownship/parks/android
rmdir main/java/org/warringtontownship/us202 debug/java/org/warringtontownship/us202
git mv main/java/org/warringtontownship/parks/android/US202App.kt \
       main/java/org/warringtontownship/parks/android/WarringtonParksApp.kt
```

- [ ] **Step 2: Rewrite package references in Kotlin**

```bash
cd /Users/steve/projects/warrington-beacons/android
find app/src -name '*.kt' -print0 | xargs -0 sed -i '' \
  -e 's/org\.warringtontownship\.us202\.android/org.warringtontownship.parks.android/g' \
  -e 's/org\.warringtontownship\.us202\.FAKE_BEACON/org.warringtontownship.parks.FAKE_BEACON/g' \
  -e 's/\bUS202App\b/WarringtonParksApp/g' \
  -e 's/\bUS202Theme\b/WarringtonParksTheme/g' \
  -e 's/"us202_prefs"/"warrington_prefs"/g'
grep -rn "us202\|US202" app/src --include='*.kt'
```

Expected from the final `grep`: no output. (`FakeBeaconReceiver.kt`'s KDoc examples contain the package name and are covered by the first two patterns; the `-n org.warringtontownship.us202.android/.beacon...` lines in that KDoc are covered by the first pattern too.)

- [ ] **Step 3: Update Gradle, manifests, theme and the simulate script**

`android/app/build.gradle.kts` — in the `android` block:

```kotlin
    namespace = "org.warringtontownship.parks.android"
    compileSdk = 36

    defaultConfig {
        applicationId = "org.warringtontownship.parks.android"
        minSdk = 31
        targetSdk = 36
        versionCode = 1
        versionName = "2026.7.27"
    }
```

`android/settings.gradle.kts` — last two lines:

```kotlin
rootProject.name = "WarringtonParksAndTrails"
include(":app")
```

`android/app/src/main/AndroidManifest.xml` — inside `<application>`:

```xml
        android:name=".WarringtonParksApp"
        android:label="Warrington Parks &amp; Trails"
```

and on the activity: `android:theme="@style/Theme.WarringtonParks.Splash"`.

`android/app/src/main/res/values/themes.xml`:

```xml
    <style name="Theme.WarringtonParks.Splash" parent="Theme.SplashScreen">
```

`android/app/src/debug/AndroidManifest.xml` — the two `<action>` names become `org.warringtontownship.parks.FAKE_BEACON` and `org.warringtontownship.parks.FAKE_BEACON_CLEAR`.

`android/simulate_beacon.sh` — the three constants:

```bash
PKG="org.warringtontownship.parks.android"
RECEIVER="$PKG/.beacon.FakeBeaconReceiver"
ACTION_SET="org.warringtontownship.parks.FAKE_BEACON"
ACTION_CLEAR="org.warringtontownship.parks.FAKE_BEACON_CLEAR"
```

- [ ] **Step 4: Verify nothing is left behind**

```bash
cd /Users/steve/projects/warrington-beacons/android
grep -rn "us202\|US202\|US 202" app/src settings.gradle.kts app/build.gradle.kts simulate_beacon.sh
```

Expected: no output.

- [ ] **Step 5: Build**

```bash
cd /Users/steve/projects/warrington-beacons/android && ./gradlew assembleDebug
```

Expected: `BUILD SUCCESSFUL`.

- [ ] **Step 6: Commit**

```bash
cd /Users/steve/projects/warrington-beacons
git add -A android
git commit -m "Rename app to Warrington Parks & Trails"
```

---

### Task 3: Data model for the merged file

**Files:**
- Create: `android/app/src/test/java/org/warringtontownship/parks/android/data/TrailsDataParsingTest.kt`
- Create: `android/app/src/main/java/org/warringtontownship/parks/android/data/model/TrailsData.kt`
- Delete: `android/app/src/main/java/org/warringtontownship/parks/android/data/model/ConnectorData.kt`
- Modify: `android/gradle/libs.versions.toml`, `android/app/build.gradle.kts`

**Interfaces:**
- Consumes: the JSON contract from Task 1.
- Produces:
  ```kotlin
  data class TrailsData(val beaconUUID: String, val locations: List<Location>,
                        val landmarks: List<Landmark>, val trails: List<Trail>)
  data class Location(val id: String, val name: String, val address: String, val beaconMajorCode: Int)
  data class Coordinates(val latitude: Double, val longitude: Double)
  data class Landmark(val id: Int, val location: String, val imagePath: String,
                      val coordinates: Coordinates, val name: String, val category: String,
                      val description: String, val longDescription: String, val imageAlt: String,
                      val isOpen: Boolean? = null, val trailDistanceDescription: String? = null)
  data class Trail(val id: Int, val location: String, val name: String, val isOpen: Boolean,
                   val trailDistanceDescription: String, val boundaryCoordinates: List<TrailCoordinate>)
  data class TrailCoordinate(val latitude: Double, val longitude: Double,
                             val distanceToNextCounterClockwise: String? = null,
                             val distanceToNextCounterClockwiseDescription: String? = null,
                             val distanceToNextClockwise: String? = null,
                             val distanceToNextClockwiseDescription: String? = null,
                             val landmarkId: Int? = null)
  ```
  `Site` and `ConnectorData` no longer exist.

- [ ] **Step 1: Add the test source set dependency**

`android/gradle/libs.versions.toml` — add `junit = "4.13.2"` to `[versions]` and this to `[libraries]`:

```toml
junit = { group = "junit", name = "junit", version.ref = "junit" }
```

`android/app/build.gradle.kts` — add to `dependencies`:

```kotlin
    testImplementation(libs.junit)
```

Gson is already an `implementation` dependency, which puts it on the unit test compile classpath.

- [ ] **Step 2: Write the failing test**

Create `android/app/src/test/java/org/warringtontownship/parks/android/data/TrailsDataParsingTest.kt`. It parses the **real shipped file** rather than a fixture copy, so the test fails if the data and the model ever drift. Unit tests run with the module directory (`android/app`) as the working directory, so the file is two levels up.

```kotlin
package org.warringtontownship.parks.android.data

import com.google.gson.Gson
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.warringtontownship.parks.android.data.model.TrailsData
import java.io.File

class TrailsDataParsingTest {

    private val data: TrailsData =
        Gson().fromJson(File(DATA_FILE).readText(), TrailsData::class.java)

    @Test
    fun `parses both locations with their beacon major codes`() {
        assertEquals("035a0617-0875-4cc7-a29c-be0caa8f557c", data.beaconUUID)
        assertEquals(
            mapOf("lions-pride-park" to 17, "us-202" to 20),
            data.locations.associate { it.id to it.beaconMajorCode },
        )
        assertTrue(data.locations.all { it.address.isNotBlank() })
    }

    @Test
    fun `parses every landmark and trail from both locations`() {
        assertEquals(40, data.landmarks.size)
        assertEquals(4, data.trails.size)
        assertEquals(23, data.landmarks.count { it.location == "lions-pride-park" })
        assertEquals(17, data.landmarks.count { it.location == "us-202" })
    }

    @Test
    fun `landmark ids are globally unique`() {
        val duplicates = data.landmarks.groupBy { it.id }.filterValues { it.size > 1 }.keys
        assertTrue("duplicate landmark ids: $duplicates", duplicates.isEmpty())
    }

    @Test
    fun `every location key resolves and every image path is present`() {
        val locationIds = data.locations.map { it.id }.toSet()
        data.landmarks.forEach { landmark ->
            assertTrue("bad location on ${landmark.id}", landmark.location in locationIds)
            assertTrue(
                "bad imagePath on ${landmark.id}: ${landmark.imagePath}",
                landmark.imagePath.endsWith(".jpg") && landmark.imagePath.contains("/images/"),
            )
            assertTrue(
                "missing image file for ${landmark.id}",
                File("../../server/${landmark.imagePath}").exists(),
            )
        }
        data.trails.forEach { assertTrue(it.location in locationIds) }
    }

    @Test
    fun `every trail stop references a known landmark`() {
        val ids = data.landmarks.map { it.id }.toSet()
        data.trails.forEach { trail ->
            trail.boundaryCoordinates.mapNotNull { it.landmarkId }.forEach { landmarkId ->
                assertTrue("trail ${trail.id} references $landmarkId", landmarkId in ids)
            }
        }
    }

    @Test
    fun `nullable landmark fields survive absence`() {
        // Several landmarks have no isOpen / trailDistanceDescription in the source data.
        assertNotNull(data.landmarks.first { it.isOpen == null })
    }

    companion object {
        const val DATA_FILE = "../../server/warrington-trails.json"
    }
}
```

- [ ] **Step 3: Run it to verify it fails**

```bash
cd /Users/steve/projects/warrington-beacons/android && ./gradlew test
```

Expected: compilation failure — `Unresolved reference: TrailsData`.

- [ ] **Step 4: Write the model**

Create `android/app/src/main/java/org/warringtontownship/parks/android/data/model/TrailsData.kt` with exactly the declarations listed in this task's **Produces** block, under `package org.warringtontownship.parks.android.data.model`.

Then delete the old model:

```bash
cd /Users/steve/projects/warrington-beacons/android
git rm app/src/main/java/org/warringtontownship/parks/android/data/model/ConnectorData.kt
```

The app will not compile until Task 4 — that is expected; `./gradlew test` compiles the test source set and its dependencies but the app's `ConnectorApiService` and `TrailRepository` still reference the deleted types, so also apply the stopgap in Step 5.

- [ ] **Step 5: Point the existing consumers at the new model**

Minimal edits so the module compiles; Task 4 replaces both properly.

`data/network/ConnectorApiService.kt`:

```kotlin
package org.warringtontownship.parks.android.data.network

import org.warringtontownship.parks.android.data.model.TrailsData
import retrofit2.http.GET

interface ConnectorApiService {
    @GET("warrington-trails.json")
    suspend fun getConnectorData(): TrailsData
}
```

`data/repository/TrailRepository.kt` — change the cached field to `private var data: TrailsData? = null`, and for now have `getBeaconUUID()` return `data?.beaconUUID`, `getBeaconMajorCode()` return `data?.locations?.firstOrNull()?.beaconMajorCode`, and `getBoundary()` return `emptyList()`. Everything else in the file already works against `landmarks` / `trails`.

`di/AppModule.kt` — change `.baseUrl("https://trails.warringtoneac.org/us-202/")` to `.baseUrl("https://trails.warringtoneac.org/")`.

- [ ] **Step 6: Run the tests**

```bash
cd /Users/steve/projects/warrington-beacons/android && ./gradlew test
```

Expected: `BUILD SUCCESSFUL`, 6 tests passing.

- [ ] **Step 7: Commit**

```bash
cd /Users/steve/projects/warrington-beacons
git add -A android
git commit -m "Add multi-location data model with parsing tests"
```

---

### Task 4: Repository becomes the only location-aware class

**Files:**
- Create: `android/app/src/test/java/org/warringtontownship/parks/android/data/TrailRepositoryTest.kt`
- Modify: `android/app/src/main/java/org/warringtontownship/parks/android/data/repository/TrailRepository.kt`
- Rename: `data/network/ConnectorApiService.kt` → `data/network/TrailsApiService.kt`
- Modify: `android/app/src/main/java/org/warringtontownship/parks/android/di/AppModule.kt`

**Interfaces:**
- Consumes: `TrailsData` and friends from Task 3.
- Produces, on `TrailRepository`:
  ```kotlin
  suspend fun loadData()
  fun getLandmarks(): List<Landmark>
  fun getLandmarkById(id: Int): Landmark?
  fun getTrails(): List<Trail>
  fun getTrailById(id: Int): Trail?
  fun getTrailsByLocation(): List<Pair<Location, List<Trail>>>
  fun getLocations(): List<Location>
  fun imageUrlFor(landmark: Landmark): String
  fun getCombinedBounds(): List<Coordinates>
  fun getBoundsForTrail(trailId: Int): List<Coordinates>
  fun getBeaconRegions(): List<BeaconRegion>
  ```
  `getBeaconUUID()`, `getBeaconMajorCode()`, `getBoundary()` and `getFirstTrail()` are removed. This task also creates `beacon/BeaconRegion.kt` containing `data class BeaconRegion(val uuid: String, val majorCode: Int)`; Task 5 consumes it.
- Also produces on `TrailsApiService`: `suspend fun getTrailsData(): TrailsData`.

- [ ] **Step 1: Write the failing test**

Create `android/app/src/test/java/org/warringtontownship/parks/android/data/TrailRepositoryTest.kt`. The repository's `loadData()` goes through Retrofit, so the test injects a fake service that reads the real file from disk.

```kotlin
package org.warringtontownship.parks.android.data

import com.google.gson.Gson
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.warringtontownship.parks.android.beacon.BeaconRegion
import org.warringtontownship.parks.android.data.model.TrailsData
import org.warringtontownship.parks.android.data.network.TrailsApiService
import org.warringtontownship.parks.android.data.repository.TrailRepository
import java.io.File

class TrailRepositoryTest {

    private class FakeApiService : TrailsApiService {
        override suspend fun getTrailsData(): TrailsData =
            Gson().fromJson(
                File(TrailsDataParsingTest.DATA_FILE).readText(),
                TrailsData::class.java,
            )
    }

    private lateinit var repository: TrailRepository

    @Before
    fun setUp() = runBlocking {
        repository = TrailRepository(FakeApiService())
        repository.loadData()
    }

    @Test
    fun `exposes every landmark and trail as one flat set`() {
        assertEquals(40, repository.getLandmarks().size)
        assertEquals(4, repository.getTrails().size)
        assertEquals("Yellow Trail", repository.getTrailById(1002)?.name)
        assertEquals("202 Connector Trail", repository.getTrailById(4001)?.name)
    }

    @Test
    fun `groups trails by location in locations order`() {
        val grouped = repository.getTrailsByLocation()
        assertEquals(listOf("Lions Pride Park", "US202 to Bradford Dam"), grouped.map { it.first.name })
        assertEquals(3, grouped[0].second.size)
        assertEquals(1, grouped[1].second.size)
        assertTrue(grouped[0].second.all { it.location == "lions-pride-park" })
    }

    @Test
    fun `builds image urls from the domain root`() {
        val landmark = repository.getLandmarkById(1002)!!
        assertEquals(
            "https://trails.warringtoneac.org/lions-pride-park/images/Yellow_trail.jpg",
            repository.imageUrlFor(landmark),
        )
    }

    @Test
    fun `combined bounds span both locations`() {
        val bounds = repository.getCombinedBounds()
        // 40 landmark coordinates plus 887 trail polyline points.
        assertEquals(927, bounds.size)
        val latitudes = bounds.map { it.latitude }
        val longitudes = bounds.map { it.longitude }
        assertTrue(latitudes.min() < 40.228 && latitudes.max() > 40.269)
        assertTrue(longitudes.min() < -75.191 && longitudes.max() > -75.157)
        // Both clusters are represented, not just the wider US202 corridor.
        assertTrue(bounds.any { it.latitude > 40.245 && it.latitude < 40.249 })
    }

    @Test
    fun `per-trail bounds cover only that trail`() {
        val bounds = repository.getBoundsForTrail(1002)
        assertEquals(54, bounds.size)
        assertTrue(bounds.all { it.latitude > 40.246 && it.latitude < 40.248 })
        assertTrue(repository.getBoundsForTrail(999999).isEmpty())
    }

    @Test
    fun `yields one beacon region per location`() {
        assertEquals(
            listOf(
                BeaconRegion("035a0617-0875-4cc7-a29c-be0caa8f557c", 17),
                BeaconRegion("035a0617-0875-4cc7-a29c-be0caa8f557c", 20),
            ),
            repository.getBeaconRegions(),
        )
    }
}
```

- [ ] **Step 2: Run it to verify it fails**

```bash
cd /Users/steve/projects/warrington-beacons/android && ./gradlew test
```

Expected: compilation failure — `Unresolved reference: TrailsApiService`.

- [ ] **Step 3: Rename the API service**

```bash
cd /Users/steve/projects/warrington-beacons/android/app/src/main/java/org/warringtontownship/parks/android
git mv data/network/ConnectorApiService.kt data/network/TrailsApiService.kt
```

Contents:

```kotlin
package org.warringtontownship.parks.android.data.network

import org.warringtontownship.parks.android.data.model.TrailsData
import retrofit2.http.GET

interface TrailsApiService {
    @GET("warrington-trails.json")
    suspend fun getTrailsData(): TrailsData
}
```

In `di/AppModule.kt`, rename the provider and its type:

```kotlin
    @Provides
    @Singleton
    fun provideTrailsApiService(retrofit: Retrofit): TrailsApiService =
        retrofit.create(TrailsApiService::class.java)
```

with the import updated to `org.warringtontownship.parks.android.data.network.TrailsApiService`. Leave `provideOkHttpClient` and its offline-cache interceptor untouched.

- [ ] **Step 4: Write the repository**

Replace the body of `data/repository/TrailRepository.kt`:

```kotlin
package org.warringtontownship.parks.android.data.repository

import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import org.warringtontownship.parks.android.beacon.BeaconRegion
import org.warringtontownship.parks.android.data.model.Coordinates
import org.warringtontownship.parks.android.data.model.Landmark
import org.warringtontownship.parks.android.data.model.Location
import org.warringtontownship.parks.android.data.model.Trail
import org.warringtontownship.parks.android.data.model.TrailsData
import org.warringtontownship.parks.android.data.network.TrailsApiService
import javax.inject.Inject
import javax.inject.Singleton

/**
 * The one class that knows the data covers more than one location. Screens see a
 * single flat set of landmarks and trails; only the Trail Tours list and beacon
 * scanning ask about locations.
 */
@Singleton
class TrailRepository @Inject constructor(
    private val apiService: TrailsApiService,
) {
    private var data: TrailsData? = null
    private val loadMutex = Mutex()

    // Loads once per process; every ViewModel calls this in its init, so without the
    // guard the same JSON is fetched three times (and racing loads clobber each other).
    // A failed load stays null, so later screens retry.
    suspend fun loadData() {
        if (data != null) return
        loadMutex.withLock {
            if (data == null) {
                data = apiService.getTrailsData()
            }
        }
    }

    fun getLandmarks(): List<Landmark> = data?.landmarks ?: emptyList()

    fun getLandmarkById(id: Int): Landmark? = data?.landmarks?.find { it.id == id }

    fun getTrails(): List<Trail> = data?.trails ?: emptyList()

    fun getTrailById(id: Int): Trail? = data?.trails?.find { it.id == id }

    fun getLocations(): List<Location> = data?.locations ?: emptyList()

    fun getTrailsByLocation(): List<Pair<Location, List<Trail>>> =
        getLocations().map { location ->
            location to getTrails().filter { it.location == location.id }
        }

    fun imageUrlFor(landmark: Landmark): String = IMAGE_BASE_URL + landmark.imagePath

    fun getCombinedBounds(): List<Coordinates> =
        getLandmarks().map { it.coordinates } +
            getTrails().flatMap { trail ->
                trail.boundaryCoordinates.map { Coordinates(it.latitude, it.longitude) }
            }

    fun getBoundsForTrail(trailId: Int): List<Coordinates> =
        getTrailById(trailId)?.boundaryCoordinates
            ?.map { Coordinates(it.latitude, it.longitude) }
            ?: emptyList()

    fun getBeaconRegions(): List<BeaconRegion> {
        val uuid = data?.beaconUUID ?: return emptyList()
        return getLocations().map { BeaconRegion(uuid, it.beaconMajorCode) }.distinct()
    }

    private companion object {
        const val IMAGE_BASE_URL = "https://trails.warringtoneac.org/"
    }
}
```

Create `beacon/BeaconRegion.kt`:

```kotlin
package org.warringtontownship.parks.android.beacon

data class BeaconRegion(val uuid: String, val majorCode: Int)
```

- [ ] **Step 5: Keep the app compiling**

`./gradlew test` compiles the app's debug sources too, so the three ViewModels that call the removed repository methods have to be updated now. `BeaconScanner` still takes `(consumer, uuid, majorCode)` until Task 5, so scan off the first region for the moment — Task 5 switches these same three call sites to the region list.

In each of `ui/parkmap/ParkMapViewModel.kt`, `ui/trailtours/TrailToursViewModel.kt` and `ui/settings/SettingsViewModel.kt`: replace the two fields

```kotlin
    private var beaconUuid: String? = null
    private var beaconMajorCode: Int? = null
```

with

```kotlin
    private var beaconRegions: List<BeaconRegion> = emptyList()
```

(importing `org.warringtontownship.parks.android.beacon.BeaconRegion`), replace the two assignment lines

```kotlin
                beaconUuid = trailRepository.getBeaconUUID()
                beaconMajorCode = trailRepository.getBeaconMajorCode()
```

with

```kotlin
                beaconRegions = trailRepository.getBeaconRegions()
```

and replace `startScanningIfReady()` with

```kotlin
    private fun startScanningIfReady() {
        val region = beaconRegions.firstOrNull() ?: return
        beaconScanner.startScanning(SCAN_CONSUMER, region.uuid, region.majorCode)
    }
```

Two more call sites of removed methods:

* `ParkMapViewModel.loadMarkers()` — replace the `getFirstTrail()?.boundaryCoordinates` expression that builds `coordinates` with `val coordinates = emptyList<Coordinates>()` and the `getBoundary()` call with `trailRepository.getCombinedBounds()`. Task 6 replaces `coordinates` with the real route list.
* `TrailToursViewModel` — replace `fun getBounds(): List<Coordinates> = trailRepository.getBoundary()` with `fun getBoundsForTrail(trailId: Int): List<Coordinates> = trailRepository.getBoundsForTrail(trailId)`, and update its two callers, `TrailDetailScreen.kt` and `TrailTourScreen.kt`, from `viewModel.getBounds()` to `viewModel.getBoundsForTrail(trailId)`.

- [ ] **Step 6: Run the tests**

```bash
cd /Users/steve/projects/warrington-beacons/android && ./gradlew test assembleDebug
```

Expected: `BUILD SUCCESSFUL`, with the 6 parsing tests and the 6 repository tests passing.

- [ ] **Step 7: Commit**

```bash
cd /Users/steve/projects/warrington-beacons
git add -A android
git commit -m "Make TrailRepository the only location-aware class"
```

---

### Task 5: Range beacons in both regions

**Files:**
- Create: `android/app/src/test/java/org/warringtontownship/parks/android/beacon/BeaconMergeTest.kt`
- Modify: `android/app/src/main/java/org/warringtontownship/parks/android/beacon/BeaconScanner.kt`

**Interfaces:**
- Consumes: `BeaconRegion` from Task 4.
- Produces:
  ```kotlin
  internal fun mergeDetections(byRegion: Map<String, List<DetectedBeacon>>): List<DetectedBeacon>
  fun startScanning(consumer: String, regions: List<BeaconRegion>)
  fun stopScanning(consumer: String)   // unchanged signature
  ```
  `startScanning(consumer, uuid, majorCode)` is gone. `closestBeaconMinorCode`, `detectedBeacons` and `injectSimulatedBeacons` keep their current types.

- [ ] **Step 1: Write the failing test**

The bug this guards against: altbeacon fires the range callback **per region**, roughly once a second each. If the notifier writes the callback's list straight into state, an empty Lions Pride cycle wipes a live US202 detection.

```kotlin
package org.warringtontownship.parks.android.beacon

import org.junit.Assert.assertEquals
import org.junit.Test

class BeaconMergeTest {

    private fun beacon(minor: Int, distance: Double) = DetectedBeacon(minor, distance)

    @Test
    fun `an empty cycle for one region does not clear the other region`() {
        val merged = mergeDetections(
            mapOf(
                "region-17" to emptyList(),
                "region-20" to listOf(beacon(4, 2.0)),
            )
        )
        assertEquals(listOf(beacon(4, 2.0)), merged)
    }

    @Test
    fun `closest is the minimum across all regions, nearest first`() {
        val merged = mergeDetections(
            mapOf(
                "region-17" to listOf(beacon(1002, 1.5), beacon(3001, 12.0)),
                "region-20" to listOf(beacon(4, 3.0)),
            )
        )
        assertEquals(listOf(1002, 4, 3001), merged.map { it.minorCode })
    }

    @Test
    fun `no detections anywhere yields an empty list`() {
        assertEquals(
            emptyList<DetectedBeacon>(),
            mergeDetections(mapOf("region-17" to emptyList(), "region-20" to emptyList())),
        )
    }
}
```

- [ ] **Step 2: Run it to verify it fails**

```bash
cd /Users/steve/projects/warrington-beacons/android && ./gradlew test --tests '*BeaconMergeTest*'
```

Expected: compilation failure — `Unresolved reference: mergeDetections`.

- [ ] **Step 3: Implement multi-region scanning**

In `beacon/BeaconScanner.kt`, add the pure merge function at file scope (outside the class, above it):

```kotlin
/**
 * Altbeacon delivers range results per region, so state has to be accumulated per
 * region and merged. Overwriting state from a single callback would let an empty
 * cycle for one location clear a live detection from the other.
 */
internal fun mergeDetections(byRegion: Map<String, List<DetectedBeacon>>): List<DetectedBeacon> =
    byRegion.values.flatten().sortedBy { it.distance }
```

Then, inside the class, replace `private var region: Region? = null` with

```kotlin
    private var regions: List<Region> = emptyList()
    private val detectionsByRegion = mutableMapOf<String, List<DetectedBeacon>>()
```

replace `rangeNotifier` with

```kotlin
    private val rangeNotifier = RangeNotifier { beacons, region ->
        if (simulationActive) return@RangeNotifier
        val detected = beacons.mapNotNull { beacon ->
            val minor = beacon.id3?.toInt() ?: return@mapNotNull null
            DetectedBeacon(minorCode = minor, distance = beacon.distance)
        }
        val merged = synchronized(detectionsByRegion) {
            detectionsByRegion[region.uniqueId] = detected
            mergeDetections(detectionsByRegion)
        }
        Log.d("BeaconScanner", "Region ${region.uniqueId}: ${beacons.size} ranged, " +
            "merged closest ${merged.firstOrNull()?.minorCode}")
        _detectedBeacons.value = merged
        _closestBeaconMinorCode.value = merged.firstOrNull()?.minorCode
    }
```

replace `startScanning` with

```kotlin
    fun startScanning(consumer: String, regions: List<BeaconRegion>) {
        if (regions.isEmpty()) return
        if (!activeConsumers.add(consumer)) return
        Log.d("BeaconScanner", "Consumer $consumer added, active=$activeConsumers")
        if (activeConsumers.size == 1) {
            val started = regions.map { spec ->
                Region(
                    "park-beacons-${spec.majorCode}",
                    Identifier.parse(spec.uuid),
                    Identifier.fromInt(spec.majorCode),
                    null,
                )
            }
            this.regions = started
            BeaconManager.setRssiFilterImplClass(ArmaRssiFilter::class.java)
            beaconManager.addRangeNotifier(rangeNotifier)
            started.forEach { beaconManager.startRangingBeacons(it) }
            Log.d("BeaconScanner", "Started scanning ${started.map { it.uniqueId }}")
        }
    }
```

and the tail of `stopScanning` with

```kotlin
        if (activeConsumers.isEmpty()) {
            regions.forEach { beaconManager.stopRangingBeacons(it) }
            beaconManager.removeRangeNotifier(rangeNotifier)
            synchronized(detectionsByRegion) { detectionsByRegion.clear() }
            _closestBeaconMinorCode.value = null
            _detectedBeacons.value = emptyList()
            regions = emptyList()
            Log.d("BeaconScanner", "Stopped scanning")
        }
```

Leave `injectSimulatedBeacons` exactly as it is — the debug fake path does not go through regions.

- [ ] **Step 4: Scan every region from all three ViewModels**

Task 4 left these scanning only the first region. In each of `ui/parkmap/ParkMapViewModel.kt`, `ui/trailtours/TrailToursViewModel.kt` and `ui/settings/SettingsViewModel.kt`, replace `startScanningIfReady()` with

```kotlin
    private fun startScanningIfReady() {
        if (beaconRegions.isEmpty()) return
        beaconScanner.startScanning(SCAN_CONSUMER, beaconRegions)
    }
```

This is the change that actually makes Lions Pride beacons detectable — until now only major 17 (the first location) was ranged.

- [ ] **Step 5: Run the tests and build**

```bash
cd /Users/steve/projects/warrington-beacons/android && ./gradlew test assembleDebug
```

Expected: `BUILD SUCCESSFUL`, all 15 tests passing.

- [ ] **Step 6: Commit**

```bash
cd /Users/steve/projects/warrington-beacons
git add -A android
git commit -m "Range beacons across both locations"
```

---

### Task 6: Draw every trail on one map

**Files:**
- Modify: `android/app/src/main/java/org/warringtontownship/parks/android/ui/common/TrailMap.kt`
- Modify: `android/app/src/main/java/org/warringtontownship/parks/android/ui/parkmap/ParkMapViewModel.kt`
- Modify: `android/app/src/main/java/org/warringtontownship/parks/android/ui/parkmap/ParkMapScreen.kt`
- Modify: `android/app/src/main/java/org/warringtontownship/parks/android/ui/trailtours/TrailDetailScreen.kt`
- Modify: `android/app/src/main/java/org/warringtontownship/parks/android/ui/trailtours/TrailTourScreen.kt`

**Interfaces:**
- Consumes: `TrailRepository.getCombinedBounds()`, `getBoundsForTrail(trailId)` from Task 4.
- Produces: `TrailMap(routes: List<List<Coordinates>>, markers, boundsCoordinates, modifier, onMarkerClick, focusPosition, centerZoomPosition, centerZoomLevel, highlightedMarkerId)` — the `routeCoordinates: List<Coordinates>` parameter is replaced by `routes`; all other parameters keep their names, types and defaults. `ParkMapUiState` gains `routes: List<List<Coordinates>>` and drops `coordinates`.

- [ ] **Step 1: Change the map to take many polylines**

In `ui/common/TrailMap.kt`, change the signature's first parameter from `routeCoordinates: List<Coordinates>` to `routes: List<List<Coordinates>>`, and in the `AndroidView` `update` block replace the single-polyline block with:

```kotlin
            routes.filter { it.isNotEmpty() }.forEach { route ->
                view.overlays.add(Polyline(view).apply {
                    setPoints(route.map { GeoPoint(it.latitude, it.longitude) })
                    outlinePaint.color = Color.BLUE
                    outlinePaint.strokeWidth = 8f
                    infoWindow = null
                })
            }
```

Nothing else in the file changes — marker rendering, bounds fitting, the location overlay and the lifecycle wiring stay as they are.

- [ ] **Step 2: Show all landmarks and all trails on the park map**

In `ui/parkmap/ParkMapViewModel.kt`, change the state class to

```kotlin
data class ParkMapUiState(
    val markers: List<MapMarker> = emptyList(),
    val routes: List<List<Coordinates>> = emptyList(),
    val boundary: List<Coordinates> = emptyList(),
    val selectedMarker: MapMarker? = null,
)
```

and in `loadMarkers()` replace the `coordinates` / `boundary` computation with

```kotlin
                val routes = trailRepository.getTrails().map { trail ->
                    trail.boundaryCoordinates.map { Coordinates(it.latitude, it.longitude) }
                }
                val boundary = trailRepository.getCombinedBounds()
                _uiState.value = ParkMapUiState(markers = markers, routes = routes, boundary = boundary)
```

In `ui/parkmap/ParkMapScreen.kt`, pass `routes = uiState.routes` instead of `routeCoordinates = uiState.coordinates`.

- [ ] **Step 3: Give the tour screens their own trail's bounds**

In `ui/trailtours/TrailDetailScreen.kt`, replace

```kotlin
    val bounds = viewModel.getBounds()
```

with

```kotlin
    val bounds = viewModel.getBoundsForTrail(trailId)
```

and change the `TrailMap` call's `routeCoordinates = coords` to `routes = listOf(coords)`.

In `ui/trailtours/TrailTourScreen.kt`, replace `val bounds = viewModel.getBounds()` with `val bounds = viewModel.getBoundsForTrail(trailId)` and `routeCoordinates = coords` with `routes = listOf(coords)`.

Without this the Yellow Trail tour would open zoomed out across three miles instead of framing the trail.

- [ ] **Step 4: Build**

```bash
cd /Users/steve/projects/warrington-beacons/android && ./gradlew assembleDebug test
```

Expected: `BUILD SUCCESSFUL`.

- [ ] **Step 5: Verify on the emulator**

```bash
cd /Users/steve/projects/warrington-beacons/android
./gradlew installDebug
```

Open the app. Expected on the Park Map tab: markers across both the Lions Pride Park cluster and the US202 corridor, four blue polylines, and an initial camera that frames all of them.

- [ ] **Step 6: Commit**

```bash
cd /Users/steve/projects/warrington-beacons
git add -A android
git commit -m "Draw all landmarks and all four trails on one map"
```

---

### Task 7: Group the Trail Tours list by location

**Files:**
- Modify: `android/app/src/main/java/org/warringtontownship/parks/android/ui/trailtours/TrailToursViewModel.kt`
- Modify: `android/app/src/main/java/org/warringtontownship/parks/android/ui/trailtours/TrailToursScreen.kt`

**Interfaces:**
- Consumes: `TrailRepository.getTrailsByLocation()` from Task 4.
- Produces: `TrailToursUiState(trailsByLocation: List<Pair<Location, List<Trail>>>, isLoading: Boolean, error: String?)` — the `trails: List<Trail>` field is replaced.

- [ ] **Step 1: Group in the ViewModel**

In `ui/trailtours/TrailToursViewModel.kt`:

```kotlin
data class TrailToursUiState(
    val trailsByLocation: List<Pair<Location, List<Trail>>> = emptyList(),
    val isLoading: Boolean = false,
    val error: String? = null,
)
```

with `import org.warringtontownship.parks.android.data.model.Location`, and in `loadTrails()` replace the success assignment with

```kotlin
                _uiState.value = TrailToursUiState(
                    trailsByLocation = trailRepository.getTrailsByLocation(),
                )
```

- [ ] **Step 2: Render sections**

In `ui/trailtours/TrailToursScreen.kt`, replace the `items(uiState.trails) { trail -> … }` block with a loop over the groups, keeping the existing `Card` body verbatim:

```kotlin
            uiState.trailsByLocation.forEach { (location, trails) ->
                item(key = "header-${location.id}") {
                    Text(
                        text = location.name,
                        style = MaterialTheme.typography.titleMedium,
                        color = MaterialTheme.colorScheme.primary,
                        modifier = Modifier.padding(top = 16.dp, bottom = 4.dp),
                    )
                }
                items(trails, key = { it.id }) { trail ->
                    Card(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(vertical = 4.dp)
                            .clickable { onTrailClick(trail.id) },
                        elevation = CardDefaults.cardElevation(defaultElevation = 2.dp),
                    ) {
                        Column(modifier = Modifier.padding(16.dp)) {
                            Text(
                                text = trail.name,
                                style = MaterialTheme.typography.titleLarge,
                            )
                            Text(
                                text = "${landmarkCount(trail)} Points of Interest",
                                style = MaterialTheme.typography.bodyMedium,
                                color = MaterialTheme.colorScheme.primary,
                            )
                            Text(
                                text = trail.trailDistanceDescription,
                                style = MaterialTheme.typography.bodyMedium,
                                modifier = Modifier.padding(top = 4.dp),
                            )
                        }
                    }
                }
            }
```

The intro paragraph `item { … }` above it stays unchanged. `landmarkCount` is the existing private helper at the top of the file.

- [ ] **Step 3: Build**

```bash
cd /Users/steve/projects/warrington-beacons/android && ./gradlew assembleDebug test
```

Expected: `BUILD SUCCESSFUL`.

- [ ] **Step 4: Verify on the emulator**

```bash
cd /Users/steve/projects/warrington-beacons/android && ./gradlew installDebug
```

Expected on the Trail Tours tab: a "Lions Pride Park" header over Yellow Trail, Green Trail and Kids Mountain Trail, then a "US202 to Bradford Dam" header over 202 Connector Trail. Tapping any of them opens a detail screen framed on that trail.

- [ ] **Step 5: Commit**

```bash
cd /Users/steve/projects/warrington-beacons
git add -A android
git commit -m "Group Trail Tours by location"
```

---

### Task 8: Load landmark photos from either location

**Files:**
- Modify: `android/app/src/main/java/org/warringtontownship/parks/android/ui/common/LandmarkBottomSheet.kt`
- Modify: `android/app/src/main/java/org/warringtontownship/parks/android/ui/parkmap/ParkMapViewModel.kt`
- Modify: `android/app/src/main/java/org/warringtontownship/parks/android/ui/parkmap/ParkMapScreen.kt`
- Modify: `android/app/src/main/java/org/warringtontownship/parks/android/ui/trailtours/TrailToursViewModel.kt`
- Modify: `android/app/src/main/java/org/warringtontownship/parks/android/ui/trailtours/TrailTourScreen.kt`

**Interfaces:**
- Consumes: `TrailRepository.imageUrlFor(landmark)` from Task 4.
- Produces: `LandmarkBottomSheet(landmark: Landmark?, imageUrl: String?, onDismiss: () -> Unit)`; `ParkMapViewModel.imageUrlFor(landmark: Landmark): String`; `TrailToursViewModel.imageUrlFor(landmark: Landmark): String`.

The sheet currently hardcodes `https://trails.warringtoneac.org/us-202/images/${landmark.imageName}.jpg`, which cannot reach Lions Pride photos and references a field that no longer exists.

- [ ] **Step 1: Take the URL as a parameter**

In `ui/common/LandmarkBottomSheet.kt`, add `imageUrl: String?` as the second parameter and replace the `AsyncImage` model:

```kotlin
                AsyncImage(
                    model = imageUrl,
                    contentDescription = landmark.name,
                    modifier = Modifier
                        .fillMaxWidth()
                        .aspectRatio(16f / 9f),
                )
```

The prefs lookup in this file already reads `warrington_prefs` after Task 2 — leave it.

- [ ] **Step 2: Expose the URL from both ViewModels**

Add to `ui/parkmap/ParkMapViewModel.kt` and `ui/trailtours/TrailToursViewModel.kt`:

```kotlin
    fun imageUrlFor(landmark: Landmark): String = trailRepository.imageUrlFor(landmark)
```

`TrailToursViewModel` needs `import org.warringtontownship.parks.android.data.model.Landmark` if it is not already imported.

- [ ] **Step 3: Pass it at both call sites**

In `ui/parkmap/ParkMapScreen.kt`:

```kotlin
    if (selectedMarkerId != null) {
        val landmark = viewModel.getLandmarkForMarker(selectedMarkerId!!)
        LandmarkBottomSheet(
            landmark = landmark,
            imageUrl = landmark?.let { viewModel.imageUrlFor(it) },
            onDismiss = { selectedMarkerId = null },
        )
    }
```

In `ui/trailtours/TrailTourScreen.kt`:

```kotlin
    if (sheetLandmarkId != null) {
        val landmark = viewModel.getLandmarkById(sheetLandmarkId!!)
        LandmarkBottomSheet(
            landmark = landmark,
            imageUrl = landmark?.let { viewModel.imageUrlFor(it) },
            onDismiss = { sheetLandmarkId = null },
        )
    }
```

- [ ] **Step 4: Build**

```bash
cd /Users/steve/projects/warrington-beacons/android && ./gradlew assembleDebug test
```

Expected: `BUILD SUCCESSFUL`.

- [ ] **Step 5: Verify both image directories load**

```bash
cd /Users/steve/projects/warrington-beacons/android && ./gradlew installDebug
```

On the Park Map tab, tap a Lions Pride marker (e.g. "Yellow Trail") and a US202 marker (e.g. "Wetlands"). Expected: both sheets show a photo, not a blank 16:9 box.

- [ ] **Step 6: Commit**

```bash
cd /Users/steve/projects/warrington-beacons
git add -A android
git commit -m "Load landmark photos from either location's image directory"
```

---

### Task 9: Location-neutral Welcome and About copy

**Files:**
- Modify: `android/app/src/main/java/org/warringtontownship/parks/android/ui/welcome/WelcomeScreen.kt`
- Modify: `android/app/src/main/java/org/warringtontownship/parks/android/ui/about/AboutScreen.kt`
- Create: `android/app/src/main/java/org/warringtontownship/parks/android/ui/common/LocationsViewModel.kt`

**Interfaces:**
- Consumes: `TrailRepository.getLocations()` and `loadData()` from Task 4.
- Produces: `LocationsViewModel` with `val locations: StateFlow<List<Location>>`; `WelcomeScreen(onContinue: () -> Unit, viewModel: LocationsViewModel = hiltViewModel())`; `AboutScreen(viewModel: LocationsViewModel = hiltViewModel())`.

Both screens currently open with "Welcome to the US-202 to Bradford Dam connector trail" and hardcode one trailhead address. Addresses come from the data file so a third park needs no code change. Both screens must still render before the network load finishes — an empty location list simply shows no address block.

- [ ] **Step 1: Add the shared ViewModel**

```kotlin
package org.warringtontownship.parks.android.ui.common

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import android.util.Log
import org.warringtontownship.parks.android.data.model.Location
import org.warringtontownship.parks.android.data.repository.TrailRepository
import javax.inject.Inject

/** Supplies the location names and addresses shown on the Welcome and About screens. */
@HiltViewModel
class LocationsViewModel @Inject constructor(
    private val trailRepository: TrailRepository,
) : ViewModel() {

    private val _locations = MutableStateFlow<List<Location>>(emptyList())
    val locations: StateFlow<List<Location>> = _locations.asStateFlow()

    init {
        viewModelScope.launch {
            try {
                trailRepository.loadData()
                _locations.value = trailRepository.getLocations()
            } catch (e: Exception) {
                // Offline on first launch: the screen renders without the address block.
                Log.e("LocationsVM", "Unable to load locations", e)
            }
        }
    }
}
```

- [ ] **Step 2: Update the Welcome screen**

In `ui/welcome/WelcomeScreen.kt`, change the signature to

```kotlin
@Composable
fun WelcomeScreen(
    onContinue: () -> Unit,
    viewModel: LocationsViewModel = hiltViewModel(),
) {
    val locations by viewModel.locations.collectAsStateWithLifecycle()
```

(adding imports `androidx.hilt.navigation.compose.hiltViewModel`, `androidx.lifecycle.compose.collectAsStateWithLifecycle`, `androidx.compose.runtime.getValue`, `org.warringtontownship.parks.android.ui.common.LocationsViewModel`), change the headline text to

```kotlin
            text = "Welcome to Warrington's parks and trails",
```

and replace the three hardcoded address `Text`s ("Trailhead" / "Stump Road across from 785" / "Chalfont, PA 18914") with

```kotlin
        locations.forEach { location ->
            Text(
                text = location.name,
                style = MaterialTheme.typography.bodyLarge,
                color = MaterialTheme.colorScheme.primary,
            )
            Text(
                text = location.address,
                style = MaterialTheme.typography.bodyLarge,
            )
            Spacer(modifier = Modifier.height(8.dp))
        }
```

Leave the photo, the three explanatory paragraphs and the Continue button exactly as they are.

- [ ] **Step 3: Update the About screen**

Apply the same three changes to `ui/about/AboutScreen.kt`: signature `fun AboutScreen(viewModel: LocationsViewModel = hiltViewModel())` with the same collected state, the same headline text, and the same `locations.forEach` block replacing the same three hardcoded address lines. The `TopAppBar`, photo and paragraphs stay unchanged. `AboutScreen()` is called with no arguments from `navigation/AppNavHost.kt`; the default parameter keeps that call site working.

- [ ] **Step 4: Build**

```bash
cd /Users/steve/projects/warrington-beacons/android && ./gradlew assembleDebug test
```

Expected: `BUILD SUCCESSFUL`.

- [ ] **Step 5: Verify on a fresh install**

```bash
cd /Users/steve/projects/warrington-beacons/android
adb uninstall org.warringtontownship.parks.android || true
./gradlew installDebug
```

Expected: the Welcome screen (shown because prefs were cleared by the uninstall) reads "Welcome to Warrington's parks and trails" and lists both Lions Pride Park / 3129 Bradley Rd, Warrington, PA 18976 and US202 to Bradford Dam / Stump Road across from 785, Chalfont, PA 18914. The About tab shows the same.

- [ ] **Step 6: Commit**

```bash
cd /Users/steve/projects/warrington-beacons
git add -A android
git commit -m "Show both locations on the Welcome and About screens"
```

---

### Task 10: End-to-end beacon verification and documentation

**Files:**
- Modify: `README.md`
- Modify: `android/README.md`
- Modify: `android/HOW_IT_WORKS.md`
- Modify: `android/REPORT.md`
- Modify: `android/simulate_beacon.sh`

**Interfaces:**
- Consumes: everything above.
- Produces: no code interfaces — this task proves the merged app works end to end and leaves the docs accurate.

- [ ] **Step 1: Verify a Lions Pride beacon drives the UI**

```bash
cd /Users/steve/projects/warrington-beacons/android
./gradlew installDebug
./simulate_beacon.sh 1002 2.0
```

Open the Park Map tab first, then send the broadcast. Expected: the Yellow Trail landmark sheet opens with its photo. (Minor 1002 is a Lions Pride landmark — before this change the app could not have matched it.)

- [ ] **Step 2: Verify a US202 beacon still works, and that the two do not interfere**

```bash
cd /Users/steve/projects/warrington-beacons/android
./simulate_beacon.sh 4:1.0
./simulate_beacon.sh 1002:1.5 4:3.0
```

Expected: the first opens the US202 landmark with id 4; the second — beacons from both locations in range at once — selects landmark 1002, the nearer one.

- [ ] **Step 3: Verify the Settings beacon list names landmarks from both locations**

```bash
cd /Users/steve/projects/warrington-beacons/android
./simulate_beacon.sh 1002:1.5 4:3.0
```

Open the Settings tab. Expected: "Nearby Landmarks" lists two rows with real landmark names — no "Unknown (1002)".

- [ ] **Step 4: Update the simulate script's documentation**

In `android/simulate_beacon.sh`, update the two comment lines that describe the data set:

```bash
#   ./simulate_beacon.sh walk [seconds-per-stop]     # auto-walk US202 landmarks 1..16 (Ctrl-C stops)
#
# Landmark ids: US202 1-16 (trail stops) and 4001 (trailhead); Lions Pride Park 1002-3008.
```

- [ ] **Step 5: Update the READMEs**

In the top-level `README.md`, under "Hosted files (`server/`)", state that `server/warrington-trails.json` is the source of truth for the Android app and covers both locations, that `server/us-202/us202trail-v2.json` is kept unchanged because the shipped iOS app reads it, and that until iOS migrates a data edit must be made in both files. Update the "Moving to a new host" list: the Android hardcoded URLs are now the Retrofit base URL in `android/app/src/main/java/org/warringtontownship/parks/android/di/AppModule.kt` and `IMAGE_BASE_URL` in `.../data/repository/TrailRepository.kt`. Update the `android/` bullet in "Layout" to say the app covers both Lions Pride Park and the US202 to Bradford Dam trail.

In `android/README.md`, change the app name to "Warrington Parks & Trails", point the data-file description at `warrington-trails.json`, and note under "Beacon Programming" that both major codes are live in one app (17 Lions Pride, 20 US202) rather than one per app.

- [ ] **Step 6: Update the architecture docs**

Read `android/HOW_IT_WORKS.md` and `android/REPORT.md` and correct every place that describes the app as single-site: the package name, the data file and its shape, `TrailRepository`'s API, the single-region beacon scan, and the single-polyline map. Do not rewrite sections that are still accurate.

- [ ] **Step 7: Final check**

```bash
cd /Users/steve/projects/warrington-beacons/android && ./gradlew clean assembleDebug test
grep -rn "us202\|US202\|US 202\|ConnectorData\|ConnectorApiService" app/src README.md HOW_IT_WORKS.md ../README.md
```

Expected: `BUILD SUCCESSFUL`, and the only `grep` hits are legitimate references to the US202 *trail* by name or to the frozen `us-202/us202trail-v2.json` path — no stale package names, no references to the deleted `ConnectorData` / `ConnectorApiService` types.

- [ ] **Step 8: Commit**

```bash
cd /Users/steve/projects/warrington-beacons
git add -A
git commit -m "Update docs for the merged two-location app"
```
