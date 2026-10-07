# Master Sheet and KML data flow

The two editable sources have separate responsibilities:

- **Google Earth/KML owns geometry:** every Point coordinate and route shape.
- **The master spreadsheet owns content:** names, descriptions, images, beacon
  IDs and status, location configuration, trail text, turn-by-turn wording,
  tour stops and their order, and trail start/end points.

`recordKey` is the permanent join between a Beacons row, a Stop Content row and
a KML Point. Trails, Stop Content and KML route placemarks share the canonical
Trail ID. Do not move coordinates back into the spreadsheet.

The current local editor workbook, refreshed from the public Sheet on October 7
with the three missing route rows added, is:

`outputs/master/warrington-master-review.xlsx`

Overwrite this workbook for future revisions. Do not retain superseded
spreadsheet versions or their previews, inspection files, and export folders.

It contains Guide, Beacons, Locations, Trails and Stop Content tabs. Draft and
Retired rows remain in the master for ongoing planning and history but do not
enter app data.

The Guide tab stays first and includes direct links to the served KML and image
library. The external-editor workbook excludes old-source reconciliation fields
(`sourceId`, `sourceMajor`, `sourceLocationCode`, `sourceImageName`, `sourceRow`,
`decisionNotes`, `hardwareNotes`, `macAddress` and location `sourceCodes`). The
completed Decisions tab is also omitted. None of these are consumed by the
app-data generator. Join keys, KML route-group IDs, beacon placement/status and
review controls remain visible because outside editors may need them. Beacon
matching uses UUID, major and minor; the apps do not use hardware MAC addresses.

## Generation and deployment

Both mobile apps continue to read one atomic file:

`https://trails.warringtoneac.org/warrington-trails.json`

Spreadsheet edits are drafts and never update the live server automatically.
Run the **Prepare trail data release** GitHub workflow when a snapshot is ready.
It downloads the four public Sheet data tabs, validates them together with
`server/talking-trails.kml`, and opens a pull request containing the generated
JSON and KML snapshot. Review and merge that pull request to publish it. A
failed or partially edited source cannot create a release pull request.

For v2 and v3, every KML route with a canonical `trailId` must have a matching
row in the Trails tab, and every Trails row must have a matching KML route.
Missing rows block generation and identify each omitted Trail ID in the
validation report. Routes with no beacon stops remain valid. To keep a planned
route outside app data, do not assign it an app `trailId` in KML until its
approved Trails row is ready.

The workflow defaults to **all**, generating v2 and v3 from the same Sheet
snapshot; every version must validate before any is staged. Content can change
within a major version, but field names, types and relationships cannot. A
breaking contract change requires implementing a new `/api/vN/` generator,
updating both apps, and adding that version to the workflow and
`server/api/versions.json` before it can be published.

The current contract is `server/api/v3/schema.json`. Places use their
`recordKey` as `id`; `beaconMinor` appears only for a physical beacon. Trails may
carry beacon-free `start` and `end` points, and any number of tour stops,
including stops without beacons. v2 (`server/api/v2/schema.json`) is still
generated for installed v2 builds: it can only identify places by Minor, so it
omits places without a beacon, trail start/end points, and single-stop tours.

Both contracts use the same string
Trail ID in the Trails sheet, Stop Content sheet, and KML `trailId` metadata.
The generator canonicalizes editor capitalization and spaces to lowercase
kebab-case. Trails with no associated beacons are valid and contain route
coordinates without embedded landmark stops. The frozen v1 contract remains at
`server/api/v1/schema.json` for installed v1 clients.

For a local validation run:

```sh
python3 scripts/master_sheet.py \
  outputs/master/warrington-master-review.xlsx \
  --kml server/talking-trails.kml \
  --api-version v3 \
  --output-dir outputs/master-tour-stop-validation
```

The command writes `validation.csv`, `candidate.json` and `changes.diff` outside
the served directory. After review, `candidate.json` is the generated form of
`server/warrington-trails.json`.

The release workflow reads public Google Sheet tabs by name with:

```sh
python3 scripts/fetch_master_sheet.py SHEET_ID /tmp/warrington-master-csv
```

Required live tab names are Beacons, Locations, Trails and Stop Content.

## Editing rules

In Google Earth/KML, keep every Point's `recordKey`. Route placemarks use the
same canonical `trailId` as the Trails tab. A route may have no beacon stops.

Each Stop Content row is one tour stop: `Trail ID`, `KML recordKey`, the
directions and `Stop Order`. Number stops 1, 2, 3 … within each trail with no
gaps; renumber whenever a stop is inserted. A place may be a stop on several
trails. Forward directions lead to the next stop and Reverse directions lead to
the previous stop. A Beacons row that has no Stop Content row is a standalone
place.

On Trails, `Start recordKey` and `End recordKey` optionally name KML Points
where the trail begins and ends. They must not be active beacons, although they
may sit beside one. A Stop Content row for a start or end leaves `Stop Order`
blank: the start row's Forward columns lead to stop 1, and the end row's Reverse
columns lead back from the end to the last stop.

On Beacons, leave `Minor` blank for a place without a physical beacon. v3 lists
it with no `beaconMinor`; v2 omits it. A filled Minor must be unique.
`location` must be a Locations id, never a Trail ID.

To move an older Sheet whose Beacons tab still holds `trailId` and `stopOrder`
into this layout (this never publishes data):

```sh
python3 scripts/fetch_master_sheet.py SHEET_ID /tmp/warrington-master-csv
python3 scripts/migrate_tour_stops.py /tmp/warrington-master-csv /tmp/master-tour-stops.json
node scripts/build_master_workbook.mjs /tmp/master-tour-stops.json outputs/master-tour-stops
```

The migration keeps every existing column in place, appends `Stop Order` to
Stop Content and `Start recordKey`/`End recordKey` to Trails, renames the old
Beacons columns to `old trailId (unused)` and `old stopOrder (unused)`, and
prints every row that needs an editor's decision. Do not replace newer Sheet
content with an older workbook. Generation blocks if a Trail ID is unknown, a
Stop Order is missing or not consecutive, a stop is not an active Beacons row,
a Minor repeats, or a trail start/end is an active beacon.

Google Earth's web project export currently drops custom `ExtendedData`, even
though it retains each Placemark's stable `id`. Do not replace the served KML
with that download directly. Import it through the metadata-preserving command:

```sh
python3 scripts/import_google_earth_kml.py ~/Downloads/Talking\ Trails.kml
```

The importer copies names and geometry by Placemark ID, retains app join fields,
and keeps generated app points that are absent from the Earth project. It stops
if the export contains a new Placemark ID, since that item must first receive an
explicit `recordKey` or trail ID instead of being guessed from its name.

In the spreadsheet, set `reviewStatus` to Approved only when a row is ready.
Active Beacons require complete app content, a known
location, an existing image file and a matching KML Point. Minor is optional
and marks a physical beacon.

Use the public image library at `https://trails.warringtoneac.org/images/` to
browse available images and copy an image URL. Paste the full URL into the
Beacons tab's `imagePath` cell so it remains clickable in Google Sheets. The
validator accepts only HTTPS image URLs on `trails.warringtoneac.org`, confirms
that the file exists, and converts the URL back to the relative path expected by
existing app builds. Relative paths remain accepted during the transition.

Run the regression checks with:

```sh
python3 -m unittest discover -s scripts -p 'test_*.py'
```
