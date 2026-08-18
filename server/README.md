# Warrington Trails data server

Static JSON served via GitHub Pages at `https://trails.warringtoneac.org/`.

- `warrington-trails.json` — combined file used by the Android app (one UUID,
  per-location major codes, all landmarks and trails)
- `us-202/us202trail-v2.json` — US-202 park file, used by the iOS app
- `lions-pride-park/lionsPrideData.json` — Lions Pride park file, used by the iOS app

## Beacon identifiers

Every physical beacon in both parks **dual-advertises iBeacon and AltBeacon
frames**, and the two frames do not necessarily carry the same UUID. The park is
distinguished by the **major** value and the landmark by the **minor** value
(minor = the landmark's `id` in the JSON); both frames carry the same
major/minor.

- **iBeacon UUID: `035a0617-0875-4cc7-a29c-be0caa8f557c`** (all beacons, both parks)
- **AltBeacon UUID: `00112233-4455-6677-8899-aabbccddeeff`** (Lions Pride
  hardware; US-202 hardware uses the iBeacon UUID on its AltBeacon frames too)

These live in the JSON as per-location `iBeaconUUID` / `altBeaconUUID` (on each
entry of `locations[]` in `warrington-trails.json`, and in the `site` section of
the per-park files). iOS ranges only iBeacon frames (CoreLocation limitation),
so it only needs `iBeaconUUID`; Android ranges **both** UUIDs per location so a
beacon is seen on whichever frame its hardware actually broadcasts.

| Park | Major | Minor | Landmark | Category |
|---|---|---|---|---|
| Lions Pride Park | 17 | 1002 | Yellow Trail | Trail |
| Lions Pride Park | 17 | 1003 | Kids Mountain | PointOfInterest |
| Lions Pride Park | 17 | 1009 | Park Entrance | PointOfInterest |
| Lions Pride Park | 17 | 1011 | Restrooms | Building |
| Lions Pride Park | 17 | 1012 | The Grove | PointOfInterest |
| Lions Pride Park | 17 | 1015 | Pavilion | Building |
| Lions Pride Park | 17 | 1016 | Tennis Courts | PointOfInterest |
| Lions Pride Park | 17 | 1017 | Small Mountain | PointOfInterest |
| Lions Pride Park | 17 | 2001 | Invasive Species and The Woods | PointOfInterest |
| Lions Pride Park | 17 | 2002 | Recycling | PointOfInterest |
| Lions Pride Park | 17 | 2003 | Small Slides and Rope Ladder | PointOfInterest |
| Lions Pride Park | 17 | 2004 | Green Trail Mid-Point | PointOfInterest |
| Lions Pride Park | 17 | 2005 | Bees | PointOfInterest |
| Lions Pride Park | 17 | 2006 | Butterflies | PointOfInterest |
| Lions Pride Park | 17 | 2007 | Natural Slope | PointOfInterest |
| Lions Pride Park | 17 | 3001 | Green Trail | Trail |
| Lions Pride Park | 17 | 3002 | Kids Mountain Trail | Trail |
| Lions Pride Park | 17 | 3003 | Green Trail Turn-off | PointOfInterest |
| Lions Pride Park | 17 | 3004 | Music Grove | PointOfInterest |
| Lions Pride Park | 17 | 3005 | Rain Garden | PointOfInterest |
| Lions Pride Park | 17 | 3006 | Recycled Plastic Furniture | PointOfInterest |
| Lions Pride Park | 17 | 3007 | Pollinator Plants | PointOfInterest |
| Lions Pride Park | 17 | 3008 | Insects | PointOfInterest |
| US-202 to Bradford Dam | 20 | 1 | Bluebird and cavity nesting bird program | PointOfInterest |
| US-202 to Bradford Dam | 20 | 2 | Pollinator Habitat | PointOfInterest |
| US-202 to Bradford Dam | 20 | 3 | Pet Waste | PointOfInterest |
| US-202 to Bradford Dam | 20 | 4 | Naturalized Basin | PointOfInterest |
| US-202 to Bradford Dam | 20 | 5 | Native Plant Management Area | PointOfInterest |
| US-202 to Bradford Dam | 20 | 6 | Rain Barrels | PointOfInterest |
| US-202 to Bradford Dam | 20 | 7 | Bluebird and cavity nesting bird program | PointOfInterest |
| US-202 to Bradford Dam | 20 | 8 | Native Plant vs Invasive Plants | PointOfInterest |
| US-202 to Bradford Dam | 20 | 9 | Native Plant Management Area | PointOfInterest |
| US-202 to Bradford Dam | 20 | 10 | Pet Waste | PointOfInterest |
| US-202 to Bradford Dam | 20 | 11 | Trees | PointOfInterest |
| US-202 to Bradford Dam | 20 | 12 | Wetlands | PointOfInterest |
| US-202 to Bradford Dam | 20 | 13 | Fish | PointOfInterest |
| US-202 to Bradford Dam | 20 | 14 | Meadows | PointOfInterest |
| US-202 to Bradford Dam | 20 | 15 | Waterfowl | PointOfInterest |
| US-202 to Bradford Dam | 20 | 16 | End of trail | PointOfInterest |
| US-202 to Bradford Dam | 20 | 4001 | 202 Connector Trail | Trail |

### Testing with these values

- **Android (debug builds):** drive fake detections without radio hardware via
  `FakeBeaconReceiver`, or watch real scans with
  `adb logcat -s BeaconScanner` (`Region park-beacons-<uuid>-<major>: N ranged` lines).
- **iOS (debug builds):** `./simulate_beacon.sh` at the repo root, or
  `xcrun simctl openurl booted "bradfordtrail://fakebeacon?minor=<minor>&distance=2.5"`.
  Note the simulator injection takes only a minor — majors aren't needed there
  since minors are unique across parks.
- **Field check:** a BLE scanner app (e.g. nRF Connect) at the park should show
  both advertisement frames with the UUIDs above and the major for that park;
  absence means dead hardware, not an app bug. If a beacon shows in the scanner
  app but never triggers ours, compare the UUID on **each frame** against the
  values here — a frame carrying an unexpected UUID means the app is filtering
  it out at the region match.
