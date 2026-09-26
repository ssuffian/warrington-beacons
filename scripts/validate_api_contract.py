#!/usr/bin/env python3
"""Validate versioned trail JSON against its published contract."""

import argparse
import json
from pathlib import Path

from jsonschema import Draft202012Validator


def _path(error):
    return '$' + ''.join(f'[{part}]' if isinstance(part, int) else f'.{part}' for part in error.absolute_path)


def validate_document(schema, document):
    """Return stable, human-readable schema and cross-record errors."""
    validator = Draft202012Validator(schema)
    errors = [f'{_path(error)}: {error.message}' for error in sorted(validator.iter_errors(document), key=lambda e: list(e.absolute_path))]
    if errors or not isinstance(document, dict):
        return errors

    locations = document.get('locations', [])
    landmarks = document.get('landmarks', [])
    trails = document.get('trails', [])

    def unique(rows, label):
        ids = [row.get('id') for row in rows if isinstance(row, dict)]
        duplicates = sorted({value for value in ids if ids.count(value) > 1}, key=str)
        for value in duplicates:
            errors.append(f'$.{label}: duplicate id {value!r}')

    unique(locations, 'locations')
    unique(landmarks, 'landmarks')
    unique(trails, 'trails')

    location_ids = {row.get('id') for row in locations if isinstance(row, dict)}
    landmark_ids = {row.get('id') for row in landmarks if isinstance(row, dict)}
    for label, rows in (('landmarks', landmarks), ('trails', trails)):
        for index, row in enumerate(rows):
            if isinstance(row, dict) and row.get('location') not in location_ids:
                errors.append(f'$.{label}[{index}].location: unknown location {row.get("location")!r}')
    for trail_index, trail in enumerate(trails):
        if not isinstance(trail, dict):
            continue
        for point_index, point in enumerate(trail.get('boundaryCoordinates', [])):
            if isinstance(point, dict) and 'landmarkId' in point and point['landmarkId'] not in landmark_ids:
                errors.append(
                    f'$.trails[{trail_index}].boundaryCoordinates[{point_index}].landmarkId: '
                    f'unknown landmark {point["landmarkId"]!r}'
                )
    return errors


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('schema', type=Path)
    parser.add_argument('documents', nargs='+', type=Path)
    args = parser.parse_args()

    schema = json.loads(args.schema.read_text())
    Draft202012Validator.check_schema(schema)
    failed = False
    for path in args.documents:
        errors = validate_document(schema, json.loads(path.read_text()))
        if errors:
            failed = True
            print(f'{path} does not satisfy {args.schema}:')
            for error in errors:
                print(f'  - {error}')
        else:
            print(f'{path} satisfies {args.schema}')
    return 1 if failed else 0


if __name__ == '__main__':
    raise SystemExit(main())
