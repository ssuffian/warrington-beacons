# Read-only admin preview

The existing static server now includes `/admin/` (`server/admin/index.html`).
No separate site, framework, login, backend, or deployment service was created.
Serve the existing `server/` directory as before. This works with a Vercel static
deployment whose output/root is `server`, and with the existing Pages workflow.
No Vercel project link is present in this checkout; deployment configuration was
not changed, and no commit, push or production deployment was performed.

## Sources and refresh

`server/admin/config.json` defines the public read URLs and external edit links:

- `sheetDataUrls`: published CSV URL for each Google Sheet tab. All configured
  tabs must load before one coherent live snapshot replaces the prior data.
- `sheetDataUrl`: backward-compatible single workbook download or CSV URL.
- `sheetFormat`: `workbook` for XLSX/XLSM; `csv` for a Beacons-only CSV.
- `sheetEditUrl`: shared file link opened by **Edit master sheet**.
- `kmlUrl`: `../talking-trails.kml`, the canonical served geometry.
- `earthEditUrl`: Google Earth. Replace with the team's actual Earth project URL
  when available. Until then, the page explains download/import/export steps.
- `appJsonUrl`: `../warrington-trails.json`, this site's current app baseline.
- `fallbackManifest`: CSV snapshot metadata and per-table paths.
- `refreshSeconds`: 60 by default; minimum 30. Refresh pauses in a hidden tab.

The supplied public Drive file is **Warrington Talking Trails Robot.xlsm**.
Its original Drive download endpoint was reachable without credentials, but the
actual browser GET was blocked by Google's CORS response during the September 12
live check. The workbook has now been published as a native Google Sheet. Its
seven tab-specific CSV endpoints allow browser reads and are configured as the
live source. No Google credentials, service account or proxy are used.
The preview reads workbook XML values only. Macros, external links and formulas
are never executed; any formula cells use saved results with a visible warning.
Do not place credentials or secrets in this public configuration or workbook.

The initial source snapshot was downloaded September 11, 2026 UTC. Its exact
capture time, source URL and SHA-256 are in `server/admin/data/snapshot.json`.
It has 64 Beacons, 2 Locations, 4 Trails, 30 extracted Trail Stops and 6 grouped
decisions. The remote workbook still uses the older headers and full Trail
Coordinates; both that layout and the newer friendly-column/Trail Stops layout
are accepted. Only landmark-linked legacy rows become stops. KML remains the
only route geometry used by the preview. Original values remain available in
Sheet tables. Hardware labels are normalized for display with source wording
retained in point details; counts are not silently consolidated by the preview.

Refresh reads the remote workbook, KML and app JSON independently. Failures are
visible. A failed workbook refresh retains the last successful data and labels
it stale, or uses the CSV snapshot if no live data has loaded. Failure to read
KML or app JSON never claims their checks completed successfully.

A local CSV or XLSX/XLSM can be selected in **Sources & linking**. It stays in
memory in that browser tab, pauses live refresh and is never uploaded. A CSV
replaces Beacons only; supporting tables are explicitly labeled snapshots.
**Return to linked source** resumes remote reads. The same distinction applies
when configuring a future Google Sheets CSV export; use a public export for the
Beacons tab, not a `/edit` webpage. Public sharing alone may not enable an export
in every Google Workspace configuration. Failed reads fall back visibly.

To refresh the checked-in CSV fallback from a downloaded workbook:

```sh
python3 scripts/export_admin_snapshot.py /path/to/master.xlsm --source-url 'https://drive.google.com/file/d/FILE_ID/view'
```

This exports source values without modifying the workbook or app JSON. The
generated CSVs are app data intermediates, not a new editable master workbook.

## Linking and map behavior

The **Master vs app** view presents the current app JSON as the before side and
the master sheet as the proposed after side. It defaults to records that could
affect the next release and separates changed records, identity/location
mismatches, retirements and source-only records. Draft rows, unchanged records
and rounding notes have their own filters. Each record expands to show only its
changed app fields in side-by-side removed/added columns and links back to the
same point on the map. A same-Minor/different-location comparison is labeled an
identity warning and is never treated as a confirmed join.

Collapsed comparison rows show every applicable field tag, including Text,
Image, Location and Rounding note, in addition to the record's primary state.

The comparison summary starts with all records and the records changed by the
next release. Its four mutually exclusive change types—updated, identity
mismatch, leaving the app and present in only one source—add up to the changed
count. Every count is also a list filter; there is no separate dropdown. Search
narrows the selected count by text without changing its category.

When both sources contain different coordinates, the expanded record also has
an inline location map. Red marks the current app position, green marks the
master-sheet position and a dashed line shows the gap. Single-source records
show the one available position. This map explains the app-to-sheet diff only;
KML remains the final geographic authority. All comparison records start
collapsed. Opening a record closes the previously open record, removes its map
and initializes only the newly selected map.

