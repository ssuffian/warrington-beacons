# warrington-beacons

Monorepo for the Warrington Township beacon-guided trail apps,
covering both Lions Pride Park and the US202 to Bradford Dam trail
(the Android app was originally built for Lions Pride Park alone).

## Layout

* `android/` — Android app covering both Lions Pride Park and the
  US202 to Bradford Dam trail (Kotlin / Jetpack Compose). See
  `android/README.md` for beacon programming instructions,
  cloud/account details, and TODOs.
* `ios/` — iOS app (the original Lions Pride codebase, since pointed
  at the US202 to Bradford Dam trail as "202 Connector").
  See `ios/README.md` for design links and history.
* `server/` — every remotely hosted file the apps reference, served
  by GitHub Pages at `https://trails.warringtoneac.org/` (see below).

## Hosted files (`server/`)

Both apps load their data and images from GitHub Pages:

```
https://trails.warringtoneac.org/us-202/
```

The `server/` folder is the source of truth: pushing a change to
anything under `server/` on `main` redeploys it automatically via
`.github/workflows/pages.yml`. The domain is a `trails` CNAME record
on `warringtoneac.org` (DNS at Namecheap) pointing to
`ssuffian.github.io`, set as the custom domain in this repo's Pages
settings. Because the township owns the domain, hosting can move
anywhere later with just a DNS change — no app re-release. (Files
were previously hosted at
`https://lionspride.chariotsolutions.cloud/us202/`, a Chariot sandbox
S3 bucket.) Contents, organized by app:

* `warrington-trails.json` — the source of truth for the Android app.
  It covers both locations (Lions Pride Park and the US202 to
  Bradford Dam trail) in a single file: landmarks, trails, locations,
  and beacon codes for both.
* `api/v1/` — versioned copy of the deployed numeric Trail ID schema. Existing
  unversioned URLs remain available for installed apps.
* `api/v2/` — current unified string Trail ID schema, including trails that do
  not have beacon stops.
* `api/versions.json` — machine-readable list of published API versions. New app
  releases pin a major version instead of following an unversioned or `latest`
  URL.
* `api/app-builds.json` — public release ledger showing the exact iOS and
  Android build numbers and the API major version each build uses.
* `server/us-202/` — the US202 to Bradford Dam trail. Everything the
  apps need is here:
  * `us202trail-v2.json` — trail geometry, landmarks, and beacon
    codes. Kept unchanged (not folded into `warrington-trails.json`)
    because the shipped iOS app still reads this file directly. Until
    iOS migrates to `warrington-trails.json`, a data edit affecting
    the US202 trail must be made in both files.
  * `images/*.jpg` — 13 landmark photos, fetched as
    `images/<imageName>.jpg` per the `imageName` fields in the JSON
  * `legacy/202ConnectorData.json` — earlier US202 data file, not used
    by current code (note: not strictly valid JSON — it has trailing
    commas that lenient parsers tolerate)
* `server/lions-pride-park/` — the original Lions Pride Park app.
  `lionsPrideData.json` itself is no longer used by current code, but
  the Android app fetches the 23 photos in `images/` live, per the
  `imagePath` field on each Lions Pride Park landmark in
  `warrington-trails.json`. The directory is preserved because its
  original host, AWS bucket `lions-pride-park-configuration`, is in an
  inaccessible account (owner email domain abandoned, so 2FA login is
  impossible):
  * `lionsPrideData.json` — Lions Pride Park data
  * `images/*.jpg` — 23 park photos

### Moving to a new host

Any new host must serve the contents of `server/` with
`warrington-trails.json`, `us-202/us202trail-v2.json`, and the photos
under `us-202/images/` and `lions-pride-park/images/` all reachable
from the base URL. The hardcoded URLs to update are:

* Android:
  * `android/app/src/main/java/org/warringtontownship/parks/android/di/AppModule.kt`
    — Retrofit base URL
  * `android/app/src/main/java/org/warringtontownship/parks/android/data/repository/TrailRepository.kt`
    — `IMAGE_BASE_URL`
* iOS:
  * `ios/WarringtonTalkingTrails/Info.plist` — `base_url_string`

### API versions

Breaking data-shape changes use a new major version in the URL:

```text
https://trails.warringtoneac.org/api/v1/trails.json
https://trails.warringtoneac.org/api/v1/talking-trails.kml
https://trails.warringtoneac.org/api/v1/schema.json
https://trails.warringtoneac.org/api/v2/trails.json
https://trails.warringtoneac.org/api/v2/talking-trails.kml
https://trails.warringtoneac.org/api/v2/schema.json
```

Version 1 preserves the deployed numeric Trail ID schema. Version 2 uses one
canonical string Trail ID across the spreadsheet, KML, JSON, and new apps, and
allows route-only trails without beacon stops. Content may change within a major version, but its field names,
types and relationships must remain compatible. Mobile releases must pin a
specific major version; they must not use a moving `latest` endpoint.
The JSON Schema is the machine-readable boundary: spreadsheet and KML content
changes remain on v1 when the generated response validates, while a new field,
field type, required property, enum or record relationship requires a new major
version. Published schemas are immutable.

The build-to-API ledger is published at
`https://trails.warringtoneac.org/api/app-builds.json`. Each app also shows its
version, build number and pinned data API in Settings. When either app's build
number or API constant changes, update `server/api/app-builds.json` in the same
commit. `scripts/validate_app_builds.py` and the **Check mobile build API
mapping** workflow reject a mismatch.

The original `/warrington-trails.json` and `/talking-trails.kml` URLs remain for
already-installed builds. Publishing a new API version must not replace or
remove an older version that an installed app may still request.

