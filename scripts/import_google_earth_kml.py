"""Merge a Google Earth export into the metadata-bearing served KML.

Google Earth preserves Placemark IDs but drops the ExtendedData fields used to
join the KML to the master Sheet.  This importer copies edited names and
geometries by stable Placemark ID while retaining those application fields and
any generated points that do not exist in the Earth project.
"""
import argparse
import copy
import xml.etree.ElementTree as ET
from pathlib import Path

KML = "http://www.opengis.net/kml/2.2"
NS = {"k": KML}
GEOMETRY_TAGS = {
    f"{{{KML}}}{name}"
    for name in ("Point", "LineString", "Polygon", "MultiGeometry", "Model")
}

ET.register_namespace("", KML)


def placemarks(root):
    result = {}
    for placemark in root.findall(".//k:Placemark", NS):
        placemark_id = placemark.get("id")
        if not placemark_id:
            raise ValueError("Every Placemark must have an id")
        if placemark_id in result:
            raise ValueError(f"Duplicate Placemark id: {placemark_id}")
        result[placemark_id] = placemark
    return result


def import_export(base_path: Path, export_path: Path, output_path: Path):
    tree = ET.parse(base_path)
    base = placemarks(tree.getroot())
    exported = placemarks(ET.parse(export_path).getroot())

    unknown = sorted(exported.keys() - base.keys())
    if unknown:
        raise ValueError(
            "Google Earth contains new Placemark IDs with no app metadata: "
            + ", ".join(unknown)
        )

    renamed = []
    for placemark_id, source in exported.items():
        target = base[placemark_id]
        source_name = source.find("k:name", NS)
        target_name = target.find("k:name", NS)
        old_name = (target_name.text or "") if target_name is not None else ""
        new_name = (source_name.text or "") if source_name is not None else ""
        if source_name is not None:
            if target_name is None:
                target_name = ET.Element(f"{{{KML}}}name")
                target.insert(0, target_name)
            target_name.text = source_name.text
        if old_name != new_name:
            renamed.append((placemark_id, old_name, new_name))

        positions = [i for i, child in enumerate(target) if child.tag in GEOMETRY_TAGS]
        insert_at = positions[0] if positions else len(target)
        for position in reversed(positions):
            del target[position]
        for geometry in (child for child in source if child.tag in GEOMETRY_TAGS):
            geometry_copy = copy.deepcopy(geometry)
            for coordinates in geometry_copy.findall(".//k:coordinates", NS):
                coordinates.text = (coordinates.text or "").strip()
            target.insert(insert_at, geometry_copy)
            insert_at += 1

    preserved = sorted(base.keys() - exported.keys())
    ET.indent(tree, space="  ")
    tree.write(output_path, encoding="utf-8", xml_declaration=True)
    return renamed, preserved


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("export", type=Path, help="KML downloaded from Google Earth")
    parser.add_argument("--base", type=Path, default=Path("server/talking-trails.kml"))
    parser.add_argument("--output", type=Path, default=Path("server/talking-trails.kml"))
    args = parser.parse_args()
    renamed, preserved = import_export(args.base, args.export, args.output)
    for placemark_id, old, new in renamed:
        print(f"Renamed {placemark_id}: {old!r} -> {new!r}")
    print(f"Updated {len(placemarks(ET.parse(args.output).getroot())) - len(preserved)} exported placemarks")
    print(f"Preserved {len(preserved)} base-only placemarks: {', '.join(preserved) or 'none'}")


if __name__ == "__main__":
    main()
