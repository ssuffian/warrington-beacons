import fs from 'node:fs/promises';
import { pathToFileURL } from 'node:url';
import os from 'node:os';
import path from 'node:path';

let artifactTool;
try {
  artifactTool = await import('@oai/artifact-tool');
} catch {
  artifactTool = await import(pathToFileURL(`${os.homedir()}/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/@oai/artifact-tool/dist/artifact_tool.mjs`));
}
const { FileBlob, SpreadsheetFile } = artifactTool;

const [input, output] = process.argv.slice(2);
if (!input || !output) throw new Error('Usage: node scripts/link_master_image_urls.mjs INPUT.xlsx OUTPUT.xlsx');

const workbook = await SpreadsheetFile.importXlsx(await FileBlob.load(input));
const beacons = workbook.worksheets.getItem('Beacons');
const used = beacons.getUsedRange();
const headers = used.getRow(0).values[0];
const imageColumn = headers.indexOf('imagePath');
if (imageColumn < 0) throw new Error('Beacons.imagePath column not found');

const imageCells = beacons.getRangeByIndexes(1, imageColumn, used.rowCount - 1, 1);
imageCells.values = imageCells.values.map(([value]) => {
  const text = String(value ?? '').trim();
  if (!text || /^https?:\/\//i.test(text)) return [text];
  return [`https://trails.warringtoneac.org/${text.replace(/^\/+/, '')}`];
});
imageCells.format.font = { name: 'Arial', size: 10, color: '#0563C1', underline: true };

const guide = workbook.worksheets.getItem('Guide');
const guideUsed = guide.getUsedRange();
const guideRows = guideUsed.values;
const existingLibrary = guideRows.findIndex(row => row[0] === 'Image library');
const libraryRow = ['Image library', 'Browse and copy hosted image links: https://trails.warringtoneac.org/images/'];
if (existingLibrary >= 0) {
  guide.getRangeByIndexes(existingLibrary, 0, 1, 2).values = [libraryRow];
} else {
  const target = guide.getRangeByIndexes(guideUsed.rowCount, 0, 1, 2);
  target.values = [libraryRow];
  target.copyFrom(guide.getRangeByIndexes(guideUsed.rowCount - 1, 0, 1, 2), 'formats');
}

workbook.recalculate();
await fs.mkdir(path.dirname(output), { recursive: true });
await (await SpreadsheetFile.exportXlsx(workbook)).save(output);
console.log(`Saved ${output}`);
