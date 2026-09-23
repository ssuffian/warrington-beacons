import fs from 'node:fs/promises';
import { FileBlob, SpreadsheetFile } from '@oai/artifact-tool';

const path = process.argv[2];
const wb = await SpreadsheetFile.importXlsx(await FileBlob.load(path));
const mappings = {
  'Beacons': {id:'Minor', sourceId:'Source Minor', sourceMajor:'Source Major'},
  'Locations': {beaconMajorCode:'Major', iBeaconUUID:'iBeacon UUID', altBeaconUUID:'AltBeacon UUID'},
  'Trail Coordinates': {landmarkId:'Beacon Minor'},
};
for (const [name,mapping] of Object.entries(mappings)) {
  const sheet = wb.worksheets.getItem(name);
  const header=sheet.getRangeByIndexes(0,0,1,sheet.getUsedRange().columnCount);
  header.values=[header.values[0].map(v=>mapping[v]??v)];
}
const guide=wb.worksheets.getItem('Guide');
const values=guide.getUsedRange().values;
const replacements=[['sourceMajor','Source Major'],['sourceId','Source Minor'],["Beacons `id`",'Beacons Minor'],['id is the proposed app ID/beacon minor','Minor is the proposed beacon minor (also the app point ID)'],['id and source','Minor and source'],['landmarkId','Beacon Minor']];
guide.getUsedRange().values=values.map(row=>row.map(value=>{
  if(typeof value!=='string') return value;
  for(const [from,to] of replacements) value=value.replaceAll(from,to);
  return value;
}));
wb.recalculate();
await (await SpreadsheetFile.exportXlsx(wb)).save(path);
for(const name of Object.keys(mappings)) {
  const sheet=wb.worksheets.getItem(name);
  const preview=await wb.render({sheetName:name,range:sheet.getRangeByIndexes(0,0,3,Math.min(8,sheet.getUsedRange().columnCount)).address.split('!').pop(),scale:1,format:'png'});
  await fs.writeFile('/private/tmp/renamed-'+name.replaceAll(' ','-')+'.png',new Uint8Array(await preview.arrayBuffer()));
}
console.log('Renamed beacon terminology in workbook headers and Guide.');
