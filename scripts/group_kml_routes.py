"""Group served KML routes by location and add stable route metadata."""
import argparse
from pathlib import Path
import xml.etree.ElementTree as ET

KML = 'http://www.opengis.net/kml/2.2'
GX = 'http://www.google.com/kml/ext/2.2'
NS = {'k': KML}
ET.register_namespace('', KML)
ET.register_namespace('gx', GX)

GROUPS = [
    ('routes-lions-pride-park', 'Lions Pride Park Trails', 'lions-pride-park', {
        'Outdoor Classroom Trail': 'outdoor-classroom-trail',
        'IPW Trail': 'ipw-trail',
        'Green Trail': 'green-trail',
        'Yellow Trail': 'yellow-trail',
        'Kids Mt. Trail': 'kids-mountain-trail',
    }),
    ('routes-us-202', 'US-202 Trails', 'us-202', {
        'Weisel Preserve Trail': 'weisel-preserve-trail',
        'Route 202 Connector Trail': 'route-202-connector-trail',
        'Upper Nike Trail': 'upper-nike-trail',
        'Lower Nike Trail': 'lower-nike-trail',
        'Kings Court Access': 'kings-court-access',
    }),
    ('routes-location-review', 'Trails Needing Location Review', 'unassigned', {
        'Emerson Preserve Trail': 'emerson-preserve-trail',
        'Mill Creek Preserve Trail': 'mill-creek-preserve-trail',
    }),
]

def route(pm):
    return pm.find('.//k:LineString', NS) is not None or pm.find('.//k:Polygon', NS) is not None

def add_data(parent, values):
    extended = ET.Element(f'{{{KML}}}ExtendedData')
    for key, value in values.items():
        data = ET.SubElement(extended, f'{{{KML}}}Data', {'name': key})
        ET.SubElement(data, f'{{{KML}}}value').text = value
    # Place metadata after styleUrl and before geometry for readable exports.
    children = list(parent)
    index = next((i for i, node in enumerate(children) if node.tag in
                  (f'{{{KML}}}LineString', f'{{{KML}}}Polygon', f'{{{KML}}}MultiGeometry')), len(children))
    parent.insert(index, extended)

def group_routes(source, output):
    tree = ET.parse(source); root = tree.getroot(); document = root.find('k:Document', NS)
    if document is None: raise ValueError('KML Document missing')
    if document.findall('k:Folder', NS): raise ValueError('KML already contains folders; review before regrouping')
    routes = [pm for pm in document.findall('k:Placemark', NS) if route(pm)]
    lookup = {name: (folder_id, folder_name, location, group_id)
              for folder_id, folder_name, location, names in GROUPS
              for name, group_id in names.items()}
    unknown = sorted({pm.findtext('k:name', default='', namespaces=NS) for pm in routes} - set(lookup))
    if unknown: raise ValueError('Unmapped KML routes: ' + ', '.join(unknown))
    if len(routes) != 15: raise ValueError(f'Expected 15 route geometries, found {len(routes)}')
    by_folder = {folder_id: [] for folder_id, *_ in GROUPS}
    for pm in routes:
        name = pm.findtext('k:name', default='', namespaces=NS)
        folder_id, _, location, group_id = lookup[name]
        if pm.find('k:ExtendedData', NS) is not None:
            raise ValueError(f'Route already has ExtendedData: {name}')
        document.remove(pm)
        add_data(pm, {'location': location, 'trailGroupId': group_id})
        by_folder[folder_id].append(pm)
    for folder_id, folder_name, location, _ in GROUPS:
        folder = ET.SubElement(document, f'{{{KML}}}Folder', {'id': folder_id})
        ET.SubElement(folder, f'{{{KML}}}name').text = folder_name
        add_data(folder, {'location': location, 'content': 'routeGeometry'})
        folder.extend(by_folder[folder_id])
    ET.indent(tree, space='\t')
    tree.write(output, encoding='UTF-8', xml_declaration=True, short_empty_elements=True)

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path); parser.add_argument('output', type=Path)
    args = parser.parse_args(); group_routes(args.source, args.output)
