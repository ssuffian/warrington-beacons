# Handoff Review — Bradford Trail (iOS, branch `202Trail`)

*Prepared 2026-07-18, mirroring the review in `../us202-android/REPORT.md`. Read
`HOW_IT_WORKS.md` first for architecture. Everything below was verified on the
iPhone 16 simulator (iOS 18.3) under Xcode 26.6 unless labeled otherwise.*

## TL;DR

- **What it is:** the iOS sibling of the Android trail app — same product, same JSON
  data, iBeacon instead of AltBeacon, **Apple MapKit instead of Google Maps (so iOS
  never had the API-key problem; see "About the map swap" below).**
- **State:** 2020-vintage SwiftUI that still builds clean on Xcode 26 and passes a
  full simulator walkthrough. Functional, with dated idioms and a handful of
  operational problems — the biggest was that it **loaded data from the frozen S3
  bucket in the lost AWS account** (fixed today, see below).
- **This repo holds TWO apps on two branches** (`master` = Lions Pride Park,
  `202Trail` = this app). Don't develop on `master` by accident.

## About the map swap you planned

You asked (after the Android OSM work) to "make a similar change in iOS." **My
recommendation: don't.** iOS uses Apple's MapKit — free, built-in, zero keys, zero
third-party dependencies, nothing owned by Russ Diamond. The reason the Android swap
was worth it (retiring the Google Cloud key dependency) doesn't exist here. The only
argument left is visual consistency with Android's OSM look, which I'd weigh against
adding a dependency (MapLibre/osmdroid-equivalent) to a codebase that currently has
almost none. Decision is yours, but the operational win is already fully banked.

## Bugs/problems found and fixed (uncommitted on `202Trail` — `git diff` to review)

1. **Data loaded from the dead bucket** — `Info.plist`'s `base_url_string` pointed at
   `lions-pride-park-configuration.s3.us-east-2.amazonaws.com`, the bucket whose AWS
   account is unrecoverable (per the Android README). It still *serves*, so the app
   worked — but its content is frozen forever, and iOS/Android were reading two
   different files that could silently diverge. *Fixed: repointed to
   `https://lionspride.chariotsolutions.cloud/us202` and the same `us202trail-v2.json`
   Android uses. Verified live in the simulator (map pins, trail list, tour all
   populate from the new URL).*
2. **Zero offline tolerance** — data was fetched with an **ephemeral** URLSession
   (deliberately uncached, per a code comment, so content edits showed up promptly).
   No signal at the trailhead = empty app, same flaw Android had. *Fixed: normal
   session with `reloadRevalidatingCacheData` (still picks up content changes
   promptly via ETag revalidation — preserving the original intent) plus a
   cache-only fallback when the network is unreachable. Mechanism verified: after one
   online fetch, a cache-only request returns the full payload.*
3. **Welcome screen showed on every launch** (state was never persisted; Android
   persists it). *Fixed with a `welcome_seen` UserDefault; verified — second launch
   goes straight to the map.*
4. **"Simplified Text" setting reset on every launch** (same cause). *Fixed with a
   UserDefault behind the existing `@Published` property.*
5. **App Transport Security was disabled globally** (`NSAllowsArbitraryLoads=true`) —
   unnecessary (all endpoints are https), a security smell, and an App Store review
   question waiting to happen. *Removed; everything still loads.*
6. **Both test targets were broken by the project rename** (`LionsPride` →
   `202Connector`): the UI-test target pointed at a nonexistent host target name, the
   unit tests imported the old module name, and both were pinned to a 13.4 deployment
   target against a 16.0 app. *Fixed all three; full suite now passes.*
7. **No meaningful tests existed** (the UI test was empty boilerplate). *Added a
   walkthrough UI test (welcome → park-map pins → trail list → detail → start tour)
   that doubles as a live check that the JSON downloads and decodes. `xcodebuild
   test` is green: unit + UI.*

## Data-file health warning (needs a decision, not code)

