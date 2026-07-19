# warrington-beacons

Monorepo for the Warrington Township beacon-guided trail apps
(US202 to Bradford Dam trail, originally built for Lions Pride Park).

## Layout

* `android/` — Android app for the US202 to Bradford Dam trail
  (Kotlin / Jetpack Compose). See `android/README.md` for beacon
  programming instructions, cloud/account details, and TODOs.
* `ios/` — iOS app (the original Lions Pride codebase, since pointed
  at the US202 to Bradford Dam trail as "202 Connector").
  See `ios/README.md` for design links and history.
* `server/` — local copies of every remotely hosted file the apps
  reference, staged here so hosting can be moved (ultimately to an
  AWS account owned by Warrington Township).

## Hosted files (`server/`)

Both apps load their data and images from GitHub Pages:

```
https://ssuffian.github.io/warrington-beacons/us-202/
```

The `server/` folder is the source of truth: pushing a change to
anything under `server/` on `main` redeploys it automatically via
`.github/workflows/pages.yml`. (Files were previously hosted at
`https://lionspride.chariotsolutions.cloud/us202/`, a Chariot sandbox
S3 bucket.) Contents, organized by app:

* `server/us-202/` — the US202 to Bradford Dam trail. Everything the
  apps need is here:
  * `us202trail-v2.json` — trail geometry, landmarks, and beacon codes
  * `images/*.jpg` — 13 landmark photos, fetched as
    `images/<imageName>.jpg` per the `imageName` fields in the JSON
  * `legacy/202ConnectorData.json` — earlier US202 data file, not used
    by current code (note: not strictly valid JSON — it has trailing
    commas that lenient parsers tolerate)
* `server/lions-pride-park/` — the original Lions Pride Park app,
  not used by current code. Preserved because its host, AWS bucket
  `lions-pride-park-configuration`, is in an inaccessible account
  (owner email domain abandoned, so 2FA login is impossible):
  * `lionsPrideData.json` — Lions Pride Park data
  * `images/*.jpg` — 23 park photos

### Moving to a new host

Any new host must serve the contents of `server/` with
`us-202/us202trail-v2.json` and the photos under `us-202/images/`
reachable from the base URL. The hardcoded URLs to update are:

* Android:
  * `android/app/src/main/java/org/warringtontownship/us202/android/di/AppModule.kt`
    — Retrofit base URL
  * `android/app/src/main/java/org/warringtontownship/us202/android/ui/common/LandmarkBottomSheet.kt`
    — image URL prefix
* iOS:
  * `ios/LionsPride/Info.plist` — `base_url_string`

## Beacons

Physical beacons on the trail are Radius Networks RadBeacon E4 units
broadcasting iBeacon (iOS) and AltBeacon (Android). The UUID/Major/Minor
codes and programming steps are documented in `android/README.md`;
the Minor code for each beacon matches a landmark `id` in
`us202trail-v2.json`.
