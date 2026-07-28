# Spoken landmarks and accessible browsing — design

Date: 2026-07-28
Scope: Android app. iOS is out of scope and gets its own spec later.

## Goal

The app exists so that a walker — including a blind or low-vision walker — is told
about a point of interest when they reach it. On Android that does not happen at
all today: there is no announcement code of any kind, no notifications, no live
regions, no text-to-speech. A beacon detection silently slides a bottom sheet up.
If the phone is in a pocket, nothing is conveyed. If it is in hand with TalkBack
running, TalkBack announces the sheet container but does not read the description.

This spec makes landmarks spoken, makes detection survive a pocketed phone, and
makes the app's content browsable without sight.

## What iOS does, and where we deliberately differ

The iOS app is the reference implementation, so each decision below is stated
against it.

| Concern | iOS | This spec |
|---|---|---|
| Announcement channel | Local notification; `willPresent` shows an alert when VoiceOver is running, sound only when it isn't | Notification **and** an explicit in-app announcement |
| Announcement content | Title "Nearby point of interest", body is the landmark **name** only | Name as title, **full description** as body |
| Scan lifecycle | `startScanning()` on `.onAppear`, `stopScanning()` on `.onDisappear` | Same trigger, but backed by a foreground service |
| Background operation | None — `NSLocationWhenInUseUsageDescription` only, no `UIBackgroundModes`, CoreLocation *ranging* rather than region *monitoring*, so scanning dies when the app isn't frontmost | Foreground service, so scanning survives screen-off and pocketing |
| Trigger debounce | Distance < 30 m, seen 3+ times, not the immediately previous landmark, 60 s per-landmark cooldown | Ported as-is |
| Browsing without sight | `LandmarkListView2`, `LandmarkSearchView`, `TrailListView` | A Landmarks tab (list only; no search) |
| Explicit on/off control | None | A status toggle, defaulting to on |

Two divergences are load-bearing and worth restating. **Background operation:**
matching iOS exactly would leave the pocketed-phone case broken on both
platforms, which defeats the app's purpose for its most important users, so
Android goes further. **Announcement content:** reading only the name forces a
blind user to take the phone out and explore a sheet to learn anything, so the
description is read too.

## Phase 1 — Spoken landmarks

### The announcer

A new `LandmarkAnnouncer` (singleton, injected) owns the step "a landmark became
current → tell the user". Screens do not know about notifications; they report
that a landmark became current and the announcer decides how to say it. It has
one entry point:

```kotlin
fun announce(landmark: Landmark, source: AnnouncementSource)
enum class AnnouncementSource { BEACON, USER_TAP }
```

`USER_TAP` announcements do nothing — TalkBack already narrates an interaction the
user initiated, and a notification for a tap the user just made is noise. Passing
the source explicitly rather than having callers decide keeps the policy in one
place.

### What gets said

Announcement text is built by a pure function so it can be tested without Android:

```kotlin
internal fun announcementText(landmark: Landmark, simplifiedText: Boolean): AnnouncementText
data class AnnouncementText(val title: String, val body: String)
```

`title` is the landmark name. `body` is `landmark.description` when the Simplified
Text setting is on and `landmark.longDescription` when it is off — the same choice
`LandmarkBottomSheet` already makes for the visible sheet, so what is spoken
matches what is shown.

Two delivery paths, because the phone may or may not be in the user's hand:

* **Notification** — channel `landmark_alerts`, importance HIGH, default sound,
  `NotificationCompat.BigTextStyle` carrying the full body so TalkBack speaks all
  of it rather than a truncated line. A single notification id is reused for every
  landmark alert, so arriving at a new landmark replaces the previous alert instead
  of stacking a queue the user has to clear.
* **In-app** — `LocalView.current.announceForAccessibility("$title. $body")` when a
  beacon opens the sheet, plus `Modifier.semantics { liveRegion = LiveRegionMode.Assertive }`
  on the sheet body. The explicit announce is the reliable one; the live region
  covers the case where the sheet is already open and its content changes.

### Debounce

Android currently fires on the first sighting of a beacon at any distance and then
never fires for that landmark again (`distinctUntilChanged`). That is
simultaneously twitchy — a beacon 80 m away can pop a sheet — and sticky, since a
dismissed landmark cannot be recovered. iOS's four rules are ported into one
tested pure function:

```kotlin
internal class AnnouncementGate(private val clock: () -> Long) {
    fun shouldAnnounce(minorCode: Int, distanceMeters: Double): Boolean
    fun reset()
}
```

* **Distance gate** — ignore unless `distanceMeters in 0.0..<30.0`. AltBeacon
  reports a negative distance for unknown, matching iOS's `accuracy > 0` check.
* **Confirmation** — the same minor must pass the distance gate `3` times before
  announcing; the per-minor counters clear on a successful announcement.
* **Immediate-repeat guard** — never announce the landmark that was announced last.
* **Cooldown** — at most one announcement per minor per `60` seconds.

Values are taken from iOS unchanged (`MIN_SEEN_COUNT = 3`,
`MIN_NOTIFICATION_SECONDS = 60`, 30 m) rather than retuned, because they were
derived from real trail behaviour. `clock` is injected so cooldown tests do not
sleep. `reset()` is called when scanning stops, mirroring iOS clearing
`lastNearbyBeaconId` in `startScanning()`.

The cooldown is also what fixes the "I dismissed it and can't get it back"
problem: linger near the sign and it speaks again after a minute.

### Foreground service

Scanning still starts on screen-appear and stops when no screen needs it — the
existing consumer ref-counting in `BeaconScanner` already models this correctly
and does not change. What changes is that `BeaconScanner` now wraps its ranging in
AltBeacon's foreground service so it survives screen-off and pocketing:

* `beaconManager.setEnableScheduledScanJobs(false)` then
  `beaconManager.enableForegroundServiceScanning(notification, NOTIFICATION_ID)`
  when the first consumer starts, `disableForegroundServiceScanning()` when the
  last one stops.
* Ongoing notification: channel `trail_scanning`, importance LOW (silent), text
  "Listening for trail landmarks", not dismissible while scanning.
* If `foregroundServiceStartFailed()` returns true, log it, keep scanning in the
  foreground only, and surface it through the status toggle rather than failing
  silently.

AltBeacon 2.20.6 declares its `BeaconService` with
`android:foregroundServiceType="location"` and merges in
`FOREGROUND_SERVICE_LOCATION`, so no service of our own is needed.

### Status control

The Park Map is an osmdroid `AndroidView` and is therefore invisible to TalkBack;
a screen-reader user currently lands on that screen with nothing focusable but the
bottom nav, and cannot tell whether the app is listening or broken. The screen
gains one labelled control above the map:

* A `Switch` with a text label, `stateDescription` reading "Announcements on.
  Listening for nearby landmarks." or "Announcements off."
* **Defaults to on**, since that matches today's behaviour and silence should not
  require opting in. The choice persists in `warrington_prefs` under
  `announcements_enabled`.
* When off, the Park Map does not scan at all — no service, no ongoing
  notification, no battery cost — because ambient scanning has no purpose once
  nothing will be announced.
* A Trail Tour still scans while it is open even when the toggle is off, because a
  tour's beacon-driven auto-advance is navigation the user explicitly asked for
  rather than an announcement. With the toggle off a tour advances silently: the
  current stop updates, and nothing is spoken or posted.
* It is where problems get reported: "Bluetooth is off — announcements paused" and
  "Notifications are blocked — landmarks will only be announced on screen".

### Permissions

* Add `android.permission.FOREGROUND_SERVICE` — AltBeacon merges
  `FOREGROUND_SERVICE_LOCATION` but not the base permission, which has been
  required since API 28.
* Add `android.permission.POST_NOTIFICATIONS`, requested at the same moment
  `BLUETOOTH_SCAN` is requested on the Park Map. `minSdk` is 31, so on 31–32 it is
  granted implicitly and only 33+ prompts.
* Denied notifications is a supported state, not an error: in-app announcements
  still work and the status control says so.

## Phase 2 — Accessible browsing

### Landmarks tab

The map is the only way to browse landmarks today, and it is invisible to
TalkBack, so a blind user can only receive what a beacon pushes at them. A fifth
bottom-nav tab, "Landmarks", lists all 40 grouped under the same two location
headers the Trail Tours tab uses, each row showing name and category and opening
the same `LandmarkBottomSheet`.

This is also the "read it again" path — any landmark's description is reachable on
demand, not only when standing next to its beacon.

No search: 40 rows under two headers is a short list, and search adds a text field
that a screen-reader user must fight. iOS has `LandmarkSearchView`; if the data
grows past a few hundred landmarks this decision should be revisited.

### Semantics fixes

* `LandmarkBottomSheet` passes `landmark.name` as the image `contentDescription`,
  so TalkBack says the name twice and the data's own `imageAlt` field — populated
  for all 40 landmarks and currently read by nothing — is wasted. Use `imageAlt`.
* Add `heading()` semantics to the sheet title, the location headers on the Trail
  Tours and Landmarks tabs, and the screen titles, so heading navigation works.
* The "Trailhead"/"Landmark" category line is decorative next to the title that
  precedes it; merge it into the title's semantics rather than leaving it as a
  separate stop.

### Copy and units

* Welcome mentions the Simplified Text setting exists, since it is an
  accessibility feature currently discoverable only by opening Settings.
* Settings' "Nearby Landmarks" distances render in feet, not "%.1f m" — the trail
  descriptions in the data are already in feet and miles.
* Trail detail's bare "Forward"/"Reverse" buttons gain a line naming the landmark
  each direction heads toward first, so the choice is concrete.

### Considered and dropped

Text labels for the two locations drawn on the map. The Landmarks tab answers
"where can I go?" better than map labels would, and osmdroid text overlays are
fiddly at the collapsed zoom where they would matter.

## Testing

Pure functions carry the logic, so the parts that matter are unit-testable:

* `AnnouncementGate` — distance gate rejects ≥30 m and negative distances; three
  sightings required; the same landmark twice in a row is refused; the cooldown
  expires exactly at 60 s using an injected clock; `reset()` clears all state.
* `announcementText` — picks `description` under Simplified Text and
  `longDescription` otherwise.
* The Landmarks tab's grouping reuses `TrailRepository.getLandmarks()` plus the
  existing location lookup, so its grouping is covered by a repository test
  alongside `getTrailsByLocation`.

On-device verification is the real gate for the rest, since none of TalkBack,
notifications, or the service can be unit tested:

1. TalkBack on, fake a beacon, confirm name and description are both spoken.
2. Screen locked, phone "pocketed", fake a beacon, confirm the notification fires
   with sound and TalkBack reads it.
3. Confirm the ongoing notification appears while scanning and clears on leaving.
4. Deny notification permission, confirm in-app announcements still work and the
   status control explains the state.
5. Toggle announcements off, confirm no service, no notification, no scanning.
6. Navigate the whole app with TalkBack using headings and the Landmarks tab.

## Out of scope

* iOS. Its background story needs CoreLocation region monitoring, a different API
  from the ranging it uses today — its own spec.
* Landmark search.
* Retuning the debounce constants; they are copied from iOS deliberately.
