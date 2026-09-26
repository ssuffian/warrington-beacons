# Warrington Trails data server

Static JSON served at `https://trails.warringtoneac.org/`. The hosting provider
may change, but releases always deploy committed files from `server/`.

## Versioned API

Mobile releases pin a major API version in the URL. A major version changes only
when the JSON or KML contract has a breaking change.

| Version | Status | JSON | KML | Trail identifier |
| --- | --- | --- | --- | --- |
| v1 | Legacy/current production | `/api/v1/trails.json` | `/api/v1/talking-trails.kml` | Numeric trail ID plus KML `trailGroupId` |
| v2 | Planned | `/api/v2/trails.json` | `/api/v2/talking-trails.kml` | Unified string Trail ID |

Each published version has a machine-readable JSON Schema at
`/api/vN/schema.json`. For v1, see `/api/v1/schema.json`. The release workflow
validates both the versioned response and its legacy alias against that schema
before opening a pull request.

Changing values, wording, coordinates, images, beacon assignments, or adding and
removing records does not require a version bump when the resulting document
still satisfies the current schema and its cross-record invariants. Changing a
field name or type, adding or removing a field, changing a required field,
changing an allowed enum value, or changing how records relate requires a new
major API version and corresponding app support. `additionalProperties: false`
makes accidental fields fail validation instead of silently expanding v1.
GitHub also treats every schema already present on `main` as immutable: a new
major version is added in a new directory instead of editing the old schema.

`/api/versions.json` lists only versions that have actually been published. Do
not create a placeholder v2 response: the new apps should receive a missing-file
error until the v2 generator, validation and fixtures are complete.

Content and trail status may change within a major version. Field names, field
types and relationships may not. Never point a released app at `latest`; pin it
to `/api/vN/` so a future schema migration cannot silently break installed
builds.

The legacy `/warrington-trails.json` and `/talking-trails.kml` endpoints remain
available for existing app builds. During the v1 period, an approved data-release
pull request updates both the legacy URLs and `/api/v1/`. Spreadsheet edits alone
update neither. A failed validation cannot create a release pull request.

## Image library

`https://trails.warringtoneac.org/images/` is a searchable library of every
JPG, PNG, WebP and GIF under each location's `images` directory. Its cards open
the full image and copy the absolute URL used in the master Sheet. Rebuild it
with `python3 scripts/build_image_library.py`; the Pages workflow runs that
command after generating JSON so landmark usage stays current.

The master Sheet may store either an existing relative image path or the full
`https://trails.warringtoneac.org/...` URL. Full URLs are preferred because
Google Sheets makes them clickable. The JSON generator validates the hosted
file and emits a relative path so already-installed app builds remain compatible.

## Read-only admin preview

`admin/index.html` adds `/admin/` to this same static server. It shows KML shapes
and points alongside the public Drive workbook, with clickable point text,
hardware status, optional trail stops, current-app comparisons and grouped
review issues. No login or write access is required. Remote edits are made via
the external sheet/Earth links; refresh never deploys changes to the app.

The page supports live XLSX/XLSM reads, CSV fallback and browser-only local-file
preview. Source freshness and suggested-versus-confirmed links are explicit.
See [admin preview setup and tests](../docs/admin-preview.md). No hosting
configuration was changed; deploy this `server/` directory through the existing
hosting setup when ready.

## Google Earth route geometry

`talking-trails.kml` is the served route source from the September 10, 2026
Talking Trails Google Earth export, with the northern Pollinator Garden renamed
Pollinator Habitat after coordinate reconciliation. After deployment it is
available at `https://trails.warringtoneac.org/talking-trails.kml`.

Both apps' overview maps fetch this file and draw its LineStrings and Polygon
boundaries. KML now owns all route geometry and Point coordinates. It also owns
tour membership and order through `trailId` and `stopOrder` on Point
placemarks. Multiple geometries with the same route group remain separate in
KML; the generator combines them for the selected tour's JSON route.

Route placemarks are grouped into Lions Pride Park, US-202 and Trails Needing
Location Review folders. Each route has `location` and `trailGroupId`
ExtendedData. Repeated Mill Creek and Kids Mt. geometries share their respective
group ID but remain separate shapes. Native apps currently ignore this metadata;
the admin location filter uses it.

Point placemarks store the master workbook's stable `recordKey` in
ExtendedData. Use Google Earth/KML to edit point locations, route geometry,
tour membership and stop order. Use the workbook for text, hardware status,
app inclusion, beacon configuration and directional wording.

`scripts/master_sheet.py` validates the workbook and KML together and generates
the atomic `warrington-trails.json` consumed by both apps. The manually started
**Prepare trail data release** workflow does the same from the public Sheet tabs
and opens a review pull request. Only merging that snapshot changes served app
data.

Update the served copy here for future deployments. `data/trails/Talking Trails.kml`
is the original import snapshot, not the active served source. Neither copying
the file nor changing app source publishes a deployment or updates installed
apps; a data-release pull request and new app builds are required.

- `warrington-trails.json` — combined file used by the Android app (one UUID,
  per-location major codes, all landmarks and trails)
- `us-202/us202trail-v2.json` — US-202 park file, used by the iOS app
- `lions-pride-park/lionsPrideData.json` — Lions Pride park file, used by the iOS app

## Beacon identifiers

