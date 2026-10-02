"""Prepare a workbook snapshot with editable beacon memberships seeded from KML.

This is an explicit one-time migration, not a fallback in release generation.
Existing spreadsheet membership values are never overwritten.
"""
import argparse
import json
from pathlib import Path
from master_sheet import ROOT, canonical_trail_id, read_kml, tables


def migrate(t, kml_path, api_version='v2'):
    points, _, errors = read_kml(kml_path, api_version)
    if errors:
        raise ValueError(str(errors))
    for row in t['Beacons']:
        point = points.get(row.get('recordKey'), {})
        trail_id = point.get('trailId', '')
        if api_version == 'v2': trail_id = canonical_trail_id(trail_id)
        if 'trailId' not in row and 'stopOrder' not in row:
            row['trailId'] = trail_id
            row['stopOrder'] = point.get('stopOrder', '') if trail_id else ''
        elif 'trailId' not in row or 'stopOrder' not in row:
            raise ValueError('Both membership columns must be present or absent')
    guidance = {
        'Start here': 'Edit content, beacon information, trail membership and stop order in this spreadsheet. Edit point locations and route shapes in Google Earth/KML.',
        'Optional tour stops': 'On Beacons, set trailId to the Trail ID on Trails and stopOrder to 1, 2, 3 and so on within that trail. Add a Stop Content row with the same Trail ID and recordKey. Leave both Beacons fields blank for a standalone point. A trail can have no beacon stops.',
        'Trail membership': 'Beacons trailId and stopOrder determine trail membership and sequence. Use the same Trail ID on Trails and Stop Content. Leave both fields blank for a standalone point.',
        'Geographic source': 'KML owns point coordinates and route shapes. The spreadsheet owns trail membership and stop order.',
    }
    guide = t.get('Guide') or [
        {'topic': 'Start here', 'guidance': guidance['Start here']},
        {'topic': 'Download KML', 'guidance': 'https://trails.warringtoneac.org/talking-trails.kml'},
        {'topic': 'Image library', 'guidance': 'https://trails.warringtoneac.org/images/'},
        {'topic': 'Join key', 'guidance': 'Keep recordKey unchanged. It links each Beacons row to its KML Point and Stop Content.'},
        {'topic': 'Review and release', 'guidance': 'Sheet edits remain drafts. Approve completed rows, then run Prepare trail data release and review its pull request before publication.'},
    ]
    for row in guide:
        if row.get('topic') in guidance: row['guidance'] = guidance[row['topic']]
        elif 'KML' in row.get('guidance', '') and ('stopOrder' in row['guidance'] or 'tour-stop order' in row['guidance']):
            row['guidance'] = guidance['Optional tour stops']
    if not any(row.get('topic') in ('Optional tour stops', 'Trail membership') for row in guide):
        guide.append({'topic': 'Trail membership', 'guidance': guidance['Trail membership']})
    t['Guide'] = guide
    return {name: t[name] for name in ('Guide', 'Beacons', 'Locations', 'Trails', 'Stop Content')}


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('source', type=Path)
    p.add_argument('output', type=Path, help='JSON input for build_master_workbook.mjs')
    p.add_argument('--kml', type=Path, default=ROOT/'server/talking-trails.kml')
    p.add_argument('--api-version', choices=('v1', 'v2'), default='v2')
    args = p.parse_args()
    args.output.write_text(json.dumps(migrate(tables(args.source), args.kml, args.api_version), indent=2, ensure_ascii=False))


if __name__ == '__main__': main()