The **old** bucket's `202ConnectorData.json` contains a JSON syntax error (a trailing
comma) that Apple's current parser happens to tolerate but strict parsers (Python,
most tooling) reject. The new bucket's `us202trail-v2.json` is clean. Since content
updates are hand-edited (per the Android README, the old Google-Sheet pipeline is
abandoned), **add a JSON-lint step to whatever process edits the data file** — one
stray comma is currently the difference between "works" and "app-wide empty state,"
depending on parser mood across OS versions.

## Stack modernization (2026-07-18, uncommitted — verified)

Requested general modernization; done in safe, individually-verified increments (build
+ full test suite green after each), keeping the iOS 16 deployment target:

1. **Removed the `URLImage` third-party dependency → SwiftUI `AsyncImage`** across all
   6 image sites. The app now has **zero third-party SPM dependencies** (Package.resolved
   emptied, project package refs removed). Verified: builds and images render.
2. **`NavigationView` → `NavigationStack`** and the deprecated `isActive:`
   `NavigationLink`s → `navigationDestination(isPresented:)` in the three live nav
   surfaces (park map, trail list, trail detail→tour). This was the riskiest change —
   it's the navigation the original author left a dozen workaround comments around — so
   I added a UI test for the **cross-tab trailhead launch** (the fragile
   `forceStartTour` path) and verified it lands on the trail detail inside the Trail
   Tours tab. Both the row-tap and cross-tab tour-launch flows pass.
3. **Deleted dead iOS 13/14 workaround code** (the `systemVersion` branch and stale
   comments) now that the floor is iOS 16.

Test suite after modernization: 2 unit + 2 UI tests all green.

