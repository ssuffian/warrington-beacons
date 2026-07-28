# Spoken Landmarks and Accessible Browsing Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the Android app speak a landmark's name and description when a walker reaches it — including with the phone pocketed and the screen off — and make all 40 landmarks browsable without sight.

**Architecture:** A new `LandmarkAnnouncer` singleton observes `BeaconScanner.detectedBeacons`, filters raw detections through an `AnnouncementGate` that ports iOS's four debounce rules, and emits gated "this landmark is now current" events. Screens consume those events instead of raw closest-beacon values, so the map sheet and tour auto-advance inherit the same debouncing. The announcer separately posts a notification and drives a TalkBack announcement when announcements are enabled. `BeaconScanner` wraps its ranging in AltBeacon's foreground service so scanning survives a locked screen.

**Tech Stack:** Kotlin, Jetpack Compose, Hilt, AltBeacon android-beacon-library 2.20.6, NotificationCompat, JUnit 4.

## Global Constraints

- Spec: `docs/superpowers/specs/2026-07-28-spoken-landmarks-and-accessible-browsing-design.md`.
- Package root: `org.warringtontownship.parks.android`. Run all Gradle commands from `android/`.
- Debounce constants are copied from iOS unchanged and must not be retuned: distance gate `30.0` m, `MIN_SEEN_COUNT = 3`, cooldown `60` seconds.
- SharedPreferences file name is `warrington_prefs`. Keys: existing `welcome_seen`, `simplified_text`; new `announcements_enabled`, default **true**.
- Notification channels: `landmark_alerts` (IMPORTANCE_HIGH, sound) and `trail_scanning` (IMPORTANCE_LOW, silent).
- Announcement body uses `landmark.description` when Simplified Text is on, `landmark.longDescription` when off — matching what the visible sheet shows.
- `minSdk` is 31, `targetSdk` 36. `POST_NOTIFICATIONS` is implicitly granted on 31–32 and must be requested on 33+.
- AltBeacon declares `FOREGROUND_SERVICE_LOCATION` and `foregroundServiceType="location"` itself; the app must add the base `FOREGROUND_SERVICE` permission.
- 21 unit tests pass at the start of this plan. Never leave them failing.
- Do not modify anything under `server/`, and do not modify `android/local.properties`.

---

## File Structure

**Created:**

| Path (under `android/app/src/`) | Responsibility |
|---|---|
| `main/.../data/prefs/AppPreferences.kt` | One typed, observable home for the three user settings |
| `main/.../beacon/AnnouncementGate.kt` | The four debounce rules, pure and clock-injected |
| `main/.../beacon/LandmarkAnnouncer.kt` | Raw detections → gated landmark events + notification |
| `main/.../beacon/AnnouncementNotifier.kt` | Notification channels and posting; the only Android-notification code |
| `main/.../ui/landmarks/LandmarksScreen.kt` | The Landmarks tab list |
| `main/.../ui/landmarks/LandmarksViewModel.kt` | Landmarks grouped by location |
| `test/.../beacon/AnnouncementGateTest.kt` | Gate rules |
| `test/.../beacon/AnnouncementTextTest.kt` | Announcement text selection |

**Modified:** `beacon/BeaconScanner.kt` (foreground service), `ui/parkmap/ParkMapViewModel.kt` + `ParkMapScreen.kt` (gated events, status toggle, permission), `ui/trailtours/TrailToursViewModel.kt` + `TrailDetailScreen.kt` (gated events, direction copy), `ui/common/LandmarkBottomSheet.kt` (announce, alt text, headings), `ui/settings/SettingsViewModel.kt` + `SettingsScreen.kt` (prefs, feet), `ui/welcome/WelcomeScreen.kt` (Simplified Text copy), `ui/trailtours/TrailToursScreen.kt` (heading semantics), `navigation/BottomNavItem.kt` + `NavRoutes.kt` + `AppNavHost.kt` (Landmarks tab), `WarringtonParksApp.kt` (channels), `AndroidManifest.xml` (permissions), `data/repository/TrailRepository.kt` (landmarks grouped by location).

---

### Task 1: One home for user settings

**Files:**
- Create: `android/app/src/main/java/org/warringtontownship/parks/android/data/prefs/AppPreferences.kt`
- Modify: `android/app/src/main/java/org/warringtontownship/parks/android/ui/settings/SettingsViewModel.kt`
- Modify: `android/app/src/main/java/org/warringtontownship/parks/android/MainActivity.kt`

**Interfaces:**
- Consumes: nothing.
- Produces:
  ```kotlin
  @Singleton
  class AppPreferences @Inject constructor(@ApplicationContext context: Context) {
      val simplifiedText: StateFlow<Boolean>          // default false
      val announcementsEnabled: StateFlow<Boolean>    // default true
      fun setSimplifiedText(enabled: Boolean)
      fun setAnnouncementsEnabled(enabled: Boolean)
      fun isWelcomeSeen(): Boolean
      fun setWelcomeSeen()
  }
  ```

Three places read `warrington_prefs` ad hoc today, and the announcer needs
`simplified_text` from outside a composable while the new toggle needs to be
observable. One injected holder replaces all of it.

This class is a thin wrapper over `SharedPreferences` with no logic worth unit
testing — Android's `SharedPreferences` needs an instrumented or Robolectric
environment, and neither is set up here. Its behaviour is covered by the on-device
pass in Task 11. The logic that *does* deserve tests lives in Tasks 2 and 3.

Deliberately **not** migrated: `LandmarkBottomSheet` keeps reading
`simplified_text` from `SharedPreferences` directly. It is a composable with no
ViewModel of its own and three call sites, so injecting or threading the value
through all of them costs more than the duplication saves. Both readers use the
same file name and key, so they cannot disagree.

- [ ] **Step 1: Write the class**

```kotlin
package org.warringtontownship.parks.android.data.prefs

import android.content.Context
import android.content.SharedPreferences
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import javax.inject.Inject
import javax.inject.Singleton

/**
 * The app's user settings, in one place. Exposed as flows because the announcements
 * toggle has to update the Park Map's status control as soon as it changes, and the
 * announcer reads Simplified Text from outside composition.
 */
@Singleton
class AppPreferences @Inject constructor(
    @ApplicationContext context: Context,
) {
    private val prefs: SharedPreferences =
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    private val _simplifiedText = MutableStateFlow(prefs.getBoolean(KEY_SIMPLIFIED_TEXT, false))
    val simplifiedText: StateFlow<Boolean> = _simplifiedText.asStateFlow()

    // Defaults on: this is what the app already did, and silence should not need
    // opting in.
    private val _announcementsEnabled =
        MutableStateFlow(prefs.getBoolean(KEY_ANNOUNCEMENTS_ENABLED, true))
    val announcementsEnabled: StateFlow<Boolean> = _announcementsEnabled.asStateFlow()

    fun setSimplifiedText(enabled: Boolean) {
        prefs.edit().putBoolean(KEY_SIMPLIFIED_TEXT, enabled).apply()
        _simplifiedText.value = enabled
    }

    fun setAnnouncementsEnabled(enabled: Boolean) {
        prefs.edit().putBoolean(KEY_ANNOUNCEMENTS_ENABLED, enabled).apply()
        _announcementsEnabled.value = enabled
    }

    fun isWelcomeSeen(): Boolean = prefs.getBoolean(KEY_WELCOME_SEEN, false)

    fun setWelcomeSeen() {
        prefs.edit().putBoolean(KEY_WELCOME_SEEN, true).apply()
    }

    private companion object {
        const val PREFS_NAME = "warrington_prefs"
        const val KEY_SIMPLIFIED_TEXT = "simplified_text"
        const val KEY_ANNOUNCEMENTS_ENABLED = "announcements_enabled"
        const val KEY_WELCOME_SEEN = "welcome_seen"
    }
}
```

