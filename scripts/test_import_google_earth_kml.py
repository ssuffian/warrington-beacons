import tempfile
import unittest
import xml.etree.ElementTree as ET
from pathlib import Path

from import_google_earth_kml import import_export

KML = "http://www.opengis.net/kml/2.2"
NS = {"k": KML}


class ImportGoogleEarthKmlTest(unittest.TestCase):
    def test_preserves_metadata_and_base_only_points(self):
        base = f'''<kml xmlns="{KML}"><Document>
          <Placemark id="earth"><name>Old</name><ExtendedData><Data name="recordKey"><value>A</value></Data></ExtendedData><Point><coordinates>-75,40,0</coordinates></Point></Placemark>
          <Placemark id="generated"><name>Generated</name><ExtendedData><Data name="recordKey"><value>B</value></Data></ExtendedData><Point><coordinates>-76,41,0</coordinates></Point></Placemark>
        </Document></kml>'''
        exported = f'''<kml xmlns="{KML}"><Document>
          <Placemark id="earth"><name>New</name><Point><coordinates>-75.1,40.1,0</coordinates></Point></Placemark>
        </Document></kml>'''
        with tempfile.TemporaryDirectory() as directory:
            directory = Path(directory)
            for name, value in (("base.kml", base), ("export.kml", exported)):
                (directory / name).write_text(value)
            renamed, preserved = import_export(
                directory / "base.kml", directory / "export.kml", directory / "out.kml"
            )
            root = ET.parse(directory / "out.kml").getroot()
            values = {p.get("id"): p for p in root.findall(".//k:Placemark", NS)}
            self.assertEqual(values["earth"].findtext("k:name", namespaces=NS), "New")
            self.assertEqual(values["earth"].findtext("k:ExtendedData/k:Data/k:value", namespaces=NS), "A")
            self.assertEqual(values["earth"].findtext("k:Point/k:coordinates", namespaces=NS), "-75.1,40.1,0")
            self.assertIn("generated", values)
            self.assertEqual(renamed, [("earth", "Old", "New")])
            self.assertEqual(preserved, ["generated"])


if __name__ == "__main__":
    unittest.main()