## Beacons

Physical beacons on the trail are Radius Networks RadBeacon E4 units
broadcasting iBeacon (iOS) and AltBeacon (Android). The UUID/Major/Minor
codes and programming steps are documented in `android/README.md`.
Both locations have live beacons in the Android app: Major 17 for
Lions Pride Park and Major 20 for the US202 to Bradford Dam trail. The
Minor code for each beacon matches a landmark `id` in
`warrington-trails.json`.

## How to add a new location

> **Migration status:** This guide describes the unified string Trail ID format
> in `warrington-master-trail-id-format.xlsx`. The deployed generator and mobile
> apps still use the legacy numeric trail ID plus `trailGroupId` format. Do not
> publish a workbook that uses this new format until the generator and both apps
> have been migrated.

The KML file is the source of truth for coordinates and route geometry. The
master spreadsheet is the source of truth for descriptions, images, beacon
numbers, trail membership, stop order and walking instructions.

1. Choose a unique, permanent location ID made from lowercase words separated
   by hyphens, such as `lions-pride-park`. Do not change it when the displayed
   location name changes.
2. Add a row to the Locations tab with the location ID, displayed name and
   street address.
3. Assign the location a beacon Major from `0` through `65535`. The combination
   of UUID and Major must be unique so the apps can distinguish this location's
   beacons from every other location.
4. Enter the location's `iBeacon UUID` and `AltBeacon UUID`. iOS uses the
   iBeacon value; Android reads both values. They may be the same if the
   hardware broadcasts the same UUID in both formats.
5. Download the current KML from
   `https://trails.warringtoneac.org/talking-trails.kml` and edit it in Google
   Earth. Put the exact location ID in the `location` field of every route and
   Point placemark belonging to the new location.
6. Add the location's trails using the next section. Beacon rows are optional;
   a location and its trails can be published without physical beacons.
7. Set `reviewStatus` to `Approved` only after the spreadsheet values and KML
   location fields are complete.

### How to make a new trail

1. Download the current KML from
   `https://trails.warringtoneac.org/talking-trails.kml` and edit it in Google
   Earth.
2. Choose a unique, permanent Trail ID made from lowercase words separated by
   hyphens, such as `upper-nike-trail`.
3. Add a row to the Trails tab with its Trail ID, location, displayed name,
   `isOpen` value, description and review status.
4. Draw the route in the KML. Put the same `trailId` on every LineString or
   Polygon placemark that belongs to the route. Multiple KML segments may share
   one Trail ID and will be combined into one app trail.
5. Leave the Beacons and Stop Content tabs unchanged if the trail has no beacon
   stops. The trail can still appear in the trail list and on the map.
6. Mark the trail `Approved` after its spreadsheet row and KML route are ready.

A trail does not need a beacon. A beacon does not need to be part of a trail.
They become associated when the beacon's Beacons row contains that trail's
`trailId` and its `stopOrder`.

### Add a beacon to a trail

1. Add or update a row on the Beacons tab. Give it a permanent, unique
   `recordKey` and a numeric Minor. Use the UUID and Major from the matching row
   on the Locations tab when programming the physical beacon.
2. Add a KML Point at the beacon's physical location with the same `recordKey`.
3. To make it a guided stop, enter the trail's string `trailId` and a consecutive
   `stopOrder` on the Beacons row. Begin at `1` and do not leave gaps within a
   trail.
4. Add a Stop Content row using the same Trail ID and KML `recordKey`. Enter the
   forward and reverse distances and instructions.
5. Ensure the beacon image exists in the public image library, use its full
   `https://trails.warringtoneac.org/...` URL in `imagePath`, and complete the
   description and accessibility text.
6. Set the affected rows to `Approved` only after the beacon has been programmed
   and the spreadsheet and KML values match.

For example, the following values make beacon `LP-3` the first guided stop on
Green Trail:

```text
Trails row:       Trail ID = green-trail
Beacons row:      recordKey = LP-3, Minor = 3001, trailId = green-trail, stopOrder = 1
KML route:        trailId = green-trail
KML Point:        recordKey = LP-3 (coordinates only)
Stop Content row: Trail ID = green-trail, KML recordKey = LP-3
```

If the Beacons row leaves `trailId` and `stopOrder` blank, the beacon remains a standalone
landmark. If a trail has no active Beacons with its Trail ID, it remains a normal mapped
trail without a beacon-guided tour.

### Update an existing trail

1. Download the current KML and edit it in Google Earth.
2. Keep the existing Trail ID unchanged. Treat it as permanent even if the
   displayed trail name changes.
3. Edit the route geometry. Every route segment belonging to the trail must
   retain the same `trailId`.
4. Update the matching row on the spreadsheet's Trails tab when its name,
   description, open status or other content changes.
5. Update any affected Beacons `trailId`/`stopOrder` values and Stop Content instructions.
6. Set `reviewStatus` to `Approved` only after the route, text and optional tour
   stops are complete.

### Field reference

The unified format uses one readable Trail ID everywhere, such as
`green-trail`:

| Field | Purpose |
| --- | --- |
| `location` | Permanent string that associates spreadsheet rows and KML placemarks with one park or trail area. |
| `Trail ID` | Stable string that identifies a trail in the spreadsheet, KML, server JSON and apps. |
| `recordKey` | Stable link between a Beacons row, a KML Point and an optional Stop Content row. |
| `Major` | Numeric code that distinguishes one location's beacons under its UUID. |
| `Minor` | Numeric identifier broadcast by an individual beacon. It does not identify a trail. |
| `stopOrder` | Position of an optional beacon stop within a guided trail tour. |