- [ ] **Step 2: Migrate SettingsViewModel**

In `ui/settings/SettingsViewModel.kt`, inject `private val appPreferences: AppPreferences`,
delete the `application`/`prefs` constructor parameter and field along with the local
`_simplifiedText`, and replace them:

```kotlin
    val simplifiedText: StateFlow<Boolean> = appPreferences.simplifiedText

    fun setSimplifiedText(enabled: Boolean) = appPreferences.setSimplifiedText(enabled)
```

Remove the now-unused `android.app.Application` and `android.content.Context` imports.

- [ ] **Step 3: Migrate MainActivity**

`MainActivity` reads the welcome flag directly. Replace the `prefs` block inside
`setContent` with an injected field on the activity:

```kotlin
    @Inject
    lateinit var appPreferences: AppPreferences
```

and inside `setContent`:

```kotlin
            var showWelcome by remember {
                mutableStateOf(!appPreferences.isWelcomeSeen())
            }
```

with the Continue callback calling `appPreferences.setWelcomeSeen()` before
`showWelcome = false`. Add imports `javax.inject.Inject` and
`org.warringtontownship.parks.android.data.prefs.AppPreferences`; drop
`android.content.Context` if nothing else uses it. Field injection works because
`MainActivity` is already `@AndroidEntryPoint`.

- [ ] **Step 4: Build**

```bash
cd /Users/steve/projects/warrington-beacons/android && ./gradlew test assembleDebug
```

Expected: `BUILD SUCCESSFUL`, 21 tests still passing.

- [ ] **Step 5: Commit**

```bash
cd /Users/steve/projects/warrington-beacons
git add -A android
git commit -m "Centralize user settings in AppPreferences"
```

---

### Task 2: The debounce gate

**Files:**
- Create: `android/app/src/test/java/org/warringtontownship/parks/android/beacon/AnnouncementGateTest.kt`
- Create: `android/app/src/main/java/org/warringtontownship/parks/android/beacon/AnnouncementGate.kt`

**Interfaces:**
- Consumes: nothing.
- Produces:
  ```kotlin
  internal const val MAX_ANNOUNCE_DISTANCE_METERS = 30.0
  internal const val MIN_SEEN_COUNT = 3
  internal const val COOLDOWN_MILLIS = 60_000L

  internal class AnnouncementGate(private val clock: () -> Long) {
      fun shouldAnnounce(minorCode: Int, distanceMeters: Double): Boolean
      fun reset()
  }
  ```

Today any beacon at any distance fires immediately and then that landmark never
fires again. This is both halves of the fix, ported from iOS `BeaconScanner.swift`.

- [ ] **Step 1: Write the failing test**

```kotlin
package org.warringtontownship.parks.android.beacon

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AnnouncementGateTest {

    private var now = 0L
    private fun gate() = AnnouncementGate(clock = { now })

    /** Pass the distance gate [times] times; returns whether the last call announced. */
    private fun sight(gate: AnnouncementGate, minor: Int, times: Int, distance: Double = 5.0): Boolean {
        var announced = false
        repeat(times) { announced = gate.shouldAnnounce(minor, distance) }
        return announced
    }

    @Test
    fun `announces only on the third sighting`() {
        val gate = gate()
        assertFalse(gate.shouldAnnounce(7, 5.0))
        assertFalse(gate.shouldAnnounce(7, 5.0))
        assertTrue(gate.shouldAnnounce(7, 5.0))
    }

    @Test
    fun `ignores beacons beyond thirty metres however many times they are seen`() {
        val gate = gate()
        assertFalse(sight(gate, 7, times = 10, distance = 30.0))
        assertFalse(sight(gate, 7, times = 10, distance = 80.0))
    }

    @Test
    fun `ignores negative distances, which altbeacon uses for unknown`() {
        val gate = gate()
        assertFalse(sight(gate, 7, times = 10, distance = -1.0))
    }

    @Test
    fun `refuses to announce the same landmark twice in a row`() {
        val gate = gate()
        assertTrue(sight(gate, 7, times = 3))
        now += 120_000
        assertFalse(sight(gate, 7, times = 3))
    }

    @Test
    fun `announces a different landmark immediately after another`() {
        val gate = gate()
        assertTrue(sight(gate, 7, times = 3))
        assertTrue(sight(gate, 8, times = 3))
    }

    @Test
    fun `re-announces a landmark after the cooldown once another has intervened`() {
        val gate = gate()
        assertTrue(sight(gate, 7, times = 3))
        assertTrue(sight(gate, 8, times = 3))
        // 7 is no longer the last announced, but its own cooldown is still running.
        now += 59_000
        assertFalse(sight(gate, 7, times = 3))
        now += 2_000
        assertTrue(sight(gate, 7, times = 3))
    }

    @Test
    fun `reset clears counts, cooldowns and the last announced landmark`() {
        val gate = gate()
        assertTrue(sight(gate, 7, times = 3))
        gate.reset()
        assertTrue(sight(gate, 7, times = 3))
    }

    @Test
    fun `sightings that fail the distance gate do not count toward confirmation`() {
        val gate = gate()
        gate.shouldAnnounce(7, 80.0)
        gate.shouldAnnounce(7, 80.0)
        assertFalse(gate.shouldAnnounce(7, 5.0))
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
cd /Users/steve/projects/warrington-beacons/android && ./gradlew test
```

Expected: compilation failure, `Unresolved reference 'AnnouncementGate'`.

- [ ] **Step 3: Implement the gate**

```kotlin
package org.warringtontownship.parks.android.beacon

// Copied from the iOS app's BeaconScanner.swift, where they were derived from real
// trail behaviour. Do not retune without walking a trail.
internal const val MAX_ANNOUNCE_DISTANCE_METERS = 30.0
internal const val MIN_SEEN_COUNT = 3
internal const val COOLDOWN_MILLIS = 60_000L

/**
 * The rules that decide whether a ranged beacon is worth telling the user about:
 *
 *  - only beacons within [MAX_ANNOUNCE_DISTANCE_METERS] (a negative distance means
 *    altbeacon could not estimate one)
 *  - seen [MIN_SEEN_COUNT] times, so a single stray reading can't fire
 *  - never the landmark announced immediately before
 *  - at most once per [COOLDOWN_MILLIS] per landmark, which is also what lets a
 *    user who dismissed a landmark hear it again by lingering
 *
 * [clock] is injected so cooldown behaviour can be tested without sleeping.
 * Not thread-safe: callers serialise access (the announcer collects on a single
 * coroutine).
 */
internal class AnnouncementGate(private val clock: () -> Long) {

    private val seenCount = mutableMapOf<Int, Int>()
    private val lastAnnouncedAt = mutableMapOf<Int, Long>()
    private var lastAnnouncedMinor: Int? = null

    fun shouldAnnounce(minorCode: Int, distanceMeters: Double): Boolean {
        if (distanceMeters < 0.0 || distanceMeters >= MAX_ANNOUNCE_DISTANCE_METERS) return false

        val count = (seenCount[minorCode] ?: 0) + 1
        seenCount[minorCode] = count
        if (count < MIN_SEEN_COUNT) return false

        if (lastAnnouncedMinor == minorCode) return false

        val now = clock()
        val previous = lastAnnouncedAt[minorCode]
        if (previous != null && now - previous < COOLDOWN_MILLIS) return false

        lastAnnouncedAt[minorCode] = now
        lastAnnouncedMinor = minorCode
        // Matches iOS clearing beaconSeenCount after a notification, so the next
        // announcement needs a fresh run of sightings.
        seenCount.clear()
        return true
    }

    fun reset() {
        seenCount.clear()
        lastAnnouncedAt.clear()
        lastAnnouncedMinor = null
    }
}
```

- [ ] **Step 4: Run the tests**

```bash
cd /Users/steve/projects/warrington-beacons/android && ./gradlew test
```