**Second pass, 2026-07-18 (approved: deployment target raised to iOS 17, dropping the
iPhone 8/X-era devices that can't run 17):**
- **`UserData` → the `@Observable` macro** (Observation framework); views now use
  `@Environment(UserData.self)` / `@Bindable` instead of `@EnvironmentObject` /
  `@Published`. This surfaced one real regression the test suite caught: `@Observable`
  only re-renders views that *read* the changed property, so the map/trail-list (which
  render the non-observable `landmarkService` global) stopped repopulating when data
  loaded. Fixed by having those views read `userData.initialized`. Verified: all tests
  green after the fix.
- **`AppDelegate`/`SceneDelegate` → the SwiftUI `App` lifecycle** — new
  `BradfordTrailApp.swift` (`@main`), both UIKit delegate files removed, the
  `UIApplicationSceneManifest` stripped from Info.plist, and the debug fake-beacon URL
  moved to `.onOpenURL`. Verified: app launches, full flow works, and the fake beacon
  still selects a landmark via `simulate_beacon.sh` under the new lifecycle.

After this pass the app is on a current SwiftUI stack (iOS 17+, Observation, App
lifecycle, NavigationStack, AsyncImage, zero third-party deps). All 4 tests pass;
release builds clean with no fake-beacon code.

**Dead files worth deleting (didn't, to avoid risky pbxproj surgery overnight):**
`TrailToursView.swift`, `ContentView.swift`, `LandmarkListView2.swift` are orphaned
(not in the build target; reference types that no longer exist), and `TestView.swift`
is compiled but-unused Xcode template scaffolding. Best deleted from within Xcode (so
the project file updates cleanly).

## Known limitations / not fixed (decisions or bigger work)

- **Force-unwrap crash risks** throughout the views (`userData.trailLandmark!` in a
  nav title outside its nil-check, `trailTourNextLandmark!` at tour entry,
  `filter{...}[0]` in the tour map coordinator). The happy path always sets these
  before navigation, but any state regression crashes rather than degrades. A
  systematic cleanup is half a day; I didn't want to destabilize flow-critical code
  overnight without device testing.
- **Beacon UUID/major are hardcoded** in `BeaconScanner` (code TODO says to read
  them from the JSON `site` section like Android does). Trivial change; left alone
  because it alters field-proven beacon behavior, which deserves testing on the
  trail.
- **`UserData` is a self-described "confusing AF" state machine** — it works; a
  rewrite is a modernization project, not a fix.
- (Old-era stack items — `NavigationView`, `URLImage`, `ObservableObject`, UIKit
  delegates — are all now modernized; see "Stack modernization" above. The only
  remaining 2020-ism is MapKit-via-`UIViewRepresentable`, which is still the right
  tool for this app's custom map needs.)
- **Beacon simulator hook — added 2026-07-18** (parity with Android). `BeaconScanner`
  now uses a plain `RangedBeacon` value type instead of the un-constructible
  `CLBeacon`, and a debug-only `bradfordtrail://` URL handler injects fakes.
  `./simulate_beacon.sh <id>` / `walk` / `clear` drives it on the simulator. Verified
  live: minor 12 → Wetlands selected + nearby-landmark bar; minor 7 → Bluebird
  selected + map recentered; clear works; full test suite still green; `FakeBeacon`
  code absent from the release binary (0 symbols). One wrinkle: iOS shows a one-time
  "Open in Bradford Trail?" confirm when the app is frontmost (tap Open) — documented
  in HOW_IT_WORKS.md. The URL-scheme declaration stays in Info.plist in release but is
  inert; stripping it entirely needs `INFOPLIST_PREPROCESS` (noted, not done).
- **Two-apps-via-branches** repo structure — fine until features diverge; the
  park-specific bits (name, base URL, beacon major) are nearly all config already.
- Naming inconsistency: iOS home-screen name is "Bradford Trail", Android's is
  "US 202". Pick one before the next release.
- `CFBundleShortVersionString` is `1.0` — bump before any store submission.
- **Minimum iOS is now 17.0** (raised 2026-07-18 for the Observation/App-lifecycle
  modernization). This excludes devices that top out at iOS 16 — mainly the iPhone 8 /
  iPhone X generation. Fine for a current public app; noting it for the record.
- `BradfordTrailApp.swift` is the `@main` entry (was `AppDelegate.swift`, renamed);
  `SceneDelegate.swift` was deleted. Both handled via careful `project.pbxproj` edits —
  worth a sanity-open in Xcode.

## What only you can figure out (same list as Android, minus the Maps key)

1. **App Store access** — the "Warrington Township" account; Aaron Mulder can deploy.
   Ownership unknown per the README — worth resolving while people are reachable.
2. **S3/CloudFront hosting** — now both apps depend on Chariot's sandbox bucket;
   the planned move to a township-owned account is now a two-platform migration
   (one `base_url_string` edit here, one Retrofit base-URL edit on Android).
3. **Signing/provisioning** — nothing in-repo; check who holds the distribution
   certificate for the Township account.
4. **Field test** — beacon debounce parameters (3 sightings, 60s cooldown, 30m
   gate) were tuned for the old park; the "Update sensitivity" commit suggests
   they're still being dialed in for this trail.

## How to run it

Open `202Connector.xcodeproj` in Xcode (branch `202Trail`!), scheme `202Connector`,
pick any iOS 16+ simulator, Run. No keys or config needed. Tests: Cmd-U or
`xcodebuild test -project 202Connector.xcodeproj -scheme 202Connector -destination
'platform=iOS Simulator,name=iPhone 16'`.

## Verification record (all on iPhone 16 sim, iOS 18.3)

- Build: clean under Xcode 26.6.
- Full walkthrough UI test **passed** (pre-fix baseline and post-fix): welcome →
  park map with landmark pins → trail list ("202 Connector Trail") → detail → tour
  ("NEXT: Bluebird… / 319 yards…"), against the **new** bucket after the fix.
- Welcome persistence: verified via fresh-install run (welcome shown) + relaunch
  (straight to populated map).
- Offline cache fallback: mechanism verified standalone (online fetch → cache-only
  fetch returns full payload).
- Unit tests (`MapServiceTest`) pass after the target repairs.
- Not verified (needs hardware): everything beacon-driven, and the notification UX.
