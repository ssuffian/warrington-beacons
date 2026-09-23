"""Add the spreadsheet recordKey to matched KML point placemarks.

The comparison CSV remains the reviewed mapping authority. Route placemarks and
all geometry are left unchanged.
"""
import argparse
import csv
from html import escape
from pathlib import Path
import re


PLACEMARK = re.compile(r'(?P<indent>^[ \t]*)<Placemark\s+id="(?P<id>[^"]+)"[^>]*>.*?</Placemark>', re.MULTILINE | re.DOTALL)
RECORD_KEY = re.compile(r'<Data\s+name="recordKey"[^>]*>\s*<value>.*?</value>\s*</Data>', re.DOTALL)


def link(source, comparison, output):
    rows = list(csv.DictReader(comparison.open(newline='')))
    allowed = {'Likely same point', 'Name match, placement differs'}
    mapping = {
        row['kmlId']: row['candidateRecord'].strip()
        for row in rows
        if row['comparison'] in allowed and row['candidateRecord'].strip()
    }
    if len(mapping) != len(set(mapping.values())):
        raise ValueError('A spreadsheet recordKey is assigned to more than one KML point.')

    found = set()
    text = source.read_text()

    def add_record_key(match):
        block = match.group(0)
        kml_id = match.group('id')
        record_key = mapping.get(kml_id)
        if not record_key or '<Point>' not in block:
            return block
        found.add(kml_id)
        data = f'<Data name="recordKey"><value>{escape(record_key)}</value></Data>'
        if RECORD_KEY.search(block):
            return RECORD_KEY.sub(data, block, count=1)
        indent = match.group('indent') + '\t'
        extended = f'\n{indent}<ExtendedData>\n{indent}\t{data}\n{indent}</ExtendedData>'
        if '</name>' not in block:
            raise ValueError(f'KML point {kml_id} has no name element.')
        return block.replace('</name>', f'</name>{extended}', 1)

    linked = PLACEMARK.sub(add_record_key, text)
    missing = sorted(set(mapping) - found)
    if missing:
        raise ValueError(f'Mapped KML IDs were not found as points: {missing}')
    output.write_text(linked)
    print(f'Linked {len(found)} KML points by recordKey; geometry unchanged.')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path)
    parser.add_argument('comparison', type=Path)
    parser.add_argument('output', type=Path)
    args = parser.parse_args()
    link(args.source, args.comparison, args.output)
