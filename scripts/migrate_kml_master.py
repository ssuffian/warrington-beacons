"""One-time migration that makes KML authoritative for points and tour order."""
import argparse
import json
import xml.etree.ElementTree as ET
from pathlib import Path

from master_sheet import tables
from finalize_master import finalize

KML = "http://www.opengis.net/kml/2.2"
NS = {"k": KML}
ET.register_namespace("", KML)


def data_map(pm):
    return {d.get("name"): d.findtext("k:value", "", NS) for d in pm.findall("k:ExtendedData/k:Data", NS)}


def set_data(pm, name, value):
    ext = pm.find("k:ExtendedData", NS)
    if ext is None:
        ext = ET.SubElement(pm, f"{{{KML}}}ExtendedData")
    node = next((d for d in ext.findall("k:Data", NS) if d.get("name") == name), None)
    if node is None:
        node = ET.SubElement(ext, f"{{{KML}}}Data", {"name": name})
        ET.SubElement(node, f"{{{KML}}}value")
    node.find("k:value", NS).text = str(value)


def migrate(workbook: Path, source: Path, output: Path):
    source_tables = tables(workbook)
    final = finalize(workbook)
    source_by_key = {r["recordKey"]: r for r in source_tables["Beacons"]}
    final_by_key = {r["recordKey"]: r for r in final["Beacons"]}
    old_by_minor = {str(r["id"]): r["recordKey"] for r in final["Beacons"] if str(r.get("id", ""))}
    stops = {
        old_by_minor[str(r["landmarkId"])]: (r["trailId"], r["stopOrder"])
        for r in source_tables["Trail Stops"]
    }

    tree = ET.parse(source)
    root = tree.getroot()
    document = root.find("k:Document", NS)
    points = {}
    for pm in root.findall(".//k:Placemark", NS):
        if pm.find("k:Point", NS) is not None:
            key = data_map(pm).get("recordKey")
            if key:
                points[key] = pm

    # Seed only missing active points from the last reviewed coordinate set.
    for key, row in final_by_key.items():
        if row["appStatus"] != "Active" or key in points:
            continue
        source_row = source_by_key[key]
        pm = ET.Element(f"{{{KML}}}Placemark")
        ET.SubElement(pm, f"{{{KML}}}name").text = row["name"]
        set_data(pm, "recordKey", key)
        point = ET.SubElement(pm, f"{{{KML}}}Point")
        ET.SubElement(point, f"{{{KML}}}coordinates").text = f'{source_row["longitude"]},{source_row["latitude"]},0'
        document.insert(0, pm)
        points[key] = pm

    for key, pm in points.items():
        if not pm.get("id"):
            pm.set("id", "point-" + "".join(c.lower() if c.isalnum() else "-" for c in key).strip("-"))
        if key in stops:
            trail_id, stop_order = stops[key]
            set_data(pm, "trailId", trail_id)
            set_data(pm, "stopOrder", stop_order)

    group_to_trail = {r["kmlTrailGroupId"]: r["id"] for r in final["Trails"]}
    for pm in root.findall(".//k:Placemark", NS):
        if pm.find("k:Point", NS) is None:
            group = data_map(pm).get("trailGroupId")
            if group in group_to_trail:
                set_data(pm, "trailId", group_to_trail[group])

    ET.indent(tree, space="  ")
    tree.write(output, encoding="utf-8", xml_declaration=True)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("workbook", type=Path)
    parser.add_argument("source", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    migrate(args.workbook, args.source, args.output)


if __name__ == "__main__":
    main()
