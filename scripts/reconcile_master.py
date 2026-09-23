"""Prepare a review workbook dataset from the supplied September master and app JSON."""
import argparse
import hashlib
import json
import re
from pathlib import Path
from master_sheet import ROOT, read_xlsx


def text(v):
    return re.sub(r'\s+', ' ', str(v or '')).strip()


def numeric_id(v):
    try: return int(float(v))
    except (ValueError, TypeError): return ''


def dms(v):
    values = re.findall(r'(\d+)°(\d+)\x27([\d.]+)"([NSEW])', v)
    if len(values) != 2: return '', ''
    return tuple(round((float(a)+float(b)/60+float(c)/3600)*(-1 if d in 'SW' else 1), 9) for a,b,c,d in values)


def prepare(source):
    data = json.loads((ROOT/'server/warrington-trails.json').read_text())
    sheets = read_xlsx(source, allow_cached_formulas=True)
    byid = {r['id']: r for r in data['landmarks']}
    # Explicit reviewed identity candidates, never automatic joins on reused IDs.
    lp_matches = {2:1002,3:3001,4:1009,5:1011,6:1012,7:1003,8:1015,
                  9:1016,10:1017,11:2001,13:2003,15:2005,16:2006,17:2007,
                  19:3002,21:3004,22:3005,23:3006,24:3007,25:3008,
                  26:2002,27:3003,28:2004}
    rows, used, review = [], set(), []
    keys = ['recordKey','appStatus','reviewStatus','id','sourceId','sourceMajor','location','sourceLocationCode','name','category','description','longDescription','latitude','longitude','imagePath','imageAlt','isOpen','trailDistanceDescription','beaconStatus','previousBeaconStatus','macAddress','beaconPlacement','purchaseCount','sourceNewBeaconCount','sourceImageName','sourceCoordinates','sourceRow','carriedForwardFields','reviewNotes']
    for sheet, entries in sheets.items():
        lp = sheet == 'Lions Pride'
        for rn, a in entries:
            a += ['']*30
            if rn == 1 or not a[8 if lp else 4]: continue
            sid = numeric_id(a[0])
            match = lp_matches.get(rn) if lp else (sid if sid in range(1,16) else None)
            old = byid.get(match, {})
            if old: used.add(match)
            deleted = lp and any(text(x).upper() == 'DELETE' for x in a[:16])
            name = a[8 if lp else 4]
            if name == 'DELETE': name = old.get('name', 'Unnamed retired record')
            lat, lon = a[14 if lp else 11], a[15 if lp else 12]
            source_coords = str(lat)+', '+str(lon)
            if '°' in str(lat): lat, lon = dms(lat)
            r = dict.fromkeys(keys, '')
            notes, carried = [], []
            r.update(recordKey=('LP-' if lp else 'EAC-')+str(rn), appStatus='Retired' if deleted else ('Active' if old else 'Draft'), reviewStatus='Needs Review', id=old.get('id', sid), sourceId=a[0], sourceMajor=a[1 if lp else 16], location=old.get('location', 'lions-pride-park' if lp else ''), sourceLocationCode='LP' if lp else a[5], name=name, category=a[9] if lp and not deleted else old.get('category','PointOfInterest'), description=a[11 if lp else 7], longDescription=a[10 if lp else 6], latitude=lat, longitude=lon, imageAlt=a[13 if lp else 9], imagePath=old.get('imagePath',''), isOpen=old.get('isOpen',''), trailDistanceDescription=old.get('trailDistanceDescription',''), beaconStatus=a[7 if lp else 2], previousBeaconStatus=a[3] if lp else '', macAddress=a[2 if lp else 1], beaconPlacement=a[5 if lp else 10], purchaseCount=a[6 if lp else 3], sourceImageName=a[12 if lp else 8], sourceCoordinates=source_coords, sourceRow=f'{sheet}!A{rn}:R{rn}')
            r['sourceNewBeaconCount'] = a[4] if lp else ''
            for k in ('description','longDescription','imageAlt','latitude','longitude'):
                if text(r[k]).upper() == 'DELETE': r[k] = ''
                oldval = old.get('coordinates',{}).get(k,'') if k in ('latitude','longitude') else old.get(k,'')
                if not text(r[k]) and oldval != '':
                    r[k] = oldval; carried.append(k)
            if old:
                carried += ['imagePath']
                carried += [k for k in ('isOpen','trailDistanceDescription') if k in old]
                if sid and sid != match: notes.append(f'ID conflict: source {sid}, existing app {match}; confirm hardware before changing ID.')
                if not sid: notes.append(f'Source has no numeric ID; matched by name/context to app {match}.')
                if name != old['name']: notes.append('Proposed name: '+old['name']+' → '+name)
                if r['latitude'] != '' and r['longitude'] != '' and (float(r['latitude']),float(r['longitude'])) != (old['coordinates']['latitude'],old['coordinates']['longitude']):
                    notes.append('Coordinate change; confirm placement and affected trail stops.')
            else:
                notes.append('New or distinct source record; complete required fields and confirm ID/location before activating.')
                if sid in byid:
                    notes.append(f'Source ID {sid} is used by {byid[sid]["name"]}; resolve collision.')
                    r['id'] = ''
            if deleted: notes.append('Source requests deletion; retirement proposed. Check trail references.')
            if not lp: notes.append('Confirm mapping of source location code '+a[5]+'; existing app grouping retained where available.')
            if r['sourceImageName'] and old: notes.append('Existing image path retained; verify source image name refers to the same asset.')
            if rn == 25 and lp: notes.append('Source 6000/6001 appears to be temporary programming; confirm final major/minor.')
            r['carriedForwardFields'] = ', '.join(carried)
            r['reviewNotes'] = ' '.join(notes) or 'Review revised content and hardware status.'
            rows.append(r)
    for old in data['landmarks']:
        if old['id'] in used: continue
        r = dict.fromkeys(keys, '')
        r.update({k:v for k,v in old.items() if k in r})
        r.update(old['coordinates'])
        r.update(recordKey='JSON-'+str(old['id']), appStatus='Active', reviewStatus='Needs Review', sourceRow='Current JSON', carriedForwardFields='Entire record', reviewNotes='Absent from new source. Retained pending decision; may be a required trail endpoint.')
        rows.append(r)
    for r in rows:
        review.append({'recordKey':r['recordKey'],'name':r['name'],'issue':r['reviewNotes'],'resolution':'','instructions':'Resolve in Beacons, then set reviewStatus to Approved. Generated review list; not importer authority.'})
    locations = [dict(r, sourceCodes='', reviewStatus='Needs Review') for r in data['locations']]
    trails = [{k:v for k,v in tr.items() if k != 'boundaryCoordinates'} | {'reviewStatus':'Needs Review'} for tr in data['trails']]
    points = [dict(trailId=tr['id'], pointIndex=i+1, **p) for tr in data['trails'] for i,p in enumerate(tr['boundaryCoordinates'])]
    guide = [
        {'topic':'Main workflow','guidance':'Edit Beacons first. Resolve every Needs Review row. Approve locations and trails after checking references. Export XLSX and run the local importer.'},
        {'topic':'Status','guidance':'Active exports to the app. Draft and Retired stay in the workbook. Hardware condition is independent. All rows, including Draft/Retired, must be reviewed before export.'},
        {'topic':'IDs','guidance':'id is the proposed app ID/beacon minor. sourceId and sourceMajor preserve original programming claims. Do not change IDs without checking hardware and trail references.'},
        {'topic':'Source priority','guidance':'Populated new-source content is used. Blank fields may carry existing JSON values, listed in carriedForwardFields. Images retain known app paths pending review.'},
        {'topic':'Coordinates','guidance':'Decimal latitude/longitude. DMS source coordinates converted where supplied. Trail Coordinates retain existing geometry; pointIndex is 1-based and order is required.'},
        {'topic':'Location mapping','guidance':'WP, UN, LP, LN, EP, MCP, UP and Folly Rd. need agreed mappings. Physical park assignment does not by itself determine the beacon major. Locations currently own beacon configuration in the app schema.'},
        {'topic':'Approval','guidance':'Set reviewStatus to Approved only after resolving reviewNotes. Needs Review is a generated reference list; importer validates editable tabs directly.'},
        {'topic':'Source spreadsheet','guidance':'https://docs.google.com/spreadsheets/d/1DiAbtWsEwrTBxiYrukxt_zBlKWpq-MiX/edit'},
        {'topic':'App source','guidance':'https://trails.warringtoneac.org/warrington-trails.json'},
        {'topic':'Snapshot','guidance':'Prepared from downloaded September 10, 2026 sources. New master SHA256: '+hashlib.sha256(Path(source).read_bytes()).hexdigest()},
        {'topic':'Future Google sync','guidance':'Not connected yet. Intended writes: generated validation/review tabs and sync metadata only. Human-authored fields remain authoritative.'},
    ]
    return {'Beacons':rows,'Locations':locations,'Trails':trails,'Trail Coordinates':points,'Needs Review':review,'Guide':guide}


if __name__ == '__main__':
    p=argparse.ArgumentParser();p.add_argument('source');p.add_argument('output');args=p.parse_args()
    Path(args.output).write_text(json.dumps(prepare(args.source), ensure_ascii=False, indent=2))