Expected: `BUILD SUCCESSFUL`, 29 tests passing (21 existing + 8 new).

- [ ] **Step 5: Commit**

```bash
cd /Users/steve/projects/warrington-beacons
git add -A android
git commit -m "Add iOS-derived debounce gate for landmark announcements"
```

---

### Task 3: Announcement text

**Files:**
- Create: `android/app/src/test/java/org/warringtontownship/parks/android/beacon/AnnouncementTextTest.kt`
- Create: `android/app/src/main/java/org/warringtontownship/parks/android/beacon/AnnouncementNotifier.kt`
- Modify: `android/app/src/main/java/org/warringtontownship/parks/android/WarringtonParksApp.kt`
- Modify: `android/app/src/main/AndroidManifest.xml`

**Interfaces:**
- Consumes: `Landmark` from `data/model/TrailsData.kt` (fields `name`, `description`, `longDescription`).
- Produces:
  ```kotlin
  data class AnnouncementText(val title: String, val body: String)
  internal fun announcementText(landmark: Landmark, simplifiedText: Boolean): AnnouncementText

  const val CHANNEL_LANDMARK_ALERTS = "landmark_alerts"
  const val CHANNEL_TRAIL_SCANNING = "trail_scanning"

  @Singleton
  class AnnouncementNotifier @Inject constructor(@ApplicationContext context: Context) {
      fun createChannels()
      fun notifyLandmark(text: AnnouncementText)
      fun scanningNotification(): Notification
      companion object { const val SCANNING_NOTIFICATION_ID = 1001 }
  }
  ```

- [ ] **Step 1: Write the failing test**

```kotlin
package org.warringtontownship.parks.android.beacon

import org.junit.Assert.assertEquals
import org.junit.Test
import org.warringtontownship.parks.android.data.model.Coordinates
import org.warringtontownship.parks.android.data.model.Landmark

class AnnouncementTextTest {

    private val landmark = Landmark(
        id = 1002,
        location = "lions-pride-park",
        imagePath = "lions-pride-park/images/Yellow_trail.jpg",
        coordinates = Coordinates(40.24613, -75.177778),
        name = "Yellow Trail",
        category = "Trail",
        description = "A paved loop around the park.",
        longDescription = "The yellow trail is a 0.4-mile paved loop around the park and connects with the trail around IPW.",
        imageAlt = "Picture of Yellow Trail",
    )

    @Test
    fun `the title is always the landmark name`() {
        assertEquals("Yellow Trail", announcementText(landmark, simplifiedText = false).title)
        assertEquals("Yellow Trail", announcementText(landmark, simplifiedText = true).title)
    }

    @Test
    fun `simplified text speaks the short description`() {
        assertEquals(
            "A paved loop around the park.",
            announcementText(landmark, simplifiedText = true).body,
        )
    }

    @Test
    fun `full text speaks the long description, matching the visible sheet`() {
        assertEquals(landmark.longDescription, announcementText(landmark, simplifiedText = false).body)
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
cd /Users/steve/projects/warrington-beacons/android && ./gradlew test
```

Expected: compilation failure, `Unresolved reference 'announcementText'`.

- [ ] **Step 3: Write the notifier and the text function**

Create `beacon/AnnouncementNotifier.kt`:

```kotlin
package org.warringtontownship.parks.android.beacon

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.app.PendingIntent
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import dagger.hilt.android.qualifiers.ApplicationContext
import org.warringtontownship.parks.android.MainActivity
import org.warringtontownship.parks.android.R
import org.warringtontownship.parks.android.data.model.Landmark
import javax.inject.Inject
import javax.inject.Singleton

data class AnnouncementText(val title: String, val body: String)

/**
 * What the user hears. The body deliberately matches what the visible sheet shows,
 * so a sighted companion reading the screen and a TalkBack user hearing it get the
 * same words.
 */
internal fun announcementText(landmark: Landmark, simplifiedText: Boolean): AnnouncementText =
    AnnouncementText(
        title = landmark.name,
        body = if (simplifiedText) landmark.description else landmark.longDescription,
    )

const val CHANNEL_LANDMARK_ALERTS = "landmark_alerts"
const val CHANNEL_TRAIL_SCANNING = "trail_scanning"

/**
 * The only place that talks to Android's notification system.
 *
 * Landmark alerts carry the full description in BigTextStyle rather than a
 * one-line summary, because TalkBack reads what the notification contains and a
 * truncated line would defeat the point: this is the channel that reaches a user
 * whose phone is in a pocket.
 */
@Singleton
class AnnouncementNotifier @Inject constructor(
    @ApplicationContext private val context: Context,
) {
    private val manager = NotificationManagerCompat.from(context)

    fun createChannels() {
        manager.createNotificationChannel(
            NotificationChannel(
                CHANNEL_LANDMARK_ALERTS,
                "Landmark alerts",
                NotificationManager.IMPORTANCE_HIGH,
            ).apply {
                description = "Announces a point of interest when you reach it"
            }
        )
        manager.createNotificationChannel(
            NotificationChannel(
                CHANNEL_TRAIL_SCANNING,
                "Trail scanning",
                NotificationManager.IMPORTANCE_LOW,
            ).apply {
                description = "Shown while the app is listening for trail landmarks"
            }
        )
    }

    fun notifyLandmark(text: AnnouncementText) {
        val notification = NotificationCompat.Builder(context, CHANNEL_LANDMARK_ALERTS)
            .setSmallIcon(R.drawable.poi_marker)
            .setContentTitle(text.title)
            .setContentText(text.body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(text.body))
            .setContentIntent(contentIntent())
            .setAutoCancel(true)
            .setCategory(NotificationCompat.CATEGORY_NAVIGATION)
            .build()
        // A denied POST_NOTIFICATIONS permission makes this a no-op rather than a
        // crash; in-app announcements still reach the user.
        if (manager.areNotificationsEnabled()) {
            manager.notify(LANDMARK_NOTIFICATION_ID, notification)
        }
    }

    fun scanningNotification(): Notification =
        NotificationCompat.Builder(context, CHANNEL_TRAIL_SCANNING)
            .setSmallIcon(R.drawable.poi_marker)
            .setContentTitle("Listening for trail landmarks")
            .setContentText("You'll hear about points of interest as you reach them.")
            .setContentIntent(contentIntent())
            .setOngoing(true)
            .setSilent(true)
            .build()

    private fun contentIntent(): PendingIntent =
        PendingIntent.getActivity(
            context,
            0,
            Intent(context, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

    companion object {
        const val SCANNING_NOTIFICATION_ID = 1001
        private const val LANDMARK_NOTIFICATION_ID = 1002
    }
}
```

`NotificationManagerCompat.notify` requires the permission on API 33+, so the
`areNotificationsEnabled()` guard is what keeps a denied permission from throwing.

- [ ] **Step 4: Create the channels at startup and declare permissions**

`WarringtonParksApp.kt` becomes:

```kotlin
package org.warringtontownship.parks.android

import android.app.Application
import dagger.hilt.android.HiltAndroidApp
import org.warringtontownship.parks.android.beacon.AnnouncementNotifier
import javax.inject.Inject

@HiltAndroidApp
class WarringtonParksApp : Application() {

    @Inject
    lateinit var announcementNotifier: AnnouncementNotifier

    override fun onCreate() {
        super.onCreate()
        announcementNotifier.createChannels()
    }
}
```

In `app/src/main/AndroidManifest.xml`, add alongside the existing permissions:

```xml
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
```

AltBeacon merges `FOREGROUND_SERVICE_LOCATION` and the `foregroundServiceType`
itself, so neither is declared here.

- [ ] **Step 5: Run the tests and build**

```bash
cd /Users/steve/projects/warrington-beacons/android && ./gradlew test assembleDebug
```

Expected: `BUILD SUCCESSFUL`, 32 tests passing.

- [ ] **Step 6: Commit**

