"""Group an existing reconciliation workbook without replacing its editable data."""
import argparse
from decimal import Decimal, ROUND_HALF_UP
import json
import math
from pathlib import Path
from master_sheet import ROOT, tables


def coordinate_review(row, old):
    if not old or not row.get('sourceCoordinates'):
        return 'No source comparison', '', ''
    raw = row['sourceCoordinates'].split(', ')
    if '°' not in row['sourceCoordinates'] and (len(raw) != 2 or not all(raw)):
        return 'Incomplete source coordinates', '', 'Retained values are not a complete new measurement.'
    try:
        new = [Decimal(str(row[k])) for k in ('latitude', 'longitude')]
        before = [Decimal(str(old['coordinates'][k])) for k in ('latitude', 'longitude')]
        if new == before:
            return 'Unchanged', 0, 'Same numeric coordinates.'
        lat1, lon1, lat2, lon2 = map(math.radians, map(float, [*before, *new]))
        h = math.sin((lat2-lat1)/2)**2+math.cos(lat1)*math.cos(lat2)*math.sin((lon2-lon1)/2)**2
        distance = round(6371000*2*math.asin(min(1, math.sqrt(h))), 1)
        rounded = False
        if '°' not in row['sourceCoordinates']:
            source = [Decimal(v) for v in raw]
            rounded = all(a.quantize(Decimal(1).scaleb(b.as_tuple().exponent), rounding=ROUND_HALF_UP) == b for a,b in zip(before,source))
        if rounded:
            return 'Consistent with rounding', distance, 'Both source values equal the old coordinates rounded to the source precision. No relocation implied; retain precise app coordinates if rounding is confirmed.'
        return 'Changed beyond rounding', distance, 'Not explained by rounding to the source precision; confirm the measurement source or physical placement.'
    except (ValueError, ArithmeticError):
        return 'Cannot compare', '', 'Check coordinate format.'


def group(t, baseline):
    byid = {str(r['id']):r for r in baseline['landmarks']}
    members = {str(i):[] for i in range(1,7)}
    details=[]
    for r in t['Beacons']:
        old=byid.get(str(r['id'])) if r['appStatus']!='Draft' else None
        classification, distance, explanation = coordinate_review(r,old)
        groups=[]
        if r.get('carriedForwardFields'): groups.append('1')
        if r['recordKey'].startswith('EAC-'): groups.append('2')
        if r['appStatus']=='Active' and classification in ('Consistent with rounding','Changed beyond rounding','Cannot compare'): groups.append('3')
        if r['appStatus']=='Draft': groups.append('4')
        if r['appStatus']=='Retired' or r['recordKey'].startswith('JSON-') or r['recordKey'] in ('LP-7','LP-11','LP-13','LP-14','LP-19','LP-20'): groups.append('5')
        if any(s in r.get('reviewNotes','') for s in ('ID conflict:','Source ID ','Source has no numeric ID')): groups.append('6')
        r.update(reviewGroups=', '.join(groups),coordinateReview=classification,coordinateDifferenceMetres=distance,coordinateNote=explanation)
        if classification=='Consistent with rounding':
            r['reviewNotes']=r['reviewNotes'].replace('Coordinate change; confirm placement and affected trail stops.', 'Coordinates are consistent with rounding; no relocation implied.')
        # Routine retained asset notes remain in provenance, not individual blockers.
        r['reviewNotes']=r['reviewNotes'].replace('Existing image path retained; verify source image name refers to the same asset.', 'Existing image retained under group 1 policy.')
        for g in groups:
            members[g].append(r['recordKey'])
        details.append({'recordKey':r['recordKey'],'name':r['name'],'groups':', '.join(groups),'appStatus':r['appStatus'],'coordinateReview':classification,'differenceMetres':distance,'issue':r['reviewNotes'],'coordinateNote':explanation})
    specifications=[
        ('1','Retain existing content and images','Policy decision','Keep current photos and fill blank content from the app unless explicitly replaced. Treat carried values as provenance; inspect TBA/placeholder content separately.'),
        ('2','Define location codes','Mapping decision','Define WP, UN, LP, LN, EP, MCP, UP and Folly Rd. once. Confirm whether location means physical park or beacon configuration; Rain Barrels uses LP but source major 20.'),
        ('3','Establish coordinate provenance','Measurement decision','Confirm whether source coordinates were surveyed, estimated or rounded. Separate rounding matches from changes beyond rounding. Review larger changes first; route stops may differ from physical beacon placement.'),
        ('4','Keep planned additions as Draft','Backlog decision','22 Draft points are planned additions. Keep them out of app exports until ready. Missing descriptions, images and locations become backlog work, not 22 separate publication decisions.'),
        ('5','Confirm retirements and point splits','Content structure decision','Clarify DELETE: retire the app point or stop maintaining hardware? Review five proposed retirements, split content and two JSON-only route points together. Natural Slope is still referenced by a trail.'),
        ('6','Confirm hardware IDs and matches','Field evidence needed','Check five conflicts (Kids Mountain, Insects, Large Slides, Climbing Ladder, Purple Martin) and eight missing-ID matches against a current programming list or field scan.'),
    ]
    summary=[{'group':g,'decision':title,'type':kind,'affectedRecords':len(members[g]),'status':'Open','whatResolvesIt':action,'affectedRecordKeys':', '.join(members[g]),'resolution':''} for g,title,kind,action in specifications]
    rounding=sum(r['coordinateReview']=='Consistent with rounding' and r['appStatus']=='Active' for r in details)
    summary[2]['whatResolvesIt']+=f' Active points: {rounding} consistent with rounding; {len(members["3"])-rounding} other coordinate differences.'
    guide=t.get('Guide',[])
    guide.insert(0,{'topic':'Grouped review','guidance':'Start with the six decisions in Needs Review. Filter Review Details or Beacons by group for evidence. Groups overlap. No approvals, IDs, coordinates or app statuses were changed by grouping.'})
    guide.insert(1,{'topic':'Rounding test','guidance':'Consistent with rounding means BOTH original coordinates, rounded to the written decimal precision of the new source, exactly equal the new source values. This supports a rounding explanation but does not establish how the source was measured. DMS conversion is not classified as rounding.'})
    guide.insert(2,{'topic':'Applying decisions','guidance':'Group resolutions are a planning record. Apply agreed rules to the affected Beacons/Locations/Trails rows before running ingestion. Existing per-row approval checks remain in force; this grouping does not silently approve data.'})
    return {'Needs Review':summary,'Beacons':t['Beacons'],'Review Details':details,'Locations':t['Locations'],'Trails':t['Trails'],'Trail Coordinates':t['Trail Coordinates'],'Guide':guide}


if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('workbook');p.add_argument('output');a=p.parse_args()
    result=group(tables(a.workbook),json.loads((ROOT/'server/warrington-trails.json').read_text()))
    Path(a.output).write_text(json.dumps(result,ensure_ascii=False,indent=2))
    print(json.dumps(result['Needs Review'],indent=2))
