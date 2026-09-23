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
    "appStatus", "reviewStatus", "category", "sourceId", "sourceMajor",
    "sourceLocationCode", "description", "longDescription", "imagePath",
    "imageAlt", "isOpen", "trailDistanceDescription", "macAddress",
    "beaconPlacement", "sourceImageName", "sourceRow", "hardwareNotes",
    "decisionNotes",
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
            decision = "Kept active because Natural Slope is an existing Kids Mountain Trail stop."
        elif key in {"LP-9", "LP-10"}:
            row["appStatus"] = "Retired"
            decision = "Retired as explicitly requested by the source workbook."
        elif row["appStatus"] == "Draft":
            decision = "Approved as backlog; excluded from app data until content, location and hardware are ready."
        elif row["appStatus"] == "Retired":
            decision = "Approved as retired; excluded from app data."
        else:
            decision = "Existing app identity and content retained; KML is authoritative for coordinates."
        row["decisionNotes"] = decision
        beacons.append({k: row.get(k, "") for k in BEACON_COLUMNS})

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

    locations = [dict(r, reviewStatus="Approved") for r in old["Locations"]]
    trails = []
    for row in old["Trails"]:
        row = dict(row)
        row["kmlTrailGroupId"] = TRAIL_GROUPS[str(row["id"])]
        row["reviewStatus"] = "Approved"
        trails.append(row)

    decisions = [
        {"decision": "Location source of truth", "status": "Resolved", "resolution": "KML owns every point coordinate, route shape, trail membership and stop order. Google Earth is the location editor."},
        {"decision": "Spreadsheet source of truth", "status": "Resolved", "resolution": "The spreadsheet owns display text, beacon IDs and status, images, locations, trail text and turn-by-turn stop content."},
        {"decision": "Stable join", "status": "Resolved", "resolution": "recordKey joins Beacons and Stop Content rows to KML Point placemarks. kmlTrailGroupId joins Trails rows to KML route placemarks."},
        {"decision": "Existing app content", "status": "Resolved", "resolution": "Keep current descriptions and images unless the source explicitly replaces them."},
        {"decision": "Location codes", "status": "Resolved", "resolution": "Source location codes remain provenance. Existing matched records keep their established app location and beacon major; new Draft records remain unassigned until reviewed."},
        {"decision": "Planned additions", "status": "Resolved", "resolution": "Keep all planned additions as approved Draft rows, excluded from generated app data until activated."},
        {"decision": "Retirements", "status": "Resolved", "resolution": "Retire Tennis Courts and Small Mountain. Keep Climbing Ladder and Games retired. Keep Natural Slope active because it remains a tour stop."},
        {"decision": "Beacon identities", "status": "Resolved", "resolution": "Preserve existing app minor IDs for matched active records. Source IDs remain provenance; unresolved new/colliding IDs stay Draft or Retired."},
        {"decision": "Publishing", "status": "Resolved", "resolution": "A validator combines the published spreadsheet CSV tabs with KML into one atomic warrington-trails.json file consumed by both apps."},
    ]
    guide = [
        {"topic": "Edit locations", "guidance": "Open talking-trails.kml in Google Earth. Edit route shapes and Point locations there."},
        {"topic": "Edit content", "guidance": "Edit names, descriptions, images, beacon settings and status in this spreadsheet."},
        {"topic": "Join key", "guidance": "Never change recordKey casually. It is the stable link between a Beacons row, Stop Content and a KML Point."},
        {"topic": "Tour membership", "guidance": "On a KML Point, trailId selects the tour and stopOrder sets its order. A blank trailId means the point is not a tour stop."},
        {"topic": "Route mapping", "guidance": "Trails.kmlTrailGroupId must match trailGroupId on one or more KML route placemarks."},
        {"topic": "Draft rows", "guidance": "Draft and Retired rows stay in the master for planning/history but are excluded from the app JSON."},
        {"topic": "Review status", "guidance": "Every row must be Approved before the generator publishes. Content edits can be staged by changing reviewStatus to Needs Review."},
        {"topic": "Generated app data", "guidance": "The deployment workflow validates the sheet and KML together, then creates server/warrington-trails.json atomically."},
    ]
    return {
        "Guide": guide,
        "Beacons": beacons,
        "Locations": locations,
        "Trails": trails,
        "Stop Content": stop_content,
        "Decisions": decisions,
    }


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    args.output.write_text(json.dumps(finalize(args.source), indent=2, ensure_ascii=False) + "\n")


if __name__ == "__main__":
    main()