```bash
cd /Users/steve/projects/warrington-beacons
git add -A android
git commit -m "Add landmark alert notifications and announcement text"
```

---

### Task 4: The announcer

**Files:**
- Create: `android/app/src/main/java/org/warringtontownship/parks/android/beacon/LandmarkAnnouncer.kt`
- Modify: `android/app/src/main/java/org/warringtontownship/parks/android/ui/parkmap/ParkMapViewModel.kt`
- Modify: `android/app/src/main/java/org/warringtontownship/parks/android/ui/trailtours/TrailToursViewModel.kt`

**Interfaces:**
- Consumes: `AnnouncementGate`, `announcementText`, `AnnouncementNotifier`, `AppPreferences`, `BeaconScanner.detectedBeacons`, `TrailRepository.getLandmarkById`.
- Produces:
  ```kotlin
  @Singleton
  class LandmarkAnnouncer @Inject constructor(...) {
      val currentLandmark: SharedFlow<Landmark>   // gated; replay = 0
      fun start(scope: CoroutineScope)
      fun textFor(landmark: Landmark): AnnouncementText
  }
  ```
  `ParkMapViewModel.navigationEvent` keeps its type `SharedFlow<Int>` but is now fed
  from `currentLandmark`, and gains `val lastAnnouncement: AnnouncementText?`-style
  access via `announcementTextFor(landmarkId: Int): AnnouncementText?`.
  `TrailToursViewModel.beaconEvent` likewise keeps `SharedFlow<Int>`.

The announcer is the single owner of "a landmark became current". Both the map
sheet and the tour's auto-advance consume its gated events, so all three iOS
debounce behaviours apply to navigation as well as speech — which is what makes a
dismissed landmark recoverable after 60 seconds.

- [ ] **Step 1: Write the announcer**

```kotlin
package org.warringtontownship.parks.android.beacon

import android.util.Log
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.launch
import org.warringtontownship.parks.android.data.model.Landmark
import org.warringtontownship.parks.android.data.prefs.AppPreferences
import org.warringtontownship.parks.android.data.repository.TrailRepository
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Turns raw beacon detections into "the user has arrived at this landmark", and
 * tells them about it.
 *
 * Screens consume [currentLandmark] rather than the scanner's raw closest-beacon
 * value, so the debounce rules in [AnnouncementGate] govern the map sheet and the
 * tour's auto-advance too, not just the spoken announcement.
 *
 * Announcing is separately conditional on the user's setting: a Trail Tour still
 * advances silently when announcements are off, because auto-advance is navigation
 * the user asked for rather than the app talking to them.
 */
@Singleton
class LandmarkAnnouncer @Inject constructor(
    private val beaconScanner: BeaconScanner,
    private val trailRepository: TrailRepository,
    private val notifier: AnnouncementNotifier,
    private val appPreferences: AppPreferences,
) {
    private val gate = AnnouncementGate(clock = { System.currentTimeMillis() })

    private val _currentLandmark = MutableSharedFlow<Landmark>()
    val currentLandmark: SharedFlow<Landmark> = _currentLandmark.asSharedFlow()

    private var started = false

    /**
     * Begins observing detections. Called once from the first ViewModel that needs
     * announcements; the guard keeps repeat calls from stacking collectors, and the
     * scope outlives any single screen because this is a singleton.
     */
    fun start(scope: CoroutineScope) {
        if (started) return
        started = true
        scope.launch {
            beaconScanner.detectedBeacons.collect { detections ->
                val closest = detections.minByOrNull { it.distance }
                if (closest == null) {
                    gate.reset()
                    return@collect
                }
                if (!gate.shouldAnnounce(closest.minorCode, closest.distance)) return@collect
                val landmark = trailRepository.getLandmarkById(closest.minorCode)
                if (landmark == null) {
                    Log.w("LandmarkAnnouncer", "No landmark for minor ${closest.minorCode}")
                    return@collect
                }
                _currentLandmark.emit(landmark)
                if (appPreferences.announcementsEnabled.value) {
                    notifier.notifyLandmark(textFor(landmark))
                }
            }
        }
    }

    fun textFor(landmark: Landmark): AnnouncementText =
        announcementText(landmark, appPreferences.simplifiedText.value)
}
```

- [ ] **Step 2: Feed the Park Map from the announcer**

In `ui/parkmap/ParkMapViewModel.kt`, inject `private val announcer: LandmarkAnnouncer`,
then replace `observeBeacons()` with:

```kotlin
    private fun observeBeacons() {
        announcer.start(viewModelScope)
        viewModelScope.launch {
            announcer.currentLandmark.collect { landmark ->
                _navigationEvent.emit(landmark.id)
            }
        }
    }
```

Delete the now-unused `filterNotNull` and `distinctUntilChanged` imports — the gate
subsumes both. Add:

```kotlin
    fun announcementTextFor(landmarkId: Int): AnnouncementText? =
        trailRepository.getLandmarkById(landmarkId)?.let { announcer.textFor(it) }
```

with imports `org.warringtontownship.parks.android.beacon.AnnouncementText` and
`org.warringtontownship.parks.android.beacon.LandmarkAnnouncer`.

- [ ] **Step 3: Feed the tour from the announcer**

In `ui/trailtours/TrailToursViewModel.kt`, inject `private val announcer: LandmarkAnnouncer`
and replace `observeBeacons()` with:

```kotlin
    private fun observeBeacons() {
        announcer.start(viewModelScope)
        viewModelScope.launch {
            announcer.currentLandmark.collect { landmark ->
                _beaconEvent.emit(landmark.id)
            }
        }
    }
```

Delete the unused `filterNotNull` import. Leave `getClosestBeaconMinorCode()` as it
is — `TrailTourScreen` uses it to pick a starting stop, which is a one-off read
rather than an arrival event.

- [ ] **Step 4: Build and test**

```bash
cd /Users/steve/projects/warrington-beacons/android && ./gradlew test assembleDebug
```

Expected: `BUILD SUCCESSFUL`, 32 tests passing.

- [ ] **Step 5: Commit**

```bash
cd /Users/steve/projects/warrington-beacons
git add -A android
git commit -m "Route beacon arrivals through LandmarkAnnouncer"
```

---

### Task 5: Speak it in the app

**Files:**
- Modify: `android/app/src/main/java/org/warringtontownship/parks/android/ui/common/LandmarkBottomSheet.kt`
- Modify: `android/app/src/main/java/org/warringtontownship/parks/android/ui/parkmap/ParkMapScreen.kt`
- Modify: `android/app/src/main/java/org/warringtontownship/parks/android/ui/trailtours/TrailTourScreen.kt`

**Interfaces:**
- Consumes: `ParkMapViewModel.announcementTextFor(landmarkId)`, `AnnouncementText`.
- Produces: `LandmarkBottomSheet(landmark: Landmark?, imageUrl: String?, announceOnOpen: String?, onDismiss: () -> Unit)`.

A notification only speaks if TalkBack reads notifications; when the user is
holding the phone with the sheet in front of them, the reliable path is an explicit
announcement. Beacon-opened sheets announce; tapped ones do not, because TalkBack
already narrates a tap the user made.

- [ ] **Step 1: Announce from the sheet**

In `ui/common/LandmarkBottomSheet.kt`, add the parameter and the announcement.
Replace the signature and the opening of the body:

```kotlin
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun LandmarkBottomSheet(
    landmark: Landmark?,
    imageUrl: String?,
    announceOnOpen: String? = null,
    onDismiss: () -> Unit,
) {
    val context = LocalContext.current
    val view = LocalView.current
    val simplifiedText = remember {
        context.getSharedPreferences("warrington_prefs", android.content.Context.MODE_PRIVATE)
            .getBoolean("simplified_text", false)
    }
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)

    // A beacon opened this sheet, so nothing the user did will make TalkBack read
    // it. Announce explicitly; a tapped sheet is already narrated by the tap.
    LaunchedEffect(announceOnOpen) {
        if (announceOnOpen != null) {
            view.announceForAccessibility(announceOnOpen)
        }
    }
```

