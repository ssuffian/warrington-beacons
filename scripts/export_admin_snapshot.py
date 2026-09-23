"""Export read-only CSV fallback data; never edits a workbook or app JSON.

Usage: python3 scripts/export_admin_snapshot.py source.xlsm
       --source-url https://drive.google.com/file/d/.../view
"""
import argparse
import csv
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
from master_sheet import read_xlsx, ROOT

TABS = {'Beacons': 'beacons.csv', 'Locations': 'locations.csv',
        'Trails': 'trails.csv', 'Trail Stops': 'trail-stops.csv',
        'Needs Review': 'needs-review.csv', 'Review Details': 'review-details.csv'}

def export(source, out, source_url):
    sheets = read_xlsx(source, allow_cached_formulas=True)
    if 'Beacons' not in sheets:
        raise ValueError('Expected a Beacons tab; fallback not changed.')
    # Legacy geometry is NOT a second map source. Only keep landmark stop rows.
    if 'Trail Stops' not in sheets and 'Trail Coordinates' in sheets:
        rows = sheets['Trail Coordinates']
        headers = rows[0][1]
        fields = ['trailId', 'pointIndex', 'landmarkId', 'distanceToNextClockwise',
                  'distanceToNextClockwiseDescription', 'distanceToNextCounterClockwise',
                  'distanceToNextCounterClockwiseDescription']
        indices = [headers.index(f) for f in fields]
        stop_rows = [(1, ['Trail ID', 'Stop Order', 'Beacon Minor', 'Forward Distance',
                         'Forward Instructions', 'Reverse Distance', 'Reverse Instructions'])]
        orders = {}
        for rn, values in rows[1:]:
            values += [''] * len(headers)
            if values[indices[2]]:
                row = [values[i] for i in indices]
                orders[row[0]] = orders.get(row[0], 0) + 1
                row[1] = str(orders[row[0]])
                stop_rows.append((rn, row))
        sheets['Trail Stops'] = stop_rows
    out.mkdir(parents=True, exist_ok=True)
    files = {}
    for name, filename in TABS.items():
        if name not in sheets:
            continue
        rows = sheets[name]
        with (out / filename).open('w', newline='') as f:
            writer = csv.writer(f)
            width = len(rows[0][1])
            for _, values in rows:
                writer.writerow((values + [''] * width)[:width])
        files[name] = filename
    meta = dict(capturedAt=datetime.now(timezone.utc).isoformat(), sourceUrl=source_url,
                sourceSha256=hashlib.sha256(source.read_bytes()).hexdigest(),
                files=files, note='Fallback snapshot, not live. Cached formula values only; macros never executed.')
    (out / 'snapshot.json').write_text(json.dumps(meta, indent=2) + '\n')
    print(f'Exported {len(files)} fallback tables to {out}; source workbook unchanged.')

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path)
    parser.add_argument('--output', type=Path, default=ROOT / 'server/admin/data')
    parser.add_argument('--source-url', required=True)
    args = parser.parse_args()
    export(args.source, args.output, args.source_url)
