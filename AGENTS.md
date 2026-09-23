# Repository instructions

## iOS TestFlight releases

Use the documented command-line release workflow in `ios/APP_STORE_RELEASE.md`.
This Apple team uses Xcode's automatic App Store signing during
`xcodebuild -exportArchive`; a local `Apple Distribution` keychain identity is
not required.

Create an unsigned Release archive with `CODE_SIGNING_ALLOWED=NO`, then export
or upload it with `-allowProvisioningUpdates` and the appropriate plist in
`ios/`. Do not first attempt a normally signed archive, open Xcode, ask the user
to create a distribution certificate, or infer that signing assets disappeared
because `security find-identity` has no `Apple Distribution` entry. That path
selects development signing and can fail with the misleading “team has no
devices” error.

Before uploading, increment `CURRENT_PROJECT_VERSION` in both app target build
configurations, verify the archive's `CFBundleVersion`, and run the relevant
build/tests. Uploading is an external release action; only perform it when the
user requested the TestFlight upload.

## Master data and map releases

Treat `server/talking-trails.kml` as the sole source of geographic truth. Point
coordinates, route shapes, tour membership (`trailId`) and tour sequence
(`stopOrder`) belong in KML so they can be maintained in Google Earth. Never add
those fields back to the master spreadsheet.

Treat the master Sheet as the source of text, images, beacon IDs/status,
location configuration and directional instructions. Join a Sheet row to a KML
Point only with the stable `recordKey`; join Trails to route placemarks with
`kmlTrailGroupId`/`trailGroupId`. Do not guess a link from name or proximity.

Do not make either mobile app download live Sheet tabs independently. Generate
and validate the single atomic `server/warrington-trails.json` with
`scripts/master_sheet.py`; both apps already consume that file. A validation
failure must stop deployment and preserve the last successful app data.

Use the command-line workflows documented in `docs/master-sheet.md`. Do not open
Xcode or Google Earth merely to inspect or build files; use them only when the
user explicitly wants interactive editing in those apps.