Add imports `androidx.compose.runtime.LaunchedEffect` and
`androidx.compose.ui.platform.LocalView`.

Then make the description a live region so a changed body is spoken even when the
sheet is already open. Replace the description `Text` with:

```kotlin
                    Text(
                        text = if (simplifiedText) landmark.description else landmark.longDescription,
                        style = MaterialTheme.typography.bodyLarge,
                        modifier = Modifier.semantics { liveRegion = LiveRegionMode.Assertive },
                    )
```

with imports `androidx.compose.ui.semantics.liveRegion`,
`androidx.compose.ui.semantics.LiveRegionMode` and
`androidx.compose.ui.semantics.semantics`.

- [ ] **Step 2: Pass the announcement from the Park Map**

In `ui/parkmap/ParkMapScreen.kt`, track why the sheet opened:

```kotlin
    var selectedMarkerId by remember { mutableStateOf<Int?>(null) }
    var openedByBeacon by remember { mutableStateOf(false) }
```

Set it in the two places the sheet opens:

```kotlin
    LaunchedEffect(Unit) {
        viewModel.navigationEvent.collect { markerId ->
            openedByBeacon = true
            selectedMarkerId = markerId
        }
    }
```

and in the marker click handler `onMarkerClick = { openedByBeacon = false; selectedMarkerId = it }`.

Then in the sheet call:

```kotlin
    if (selectedMarkerId != null) {
        val landmark = viewModel.getLandmarkForMarker(selectedMarkerId!!)
        val announcement = if (openedByBeacon) {
            viewModel.announcementTextFor(selectedMarkerId!!)?.let { "${it.title}. ${it.body}" }
        } else {
            null
        }
        LandmarkBottomSheet(
            landmark = landmark,
            imageUrl = landmark?.let { viewModel.imageUrlFor(it) },
            announceOnOpen = announcement,
            onDismiss = { selectedMarkerId = null },
        )
    }
```

- [ ] **Step 3: Leave the tour sheet silent**

`ui/trailtours/TrailTourScreen.kt` calls `LandmarkBottomSheet` too. It compiles
unchanged because `announceOnOpen` defaults to null, which is the behaviour we want
there: the tour screen already shows and speaks the current stop through its own
Current/Next text, so a second announcement would talk over it.

- [ ] **Step 4: Build and test**

```bash
cd /Users/steve/projects/warrington-beacons/android && ./gradlew test assembleDebug
```

Expected: `BUILD SUCCESSFUL`, 32 tests passing.

- [ ] **Step 5: Commit**

```bash
cd /Users/steve/projects/warrington-beacons
git add -A android
git commit -m "Announce beacon-opened landmarks to screen readers"
```

---

### Task 6: Keep scanning with the screen off

**Files:**
- Modify: `android/app/src/main/java/org/warringtontownship/parks/android/beacon/BeaconScanner.kt`

**Interfaces:**
- Consumes: `AnnouncementNotifier.scanningNotification()`, `AnnouncementNotifier.SCANNING_NOTIFICATION_ID`.
- Produces: `BeaconScanner.foregroundServiceFailed: StateFlow<Boolean>`. `startScanning` and `stopScanning` keep their existing signatures.

Scanning currently dies with the screen, which makes the app unusable for its most
important case — phone pocketed, headphones in. AltBeacon has first-class support
for this, so no `Service` class of our own is needed.

- [ ] **Step 1: Wrap ranging in the foreground service**

In `beacon/BeaconScanner.kt`, add the notifier to the constructor:

```kotlin
@Singleton
class BeaconScanner @Inject constructor(
    @ApplicationContext private val context: Context,
    private val notifier: AnnouncementNotifier,
) {
```

Add the failure flow next to the other flows:

```kotlin
    private val _foregroundServiceFailed = MutableStateFlow(false)
    val foregroundServiceFailed: StateFlow<Boolean> = _foregroundServiceFailed.asStateFlow()
```

In `startScanning`, inside the `if (activeConsumers.size == 1)` block and before
`beaconManager.addRangeNotifier(rangeNotifier)`, start the service:

```kotlin
            // Scheduled scan jobs and foreground-service scanning are mutually
            // exclusive in altbeacon; the service is what keeps ranging alive with
            // the screen off and the phone in a pocket.
            beaconManager.setEnableScheduledScanJobs(false)
            try {
                beaconManager.enableForegroundServiceScanning(
                    notifier.scanningNotification(),
                    AnnouncementNotifier.SCANNING_NOTIFICATION_ID,
                )
                _foregroundServiceFailed.value = beaconManager.foregroundServiceStartFailed()
            } catch (e: IllegalStateException) {
                // Already enabled, or not permitted. Ranging still works while the
                // app is in front, so degrade rather than fail.
                Log.w("BeaconScanner", "Foreground service scanning unavailable", e)
                _foregroundServiceFailed.value = true
            }
```

In `stopScanning`, inside the `if (activeConsumers.isEmpty())` block after
`beaconManager.removeRangeNotifier(rangeNotifier)`:

```kotlin
            try {
                beaconManager.disableForegroundServiceScanning()
            } catch (e: IllegalStateException) {
                Log.w("BeaconScanner", "Foreground service already disabled", e)
            }
            _foregroundServiceFailed.value = false
```

- [ ] **Step 2: Build and test**

```bash
cd /Users/steve/projects/warrington-beacons/android && ./gradlew test assembleDebug
```

Expected: `BUILD SUCCESSFUL`, 32 tests passing.

- [ ] **Step 3: Verify the ongoing notification on a device**

```bash
cd /Users/steve/projects/warrington-beacons/android && ./gradlew installDebug
adb shell am start -n org.warringtontownship.parks.android/.MainActivity
adb shell dumpsys notification --noredact | grep -A3 "Listening for trail landmarks"
```

Expected: the ongoing notification is present while the Park Map is open, and gone
after navigating to the About tab. If no device is attached, say so in your report
and leave it to Task 11.

- [ ] **Step 4: Commit**

```bash
cd /Users/steve/projects/warrington-beacons
git add -A android
git commit -m "Scan for beacons in a foreground service"
```

---

### Task 7: The announcements status control

**Files:**
- Modify: `android/app/src/main/java/org/warringtontownship/parks/android/ui/parkmap/ParkMapViewModel.kt`
- Modify: `android/app/src/main/java/org/warringtontownship/parks/android/ui/parkmap/ParkMapScreen.kt`

**Interfaces:**
- Consumes: `AppPreferences.announcementsEnabled`, `AppPreferences.setAnnouncementsEnabled`, `BeaconScanner.foregroundServiceFailed`.
- Produces: `ParkMapViewModel.announcementsEnabled: StateFlow<Boolean>`, `ParkMapViewModel.setAnnouncementsEnabled(Boolean)`, `ParkMapViewModel.statusMessage: StateFlow<String>`.

The map is an `AndroidView` and invisible to TalkBack, so a screen-reader user
currently lands here with nothing focusable but the bottom nav and no way to tell
whether the app is listening. This control is the screen's accessible anchor as
much as it is a setting.

- [ ] **Step 1: Expose state and honour the setting**

In `ParkMapViewModel`, inject `private val appPreferences: AppPreferences` and add:

```kotlin
    val announcementsEnabled: StateFlow<Boolean> = appPreferences.announcementsEnabled

    val statusMessage: StateFlow<String> = combine(
        appPreferences.announcementsEnabled,
        beaconScanner.foregroundServiceFailed,
    ) { enabled, serviceFailed ->
        when {
            !enabled -> "Announcements off."
            serviceFailed -> "Announcements on, but only while this screen is open."
            else -> "Announcements on. Listening for nearby landmarks."
        }
    }.stateIn(viewModelScope, SharingStarted.Eagerly, "Announcements on. Listening for nearby landmarks.")

    fun setAnnouncementsEnabled(enabled: Boolean) {
        appPreferences.setAnnouncementsEnabled(enabled)
        if (enabled) startScanningIfReady() else beaconScanner.stopScanning(SCAN_CONSUMER)
    }
```

