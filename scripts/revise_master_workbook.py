"""Prepare the agreed spreadsheet-only revision from the latest review workbook."""
import argparse
from collections import defaultdict
import json
from pathlib import Path
from master_sheet import tables


STATUS_OPTIONS = ['Working', 'Needs reprogrammed', 'Missing', 'Broken', 'To be purchased']


def revise(t):
    stops = []
    orders = defaultdict(int)
    for p in t['Trail Coordinates']:
        if not p.get('landmarkId'):
            continue
        orders[p['trailId']] += 1
        stops.append({
            'trailId': p['trailId'], 'stopOrder': orders[p['trailId']],
            'landmarkId': p['landmarkId'],
            'forwardDistance': p.get('distanceToNextClockwise', ''),
            'forwardInstructions': p.get('distanceToNextClockwiseDescription', ''),
            'reverseDistance': p.get('distanceToNextCounterClockwise', ''),
            'reverseInstructions': p.get('distanceToNextCounterClockwiseDescription', ''),
        })
    for r in t['Beacons']:
        raw = r.pop('beaconStatus', '')
        previous = r.pop('previousBeaconStatus', '')
        note = []
        if raw: note.append('Latest source status: '+raw)
        if previous: note.append('Other source status: '+previous)
        s = raw.strip().lower()
        if 'reprogram' in s:
            status = 'Needs reprogrammed'
        elif 'broken' in s:
            status = 'Broken'
        elif 'missing' in s or "can't locate" in s:
            status = 'Missing'
            if "can't locate" in s:
                note.append('Mapped from cannot locate; absence has not been confirmed.')
        elif s == 'working':
            status = 'Working'
        elif s in ('needs beacon', 'to be purchased'):
            status = 'To be purchased'
        else:
            status = ''
            if s: note.append('No hardware status assigned: this source value is not a hardware condition.')
        r['Status'] = status
        # The two counts refer to the same requested devices, so do not add them.
        counts = []
        for field in ('purchaseCount', 'sourceNewBeaconCount'):
            value = str(r.get(field, '')).strip()
            if not value: continue
            try:
                n = float(value)
                if n < 0 or not n.is_integer(): raise ValueError()
                counts.append(int(n))
            except ValueError:
                note.append('Original '+field+': '+value)
        if len(set(counts)) > 1:
            note.append('Purchase counts disagree; retained higher count pending review.')
        r['purchaseCount'] = max(counts) if counts else ''
        r.pop('sourceNewBeaconCount', None)
        r['hardwareNotes'] = ' '.join(note)
    guide = []
    for r in t['Guide']:
        if r['topic'] in ('Status', 'Coordinates', 'IDs', 'Grouped review', 'Applying decisions'):
            continue
        r = dict(r)
        r['guidance'] = r['guidance'].replace('Trail Coordinates', 'Trail Stops')
        guide.append(r)
    guide = [
        {'topic':'Start here','guidance':'Use Beacons for points and Needs Review for six shared decisions. Trail Stops contains only the landmark-linked stops and their text. Full route geometry will come from a Google Earth file.'},
        {'topic':'Hardware status','guidance':'Status options: Working, Needs reprogrammed, Missing, Broken, To be purchased. Original status wording is retained in hardwareNotes. Cannot locate maps to Missing with an unconfirmed note. Blank status means no supported hardware condition was supplied.'},
        {'topic':'App inclusion','guidance':'App Inclusion is separate from hardware Status: Active is intended for app export, Draft is planned/incomplete, Retired is historical. Missing or broken hardware does not automatically hide a point. Review approval remains separate.'},
        {'topic':'Purchase count','guidance':'purchaseCount is the single quantity column. Duplicate old/new counts were not added together. Nonnumeric source notes, including DELETE, are preserved in hardwareNotes.'},
        {'topic':'Trail membership','guidance':'A point belongs to a location and may belong to zero, one or more trails. Trail Stops associates Trail ID with Beacon Minor. Stop Order begins at 1 within each trail. Points without stop rows are standalone points.'},
        {'topic':'Geometry','guidance':'No route geometry is maintained in this workbook. Trail Stops holds ordered Beacon Minor references and forward/reverse distances and instructions, preserving the existing clockwise/counterclockwise meanings. Beacons retains individual point coordinates. Google Earth geometry integration is a separate future step.'},
        {'topic':'Programming numbers','guidance':'Minor is the app point ID and the beacon minor to program. Source Minor and Source Major are original spreadsheet values retained for reconciliation. Locations supplies Major and UUID configuration. Trail ID is a route identifier, not a beacon number.'},
        {'topic':'Review workflow','guidance':'Resolve the six grouped decisions and apply them to the owning rows. Group resolutions do not automatically approve rows. This workbook remains a draft; no app data was published.'},
        {'topic':'Importer transition','guidance':'The earlier local importer expects full Trail Coordinates. This new workbook uses Trail Stops and requires a separate geometry integration before generating deployable JSON. Do not use stop-only rows as the complete route line.'},
    ] + guide
    del t['Trail Coordinates']
    t['Trail Stops'] = stops
    t['Guide'] = guide
    return {k:t[k] for k in ('Needs Review','Beacons','Review Details','Locations','Trails','Trail Stops','Guide')}


if __name__ == '__main__':
    p=argparse.ArgumentParser();p.add_argument('workbook');p.add_argument('output');a=p.parse_args()
    Path(a.output).write_text(json.dumps(revise(tables(a.workbook)),ensure_ascii=False,indent=2))
