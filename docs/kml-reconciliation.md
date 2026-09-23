# Talking Trails KML reconciliation

Compared `server/talking-trails.kml` to the latest workbook at
`outputs/master-polished-linked-2026-09-16/warrington-master-review.xlsx`.

Point placemarks use the Beacons tab's stable `recordKey` in KML
`ExtendedData`. Google Earth/KML owns point locations and route geometry; the
workbook owns point text, hardware status, app inclusion and other metadata.
The KML placemark ID remains unchanged as a technical identifier.

## Ownership

- KML owns map route shapes, including disconnected segments.
- KML owns point locations. Spreadsheet Beacons retains the currently accepted
  coordinates for app export until KML-to-export synchronization is implemented.
- Spreadsheet Beacons owns point IDs/minors, names, text and status.
- Spreadsheet Trail Stops owns trail membership, order and directional text.
- A point does not need any trail membership to appear as an app landmark.

Do not import KML point markers as additional app landmarks or infer a beacon
minor from a Google Earth placemark ID. Point placemarks carry only the matching
spreadsheet `recordKey` as metadata. The opaque KML IDs are not the app's numeric
trail IDs.

Route placemarks now have explicit `location` and `trailGroupId` ExtendedData
and sit inside three location folders. These fields were added during local
reconciliation; they were not present in the Google Earth export. The 15
geometries remain separate. The three Mill Creek segments share
`mill-creek-preserve-trail`; both Kids Mt. segments share
`kids-mountain-trail`.

## Point comparison

The file contains 49 point placemarks. Each has a unique `recordKey` link to a
Beacons row. The links were established from 46 nearby name/alias matches and
three unique name matches with larger position differences. Identity and
placement remain separate: a linked point can still need a location review.

| KML point | Spreadsheet candidate | Difference |
| --- | --- | --- |
| Pollinator Garden (northern point) | EAC-3 / minor 2, Pollinator Habitat | 0.0 m (rounded to 0.1 m) |
| Reptiles | EAC-23 / source minor 22 | 1,967.5 m |
| Wetlands | EAC-13 / minor 12 | 129.7 m |
| Fish | EAC-14 / minor 13 | 91.2 m |

Correction applied: the northern placemark `00F04859784182B6B0D8` in the served
KML is now named Pollinator Habitat. Its coordinates are unchanged; the original
download in `data/trails/Talking Trails.kml` is preserved. The audit now reports
49 points linked by `recordKey`, including the three larger placement differences.

The other Pollinator Garden is 0.2 m from EAC-29. A name-only match incorrectly
suggested the northern point was 3.5 km away; it is instead a strong candidate
for Pollinator Habitat under a different name. Wetlands also has another spreadsheet row with no coordinates,
so its identity should not be inferred from distance alone.

Small Mt., Rope Ladder and Tennis Courts match rows proposed as Retired in the
spreadsheet. Rendering every KML pin would reintroduce those points.

Fifteen spreadsheet rows have no linked KML point: Green Trail,
Restrooms, Invasive Species, Natural Slope, Games, The Woods, Recycled Plastic
Furniture, Trash/Recycle, the new Wetlands row, Kiosk,
Corral Garden, Solitary Bees, School House, 202 Connector Trail and End of Trail.
Some are route markers or incomplete planned points. Absence from KML is not
evidence that a spreadsheet point should be deleted.

## Routes

There are 15 route shapes under 12 names:

- Outdoor Classroom Trail
- Emerson Preserve Trail
- Mill Creek Preserve Trail (three separate segments)
- Weisel Preserve Trail
- Route 202 Connector Trail
- Upper Nike Trail
- IPW Trail (Polygon boundary)
- Lower Nike Trail
- Green Trail
- Yellow Trail (Polygon boundary)
- Kids Mt. Trail (two separate segments)
- Kings Court Access

The KML groups six route geometries under Lions Pride Park, five under US-202,
and four Emerson/Mill Creek geometries under Trails Needing Location Review.
The admin location filter reads these KML fields directly.

The app currently has four selectable tours. In particular, its old 202
Connector route spans a much larger corridor than the newly labeled KML Route
202 Connector segment. Do not replace that entire tour by matching names.
The next navigation step is to identify which KML segments form each selectable
tour, their direction, and how the spreadsheet's ordered stops attach to them.
Separate route shapes should not be joined merely because their names match.

## Implementation and reproducibility

The KML is now under `server/`, which the existing Pages workflow publishes.
Android and iOS overview maps read its route shapes and ignore its point pins.
Landmark data and tour navigation retain their existing source until reviewed
master ingestion and route mapping are ready. This avoids guessing identities
or replacing a multi-segment tour with an incomplete shape.

Run the read-only comparison again with:

```sh
python3 scripts/audit_trail_kml.py server/talking-trails.kml outputs/master-with-trail-stops/warrington-master-review.xlsx outputs/kml-audit
```

The output directory contains point candidates, a route inventory and a summary.
No spreadsheet edits or deployment are performed by the audit.