with imports `kotlinx.coroutines.flow.combine`, `kotlinx.coroutines.flow.stateIn`
and `kotlinx.coroutines.flow.SharingStarted`.

Then make `startScanningIfReady()` respect the setting, so turning it off means no
service, no ongoing notification and no battery cost:

```kotlin
    private fun startScanningIfReady() {
        if (!appPreferences.announcementsEnabled.value) return
        if (beaconRegions.isEmpty()) return
        beaconScanner.startScanning(SCAN_CONSUMER, beaconRegions)
    }
```

Leave `TrailToursViewModel.startScanningIfReady()` alone: a tour scans regardless,
because its auto-advance is navigation the user explicitly started. With
announcements off the tour advances silently, since the announcer checks the
setting before notifying.

- [ ] **Step 2: Add the control to the screen**

In `ui/parkmap/ParkMapScreen.kt`, collect the new state and put a labelled row
above the map. Replace the bare `TrailMap(...)` call with a `Column` containing the
control and the map:

```kotlin
    val announcementsEnabled by viewModel.announcementsEnabled.collectAsStateWithLifecycle()
    val statusMessage by viewModel.statusMessage.collectAsStateWithLifecycle()

    Column(modifier = Modifier.fillMaxSize()) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp, vertical = 8.dp)
                .semantics(mergeDescendants = true) { stateDescription = statusMessage },
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                text = "Announce nearby landmarks",
                style = MaterialTheme.typography.bodyLarge,
                modifier = Modifier.weight(1f),
            )
            Switch(
                checked = announcementsEnabled,
                onCheckedChange = { viewModel.setAnnouncementsEnabled(it) },
            )
        }
        TrailMap(
            routes = uiState.routes,
            markers = uiState.markers.map {
                TrailMapMarker(it.id, it.title, it.category, it.latitude, it.longitude)
            },
            boundsCoordinates = uiState.boundary,
            modifier = Modifier.fillMaxSize(),
            onMarkerClick = { openedByBeacon = false; selectedMarkerId = it },
            collapseMarkersWhenZoomedOut = true,
        )
    }
```

Imports to add: `androidx.compose.foundation.layout.Column`,
`androidx.compose.foundation.layout.Row`,
`androidx.compose.foundation.layout.fillMaxWidth`,
`androidx.compose.foundation.layout.padding`,
`androidx.compose.material3.MaterialTheme`, `androidx.compose.material3.Switch`,
`androidx.compose.material3.Text`, `androidx.compose.ui.Alignment`,
`androidx.compose.ui.semantics.semantics`,
`androidx.compose.ui.semantics.stateDescription`, `androidx.compose.ui.unit.dp`.

- [ ] **Step 3: Request notification permission alongside Bluetooth**

Still in `ParkMapScreen.kt`, the existing `LaunchedEffect` requests
`BLUETOOTH_SCAN`. Add notifications to the same moment using a multiple-permission
launcher:

```kotlin
    val permissionLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.RequestMultiplePermissions(),
        onResult = { },
    )

    LaunchedEffect(Unit) {
        val wanted = mutableListOf(Manifest.permission.BLUETOOTH_SCAN)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            wanted += Manifest.permission.POST_NOTIFICATIONS
        }
        permissionLauncher.launch(wanted.toTypedArray())
    }
```

This replaces the existing `bluetoothPermissionLauncher` and its `LaunchedEffect`.
The `Build.VERSION.SDK_INT >= S` guard around BLUETOOTH_SCAN can go: `minSdk` is
31, which is S.

- [ ] **Step 4: Build and test**

```bash
cd /Users/steve/projects/warrington-beacons/android && ./gradlew test assembleDebug
```

Expected: `BUILD SUCCESSFUL`, 32 tests passing.

- [ ] **Step 5: Commit**

```bash
cd /Users/steve/projects/warrington-beacons
git add -A android
git commit -m "Add an accessible announcements status control to the Park Map"
```

---

### Task 8: The Landmarks tab

**Files:**
- Create: `android/app/src/main/java/org/warringtontownship/parks/android/ui/landmarks/LandmarksViewModel.kt`
- Create: `android/app/src/main/java/org/warringtontownship/parks/android/ui/landmarks/LandmarksScreen.kt`
- Modify: `android/app/src/main/java/org/warringtontownship/parks/android/data/repository/TrailRepository.kt`
- Modify: `android/app/src/test/java/org/warringtontownship/parks/android/data/TrailRepositoryTest.kt`
- Modify: `android/app/src/main/java/org/warringtontownship/parks/android/navigation/NavRoutes.kt`
- Modify: `android/app/src/main/java/org/warringtontownship/parks/android/navigation/BottomNavItem.kt`
- Modify: `android/app/src/main/java/org/warringtontownship/parks/android/navigation/AppNavHost.kt`

**Interfaces:**
- Consumes: `TrailRepository.getLandmarks()`, `getLocations()`, `imageUrlFor()`, `LandmarkBottomSheet`.
- Produces: `TrailRepository.getLandmarksByLocation(): List<Pair<Location, List<Landmark>>>`; `NavRoutes.LANDMARKS` / `LANDMARKS_GRAPH`; `BottomNavItem.Landmarks`.

The map is the only way to browse landmarks and it is invisible to TalkBack, so
without this a blind user can only receive what a beacon pushes at them. It is also
the "read it again" path for anyone.

- [ ] **Step 1: Write the failing repository test**

Add to `TrailRepositoryTest.kt`:

```kotlin
    @Test
    fun `groups landmarks by location in locations order`() {
        val grouped = repository.getLandmarksByLocation()
        assertEquals(listOf("Lions Pride Park", "US202 to Bradford Dam"), grouped.map { it.first.name })
        assertEquals(23, grouped[0].second.size)
        assertEquals(17, grouped[1].second.size)
        assertEquals(40, grouped.sumOf { it.second.size })
    }
```

- [ ] **Step 2: Run it to verify it fails**

```bash
cd /Users/steve/projects/warrington-beacons/android && ./gradlew test
```

Expected: compilation failure, `Unresolved reference 'getLandmarksByLocation'`.

- [ ] **Step 3: Add the repository method**

In `TrailRepository.kt`, next to `getTrailsByLocation()`:

```kotlin
    fun getLandmarksByLocation(): List<Pair<Location, List<Landmark>>> =
        getLocations().map { location ->
            location to getLandmarks().filter { it.location == location.id }
        }
```

- [ ] **Step 4: Run the test**

```bash
cd /Users/steve/projects/warrington-beacons/android && ./gradlew test
```

Expected: `BUILD SUCCESSFUL`, 33 tests passing.

- [ ] **Step 5: Write the ViewModel**

```kotlin
package org.warringtontownship.parks.android.ui.landmarks

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import android.util.Log
import org.warringtontownship.parks.android.data.model.Landmark
import org.warringtontownship.parks.android.data.model.Location
import org.warringtontownship.parks.android.data.repository.TrailRepository
import javax.inject.Inject

data class LandmarksUiState(
    val landmarksByLocation: List<Pair<Location, List<Landmark>>> = emptyList(),
    val error: String? = null,
)

@HiltViewModel
class LandmarksViewModel @Inject constructor(
    private val trailRepository: TrailRepository,
) : ViewModel() {

    private val _uiState = MutableStateFlow(LandmarksUiState())
    val uiState: StateFlow<LandmarksUiState> = _uiState.asStateFlow()

    init {
        viewModelScope.launch {
            try {
                trailRepository.loadData()
                _uiState.value = LandmarksUiState(
                    landmarksByLocation = trailRepository.getLandmarksByLocation(),
                )
            } catch (e: Exception) {
                Log.e("LandmarksVM", "Unable to load landmarks", e)
                _uiState.value = LandmarksUiState(error = e.message)
            }
        }
    }

    fun imageUrlFor(landmark: Landmark): String = trailRepository.imageUrlFor(landmark)
}
```

