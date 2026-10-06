import fs from 'node:fs/promises';
import os from 'node:os';
import { pathToFileURL } from 'node:url';

let artifactTool;
try {
  artifactTool = await import('@oai/artifact-tool');
} catch {
  const fallback = `${os.homedir()}/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/@oai/artifact-tool/dist/artifact_tool.mjs`;
  artifactTool = await import(pathToFileURL(fallback));
}
const { Workbook, SpreadsheetFile } = artifactTool;

const excludedColumns = {
  'Beacons': new Set(['sourceId','sourceMajor','sourceLocationCode','sourceImageName','sourceRow','decisionNotes','hardwareNotes','macAddress']),
  'Locations': new Set(['sourceCodes']),
};

const [input, output] = process.argv.slice(2);
const tables = JSON.parse(await fs.readFile(input, 'utf8'));
const wb = Workbook.create();
for (const [name, rows] of Object.entries(tables)) {
  const sheet = wb.worksheets.add(name);
  // Keep the editors' live column order exactly as provided.
  const headers = [...new Set(rows.flatMap(r => Object.keys(r)))]
    .filter(k => !excludedColumns[name]?.has(k));
  const labels={
    'Beacons':{id:'Minor',sourceId:'Source Minor',sourceMajor:'Source Major',appStatus:'App Inclusion'},
    'Trails':{startRecordKey:'Start recordKey',endRecordKey:'End recordKey'},
    'Locations':{beaconMajorCode:'Major',iBeaconUUID:'iBeacon UUID',altBeaconUUID:'AltBeacon UUID'},
    'Trail Stops':{trailId:'Trail ID',stopOrder:'Stop Order',landmarkId:'Beacon Minor',forwardDistance:'Forward Distance',forwardInstructions:'Forward Instructions',reverseDistance:'Reverse Distance',reverseInstructions:'Reverse Instructions'},
    'Stop Content':{trailId:'Trail ID',recordKey:'KML recordKey',stopOrder:'Stop Order',forwardDistance:'Forward Distance',forwardInstructions:'Forward Instructions',reverseDistance:'Reverse Distance',reverseInstructions:'Reverse Instructions'},
    'Trail Coordinates':{landmarkId:'Beacon Minor'},
  };
  const numeric=new Set(['id','sourceId','sourceMajor','trailId','landmarkId','pointIndex','stopOrder','beaconMajorCode','latitude','longitude','purchaseCount','sourceNewBeaconCount']);
  const values = [headers.map(k=>labels[name]?.[k]??k), ...rows.map(r => headers.map(k => {
    let v=r[k]??'';
    if(k==='imagePath' && v && !/^https?:\/\//i.test(String(v))) v=`https://trails.warringtoneac.org/${String(v).replace(/^\/+/, '')}`;
    if(v!=='' && numeric.has(k) && Number.isFinite(Number(v))) return Number(v);
    return v;
  }))];
  sheet.getRangeByIndexes(0,0,values.length,headers.length).values = values;
  const range = sheet.getUsedRange();
  range.format.font = {name:'Arial',size:10};
  range.format.rowHeight = 32;
  range.format.columnWidth = 22;
  range.format.verticalAlignment = 'top';
  range.format.wrapText = true;
  sheet.getRangeByIndexes(0,0,1,headers.length).format = {fill:'#24475A',font:{name:'Arial',bold:true,color:'#FFFFFF'},rowHeight:46};
  sheet.freezePanes.freezeRows(1);
  sheet.freezePanes.freezeColumns(name === 'Beacons' ? 1 : 0);
  sheet.showGridLines = false;
  sheet.tables.add(range.address.split('!').pop(),true,name.replaceAll(' ','')+'Table');
  for (let i=0;i<headers.length;i++) {
    const k=headers[i];const col=sheet.getRangeByIndexes(1,i,rows.length,1);
    if (['id','sourceId','sourceMajor','trailId','landmarkId','pointIndex','beaconMajorCode'].includes(k)) col.setNumberFormat('0');
    if (['latitude','longitude'].includes(k)) col.setNumberFormat('0.#########');
    if (['description','longDescription','reviewNotes','guidance','issue','instructions','carriedForwardFields','trailDistanceDescription','whatResolvesIt','affectedRecordKeys','coordinateNote','hardwareNotes','decisionNotes','resolution','forwardInstructions','reverseInstructions','whatChanged','actionNeeded'].includes(k) || k.endsWith('Description')) {
      col.format.columnWidth=70;
      for(let j=0;j<rows.length;j++) {
        const lines=String(rows[j][k]??'').split('\n').reduce((n,s)=>n+Math.max(1,Math.ceil(s.length/70)),0);
        const row=sheet.getRangeByIndexes(j+1,0,1,headers.length);
        row.format.rowHeight=Math.max(row.format.rowHeight || 32,lines*15+12);
      }
    }
    if (['name','sourceRow','imagePath','sourceCoordinates','decision','coordinateReview'].includes(k)) col.format.columnWidth=44;
    if (k==='imagePath') col.format.font = {name:'Arial',size:10,color:'#0563C1',underline:true};
    if (k==='reviewStatus') {col.dataValidation={rule:{type:'list',values:['Needs Review','Approved']}};col.conditionalFormats.add('containsText',{text:'Needs Review',format:{fill:'#FFF0C2'}});}
    if (k==='appStatus') col.dataValidation={rule:{type:'list',values:['Active','Draft','Retired']}};
    if (k==='Status') col.dataValidation={rule:{type:'list',values:['Working','Needs reprogrammed','Missing','Broken','To be purchased']}};
    if (k==='purchaseCount') col.dataValidation={rule:{type:'whole',operator:'greaterThanOrEqual',formula1:0}};
    if (name==='Beacons' && k==='trailId') {
      col.setNumberFormat('@');
      col.format.columnWidth=44;
      col.dataValidation={rule:{type:'list',values:tables.Trails.map(r=>String(r.id)).filter(Boolean)}};
    }
    if (name==='Stop Content' && k==='trailId') {
      col.setNumberFormat('@');
      col.dataValidation={rule:{type:'list',values:tables.Trails.map(r=>String(r.id)).filter(Boolean)}};
    }
    if (name==='Stop Content' && k==='stopOrder') {
      col.setNumberFormat('0');
      col.dataValidation={rule:{type:'whole',operator:'greaterThanOrEqual',formula1:1}};
    }
    if (name==='Beacons' && k==='location' || name==='Trails' && k==='location') {
      col.dataValidation={rule:{type:'list',values:tables.Locations.map(r=>String(r.id)).filter(Boolean)}};
    }
    if (name==='Beacons' && k.startsWith('old ')) col.format.fill='#EEEEEE';
    if (name==='Beacons' && k==='stopOrder') {
      col.setNumberFormat('0');
      col.dataValidation={rule:{type:'whole',operator:'greaterThanOrEqual',formula1:1}};
    }
  }
  if (name==='Guide') {
    for (let row=0; row<rows.length; row++) {
      if (/^https:\/\//.test(String(rows[row].guidance??''))) {
        sheet.getRangeByIndexes(row+1,1,1,1).format.font = {name:'Arial',size:10,color:'#0563C1',underline:true};
      }
    }
  }
}
wb.recalculate();
console.log((await wb.inspect({kind:'table',range:'Beacons!A1:H4',include:'values,formulas',tableMaxRows:4,tableMaxCols:8,maxChars:1800})).ndjson);
console.log((await wb.inspect({kind:'match',searchTerm:'#REF!|#DIV/0!|#VALUE!|#NAME\\?|#NUM!|#SPILL!',options:{useRegex:true,maxResults:10},maxChars:1000})).ndjson);
await fs.mkdir(output,{recursive:true});
await (await SpreadsheetFile.exportXlsx(wb)).save(output+'/warrington-master-review.xlsx');
for (const name of Object.keys(tables)) {
  const sheet=wb.worksheets.getItem(name);
  const preview=await wb.render({sheetName:name,range:sheet.getRangeByIndexes(0,0,Math.min(name==='Needs Review'?7:5,tables[name].length+1),Math.min(8,sheet.getUsedRange().columnCount)).address.split('!').pop(),scale:1,format:'png'});
  await fs.writeFile(output+'/'+name.replaceAll(' ','-')+'.png',new Uint8Array(await preview.arrayBuffer()));
}
console.log(JSON.stringify(Object.fromEntries(Object.entries(tables).map(([k,v])=>[k,v.length]))));
