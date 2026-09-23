"""Inventory KML geometry and compare point candidates to the editable master."""
import argparse
import csv
import json
import math
from pathlib import Path
import re
import xml.etree.ElementTree as ET
from master_sheet import tables

NS={'k':'http://www.opengis.net/kml/2.2'}
ALIASES={'kids mt':'kids mountain','small mt':'small mountain','rope ladder':'climbing ladder',
 '3 small green slides':'small slides','2 main blue slides':'large slides',
 'gently sloping trail':'kids mountain trail','welcome to park':'park entrance',
 'pavillion':'pavilion','rain barrel':'rain barrels','native plant mgt area':'native plant management area',
 'native plant management':'native plant management area','bluebird and cavity nesting birds':'bluebird and cavity nesting bird program',
 'native vs invasives plants':'native plant vs invasive plants','water fowl':'waterfowl','nike missle':'nike missile'}


def norm(v):
    v=re.sub(r'[^a-z0-9 ]','',v.lower()).strip()
    return ALIASES.get(v,v)


def distance(a,b):
    la,lo,lb,ln=map(math.radians,[a[0],a[1],b[0],b[1]])
    h=math.sin((lb-la)/2)**2+math.cos(la)*math.cos(lb)*math.sin((ln-lo)/2)**2
    return round(12742000*math.asin(min(1,math.sqrt(h))),1)


def audit(kml,workbook,out):
    root=ET.parse(kml); beacons=tables(workbook)['Beacons']; matches=[];routes=[]
    for p in root.findall('.//k:Placemark',NS):
        name=p.findtext('k:name',default='',namespaces=NS); pid=p.get('id','')
        point=p.find('k:Point/k:coordinates',NS)
        if point is not None:
            metadata={d.get('name'):d.findtext('k:value',default='',namespaces=NS) for d in p.findall('k:ExtendedData/k:Data',NS)}
            linked_key=metadata.get('recordKey','').strip()
            lon,lat,*_=map(float,point.text.strip().split(',')); candidates=[]
            for b in beacons:
                if norm(b['name'])!=norm(name):continue
                try:d=distance((lat,lon),(float(b['latitude']),float(b['longitude'])))
                except ValueError:d=None
                candidates.append((d,b))
            candidates.sort(key=lambda x:float('inf') if x[0] is None else x[0])
            d,b=candidates[0] if candidates else (None,{})
            decision='No name match' if not b else ('Name match, no coordinates' if d is None else ('Likely same point' if d<=75 else 'Name match, placement differs'))
            if len(candidates)>1 and (d is None or (candidates[1][0] is not None and abs(candidates[1][0]-d)<25)):
                decision='Ambiguous repeated name'
            nearby=[]
            for other in beacons:
                try: nearby.append((distance((lat,lon),(float(other['latitude']),float(other['longitude']))),other))
                except ValueError: pass
            nearby.sort(key=lambda v:v[0])
            if nearby and nearby[0][0]<=3 and (d is None or d>75):
                d,b=nearby[0]
                decision='Same coordinates, different name'
            if linked_key:
                linked=[row for row in beacons if row['recordKey']==linked_key]
                if len(linked)==1:
                    b=linked[0]
                    try:d=distance((lat,lon),(float(b['latitude']),float(b['longitude'])))
                    except ValueError:d=None
                    decision='Linked by recordKey'
                else:
                    b={}
                    d=None
                    decision='Invalid recordKey link'
            matches.append(dict(kmlId=pid,linkedRecordKey=linked_key,kmlName=name,latitude=lat,longitude=lon,comparison=decision,
                candidateRecord=b.get('recordKey',''),candidateName=b.get('name',''),candidateMinor=b.get('id',''),
                appStatus=b.get('appStatus',''),distanceMetres='' if d is None else d,
                alternatives='; '.join(f'{v["recordKey"]}: {n} m' for n,v in candidates[1:])))
        for kind,path in [('LineString','.//k:LineString/k:coordinates'),('Polygon boundary','.//k:Polygon/k:outerBoundaryIs/k:LinearRing/k:coordinates')]:
            for c in p.findall(path,NS):
                pairs=[list(map(float,x.split(','))) for x in c.text.split()]
                metadata={d.get('name'):d.findtext('k:value',default='',namespaces=NS) for d in p.findall('k:ExtendedData/k:Data',NS)}
                routes.append(dict(kmlId=pid,name=name,trailGroupId=metadata.get('trailGroupId',''),location=metadata.get('location',''),geometry=kind,vertices=len(pairs),start=pairs[0][:2],end=pairs[-1][:2]))
    out.mkdir(parents=True,exist_ok=True)
    for name,rows in [('kml-point-comparison.csv',matches),('kml-route-inventory.csv',routes)]:
        with (out/name).open('w',newline='') as f:
            w=csv.DictWriter(f,fieldnames=list(rows[0]));w.writeheader();w.writerows(rows)
    used={r['candidateRecord'] for r in matches if r['candidateRecord']}
    summary={'pointCount':len(matches),'routeGeometries':len(routes),'uniqueRouteNames':len({r['name'] for r in routes}),
        'comparisons':{k:sum(r['comparison']==k for r in matches) for k in {r['comparison'] for r in matches}},
        'pointsWithoutCandidate':[r['kmlName'] for r in matches if not r['candidateRecord']],
        'sheetWithoutCandidate':[{'recordKey':b['recordKey'],'name':b['name']} for b in beacons if b['recordKey'] not in used],
        'retiredCandidates':[r['kmlName'] for r in matches if r['appStatus']=='Retired'],
        'note':'recordKey links are authoritative cross-file identities. Unlinked name/alias and distance matches remain candidates only. KML IDs are technical Google Earth identifiers, not beacon minors.'}
    (out/'summary.json').write_text(json.dumps(summary,indent=2));print(json.dumps(summary,indent=2))


if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('kml');p.add_argument('workbook');p.add_argument('output');a=p.parse_args()
    audit(a.kml,a.workbook,Path(a.output))