- [ ] **Step 6: Write the screen**

```kotlin
package org.warringtontownship.parks.android.ui.landmarks

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import org.warringtontownship.parks.android.ui.common.LandmarkBottomSheet

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun LandmarksScreen(
    viewModel: LandmarksViewModel = hiltViewModel(),
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    var selectedLandmarkId by remember { mutableStateOf<Int?>(null) }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Landmarks", modifier = Modifier.semantics { heading() }) },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = MaterialTheme.colorScheme.primary,
                    titleContentColor = MaterialTheme.colorScheme.onPrimary,
                ),
            )
        }
    ) { padding ->
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .padding(horizontal = 16.dp),
        ) {
            item {
                Text(
                    text = "Every point of interest on both trails. Open one to read about it.",
                    style = MaterialTheme.typography.bodyMedium,
                    modifier = Modifier.padding(vertical = 8.dp),
                )
            }
            uiState.landmarksByLocation.forEach { (location, landmarks) ->
                item(key = "header-${location.id}") {
                    Text(
                        text = location.name,
                        style = MaterialTheme.typography.titleMedium,
                        color = MaterialTheme.colorScheme.primary,
                        modifier = Modifier
                            .padding(top = 16.dp, bottom = 4.dp)
                            .semantics { heading() },
                    )
                }
                items(landmarks, key = { it.id }) { landmark ->
                    Card(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(vertical = 4.dp)
                            .clickable { selectedLandmarkId = landmark.id },
                        elevation = CardDefaults.cardElevation(defaultElevation = 2.dp),
                    ) {
                        Column(modifier = Modifier.padding(16.dp)) {
                            Text(
                                text = landmark.name,
                                style = MaterialTheme.typography.titleLarge,
                            )
                            Text(
                                text = if (landmark.category == "Trail") "Trailhead" else "Landmark",
                                style = MaterialTheme.typography.bodyMedium,
                                color = MaterialTheme.colorScheme.primary,
                            )
                        }
                    }
                }
            }
        }
    }

    if (selectedLandmarkId != null) {
        val landmark = uiState.landmarksByLocation
            .flatMap { it.second }
            .firstOrNull { it.id == selectedLandmarkId }
        LandmarkBottomSheet(
            landmark = landmark,
            imageUrl = landmark?.let { viewModel.imageUrlFor(it) },
            onDismiss = { selectedLandmarkId = null },
        )
    }
}
```

- [ ] **Step 7: Add it to navigation**

In `NavRoutes.kt`:

```kotlin
    const val LANDMARKS_GRAPH = "landmarks_graph"
    const val LANDMARKS = "landmarks"
```

In `BottomNavItem.kt`, add the item and include it in `items` between `ParkMap`
and `TrailTours`:

```kotlin
    data object Landmarks : BottomNavItem(
        label = "Landmarks",
        icon = Icons.Default.FormatListBulleted,
        graphRoute = NavRoutes.LANDMARKS_GRAPH,
    )
```

```kotlin
        val items = listOf(ParkMap, Landmarks, TrailTours, About, Settings)
```

with import `androidx.compose.material.icons.filled.FormatListBulleted`.

In `AppNavHost.kt`, add the graph alongside the About one:

```kotlin
        navigation(
            startDestination = NavRoutes.LANDMARKS,
            route = NavRoutes.LANDMARKS_GRAPH,
        ) {
            composable(NavRoutes.LANDMARKS) {
                LandmarksScreen()
            }
        }
```

with import `org.warringtontownship.parks.android.ui.landmarks.LandmarksScreen`.

- [ ] **Step 8: Build and test**

```bash
cd /Users/steve/projects/warrington-beacons/android && ./gradlew test assembleDebug
```

Expected: `BUILD SUCCESSFUL`, 33 tests passing.

- [ ] **Step 9: Commit**

```bash
cd /Users/steve/projects/warrington-beacons
git add -A android
git commit -m "Add a Landmarks tab so content is browsable without the map"
```

---

### Task 9: Semantics fixes

**Files:**
- Modify: `android/app/src/main/java/org/warringtontownship/parks/android/ui/common/LandmarkBottomSheet.kt`
- Modify: `android/app/src/main/java/org/warringtontownship/parks/android/ui/trailtours/TrailToursScreen.kt`

**Interfaces:**
- Consumes: `Landmark.imageAlt`.
- Produces: no new API.

- [ ] **Step 1: Use the data's own alt text**

`LandmarkBottomSheet` passes `landmark.name` as the image `contentDescription`, so
TalkBack says the name twice — once for the image, once for the title — while the
data's `imageAlt` field, populated for all 40 landmarks, is read by nothing.

```kotlin
                AsyncImage(
                    model = imageUrl,
                    contentDescription = landmark.imageAlt,
                    modifier = Modifier
                        .fillMaxWidth()
                        .aspectRatio(16f / 9f),
                )
```

- [ ] **Step 2: Make the title a heading, and fold the category into it**

The "Trailhead"/"Landmark" line is a second TalkBack stop that adds nothing beside
the title it follows. Merge them into one node:

```kotlin
                Column(
                    modifier = Modifier
                        .padding(16.dp)
                        .semantics(mergeDescendants = true) { heading() },
                ) {
                    Text(
                        text = landmark.name,
                        style = MaterialTheme.typography.headlineMedium,
                    )
                    Spacer(modifier = Modifier.height(8.dp))
                    Text(
                        text = if (landmark.category == "Trail") "Trailhead" else "Landmark",
                        style = MaterialTheme.typography.titleMedium,
                        color = MaterialTheme.colorScheme.primary,
                    )
                }
```

The description `Text` moves out of that merged `Column` into a sibling below it,
keeping its live-region modifier from Task 5, so the body stays its own stop and is
not swallowed into the heading.

Add imports `androidx.compose.ui.semantics.heading` and
`androidx.compose.ui.semantics.semantics` if not already present.

- [ ] **Step 3: Make the Trail Tours location headers headings**

In `TrailToursScreen.kt`, the location header `Text` gains the same treatment:

```kotlin
                        modifier = Modifier
                            .padding(top = 16.dp, bottom = 4.dp)
                            .semantics { heading() },
```

with imports `androidx.compose.ui.semantics.heading` and
`androidx.compose.ui.semantics.semantics`.

- [ ] **Step 4: Build and test**

```bash
cd /Users/steve/projects/warrington-beacons/android && ./gradlew test assembleDebug
```

Expected: `BUILD SUCCESSFUL`, 33 tests passing.

- [ ] **Step 5: Commit**

```bash
cd /Users/steve/projects/warrington-beacons
git add -A android
git commit -m "Use landmark alt text and add heading semantics"
```

---

### Task 10: Copy and units

**Files:**
- Modify: `android/app/src/main/java/org/warringtontownship/parks/android/ui/welcome/WelcomeScreen.kt`
- Modify: `android/app/src/main/java/org/warringtontownship/parks/android/ui/settings/SettingsScreen.kt`
- Modify: `android/app/src/main/java/org/warringtontownship/parks/android/ui/trailtours/TrailDetailScreen.kt`

**Interfaces:**
- Consumes: nothing new.
- Produces: no new API.

- [ ] **Step 1: Mention Simplified Text on Welcome**

Simplified Text is an accessibility feature discoverable only by opening Settings.
After the paragraph about Trail Tours in `WelcomeScreen.kt`, add:

