"""Apply the approved reconciliation policy and emit the final master tables.

The spreadsheet owns editorial and beacon data. Geographic data is deliberately
excluded: ``recordKey`` joins each row to the authoritative KML Point.
"""
import argparse
import json
from pathlib import Path

from master_sheet import tables


TRAIL_GROUPS = {
    "1002": "yellow-trail",
    "3001": "green-trail",
    "3002": "kids-mountain-trail",
    "4001": "route-202-connector-trail",
}

BEACON_COLUMNS = (
    "recordKey", "name", "id", "location", "Status", "purchaseCount",
    "appStatus", "reviewStatus", "category", "description", "longDescription", "imagePath",
    "imageAlt", "isOpen", "trailDistanceDescription", "beaconPlacement",
)

LOCATION_COLUMNS = (
    "id", "name", "address", "beaconMajorCode", "iBeaconUUID",
    "altBeaconUUID", "reviewStatus",
)


def finalize(source: Path):
    old = tables(source)
    beacons = []
    for row in old["Beacons"]:
        row = dict(row)
        key = row["recordKey"]
        row["reviewStatus"] = "Approved"
        if key == "LP-17":
            row["appStatus"] = "Active"
        elif key in {"LP-9", "LP-10"}:
            row["appStatus"] = "Retired"
        beacons.append({k: row.get(k, "") for k in BEACON_COLUMNS})

    stop_content_columns = (
        "trailId", "recordKey", "forwardDistance", "forwardInstructions",
        "reverseDistance", "reverseInstructions",
    )
    if "Stop Content" in old:
        stop_content = [
            {k: row.get(k, "") for k in stop_content_columns}
            for row in old["Stop Content"]
        ]
    else:
        by_minor = {str(r["id"]): r["recordKey"] for r in beacons if str(r.get("id", ""))}
        stop_content = []
        for row in old["Trail Stops"]:
            minor = str(row["landmarkId"])
            stop_content.append({
                "trailId": row["trailId"],
                "recordKey": by_minor[minor],
                "forwardDistance": row.get("forwardDistance", ""),
                "forwardInstructions": row.get("forwardInstructions", ""),
                "reverseDistance": row.get("reverseDistance", ""),
                "reverseInstructions": row.get("reverseInstructions", ""),
            })

    locations = []
    for source_row in old["Locations"]:
        row = dict(source_row, reviewStatus="Approved")
        locations.append({k: row.get(k, "") for k in LOCATION_COLUMNS})
    trails = []
    for row in old["Trails"]:
        row = dict(row)
        row["kmlTrailGroupId"] = TRAIL_GROUPS[str(row["id"])]
        row["reviewStatus"] = "Approved"
        trails.append(row)

    guide = [
        {"topic": "Start here", "guidance": "Edit content and beacon information in this spreadsheet. Edit all map locations, routes and tour order in the KML file."},
        {"topic": "Download KML", "guidance": "https://trails.warringtoneac.org/talking-trails.kml"},
        {"topic": "Image library", "guidance": "https://trails.warringtoneac.org/images/"},
        {"topic": "Edit content", "guidance": "Edit names, descriptions, images, beacon settings and status in this spreadsheet."},
        {"topic": "Join key", "guidance": "Never change recordKey casually. It is the stable link between a Beacons row, Stop Content and a KML Point."},
        {"topic": "Tour membership", "guidance": "On a KML Point, trailId selects the tour and stopOrder sets its order. A blank trailId means the point is not a tour stop."},
        {"topic": "Route mapping", "guidance": "Trails.kmlTrailGroupId must match trailGroupId on one or more KML route placemarks."},
        {"topic": "Draft rows", "guidance": "Draft and Retired rows stay in the master for planning/history but are excluded from the app JSON."},
        {"topic": "Review status", "guidance": "Every row must be Approved before the generator publishes. Content edits can be staged by changing reviewStatus to Needs Review."},
        {"topic": "Generated app data", "guidance": "The deployment workflow validates the sheet and KML together, then creates server/warrington-trails.json atomically."},
        {"topic": "Editor view", "guidance": "Old-source reconciliation and import-audit columns are excluded. The visible columns are the fields external content, map and beacon editors may need."},
    ]
    return {
        "Guide": guide,
        "Beacons": beacons,
        "Locations": locations,
        "Trails": trails,
        "Stop Content": stop_content,
    }


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    args.output.write_text(json.dumps(finalize(args.source), indent=2, ensure_ascii=False) + "\n")


if __name__ == "__main__":
    main()
