# Master Sheet and KML data flow

The two editable sources have separate responsibilities:

- **Google Earth/KML owns geometry:** every Point coordinate and route shape.
- **The master spreadsheet owns content:** names, descriptions, images, beacon
  IDs and status, location configuration, trail text, turn-by-turn wording,
  and the Beacons tab's optional `trailId` and `stopOrder`.

`recordKey` is the permanent join between a Beacons row, a Stop Content row and
a KML Point. `kmlTrailGroupId` joins a Trails row to one or more KML route
placemarks. Do not move coordinates or stop order back into the spreadsheet.

The updated local workbook, seeded from the public Sheet on September 30, is:

`outputs/beacon-trail-memberships-2026-09-30/warrington-master-review.xlsx`

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

Choose the existing API major version in the workflow. Content can change
within a major version, but field names, types and relationships cannot. A
breaking contract change requires implementing a new `/api/vN/` generator,
updating both apps, and adding that version to the workflow and
`server/api/versions.json` before it can be published.

The current contract is `server/api/v2/schema.json`. It uses the same string
Trail ID in the Trails sheet, Stop Content sheet, and KML `trailId` metadata.
The generator canonicalizes editor capitalization and spaces to lowercase
kebab-case. Trails with no associated beacons are valid and contain route
coordinates without embedded landmark stops. The frozen v1 contract remains at
`server/api/v1/schema.json` for installed v1 clients.

For a local validation run:

```sh
python3 scripts/master_sheet.py \
  outputs/beacon-trail-memberships-2026-09-30/warrington-master-review.xlsx \
  --kml server/talking-trails.kml \
  --api-version v2 \
  --output-dir outputs/master-membership-validation
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

On Beacons, set `trailId` to the Trail ID from Trails and `stopOrder` to its
position in the tour, beginning at 1 with no gaps. Leave both fields blank for
a standalone point. Each row supports one trail membership. Stop Content must
use that same Trail ID and `recordKey`. Old KML Point `trailId` and `stopOrder`
values are ignored by the generator; spreadsheet edits are authoritative.

For an existing Sheet without these columns, explicitly seed them from the KML
once (this never publishes data or overwrites existing membership edits):

```sh
python3 scripts/migrate_sheet_memberships.py /tmp/warrington-master-csv /tmp/master-memberships.json
node scripts/build_master_workbook.mjs /tmp/master-memberships.json outputs/master-memberships
```

Add the populated `trailId` and `stopOrder` columns to the live Beacons tab by
matching `recordKey`, and update the Guide instructions. Do not replace newer
Sheet content with an older workbook. Generation blocks if the columns are
missing, a Trail ID is unknown, an order is invalid, or stop content is unmatched.

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
Active Beacons require complete app content, a valid unique Minor, a known
location, an existing image file and a matching KML Point. Every active Beacon tour stop
requires one matching Stop Content row.

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