```kotlin
        Spacer(modifier = Modifier.height(12.dp))
        Text(
            text = "If you'd prefer shorter, plainer descriptions, turn on Simplified Text in Settings.",
            style = MaterialTheme.typography.bodyLarge,
        )
```

- [ ] **Step 2: Show beacon distances in feet**

The data's own trail descriptions are in feet and miles, so metres are out of place.
In `SettingsScreen.kt` replace the distance line:

```kotlin
                            text = "%.0f ft".format(item.distance * 3.28084),
```

- [ ] **Step 3: Say where each direction heads**

"Forward" and "Reverse" don't tell a walker which way to physically turn. In
`TrailDetailScreen.kt`, after the `Row` holding the two direction buttons and
before the existing `if (startMarker != null)` block, add a line naming the first
stop in the chosen direction:

```kotlin
                    val startIndex = markers.indexOfFirst { it.id == startMarker?.id }
                    val headingToward = if (startIndex >= 0 && markers.size > 1) {
                        val nextIndex = if (reverse) {
                            if (startIndex > 0) startIndex - 1 else markers.size - 1
                        } else {
                            (startIndex + 1) % markers.size
                        }
                        markers[nextIndex].title
                    } else {
                        null
                    }
                    if (headingToward != null) {
                        Spacer(modifier = Modifier.height(8.dp))
                        Text(
                            text = "You'll head toward $headingToward first.",
                            style = MaterialTheme.typography.bodyMedium,
                        )
                    }
```

- [ ] **Step 4: Build and test**

```bash
cd /Users/steve/projects/warrington-beacons/android && ./gradlew test assembleDebug
```

Expected: `BUILD SUCCESSFUL`, 33 tests passing.

- [ ] **Step 5: Commit**

```bash
cd /Users/steve/projects/warrington-beacons
git add -A android
git commit -m "Surface Simplified Text, use feet, and name the tour direction"
```

---

### Task 11: On-device verification with TalkBack, and docs

**Files:**
- Modify: `android/HOW_IT_WORKS.md`
- Modify: `android/README.md`
- Modify: `android/simulate_beacon.sh`

**Interfaces:**
- Consumes: everything above.
- Produces: no code interfaces.

None of TalkBack, notifications, or the foreground service can be unit tested, so
this task is where the feature is actually proven. The data host
`trails.warringtoneac.org` currently has no DNS record, so serve `server/` locally
and point the debug build at it for the duration:

```bash
cd /Users/steve/projects/warrington-beacons/server && python3 -m http.server 8090 --bind 127.0.0.1 &
adb reverse tcp:8090 tcp:8090
```

then temporarily set the Retrofit `baseUrl` in `di/AppModule.kt` and
`IMAGE_BASE_URL` in `data/repository/TrailRepository.kt` to
`http://127.0.0.1:8090/` and add `android:usesCleartextTraffic="true"` to the
`<application>` tag in `app/src/debug/AndroidManifest.xml`. **Revert all three
before committing** and confirm with `git status --porcelain` that the tree is
clean.

- [ ] **Step 1: Enable TalkBack and confirm a landmark is spoken**

```bash
adb shell settings put secure enabled_accessibility_services com.google.android.marvin.talkback/com.google.android.marvin.talkback.TalkBackService
adb shell settings put secure accessibility_enabled 1
cd /Users/steve/projects/warrington-beacons/android && ./gradlew installDebug
adb shell am start -n org.warringtontownship.parks.android/.MainActivity
```

Get past Welcome, stay on the Park Map, then fake a Lions Pride beacon **three
times** — the gate requires three sightings before announcing:

```bash
./simulate_beacon.sh 1002 2.0; sleep 1; ./simulate_beacon.sh 1002 2.0; sleep 1; ./simulate_beacon.sh 1002 2.0
adb logcat -d | grep -iE "talkback|announce|LandmarkAnnouncer" | tail -20
```

Expected: the sheet opens and TalkBack speaks "Yellow Trail" followed by the
description. If TalkBack isn't installed on the emulator image, say so and verify
the announcement path via `adb shell dumpsys accessibility` plus the notification
check in Step 2 instead of claiming it passed.

- [ ] **Step 2: Confirm the notification fires with the screen off**

```bash
adb shell input keyevent KEYCODE_SLEEP
./simulate_beacon.sh 3 2.0; sleep 1; ./simulate_beacon.sh 3 2.0; sleep 1; ./simulate_beacon.sh 3 2.0
adb shell dumpsys notification --noredact | grep -B2 -A8 "landmark_alerts"
```

Expected: a `landmark_alerts` notification whose title is the landmark name and
whose `bigText` holds the full description. Note in your report whether the fake
beacon path still works with the screen off — `injectSimulatedBeacons` is a debug
hook, so if the process is frozen this step may need the screen on; say so plainly
rather than reporting a false pass.

- [ ] **Step 3: Confirm the debounce rules on a device**

```bash
./simulate_beacon.sh clear
./simulate_beacon.sh 4 50.0; sleep 1; ./simulate_beacon.sh 4 50.0; sleep 1; ./simulate_beacon.sh 4 50.0
```

Expected: **nothing** happens — 50 m is beyond the 30 m gate. Then:

```bash
./simulate_beacon.sh 4 2.0; sleep 1; ./simulate_beacon.sh 4 2.0; sleep 1; ./simulate_beacon.sh 4 2.0
```

Expected: it announces. Immediately repeating the same three sightings must **not**
announce again (immediate-repeat guard).

- [ ] **Step 4: Confirm the ongoing notification and the toggle**

Expected, checked with `adb shell dumpsys notification --noredact | grep "Listening for trail landmarks"`:
present while the Park Map is open, absent after switching to About. Then toggle
"Announce nearby landmarks" off and confirm the ongoing notification disappears and
faked beacons do nothing. Toggle back on and confirm it returns.

- [ ] **Step 5: Confirm denied notifications degrade rather than break**

```bash
adb shell pm revoke org.warringtontownship.parks.android android.permission.POST_NOTIFICATIONS
```

Expected: faking a beacon still opens the sheet and still announces in-app; no
crash. Re-grant afterwards.

- [ ] **Step 6: Walk the app with TalkBack**

Expected: the Landmarks tab is reachable, its location headers and the sheet titles
are exposed as headings, opening a landmark reads its name once (not twice) and
then its description, and the Park Map's status control reads "Announcements on.
Listening for nearby landmarks."

- [ ] **Step 7: Update the docs**

In `android/simulate_beacon.sh`, add to the usage comments that a beacon must now
be faked three times within range to trigger an announcement, and that distances of
30 m or more are ignored by design.

In `android/HOW_IT_WORKS.md`, document the announcement pipeline: `BeaconScanner` →
`LandmarkAnnouncer` (gated by `AnnouncementGate`) → screens plus
`AnnouncementNotifier`, the foreground service, the two notification channels, the
announcements toggle, and the Landmarks tab. In `android/README.md`, note the new
`POST_NOTIFICATIONS` and `FOREGROUND_SERVICE` permissions and that scanning now
continues with the screen off.

- [ ] **Step 8: Revert the local-host rig, then final check**

```bash
cd /Users/steve/projects/warrington-beacons
git checkout -- android/app/src/main/java/org/warringtontownship/parks/android/di/AppModule.kt \
  android/app/src/main/java/org/warringtontownship/parks/android/data/repository/TrailRepository.kt \
  android/app/src/debug/AndroidManifest.xml
grep -rn "127.0.0.1\|usesCleartextTraffic" android/app/src || echo "clean"
cd android && ./gradlew clean test assembleDebug
```

Expected: `clean`, then `BUILD SUCCESSFUL` with 33 tests passing.

- [ ] **Step 9: Commit**

```bash
cd /Users/steve/projects/warrington-beacons
git add -A android
git commit -m "Document the announcement pipeline and accessibility behaviour"
```