The Review Issues view separates **Bulk decisions** from **Points to edit**.
Each bulk-decision card has a button that opens its `affectedRecordKeys` as a
filtered map review queue and selects the first point. The map displays the
active decision and affected-point count; **Leave review queue** restores all
points. Groups may overlap. Expanding a point-level check and selecting a point
continues to open that individual record directly on the map.

Point rows show every bulk-decision tag that includes the record, such as `D1`
and `D3`, rather than only the queue that was clicked. The active queue tag is
highlighted. Diff records likewise show their primary comparison tag plus the
Rounding note tag whenever both classifications apply.

Every KML point is shown, including draft and retired candidates, to support
review. Solid pins use KML coordinates. Hollow sheet-only pins use sheet
coordinates temporarily; rows without coordinates remain selectable in the
list. Missing/broken hardware does not automatically hide an app point.

Ordinary point filters hide trail lines so unrelated geometry does not remain on
the map. The Location filter is the exception: it reads the `location` metadata
on route placemarks, shows only those segments and fits the map to both trails
and matching points. The KML assigns six geometries to Lions Pride, five to
US-202, and the four Emerson/Mill Creek geometries to the unassigned-location
review queue. This route location is not an inference of beacon membership.

A permanent link is confirmed only by a unique Beacons `kmlPlacemarkId` (also
accepts `KML Placemark ID`) matching the KML Placemark `id`, or by KML
ExtendedData `recordKey` matching a unique sheet `recordKey`. Keep record keys
stable when sorting or renaming. Do not regenerate them from row numbers.
Conflicts and duplicate claims are not silently resolved.

Without an explicit link, normalized names/known spelling aliases and distance
suggest candidates. Near-exact coordinates (within 3 m) may suggest a differently
named point. Suggested links are never treated as approved identities. Distance
above 75 m flags placement for review, not an automatic correction. Confirmed
links can still have large coordinate differences and are still flagged.

The interface names these states in task-oriented language:

- **Possible match**: the KML point and sheet row probably describe the same
  place, but the relationship has not been saved.
- **Sheet row only**: no credible KML partner was found. This can be valid for a
  planned point or one whose geometry has not been added yet.
- **KML point only**: no credible sheet partner was found. This can be valid for
  geography that should not display app text.
- **ID confirmed**: the two sources share a unique permanent identity.
- **Link conflict**: an ID is missing, duplicated, contradictory or claimed more
  than once and must be reviewed manually.

Matched KML point placemarks carry the spreadsheet's stable `recordKey` in
`ExtendedData`. That human-readable ID is the preferred cross-file link: edit
point locations and route geometry in Google Earth/KML, and edit text, status,
hardware data and app inclusion in the workbook. The KML-generated placemark ID
remains available as a technical fallback. For an unlinked point, use **Copy KML
ID** and paste it into the Beacons row's `kmlPlacemarkId` cell until a reviewed
`recordKey` link is added to the KML.

The corrected northern Pollinator Habitat name is in the served KML. All 49 KML
points now have unique `recordKey` links. Three linked points still have larger
KML/sheet placement differences:
Reptiles (~1,967.5 m), Wetlands (~129.7 m) and Fish (~91.2 m). Seven app-to-sheet
coordinate differences are consistent with rounding on both axes; these are
listed separately, not confused with KML differences.

The public workbook moves Rain Barrels (EAC-7, Minor 6) to `lions-pride-park`,
while the app keeps it in `us-202`. Source Major remains 20 but Lions Pride's
Major is 17. This is flagged rather than silently joined by Minor alone.
Consequently this snapshot has 39 exact location-plus-Minor app matches, not 40.

Trail Stops is optional for an individual point. Separate KML route segments
are drawn independently; new geometry is not automatically a selectable app
tour. Tour-to-KML segment mapping and deployment ingestion remain separate work.

## Security and validation

The preview is public/read-only by design. It makes GET requests with no
credentials and has no save or deploy action. Sheet and KML strings are rendered
as text, not HTML. Images are restricted to this site's data directory. Remote
files are limited to 8 MB, expanded workbook XML to 24 MB, sheets to 5,000 rows
and 256 columns. DTD/entity declarations are rejected. Leaflet 1.9.4 and fflate
0.8.2 are vendored with their licenses; street-map tiles use OpenStreetMap with
attribution. The map overlays, tables and checks remain usable without tiles.

Local preview:

```sh
python3 -m http.server 8765 --bind 127.0.0.1 --directory server
```

Open `http://127.0.0.1:8765/admin/`. Browser tests require Playwright available
to Node (via installation or `NODE_PATH`):

```sh
node scripts/test_admin_preview.mjs --workbook /path/to/downloaded-public-master.xlsm
```

The supplied workbook fixture is optional; without it the suite exercises initial
CSV fallback. Tests cover the expected snapshot counts, identity conflicts,
rounding, placement gaps, filters, tables, stale/fallback handling, temporary
local import, invalid-file preservation, HTML injection safety, mobile overflow,
and absence of write requests. Counts are snapshot assertions and should be
updated intentionally when the fallback dataset changes.