Every physical beacon in both parks **dual-advertises iBeacon and AltBeacon
frames**, and the two frames do not necessarily carry the same UUID. The park is
distinguished by the **major** value and the landmark by the **minor** value
(minor = the landmark's `id` in the JSON); both frames carry the same
major/minor.

- **iBeacon UUID: `035a0617-0875-4cc7-a29c-be0caa8f557c`** (all beacons, both parks)
- **AltBeacon UUID: `00112233-4455-6677-8899-aabbccddeeff`** (Lions Pride
  hardware; US-202 hardware uses the iBeacon UUID on its AltBeacon frames too)

These live in the JSON as per-location `iBeaconUUID` / `altBeaconUUID` (on each
entry of `locations[]` in `warrington-trails.json`, and in the `site` section of
the per-park files). iOS ranges only iBeacon frames (CoreLocation limitation),
so it only needs `iBeaconUUID`; Android ranges **both** UUIDs per location so a
beacon is seen on whichever frame its hardware actually broadcasts.

| Park | Major | Minor | Landmark | Category |
|---|---|---|---|---|
| Lions Pride Park | 17 | 1002 | Yellow Trail | Trail |
| Lions Pride Park | 17 | 1003 | Kids Mountain | PointOfInterest |
| Lions Pride Park | 17 | 1009 | Park Entrance | PointOfInterest |
| Lions Pride Park | 17 | 1011 | Restrooms | Building |
| Lions Pride Park | 17 | 1012 | The Grove | PointOfInterest |
| Lions Pride Park | 17 | 1015 | Pavilion | Building |
| Lions Pride Park | 17 | 1016 | Tennis Courts | PointOfInterest |
| Lions Pride Park | 17 | 1017 | Small Mountain | PointOfInterest |
| Lions Pride Park | 17 | 2001 | Invasive Species and The Woods | PointOfInterest |
| Lions Pride Park | 17 | 2002 | Recycling | PointOfInterest |
| Lions Pride Park | 17 | 2003 | Small Slides and Rope Ladder | PointOfInterest |
| Lions Pride Park | 17 | 2004 | Green Trail Mid-Point | PointOfInterest |
| Lions Pride Park | 17 | 2005 | Bees | PointOfInterest |
| Lions Pride Park | 17 | 2006 | Butterflies | PointOfInterest |
| Lions Pride Park | 17 | 2007 | Natural Slope | PointOfInterest |
| Lions Pride Park | 17 | 3001 | Green Trail | Trail |
| Lions Pride Park | 17 | 3002 | Kids Mountain Trail | Trail |
| Lions Pride Park | 17 | 3003 | Green Trail Turn-off | PointOfInterest |
| Lions Pride Park | 17 | 3004 | Music Grove | PointOfInterest |
| Lions Pride Park | 17 | 3005 | Rain Garden | PointOfInterest |
| Lions Pride Park | 17 | 3006 | Recycled Plastic Furniture | PointOfInterest |
| Lions Pride Park | 17 | 3007 | Pollinator Plants | PointOfInterest |
| Lions Pride Park | 17 | 3008 | Insects | PointOfInterest |
| US-202 to Bradford Dam | 20 | 1 | Bluebird and cavity nesting bird program | PointOfInterest |
| US-202 to Bradford Dam | 20 | 2 | Pollinator Habitat | PointOfInterest |
| US-202 to Bradford Dam | 20 | 3 | Pet Waste | PointOfInterest |
| US-202 to Bradford Dam | 20 | 4 | Naturalized Basin | PointOfInterest |
| US-202 to Bradford Dam | 20 | 5 | Native Plant Management Area | PointOfInterest |
| US-202 to Bradford Dam | 20 | 6 | Rain Barrels | PointOfInterest |
| US-202 to Bradford Dam | 20 | 7 | Bluebird and cavity nesting bird program | PointOfInterest |
| US-202 to Bradford Dam | 20 | 8 | Native Plant vs Invasive Plants | PointOfInterest |
| US-202 to Bradford Dam | 20 | 9 | Native Plant Management Area | PointOfInterest |
| US-202 to Bradford Dam | 20 | 10 | Pet Waste | PointOfInterest |
| US-202 to Bradford Dam | 20 | 11 | Trees | PointOfInterest |
| US-202 to Bradford Dam | 20 | 12 | Wetlands | PointOfInterest |
| US-202 to Bradford Dam | 20 | 13 | Fish | PointOfInterest |
| US-202 to Bradford Dam | 20 | 14 | Meadows | PointOfInterest |
| US-202 to Bradford Dam | 20 | 15 | Waterfowl | PointOfInterest |
| US-202 to Bradford Dam | 20 | 16 | End of trail | PointOfInterest |
| US-202 to Bradford Dam | 20 | 4001 | 202 Connector Trail | Trail |

### Testing with these values

- **Android (debug builds):** drive fake detections without radio hardware via
  `FakeBeaconReceiver`, or watch real scans with
  `adb logcat -s BeaconScanner` (`Region park-beacons-<uuid>-<major>: N ranged` lines).
- **iOS (debug builds):** `./simulate_beacon.sh` at the repo root, or
  `xcrun simctl openurl booted "bradfordtrail://fakebeacon?minor=<minor>&distance=2.5"`.
  Note the simulator injection takes only a minor — majors aren't needed there
  since minors are unique across parks.
- **Field check:** a BLE scanner app (e.g. nRF Connect) at the park should show
  both advertisement frames with the UUIDs above and the major for that park;
  absence means dead hardware, not an app bug. If a beacon shows in the scanner
  app but never triggers ours, compare the UUID on **each frame** against the
  values here — a frame carrying an unexpected UUID means the app is filtering
  it out at the region match.
