"""Download the public master Google Sheet tabs as CSV files."""
import argparse
from pathlib import Path
from urllib.parse import quote
from urllib.request import urlopen

TABS = ("Beacons", "Locations", "Trails", "Stop Content")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("sheet_id")
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    for tab in TABS:
        url = f"https://docs.google.com/spreadsheets/d/{args.sheet_id}/gviz/tq?tqx=out:csv&sheet={quote(tab)}"
        data = urlopen(url, timeout=30).read()
        (args.output/f"{tab}.csv").write_bytes(data)
        print(f"Downloaded {tab}: {len(data)} bytes")


if __name__ == "__main__":
    main()
