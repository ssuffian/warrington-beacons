# Master Sheet and KML data flow

The two editable sources have separate responsibilities:

- **Google Earth/KML owns location:** every Point coordinate, every route shape,
  each point's optional `trailId`, and its `stopOrder`.
- **The master spreadsheet owns content:** names, descriptions, images, beacon
  IDs and status, location configuration, trail text, and turn-by-turn wording.

`recordKey` is the permanent join between a Beacons row, a Stop Content row and
a KML Point. `kmlTrailGroupId` joins a Trails row to one or more KML route
placemarks. Do not move coordinates or stop order back into the spreadsheet.

The final local workbook is:

`outputs/master-kml-source-of-truth-2026-09-23/warrington-master-review.xlsx`

It contains Guide, Beacons, Locations, Trails and Stop Content tabs. Draft and
Retired rows remain in the master for ongoing planning and history but do not
enter app data.

The Guide tab stays first and includes direct links to the served KML and image
library. The external-editor workbook excludes old-source reconciliation fields
(`sourceId`, `sourceMajor`, `sourceLocationCode`, `sourceImageName`, `sourceRow`,
`decisionNotes`, `hardwareNotes` and location `sourceCodes`). The completed
Decisions tab is also omitted. None of these are consumed by the app-data
generator. Join keys, KML route-group IDs, beacon maintenance fields and review
controls remain visible because outside editors may need them.

## Generation and deployment

Both mobile apps continue to read one atomic file:

`https://trails.warringtoneac.org/warrington-trails.json`

The Pages workflow downloads the four public Sheet data tabs, validates them
together with `server/talking-trails.kml`, and generates that JSON. A failed or
partially edited source cannot replace the last successful Pages deployment.
The scheduled job runs every 15 minutes; a manual workflow run is also available.

For a local validation run:

```sh
python3 scripts/master_sheet.py \
  outputs/master-kml-source-of-truth-2026-09-23/warrington-master-review.xlsx \
  --kml server/talking-trails.kml \
  --output-dir outputs/master-kml-validation-2026-09-23
```

The command writes `validation.csv`, `candidate.json` and `changes.diff` outside
the served directory. After review, `candidate.json` is the generated form of
`server/warrington-trails.json`.

The workflow reads public Google Sheet tabs by name with:

```sh
python3 scripts/fetch_master_sheet.py SHEET_ID /tmp/warrington-master-csv
```

Required live tab names are Beacons, Locations, Trails and Stop Content.

## Editing rules

In Google Earth, keep every Point's `recordKey`. A tour stop also needs integer
`trailId` and consecutive `stopOrder` values beginning at 1. Route placemarks
used by a selectable tour need the `trailGroupId` named in the Trails tab.

In the spreadsheet, set `reviewStatus` to Approved only when a row is ready.
Active Beacons require complete app content, a valid unique Minor, a known
location, an existing image file and a matching KML Point. Every KML tour stop
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
