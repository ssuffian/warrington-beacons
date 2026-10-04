"""Move tour membership from Beacons into Stop Content for the v3 Sheet layout.

This is an explicit one-time migration, not a fallback in release generation.
Existing column order is preserved: Stop Content gains Stop Order, Trails gains
Start/End recordKey, and the old Beacons membership columns are renamed so
editors can compare them before deleting them.
"""
import argparse
import json
from pathlib import Path
from master_sheet import canonical_trail_id, tables

OLD_TRAIL, OLD_ORDER = 'old trailId (unused)', 'old stopOrder (unused)'


def migrate(t):
    report = []
    memberships = {}
    for row in t['Beacons']:
        trail_id, order = canonical_trail_id(row.get('trailId')), str(row.get('stopOrder', '')).strip()
        if trail_id and order:
            memberships.setdefault(trail_id, []).append((int(order), row['recordKey']))
        elif trail_id:
            report.append(f"{row['recordKey']}: trail {trail_id} had no stopOrder; left off the tour")
    content = t['Stop Content']
    for row in content:
        row['trailId'] = canonical_trail_id(row.get('trailId'))
        row.setdefault('stopOrder', '')
    by_pair = {(r['trailId'], r['recordKey']): r for r in content}
    claimed = set()
    for trail_id, members in memberships.items():
        for number, (_, key) in enumerate(sorted(members), start=1):
            row = by_pair.get((trail_id, key))
            if row is None:
                # Carry directions over when the stop moved from one other trail.
                others = [r for r in content if r['recordKey'] == key and id(r) not in claimed
                          and (r['trailId'], key) not in {(t_, k) for t_, ms in memberships.items() for _, k in ms}]
                if len(others) == 1:
                    row = others[0]
                    report.append(f'{key}: moved Stop Content from {row["trailId"]} to {trail_id}; review its directions')
                    row['trailId'] = trail_id
                else:
                    row = {'trailId': trail_id, 'recordKey': key, 'forwardDistance': '', 'forwardInstructions': '',
                           'reverseDistance': '', 'reverseInstructions': '', 'stopOrder': ''}
                    content.append(row)
                    report.append(f'{key}: added blank Stop Content row on {trail_id}')
            row['stopOrder'] = str(number); claimed.add(id(row))
    for row in content:
        if id(row) not in claimed:
            report.append(f"{row['recordKey']}: Stop Content on {row['trailId']} has no Stop Order; set one or make it a trail start/end")
    trail_order = [canonical_trail_id(r.get('id')) for r in t['Trails']]
    content.sort(key=lambda r: (trail_order.index(r['trailId']) if r['trailId'] in trail_order else len(trail_order),
                                int(r['stopOrder']) if r['stopOrder'] else 10**6))
    # Write Trail IDs with the Trails tab spelling so the Sheet dropdown accepts them.
    spelling = {canonical_trail_id(r.get('id')): r.get('id') for r in t['Trails']}
    for r in content: r['trailId'] = spelling.get(r['trailId'], r['trailId'])
    t['Stop Content'] = [{k: r.get(k, '') for k in [*(k for k in content[0] if k != 'stopOrder'), 'stopOrder']} for r in content]
    for row in t['Trails']:
        row.setdefault('startRecordKey', ''); row.setdefault('endRecordKey', '')
    t['Beacons'] = [{(OLD_TRAIL if k == 'trailId' else OLD_ORDER if k == 'stopOrder' else k): v for k, v in r.items()}
                    for r in t['Beacons']]
    return t, report


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('source', type=Path, help='CSV folder from fetch_master_sheet.py or an .xlsx workbook')
    p.add_argument('output', type=Path, help='JSON input for build_master_workbook.mjs')
    args = p.parse_args()
    result, report = migrate(tables(args.source))
    args.output.write_text(json.dumps(result, indent=2, ensure_ascii=False))
    print('\n'.join(report))


if __name__ == '__main__': main()
